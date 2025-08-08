#!/bin/bash

FOLDER_ID="1AqsGvephv5J66AGTjQqnpLTAM-TocrMT"
TARGET_FOLDER="../datasets/T-mgBench"

# Download dataset folder from Google Drive
gdown --folder "https://drive.google.com/drive/folders/${FOLDER_ID}" -O "$TARGET_FOLDER"

# Move files in dataset folder
find "$TARGET_FOLDER" -mindepth 1 -maxdepth 1 -type f -exec mv {} "$TARGET_FOLDER/.." \;

# Clean temporary folder
rm -r "$TARGET_FOLDER"