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
temporal_q1="--temporal-query-cypher-path $temporal_query_path/cypher_Q1.txt"
temporal_q2="--temporal-query-cypher-path $temporal_query_path/cypher_Q2.txt"
temporal_q3="--temporal-query-cypher-path $temporal_query_path/cypher_Q3.txt"
temporal_q4="--temporal-query-cypher-path $temporal_query_path/cypher_Q4.txt"
temporal_q4_long="--temporal-query-cypher-path $temporal_query_path/cypher_Q4_long.txt"
temporal_q5="--temporal-query-cypher-path $temporal_query_path/cypher_Q5.txt"
temporal_q6="--temporal-query-cypher-path $temporal_query_path/cypher_Q6.txt"

temporal_q1_flat="--temporal-query-cypher-path $temporal_query_path/cypher_Q1_flat.txt"
temporal_q2_flat="--temporal-query-cypher-path $temporal_query_path/cypher_Q2_flat.txt"
temporal_q3_flat="--temporal-query-cypher-path $temporal_query_path/cypher_Q3_flat.txt"
temporal_q4_flat="--temporal-query-cypher-path $temporal_query_path/cypher_Q4_flat.txt"
temporal_q4_flat_long="--temporal-query-cypher-path $temporal_query_path/cypher_Q4_flat_long.txt"
temporal_q5_flat="--temporal-query-cypher-path $temporal_query_path/cypher_Q5_flat.txt"
temporal_q6_flat="--temporal-query-cypher-path $temporal_query_path/cypher_Q6_flat.txt"

output_q1="--output /q1.json"
output_q2="--output /q2.json"
output_q3="--output /q3.json"
output_q4="--output /q4.json"
output_q4_long="--output /q4_long.json"
output_q5="--output /q5.json"
output_q6="--output /q6.json"

output_q1_flat="--output /q1_flat.json"
output_q2_flat="--output /q2_flat.json"
output_q3_flat="--output /q3_flat.json"
output_q4_flat="--output /q4_flat.json"
output_q4_flat_long="--output /q4_flat_long.json"
output_q5_flat="--output /q5_flat.json"
output_q6_flat="--output /q6_flat.json"

echo "AeonG q1 mix"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q1 $output_q1
echo "AeonG q2 mix"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q2 $output_q2
echo "AeonG q3 mix"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q3 $output_q3
echo "AeonG q4 mix"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q4 $output_q4
echo "AeonG q4 mix_long"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q4_long $output_q4_long
echo "AeonG q5 mix"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q5 $output_q5
echo "AeonG q6 mix"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q6 $output_q6

echo "AeonG q1 mix_flat"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q1_flat $output_q1_flat
echo "AeonG q2 mix_flat"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q2_flat $output_q2_flat
echo "AeonG q3 mix_flat"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q3_flat $output_q3_flat
echo "AeonG q4 mix_flat"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q4_flat $output_q4_flat
echo "AeonG q4 mix_flat_long"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q4_flat_long $output_q4_flat_long
echo "AeonG q5 mix_flat"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q5_flat $output_q5_flat
echo "AeonG q6 mix_flat"
python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $index_path $temporal_q6_flat $output_q6_flat