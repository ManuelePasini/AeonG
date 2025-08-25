#!/bin/bash

set -e

LINK="https://big.csr.unibo.it/downloads/stgraph/aeong/"
TARGET_FOLDER="/home/AeonG/tests/datasets/T-mgBench/"
FILENAME="$1.cypher"

cd "$TARGET_FOLDER" || exit 1

echo "Downloading dataset..."
if ! wget --no-check-certificate "${LINK}${FILENAME}" -O "${TARGET_FOLDER}${FILENAME}"; then
    echo "Error downloading dataset, exiting..."
    exit 1
fi

if [[ -f "$FILENAME" ]]; then
    echo "Downloaded: $FILENAME"
else
    echo "Error: something went wrong while downloading $FILENAME!"
    exit 1
fi







