// Copyright 2021 Memgraph Ltd.
// Licensed under the Business Source License.

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
DEFINE_bool(queries_json, false, "Set to true to load all queries as a single JSON encoded list.");

DEFINE_string(input, "", "Input file. By default stdin is used.");
DEFINE_string(output, "", "Output file. By default stdout is used.");

using QueryResult = std::vector<std::map<std::string, communication::bolt::Value>>;

struct QueryExecutionResult {
  std::map<std::string, communication::bolt::Value> metadata;
  QueryResult records;
  uint64_t retries;
};

QueryExecutionResult ExecuteNTimesTillSuccess(
    communication::bolt::Client *client, const std::string &query,
    const std::map<std::string, communication::bolt::Value> &params, int max_attempts) {

  for (uint64_t i = 0; i < max_attempts; ++i) {
    try {
      auto ret = client->Execute(query, params);
      return {std::move(ret.metadata), std::move(ret.records), i};
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
  if (value.IsNull()) return nullptr;
  if (value.IsBool()) return value.ValueBool();
  if (value.IsInt()) return value.ValueInt();
  if (value.IsDouble()) return value.ValueDouble();
  if (value.IsString()) return value.ValueString();
  if (value.IsList()) {
    nlohmann::json arr = nlohmann::json::array();
    for (const auto &item : value.ValueList()) {
      arr.push_back(BoltValueToJson(item));
    }
    return arr;
  }
  if (value.IsMap()) {
    nlohmann::json obj = nlohmann::json::object();
    for (const auto &item : value.ValueMap()) {
      obj[item.first] = BoltValueToJson(item.second);
    }
    return obj;
  }
  LOG_FATAL("Unsupported Bolt value type for JSON conversion!");
}

void Execute(const std::vector<std::pair<std::string, std::map<std::string, communication::bolt::Value>>> &queries,
             std::ostream *stream) {

  std::vector<std::thread> threads;
  threads.reserve(FLAGS_num_workers);

  std::vector<uint64_t> worker_retries(FLAGS_num_workers, 0);
  std::vector<std::vector<QueryResult>> worker_results(FLAGS_num_workers);

  std::atomic<bool> run(false);
  std::atomic<uint64_t> ready(0);
  std::atomic<uint64_t> position(0);

  auto size = queries.size();

  for (int worker = 0; worker < FLAGS_num_workers; ++worker) {
    threads.push_back(std::thread([&, worker]() {
      io::network::Endpoint endpoint(FLAGS_address, FLAGS_port);
      communication::ClientContext context(FLAGS_use_ssl);
      communication::bolt::Client client(&context);
      client.Connect(endpoint, FLAGS_username, FLAGS_password);

      ready.fetch_add(1, std::memory_order_acq_rel);
      while (!run.load(std::memory_order_acq_rel)) {}

      auto &retries = worker_retries[worker];
      auto &results = worker_results[worker];

      while (true) {
        auto pos = position.fetch_add(1, std::memory_order_acq_rel);
        if (pos >= size) break;

        const auto &query = queries[pos];
        auto ret = ExecuteNTimesTillSuccess(&client, query.first, query.second, FLAGS_max_retries);

        retries += ret.retries;
        results.push_back(ret.records);
      }
      client.Close();
    }));
  }

  while (ready.load(std::memory_order_acq_rel) < FLAGS_num_workers) {}
  run.store(true, std::memory_order_acq_rel);

  for (auto &thread : threads) thread.join();

  uint64_t final_retries = 0;
  nlohmann::json results_json = nlohmann::json::array();

  for (int i = 0; i < FLAGS_num_workers; ++i) {
    final_retries += worker_retries[i];
    for (const auto &query_result : worker_results[i]) {
      for (const auto &record : query_result) {
        nlohmann::json record_json = nlohmann::json::object();
        for (const auto &field : record) {
          record_json[field.first] = BoltValueToJson(field.second);
        }
        results_json.push_back(record_json);
      }
    }
  }

  nlohmann::json summary = nlohmann::json::object();
  summary["count"] = queries.size();
  summary["retries"] = final_retries;
  summary["results"] = results_json;
  summary["num_workers"] = FLAGS_num_workers;

  (*stream) << summary.dump() << std::endl;
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
      MG_ASSERT(data.is_array() && data.size() > 0, "The root item of the loaded JSON queries must be a non-empty array!");
      MG_ASSERT(data.size() == 2, "Each item of the loaded JSON queries must be an array of length 2!");

      const auto &query = data[0];
      const auto &param = data[1];
      MG_ASSERT(query.is_string() && param.is_object(), "The query must be a string and the parameters must be a dictionary!");

      auto bolt_param = JsonToBoltValue(param);
      MG_ASSERT(bolt_param.IsMap(), "The Bolt parameters must be a map!");

      queries.emplace_back(query, std::move(bolt_param.ValueMap()));
    }
  }

  Execute(queries, ostream);

  return 0;
}