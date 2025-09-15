#!/bin/bash

#Create AeonG temporal database, get graph operation latency, and get space
aeong_binary="--aeong-binary ../../build/memgraph"
client_binary="--client-binary ../../build/tests/mgbench/client"
number_workers="--num-workers 1"
output_path="/home/AeonG/tests/results/query_results/ingestion_stats"
mgbench_download_dir="../datasets/T-mgBench"
prefix_path="../results/"

DATASET_SIZE="$1"
ITERATIONS="$2"

mkdir -p "$output_path"

database_directory="--data-directory $prefix_path/database/aeong"
original_dataset="--original-dataset-cypher-path $mgbench_download_dir/$DATASET_SIZE.cypher"
index_path="--index-cypher-path $mgbench_download_dir/cypher_index.cypher"
#echo ";" > $index_path
graph_op_cypher_path="--graph-operation-cypher-path $graph_op_path/cypher.txt"
python_script="../scripts/create_temporal_database.py"

for iteration in $(seq 1 "$ITERATIONS"); do
    # Delete old database and create a new one
    rm -rf $prefix_path/database/aeong
    mkdir -p $prefix_path/database/aeong

    echo "=============AeonG create database, iteration $iteration it cost time==========="
    output=$(python3 "$python_script" $aeong_binary $client_binary $number_workers $database_directory $original_dataset $index_path $graph_op_cypher_path)
    values=$(echo "$output" | tail -n 1)

    output_json_file="${output_path}/ingestion_${DATASET_SIZE}_${iteration}.json"

    graph_op_latency=$(echo "$values" | awk '{print $1}')
    storage_consumption=$(echo "$values" | awk '{print $2}')
    start_time=$(echo "$values" | awk '{print $3}')
    end_time=$(echo "$values" | awk '{print $4}')

    cat > "$output_json_file" <<EOF
    {
    "graph_op_latency": $graph_op_latency,
    "storage_consumption": $storage_consumption,
    "start_time": $start_time,
    "end_time": $end_time,
    "dataset_size": "$DATASET_SIZE",
    "iteration": $iteration,
    "duration": $(echo "$end_time - $start_time" | bc)
    }
EOF
    echo "graph_op_latency:$graph_op_latency"
    echo "storage_consumption:$storage_consumption"
    echo "start_time:$start_time"
    echo "end_time:$end_time"
    echo "duration:$(echo "$end_time - $start_time" | bc)"
done