#!/bin/bash

set -e

LINK="https://mega.nz/file/HREw2QLS#EJcNBI4cjAXWLPXcV9IzBmQe61TmG5lZk_1Bt45DJuY"
TARGET_FOLDER="/home/AeonG/tests/datasets/T-mgBench/"
FILENAME="dataset_cypher.tar"

wget https://mega.nz/linux/repo/CentOS_7/x86_64/megacmd-1.6.3-1.1.x86_64.rpm && yum install -y "$PWD/megacmd-1.6.3-1.1.x86_64.rpm"

export PATH="$PWD:$PATH"
export MEGACMD_USE_LEGACY_INTERFACE=1

mkdir -p "$TARGET_FOLDER"
cd "$TARGET_FOLDER" || exit 1

echo "Downloading from MEGA..."
if ! mega-get "$LINK" "$TARGET_FOLDER/$FILENAME"; then
    echo "Error: download from MEGA failed."
    exit 1
fi

if [[ -f "$FILENAME" ]]; then
    echo "Downloaded: $FILENAME"
    tar -xvf "$FILENAME"
    rm "$FILENAME"
else
    echo "Error: something went wrong while downloading $FILENAME!"
    exit 1
fi