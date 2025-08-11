#!/bin/bash

SIZE=("small" "large" "big")
INGESTION_ITERATIONS=1
QUERY_ITERATIONS=20
WORKERS=(1 2 4 8 10 16 20 32 64)

echo "Downloading datasets"
./download_datasets.sh "$size"
echo " ...done"

for size in "${SIZE[@]}"; do

    echo "Creating AeonG database with size: $size.."
    ./create_database.sh "$size" $INGESTION_ITERATIONS
    echo " ...done"

    for worker in "${WORKERS[@]}"; do
        echo "Running query experiments for size: $size with $worker workers"
        ./query_dataset.sh "$size" "$worker" $QUERY_ITERATIONS
    done
done