#!/bin/bash

IFS=',' read -r -a SIZE <<< "$DATASET_SIZE"
IFS=',' read -r -a WORKERS <<< "$THREAD"

for size in "${SIZE[@]}"; do

    echo "Downloading datasets $size..."
    ./download_datasets.sh $size
    echo " ...done"

    echo "Creating AeonG database with size: $size.."
    ./create_database.sh "$size" $INGESTION_ITERATIONS
    echo " ...done"

    for worker in "${WORKERS[@]}"; do
        echo "Running query experiments for size: $size with $worker workers"
        if [[ "$DATASET" == "mimic" ]]; then
            ./query_mimic.sh "$size" "$worker" $QUERY_ITERATIONS $QUERY_SELECTIVITY
        else
            ./query_dataset.sh "$size" "$worker" $QUERY_ITERATIONS $QUERY_SELECTIVITY
        fi
    done
done

echo "All experiments completed successfully."

echo "Post-processing results..."
python3 ./postprocess_results.py
echo " ...done"