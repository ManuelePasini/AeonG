// Copyright 2021 Memgraph Ltd.
//
// Use of this software is governed by the Business Source License
// included in the file licenses/BSL.txt; by using this file, you agree to be bound by the terms of the Business Source
// License, and you may not use this file except in compliance with the Business Source License.
//
// As of the Change Date specified in that file, in accordance with
// the Business Source License, use of this software will be governed
// by the Apache License, Version 2.0, included in the file
// licenses/APL.txt.

#include <algorithm>
#include <atomic>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <limits>
#include <map>
#include <string>
#include <thread>
#include <vector>

#include <gflags/gflags.h>
#include <json/json.hpp>

#include "communication/bolt/client.hpp"
#include "communication/bolt/v1/value.hpp"
#include "communication/init.hpp"
#include "utils/exceptions.hpp"
#include "utils/string.hpp"
#include "utils/timer.hpp"

DEFINE_string(address, "127.0.0.1", "Server address.");
DEFINE_int32(port, 7687, "Server port.");
DEFINE_string(username, "", "Username for the database.");
DEFINE_string(password, "", "Password for the database.");
DEFINE_bool(use_ssl, false, "Set to true to connect with SSL to the server.");

DEFINE_uint64(num_workers, 1, "Number of workers that should be used to concurrently execute the supplied queries.");
DEFINE_uint64(max_retries, 50, "Maximum number of retries for each query.");
DEFINE_bool(queries_json, false,
            "Set to true to load all queries as a single JSON encoded list. Each item in the list should contain another list whose first element is the query that should be executed and the second element should be a dictionary of query parameters for that query.");

DEFINE_string(input, "", "Input file. By default stdin is used.");
DEFINE_string(output, "", "Output file. By default stdout is used.");

std::pair<std::map<std::string, communication::bolt::Value>, uint64_t> ExecuteNTimesTillSuccess(
  communication::bolt::Client *client, const std::string &query,
  const std::map<std::string, communication::bolt::Value> &params, int max_attempts,
  std::vector<std::vector<communication::bolt::Value>> *results) {
for (uint64_t i = 0; i < max_attempts; ++i) {
  try {
    auto ret = client->Execute(query, params);
    *results = std::move(ret.records);  // ✅ CAMBIO QUI
    return {std::move(ret.metadata), i};
  } catch (const utils::BasicException &e) {
    if (i == max_attempts - 1) {
      LOG_FATAL("Could not execute query '{}' {} times! Error message: {}", query, max_attempts, e.what());
    } else {
      continue;
    }
  }
}
LOG_FATAL("Could not execute query '{}' {} times!", query, max_attempts);
}

communication::bolt::Value JsonToBoltValue(const nlohmann::json &data) {
  switch (data.type()) {
    case nlohmann::json::value_t::null:
      return {};
    case nlohmann::json::value_t::boolean:
      return {data.get<bool>()};
    case nlohmann::json::value_t::string:
      return {data.get<std::string>()};
    case nlohmann::json::value_t::number_integer:
      return {data.get<int64_t>()};
    case nlohmann::json::value_t::number_unsigned:
      return {static_cast<int64_t>(data.get<uint64_t>())};
    case nlohmann::json::value_t::number_float:
      return {data.get<double>()};
    case nlohmann::json::value_t::array: {
      std::vector<communication::bolt::Value> vec;
      vec.reserve(data.size());
      for (const auto &item : data.get<nlohmann::json::array_t>()) {
        vec.emplace_back(JsonToBoltValue(item));
      }
      return {std::move(vec)};
    }
    case nlohmann::json::value_t::object: {
      std::map<std::string, communication::bolt::Value> map;
      for (const auto &item : data.get<nlohmann::json::object_t>()) {
        map.emplace(item.first, JsonToBoltValue(item.second));
      }
      return {std::move(map)};
    }
    case nlohmann::json::value_t::binary:
    case nlohmann::json::value_t::discarded:
      LOG_FATAL("Unexpected JSON type!");
  }
}

