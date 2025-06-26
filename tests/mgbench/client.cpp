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

DEFINE_uint64(num_workers, 1,
              "Number of workers that should be used to concurrently execute the supplied queries.");
DEFINE_uint64(max_retries, 50, "Maximum number of retries for each query.");
DEFINE_bool(queries_json, false,
            "Set to true to load all queries as a single JSON encoded list. Each item in the list should contain another list whose first element is the query that should be executed and the second element should be a dictionary of query parameters for that query.");

DEFINE_string(input, "", "Input file. By default stdin is used.");
DEFINE_string(output, "", "Output file. By default stdout is used.");

// ExecuteNTimesTillSuccess now also returns rows
std::tuple<std::map<std::string, communication::bolt::Value>, std::vector<std::vector<communication::bolt::Value>>, uint64_t>
ExecuteNTimesTillSuccess(
    communication::bolt::Client *client,
    const std::string &query,
    const std::map<std::string, communication::bolt::Value> &params,
    int max_attempts) {
  for (uint64_t i = 0; i < max_attempts; ++i) {
    try {
      auto ret = client->Execute(query, params);
      return {std::move(ret.metadata), std::move(ret.records), i};
    } catch (const utils::BasicException &e) {
      if (i == max_attempts - 1) {
        LOG_FATAL("Could not execute query '{}' {} times! Error message: {}", query, max_attempts, e.what());
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
      for (const auto &item : data.get<nlohmann::json::array_t>()) vec.emplace_back(JsonToBoltValue(item));
      return {std::move(vec)};
    }
    case nlohmann::json::value_t::object: {
      std::map<std::string, communication::bolt::Value> map;
      for (const auto &item : data.get<nlohmann::json::object_t>()) map.emplace(item.first, JsonToBoltValue(item.second));
      return {std::move(map)};
    }
    default:
      LOG_FATAL("Unexpected JSON type!");
  }
}

nlohmann::json BoltValueToJson(const communication::bolt::Value &value) {
  using Type = communication::bolt::Value::Type;
  if (value.type() == Type::Null) return nullptr;
  if (value.IsBool()) return value.ValueBool();
  if (value.IsInt()) return value.ValueInt();
  if (value.IsDouble()) return value.ValueDouble();
  if (value.IsString()) return value.ValueString();
  if (value.IsList()) {
    nlohmann::json j = nlohmann::json::array();
    for (auto &v : value.ValueList()) j.push_back(BoltValueToJson(v));
    return j;
  }
  if (value.IsMap()) {
    nlohmann::json j = nlohmann::json::object();
    for (auto &p : value.ValueMap()) j[p.first] = BoltValueToJson(p.second);
    return j;
  }
  LOG_FATAL("Unsupported Bolt value type!");
}

void Execute(
    const std::vector<std::pair<std::string, std::map<std::string, communication::bolt::Value>>> &queries,
    std::ostream *stream) {
  // parallel workers
  std::vector<std::thread> threads;
  // Metadata class defined above
  // Prepare worker data structures
  std::vector<uint64_t> worker_retries(FLAGS_num_workers);
  std::vector<Metadata> worker_meta(FLAGS_num_workers);
  std::vector<double> worker_dur(FLAGS_num_workers);
  std::vector<std::vector<std::vector<communication::bolt::Value>>> worker_rows(FLAGS_num_workers);

  // Use atomic counters for synchronization and position
  std::atomic<uint64_t> run_flag(0), ready(0), pos(0);
  auto size = queries.size();
  threads.reserve(FLAGS_num_workers);

  std::vector<uint64_t> worker_retries(FLAGS_num_workers);
  std::vector<Metadata> worker_meta(FLAGS_num_workers);
  std::vector<double> worker_dur(FLAGS_num_workers);
  std::vector<std::vector<std::vector<communication::bolt::Value>>> worker_rows(FLAGS_num_workers);

  std::atomic<bool> run(false), ready(0), pos(0);
  auto size = queries.size();

  // launch workers
  for (uint32_t w = 0; w < FLAGS_num_workers; ++w) {
    threads.emplace_back([&](uint32_t wid) {
      io::network::Endpoint ep(FLAGS_address, FLAGS_port);
      communication::ClientContext ctx(FLAGS_use_ssl);
      communication::bolt::Client cl(&ctx);
      cl.Connect(ep, FLAGS_username, FLAGS_password);
      ready.fetch_add(1);
      while (!run.load());
      Timer timer;
      while (true) {
        auto i = pos.fetch_add(1);
        if (i >= size) break;
        auto &q = queries[i];
        auto [md, rows, retr] = ExecuteNTimesTillSuccess(&cl, q.first, q.second, FLAGS_max_retries);
        worker_retries[wid] += retr;
        worker_meta[wid].Append(md);
        worker_rows[wid].push_back(std::move(rows));
      }
      worker_dur[wid] = timer.Elapsed().count();
      cl.Close();
    }, w);
  }
  while (ready.load() < FLAGS_num_workers);
  run.store(true);
  for (auto &t : threads) t.join();

  // aggregate results
  Metadata final_meta;
  uint64_t total_retr = 0;
  double total_dur = 0;
  std::vector<std::vector<communication::bolt::Value>> all_rows;
  all_rows.reserve(size);
  for (uint32_t w = 0; w < FLAGS_num_workers; ++w) {
    final_meta += worker_meta[w];
    total_retr += worker_retries[w];
    total_dur += worker_dur[w];
    for (auto &batch : worker_rows[w])
      for (auto &r : batch) all_rows.push_back(std::move(r));
  }
  total_dur /= FLAGS_num_workers;

  // output summary including tuples
  nlohmann::json summary = {
    {"count", size},
    {"duration", total_dur},
    {"throughput", static_cast<double>(size) / total_dur},
    {"retries", total_retr},
    {"metadata", final_meta.Export()},
    {"num_workers", FLAGS_num_workers}
  };
  // results
  nlohmann::json jr = nlohmann::json::array();
  for (auto &row : all_rows) {
    nlohmann::json ja = nlohmann::json::array();
    for (auto &cell : row) ja.push_back(BoltValueToJson(cell));
    jr.push_back(std::move(ja));
  }
  summary["results"] = std::move(jr);
  (*stream) << summary.dump() << std::endl;
}

int main(int argc, char **argv) {
  gflags::ParseCommandLineFlags(&argc, &argv, true);
  communication::SSLInit sslInit;
  
  std::ifstream ifs;
  std::istream *is = &std::cin;
  if (!FLAGS_input.empty()) {
    MG_ASSERT(std::filesystem::is_regular_file(FLAGS_input), "Input file invalid");
    ifs.open(FLAGS_input);
    is = &ifs;
  }
  std::ofstream ofs;
  std::ostream *os = &std::cout;
  if (!FLAGS_output.empty()) {
    ofs.open(FLAGS_output);
    os = &ofs;
  }

  std::vector<std::pair<std::string, std::map<std::string, communication::bolt::Value>>> queries;
  if (!FLAGS_queries_json) {
    std::string q;
    while (std::getline(*is, q)) {
      auto t = utils::Trim(q);
      if (t.empty() || t == ";") { Execute(queries, os); queries.clear(); continue; }
      queries.emplace_back(q, std::map<std::string, communication::bolt::Value>{});
    }
  } else {
    std::string line;
    while (std::getline(*is, line)) {
      auto data = nlohmann::json::parse(line);
      if (data.empty()) { Execute(queries, os); queries.clear(); continue; }
      const auto &qry = data[0];
      const auto &prm = data[1];
      auto bp = JsonToBoltValue(prm);
      queries.emplace_back(qry.get<std::string>(), std::move(bp.ValueMap()));
    }
  }
  Execute(queries, os);
  return 0;
}
