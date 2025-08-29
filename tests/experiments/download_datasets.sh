#!/bin/bash

set -e

LINK="https://big.csr.unibo.it/downloads/stgraph/aeong/"
INTERNAL_LINK="https://137.204.74.24/downloads/stgraph/aeong/"
TARGET_FOLDER="/home/AeonG/tests/datasets/T-mgBench/"
FILENAME="$1.cypher"

cd "$TARGET_FOLDER" || exit 1

echo "Downloading dataset ..."
# curl -L -o "./${DATASET_SIZE}.tar" "${LINK}${DATASET_SIZE}.tar"
if ! wget --no-check-certificate --tries=3 "${LINK}${FILENAME}"; then
    echo "Primary link failed, trying backup..."
    wget --no-check-certificate --tries=3 "${INTERNAL_LINK}${FILENAME}" || {
        echo "Error: failed to download from backup too!"
        exit 1
    }
fi

if [[ -f "$FILENAME" ]]; then
    echo "Downloaded: $FILENAME"
else
    echo "Error: something went wrong while downloading $FILENAME!"
    exit 1
fi







