// Copyright 2021 Memgraph Ltd.
// Use of this software is governed by the Business Source License
// included in the file licenses/BSL.txt; by using this file, you agree to be bound by the terms of the Business Source
// License, and you may not use this file except in compliance with the Business Source License.
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
DEFINE_bool(queries_json, false, "Set to true to load all queries as a single JSON encoded list.");

DEFINE_string(input, "", "Input file. By default stdin is used.");
DEFINE_string(output, "", "Output file. By default stdout is used.");

std::pair<std::map<std::string, communication::bolt::Value>, uint64_t> ExecuteNTimesTillSuccess(
    communication::bolt::Client *client, const std::string &query,
    const std::map<std::string, communication::bolt::Value> &params, int max_attempts) {
  for (uint64_t i = 0; i < max_attempts; ++i) {
    try {
      auto ret = client->Execute(query, params);
      return {std::move(ret.metadata), i};
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
    case nlohmann::json::value_t::null: return {};
    case nlohmann::json::value_t::boolean: return {data.get<bool>()};
    case nlohmann::json::value_t::string: return {data.get<std::string>()};
    case nlohmann::json::value_t::number_integer: return {data.get<int64_t>()};
    case nlohmann::json::value_t::number_unsigned: return {static_cast<int64_t>(data.get<uint64_t>())};
    case nlohmann::json::value_t::number_float: return {data.get<double>()};
    case nlohmann::json::value_t::array: {
      std::vector<communication::bolt::Value> vec;
      for (const auto &item : data) vec.emplace_back(JsonToBoltValue(item));
      return {std::move(vec)};
    }
    case nlohmann::json::value_t::object: {
      std::map<std::string, communication::bolt::Value> map;
      for (const auto &item : data.items()) map.emplace(item.key(), JsonToBoltValue(item.value()));
      return {std::move(map)};
    }
    default: LOG_FATAL("Unexpected JSON type!");
  }
}

nlohmann::json BoltValueToJson(const communication::bolt::Value &value) {
  if (value.type == communication::bolt::Value::Type::Null) return nullptr;
  if (value.IsBool()) return value.ValueBool();
  if (value.IsInt()) return value.ValueInt();
  if (value.IsDouble()) return value.ValueDouble();
  if (value.IsString()) return value.ValueString();
  if (value.IsList()) {
    nlohmann::json arr = nlohmann::json::array();
    for (const auto &v : value.ValueList()) arr.push_back(BoltValueToJson(v));
    return arr;
  }
  if (value.IsMap()) {
    nlohmann::json obj = nlohmann::json::object();
    for (const auto &p : value.ValueMap()) obj[p.first] = BoltValueToJson(p.second);
    return obj;
  }
  LOG_FATAL("Unsupported Bolt value type for JSON conversion!");
}

class Metadata final {
  private:
   struct Record {
     uint64_t count{0};
     double average{0.0};
     double minimum{std::numeric_limits<double>::infinity()};
     double maximum{-std::numeric_limits<double>::infinity()};
   };
 
  public:
   void Append(const std::map<std::string, communication::bolt::Value> &values) {
     for (const auto &item : values) {
       if (!item.second.IsInt() && !item.second.IsDouble()) continue;
       auto [it, emplaced] = storage_.emplace(item.first, Record());
       auto &record = it->second;
       double value = 0.0;
       if (item.second.IsInt()) {
         value = item.second.ValueInt();
       } else {
         value = item.second.ValueDouble();
       }
       ++record.count;
       record.average += value;
       record.minimum = std::min(record.minimum, value);
       record.maximum = std::max(record.maximum, value);
     }
   }
 
   nlohmann::json Export() {
     nlohmann::json data = nlohmann::json::object();
     for (const auto &item : storage_) {
       nlohmann::json row = nlohmann::json::object();
       row["average"] = item.second.average / item.second.count;
       row["minimum"] = item.second.minimum;
       row["maximum"] = item.second.maximum;
       data[item.first] = row;
     }
     return data;
   }
 
   Metadata &operator+=(const Metadata &other) {
     for (const auto &item : other.storage_) {
       auto [it, emplaced] = storage_.emplace(item.first, Record());
       auto &record = it->second;
       record.count += item.second.count;
       record.average += item.second.average;
       record.minimum = std::min(record.minimum, item.second.minimum);
       record.maximum = std::max(record.maximum, item.second.maximum);
     }
     return *this;
   }
 
  private:
   std::map<std::string, Record> storage_;
 };

struct QueryResult {
  std::string query;
  std::map<std::string, communication::bolt::Value> parameters;
  std::vector<std::map<std::string, communication::bolt::Value>> results;
  uint64_t retries;
};

void Execute(const std::vector<std::pair<std::string, std::map<std::string, communication::bolt::Value>>> &queries,
             std::ostream *stream) {
  std::vector<std::thread> threads;
  threads.reserve(FLAGS_num_workers);

  std::vector<std::vector<QueryResult>> worker_results(FLAGS_num_workers);
  std::vector<Metadata> worker_metadata(FLAGS_num_workers);
  std::vector<uint64_t> worker_retries(FLAGS_num_workers, 0);
  std::vector<double> worker_duration(FLAGS_num_workers, 0.0);

  std::atomic<bool> run(false);
  std::atomic<uint64_t> ready(0);
  std::atomic<uint64_t> position(0);
  const auto total = queries.size();

  for (size_t w = 0; w < FLAGS_num_workers; ++w) {
    threads.emplace_back([&, w]() {
      io::network::Endpoint endpoint(FLAGS_address, FLAGS_port);
      communication::ClientContext context(FLAGS_use_ssl);
      communication::bolt::Client client(&context);
      client.Connect(endpoint, FLAGS_username, FLAGS_password);

      ready.fetch_add(1);
      while (!run.load());

      Metadata &meta = worker_metadata[w];
      auto &retry_cnt = worker_retries[w];
      auto &results = worker_results[w];
      utils::Timer timer;

      while (true) {
        auto idx = position.fetch_add(1);
        if (idx >= total) break;
        const auto &q = queries[idx];
        auto ret = client.Execute(q.first, q.second);
        retry_cnt += 0;
        meta.Append(ret.metadata);

        // Extract column names from metadata
        std::vector<std::string> cols;
        const auto &fields = ret.metadata.at("fields").ValueList();
        for (const auto &f : fields) cols.push_back(f.ValueString());

        // Build QueryResult
        QueryResult qr;
        qr.query = q.first;
        qr.parameters = q.second;
        qr.retries = 0;

        for (const auto &row : ret.records) {
          std::map<std::string, communication::bolt::Value> rec;
          for (size_t i = 0; i < row.size(); ++i) rec.emplace(cols[i], row[i]);
          qr.results.push_back(std::move(rec));
        }
        results.push_back(std::move(qr));
      }
      worker_duration[w] = timer.Elapsed().count();
      client.Close();
    });
  }

  while (ready.load() < FLAGS_num_workers);
  run.store(true);
  for (auto &t : threads) t.join();

  // Aggregate
  Metadata final_meta;
  uint64_t total_retries = 0;
  double total_dur = 0;
  std::vector<QueryResult> all;
  for (size_t w = 0; w < FLAGS_num_workers; ++w) {
    final_meta += worker_metadata[w];
    total_retries += worker_retries[w];
    total_dur += worker_duration[w];
    all.insert(all.end(),
               std::make_move_iterator(worker_results[w].begin()),
               std::make_move_iterator(worker_results[w].end()));
  }
  double avg_dur = total_dur / FLAGS_num_workers;

  // Build output JSON
  nlohmann::json out;
  out["summary"] = {
    {"count", total},
    {"duration", avg_dur},
    {"throughput", total / avg_dur},
    {"retries", total_retries},
    {"metadata", final_meta.Export()},
    {"num_workers", FLAGS_num_workers}
  };
  out["queries"] = nlohmann::json::array();
  for (auto &r : all) {
    nlohmann::json item;
    item["query"] = r.query;
    nlohmann::json pjs;
    for (auto &p : r.parameters) pjs[p.first] = BoltValueToJson(p.second);
    item["parameters"] = pjs;
    nlohmann::json tup;
    for (auto &rec : r.results) {
      nlohmann::json rowj;
      for (auto &c : rec) rowj[c.first] = BoltValueToJson(c.second);
      tup.push_back(rowj);
    }
    item["results"] = tup;
    item["retries"] = r.retries;
    out["queries"].push_back(item);
  }

  std::ostream &os = *stream;
  os << out.dump(2) << std::endl;
}

int main(int argc, char **argv) {
  gflags::ParseCommandLineFlags(&argc, &argv, true);
  communication::SSLInit ssl;
  std::ifstream ifs;
  std::istream *in = &std::cin;
  if (!FLAGS_input.empty()) {
    MG_ASSERT(std::filesystem::is_regular_file(FLAGS_input), "Input file invalid");
    ifs.open(FLAGS_input);
    in = &ifs;
  }
  std::ofstream ofs;
  std::ostream *out = &std::cout;
  if (!FLAGS_output.empty()) {
    ofs.open(FLAGS_output);
    out = &ofs;
  }

  std::vector<std::pair<std::string, std::map<std::string, communication::bolt::Value>>> queries;
  if (!FLAGS_queries_json) {
    std::string q;
    while (std::getline(*in, q)) {
      auto t = utils::Trim(q);
      if (t.empty() || t == ";") {
        Execute(queries, out);
        queries.clear();
      } else {
        queries.emplace_back(q, std::map<std::string, communication::bolt::Value>());
      }
    }
  } else {
    std::string line;
    while (std::getline(*in, line)) {
      auto data = nlohmann::json::parse(line);
      MG_ASSERT(data.is_array() && data.size() == 2);
      queries.emplace_back(data[0].get<std::string>(), JsonToBoltValue(data[1]).ValueMap());
    }
  }
  Execute(queries, out);
  return 0;
}
