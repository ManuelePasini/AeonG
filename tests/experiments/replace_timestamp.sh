#!/bin/bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <queryKey> <queryName> <tstampTo> <queryPath>"
  exit 1
fi

QUERY_KEY="$1"
QUERY_NAME="$2"
TSTAMP_TO="$3"
QUERY_PATH="$4"

INPUT_FILE="${QUERY_PATH}${QUERY_KEY}.txt"
OUTPUT_FILE="${QUERY_PATH}${QUERY_NAME}.txt"

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "File $INPUT_FILE non trovato"
  exit 1
fi

sed "s/{TSTAMPTO_PARAM}/${TSTAMP_TO}/g" "$INPUT_FILE" > "$OUTPUT_FILE"

echo "Generated $OUTPUT_FILE (TSTAMP_TO=$TSTAMP_TO)"