nlohmann::json BoltValueToJson(const communication::bolt::Value &value) {
  if (value.type() == communication::bolt::Value::Type::Null) return nullptr;
  if (value.IsBool()) return value.ValueBool();
  if (value.IsInt()) return value.ValueInt();
  if (value.IsDouble()) return value.ValueDouble();
  if (value.IsString()) return value.ValueString();
  if (value.IsList()) {
    nlohmann::json j = nlohmann::json::array();
    for (const auto &item : value.ValueList()) {
      j.push_back(BoltValueToJson(item));
    }
    return j;
  }
  if (value.IsMap()) {
    nlohmann::json j = nlohmann::json::object();
    for (const auto &item : value.ValueMap()) {
      j[item.first] = BoltValueToJson(item.second);
    }
    return j;
  }
  LOG_FATAL("Unsupported Bolt value type!");
}
void Execute(const std::vector<std::pair<std::string, std::map<std::string, communication::bolt::Value>>> &queries,
             std::ostream *stream) {
  for (const auto &query : queries) {
    io::network::Endpoint endpoint(FLAGS_address, FLAGS_port);
    communication::ClientContext context(FLAGS_use_ssl);
    communication::bolt::Client client(&context);
    client.Connect(endpoint, FLAGS_username, FLAGS_password);

    std::vector<std::vector<communication::bolt::Value>> rows;
    auto ret = ExecuteNTimesTillSuccess(&client, query.first, query.second, FLAGS_max_retries, &rows);

    nlohmann::json result;
    result["query"] = query.first;
    result["parameters"] = BoltValueToJson({query.second});
    result["metadata"] = BoltValueToJson({ret.first});

    nlohmann::json data = nlohmann::json::array();
    for (const auto &row : rows) {
      nlohmann::json row_json = nlohmann::json::array();
      for (const auto &value : row) {
        row_json.push_back(BoltValueToJson(value));
      }
      data.push_back(row_json);
    }
    result["results"] = data;

    (*stream) << result.dump() << std::endl;
    client.Close();
  }
}

int main(int argc, char **argv) {
  gflags::ParseCommandLineFlags(&argc, &argv, true);

  communication::SSLInit sslInit;

  std::ifstream ifile;
  std::istream *istream{&std::cin};
  if (FLAGS_input != "") {
    MG_ASSERT(std::filesystem::is_regular_file(FLAGS_input), "Input file isn't a regular file or it doesn't exist!");
    ifile.open(FLAGS_input);
    MG_ASSERT(ifile, "Couldn't open input file!");
    istream = &ifile;
  }

  std::ofstream ofile;
  std::ostream *ostream{&std::cout};
  if (FLAGS_output != "") {
    ofile.open(FLAGS_output);
    MG_ASSERT(ofile, "Couldn't open output file!");
    ostream = &ofile;
  }

  std::vector<std::pair<std::string, std::map<std::string, communication::bolt::Value>>> queries;
  if (!FLAGS_queries_json) {
    std::string query;
    while (std::getline(*istream, query)) {
      auto trimmed = utils::Trim(query);
      if (trimmed == "" || trimmed == ";") {
        Execute(queries, ostream);
        queries.clear();
        continue;
      }
      queries.emplace_back(query, std::map<std::string, communication::bolt::Value>{});
    }
  } else {
    std::string row;
    while (std::getline(*istream, row)) {
      auto data = nlohmann::json::parse(row);
      MG_ASSERT(data.is_array() && data.size() > 0,
                "The root item of the loaded JSON queries must be a non-empty array!");
      MG_ASSERT(data.is_array() && data.size() == 2, "Each item of the loaded JSON queries must be an array!");
      if (data.size() == 0) {
        Execute(queries, ostream);
        queries.clear();
        continue;
      }
      MG_ASSERT(data.size() == 2,
                "Each item of the loaded JSON queries that has data must be an array of length 2!");
      const auto &query = data[0];
      const auto &param = data[1];
      MG_ASSERT(query.is_string() && param.is_object(),
                "The query must be a string and the parameters must be a dictionary!");
      auto bolt_param = JsonToBoltValue(param);
      MG_ASSERT(bolt_param.IsMap(), "The Bolt parameters must be a map!");
      queries.emplace_back(query, std::move(bolt_param.ValueMap()));
    }
  }
  Execute(queries, ostream);

  return 0;
}
