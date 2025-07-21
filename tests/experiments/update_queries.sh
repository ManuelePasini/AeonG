#!/bin/bash

set -euo pipefail
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <size: small | large | big> <Path to query input files>"
    exit 1
fi

SIZE="$1"
QUERY_PATH="$2"
CONFIG_FILE="time_constraints.yaml"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "File $CONFIG_FILE non trovato!"
    exit 1
fi

# Get query input files
query_keys=$(grep '^[a-zA-Z0-9_]\+:' "$CONFIG_FILE" | sed 's/://')

for key in $query_keys; do
    # Get query name
    name=$(awk -v k="$key" '
        $1 == k":" {found=1}
        found && $1 == "name:" {gsub(/"/, "", $2); print $2; exit}
    ' "$CONFIG_FILE")

    # Get the timestamp value for the specified size
    value=$(awk -v k="$key" -v s="$SIZE" '
        $1 == k":" {found=1}
        found && $1 == s":" {gsub(/[ \t]*:$/, "", $2); print $2; exit}
    ' "$CONFIG_FILE")

    # File input: q2.txt (ecc.), File output: EnvironmentAggregate.txt (ecc.)
    input_file="${QUERY_PATH}${key}.txt"
    output_file="${QUERY_PATH}${name}.txt"

    if [[ -f "$input_file" ]]; then
        echo "Generating $output_file with timestamp value $value from $input_file"
        sed "s/{TSTAMPTO_PARAM}/$value/g" "$input_file" > "$output_file"
    else
        echo "File $input_file non trovato, salto."
    fi
done