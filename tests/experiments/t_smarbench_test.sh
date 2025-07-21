#!/bin/bash
update_num=320000 #$1 #320000
clockg_binary=/home/hjm/vldb/clockg/build/memgraph #$2 #/home/hjm/vldb/clockg/build/memgraph
memgraph_binary=/home/hjm/vldb/memgraph-master/build/memgraph #$3 #/home/hjm/vldb/memgraph-master/build/memgraph
mgbench_download_dir="../datasets/T-mgBench"
cypher_file_path="--cypher-file-path $mgbench_download_dir/small.cypher"
prefix_path="../results/"
graph_op_path="$prefix_path/graph_op"
write_path="--write-path $prefix_path"
dataset_path="--dataset-path ../datasets/T-mgBench/"
python_script="../benchmarks/T-mgBench/create_graph_op_queries.py"

pip3 install numpy
pip3 install pandas

#Create AeonG temporal database, get graph operation latency, and get space
aeong_binary="--aeong-binary ../../build/memgraph"
client_binary="--client-binary ../../build/tests/mgbench/client"
number_workers="--num-workers 1"
rm -rf $prefix_path/database/aeong
mkdir -p $prefix_path/database/aeong
database_directory="--data-directory $prefix_path/database/aeong"
original_dataset="--original-dataset-cypher-path $mgbench_download_dir/small.cypher"
index_path="--index-cypher-path $mgbench_download_dir/cypher_index.cypher"
#echo ";" > $index_path
graph_op_cypher_path="--graph-operation-cypher-path $graph_op_path/cypher.txt"
python_script="../scripts/create_temporal_database.py"

echo "=============AeonG create database, it cost time==========="
output=$(python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $original_dataset $index_path $graph_op_cypher_path)
#echo $output
graph_op_latency=$(echo "$output" | awk '{print $1}')
storage_consumption=$(echo "$output" | awk '{print $2}')
start_time=$(echo "$output" | awk '{print $3}')
end_time=$(echo "$output" | awk '{print $4}')-
temporal_query_path=$prefix_path"temporal_query/small"

echo "=============AeonG graph operation latency & spance==========="
echo "graph_op_latency:$graph_op_latency"
echo "storage_consumption:$storage_consumption"

aeong_binary="--aeong-binary ../../build/memgraph"
client_binary="--client-binary ../../build/tests/mgbench/client"
number_workers="--num-workers 1"
database_directory="--data-directory $prefix_path/database/aeong"
index_path="--index-cypher-path ../datasets/T-mgBench/cypher_index.cypher"
python_script="../scripts/evaluate_temporal_q.py"

temporal_q1="--temporal-query-cypher-path $temporal_query_path/EnvironmentCoverage.txt"
temporal_q2="--temporal-query-cypher-path $temporal_query_path/EnvironmentAggregate.txt"
temporal_q3="--temporal-query-cypher-path $temporal_query_path/MaintenanceOwners.txt"
temporal_q4="--temporal-query-cypher-path $temporal_query_path/EnvironmentOutlier.txt"
temporal_q5="--temporal-query-cypher-path $temporal_query_path/AgentOutlier.txt"
temporal_q6="--temporal-query-cypher-path $temporal_query_path/AgentHistory.txt"

output_q1="--output /EnvironmentCoverage.json"
output_q2="--output /EnvironmentAggregate.json"
output_q3="--output /MaintenanceOwners.json"
output_q4="--output /EnvironmentOutlier.json"
output_q5="--output /AgentOutlier.json"
output_q6="--output /AgentHistory.json"

echo "AeonG q1 mix"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q1 $output_q1
echo "AeonG q2 mix"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q2 $output_q2
echo "AeonG q3 mix"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q3 $output_q3
echo "AeonG q4 mix"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q4 $output_q4
echo "AeonG q5 mix"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q5 $output_q5
echo "AeonG q6 mix"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q6 $output_q6
