#!/bin/bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <queryName> <tstampTo> <queryPath>"
  exit 1
fi

QUERY_NAME="$1"
TSTAMP_TO="$2"
QUERY_PATH="$3"

case "$QUERY_NAME" in
  "EnvironmentAggregate") QUERY_KEY="q2" ;;
  "MaintenanceOwners")    QUERY_KEY="q3" ;;
  "AgentOutlier")         QUERY_KEY="q5" ;;
  "EnvironmentOutlier")   QUERY_KEY="q4" ;;
  *)
    echo "Unknown query name: $QUERY_NAME"
    ;;
esac

INPUT_FILE="${QUERY_PATH}/${QUERY_KEY}.txt"
OUTPUT_FILE="${QUERY_PATH}/${QUERY_NAME}.txt"

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "File $INPUT_FILE non trovato"
  exit 1
fi

sed "s/{TSTAMPTO_PARAM}/${TSTAMP_TO}/g" "$INPUT_FILE" > "$OUTPUT_FILE"

echo "Generated $OUTPUT_FILE (TSTAMP_TO=$TSTAMP_TO)"
