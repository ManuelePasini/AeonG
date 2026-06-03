#!/bin/bash

# --- Binary paths and directories ---
aeong_binary="--aeong-binary ../../build/memgraph"
client_binary="--client-binary ../../build/tests/mgbench/client"
prefix_path="../results/"
database_directory="--data-directory $prefix_path/database/aeong"
index_path="--index-cypher-path ../datasets/T-mgBench/cypher_index.cypher"
python_script="../scripts/evaluate_temporal_q.py"

output_path="../results/aeong/query_results/query_stats"
query_names=("q0" "q1" "q2" "q3")

# Create output directory if it does not exist
mkdir -p "$output_path"

# --- Script parameters ---
if [[ $# -ne 4 ]]; then
    echo "Usage: $0 <size> <worker> <iterations> <selectivity>"
    exit 1
fi

size="$1"
worker="$2"
ITERATIONS="$3"
SELECTIVITY="$4"
temporal_query_path="${prefix_path}temporal_query/"

# Ensure temporal query directory exists
mkdir -p "$temporal_query_path"

number_workers="--num-workers $worker"

echo "Running with size: $size, selectivity: $SELECTIVITY, $worker workers"

# --- Loop over the number of iterations ---
for iteration in $(seq 1 "$ITERATIONS"); do
    echo "Running query iteration $iteration"

    # Loop over all query names
    for i in "${!query_names[@]}"; do
        query="${query_names[$i]}"
        
        echo "AeonG $query mix"

        temporal_query="--temporal-query-cypher-path $cat ./../results/temporal_query/${query}.txt" 

        # Construct a unique output filename including query, size, worker, iteration, selectivity, and range
        output_file="$output_path/${query}_sz${size}_wrk${worker}_it${iteration}_sel${SELECTIVITY}_tr${0}.json"

        # Execute the Python evaluation script
        python3 "$python_script" \
            $aeong_binary $client_binary $number_workers \
            $database_directory $index_path \
            $temporal_query \
            --selectivity "$SELECTIVITY" \
            --time-range-id "0" \
            --output "$output_file"

    done
done
