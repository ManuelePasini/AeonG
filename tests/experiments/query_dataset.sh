#!/bin/bash

aeong_binary="--aeong-binary ../../build/memgraph"
client_binary="--client-binary ../../build/tests/mgbench/client"
prefix_path="../results/"
database_directory="--data-directory $prefix_path/database/aeong"
index_path="--index-cypher-path ../datasets/T-mgBench/cypher_index.cypher"

python_script="../scripts/evaluate_temporal_q.py"
output_path="../results/query_results"
query_names=("EnvironmentCoverage" "EnvironmentAggregate" "MaintenanceOwners" "EnvironmentOutlier" "AgentOutlier" "AgentHistory")


mkdir -p "$output_path"
# Script parameters
size="$1"
worker="$2"
ITERATIONS="$3"
temporal_query_path="${prefix_path}temporal_query/${size}"

# Foreach dataset size
echo "Running with size: $size"
echo "Updating queries timespan filter for size: $size"

./update_queries.sh "$size" "$temporal_query_path/"

# Foreach number of workers
echo "Running with $worker workers"
number_workers="--num-workers $worker"
    
# Foreach iteration
for iteration in $(seq 1 "$ITERATIONS"); do
    echo "Running query iteration $iteration"

    # Update the query output paths for the current size - worker - iteration
    output_paths=()

    for name in "${query_names[@]}"; do
        output_paths+=("--output $output_path/${name}_sz${size}_wrk${worker}_it${iteration}.json")
    done

    # Execute the Python script for each query
    for i in "${!query_names[@]}"; do
        echo "AeonG ${query_names[$i]} mix"
        temporal_query="--temporal-query-cypher-path $temporal_query_path/${query_names[$i]}.txt"
        python3 "$python_script" \
            $aeong_binary $client_binary $number_workers \
            $database_directory $index_path \
            $temporal_query ${output_paths[$i]}
    done
done