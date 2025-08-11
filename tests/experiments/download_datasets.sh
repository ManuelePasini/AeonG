#!/bin/bash

set -e

LINK="https://mega.nz/file/qQ8UEQDS#_6kxPINFpLjO3W0PsNnHJ1pwHXk0EpfGV7pRuLbYbUE"
TARGET_FOLDER="/home/AeonG/tests/datasets/T-mgBench/"
FILENAME="dataset_cypher.tar"

yum update -y
yum install -y wget tar

wget https://mega.nz/linux/repo/CentOS_7/x86_64/megacmd-1.6.3-1.1.x86_64.rpm && yum install "$PWD/megacmd-1.6.3-1.1.x86_64.rpm"

export PATH="$PWD:$PATH"
export MEGACMD_USE_LEGACY_INTERFACE=1

mkdir -p "$TARGET_FOLDER"
cd "$TARGET_FOLDER" || exit 1

echo "Downloading from MEGA..."
mega-get "$LINK" "$TARGET_FOLDER/$FILENAME"

if [[ -f "$FILENAME" ]]; then
    echo "Downloaded: $FILENAME"
    tar -xvf "$FILENAME"
    rm "$FILENAME"
else
    echo "Errore: il file $FILENAME non è stato scaricato correttamente!"
    exit 1
fi