#!/bin/bash


#!/bin/bash

apt-get update
wget https://mega.nz/linux/repo/xUbuntu_22.04/amd64/megacmd-xUbuntu_22.04_amd64.deb &&
apt install -y "$PWD/megacmd-xUbuntu_22.04_amd64.deb" psmisc megatools

# MEGA link (not OneDrive!)
LINK="https://mega.nz/file/qQ8UEQDS#_6kxPINFpLjO3W0PsNnHJ1pwHXk0EpfGV7pRuLbYbUE"
TARGET_FOLDER="./../datasets/T-mgBench"
FILENAME="dataset_cypher.tar"

export MEGACMD_USE_LEGACY_INTERFACE=1
mkdir -p "$TARGET_FOLDER"

echo "Downloading from MEGA..."
cd "$TARGET_FOLDER" || exit 1

# Kill mega-cmd-server
killall mega-cmd-server || true
rm -rf ~/.megaCmd/megacmdserver.lock

megadl "$LINK" --path "$TARGET_FOLDER/$FILENAME"

if [[ -f "$FILENAME" ]]; then
    echo "Downloaded: $FILENAME"
    tar -xvf "$FILENAME"
    rm "$FILENAME"
else
    echo "Errore: il file $FILENAME non è stato scaricato correttamente!"
    exit 1
fi