#!/bin/bash
set -euo pipefail

# --- Binary paths and directories ---
aeong_binary="--aeong-binary ../../build/memgraph"
client_binary="--client-binary ../../build/tests/mgbench/client"
prefix_path="../results/"
database_directory="--data-directory $prefix_path/database/aeong"
index_path="--index-cypher-path ../datasets/T-mgBench/cypher_index.cypher"
python_script="../scripts/evaluate_temporal_q.py"

output_path="../results/aeong/query_results/query_stats"
query_names=("EnvironmentCoverage" "EnvironmentAggregate" "MaintenanceOwners" "EnvironmentAlert" "AgentOutlier" "AgentHistory")

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
CONFIG_FILE="time_constraints.yaml"
temporal_query_path="${prefix_path}temporal_query/"

# Ensure temporal query directory exists
mkdir -p "$temporal_query_path"

# # --- Update queries with the appropriate timestamp range for the dataset size ---
# echo "Updating queries timespan filter for size: $size"
# ./update_queries.sh "$size" "$temporal_query_path/"

number_workers="--num-workers $worker"

echo "Running with size: $size, selectivity: $SELECTIVITY, $worker workers"

# --- Loop over the number of iterations ---
for iteration in $(seq 1 "$ITERATIONS"); do
    echo "Running query iteration $iteration"

    # Loop over all query names
    for i in "${!query_names[@]}"; do
        query="${query_names[$i]}"

        # Retrieve temporal ranges for the current query
        ranges=$(./get_temporal_ranges.sh "$$CONFIG_FILE" "$SELECTIVITY" "$query" "$size")
        
        # Loop over each temporal range
        while read -r idx to; do
            echo "AeonG $query mix (range $idx)"

            # Rewrite the query file with the current temporal range
            ./replace_timestamp.sh "$query" "$to" "$temporal_query_path"

            temporal_query="--temporal-query-cypher-path $temporal_query_path/$size/${query}.txt"

            # Construct a unique output filename including query, size, worker, iteration, selectivity, and range
            output_file="$output_path/${query}_sz${size}_wrk${worker}_it${iteration}_sel${SELECTIVITY}_tr${idx}.json"

            # Execute the Python evaluation script
            python3 "$python_script" \
                $aeong_binary $client_binary $number_workers \
                $database_directory $index_path \
                $temporal_query \
                --selectivity "$SELECTIVITY" \
                --time-range-id "$idx" \
                --output "$output_file"

        done <<< "$ranges"
    done
done
