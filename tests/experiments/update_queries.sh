#!/bin/bash

set -euo pipefail

# Controllo del parametro
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <size: small | large | big>, $1 <Path to queries files>"
    exit 1
fi

SIZE="$1"
QUERY_PATH="$2"
CONFIG_FILE="time_constraints.yaml"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "File $CONFIG_FILE non trovato!"
    exit 1
fi

# Get query names from the config file
query_names=$(grep '^[A-Za-z]' "$CONFIG_FILE" | sed 's/://')

for query in $query_names; do
    # Get the corresponding temporal constraint for the given size
    value=$(awk -v q="$query" -v s="$SIZE" '
        $1 == q":" {found=1}
        found && $1 == s":" {gsub(/[ \t]*:$/, "", $2); print $2; exit}
    ' "$CONFIG_FILE")

    # Update the query file with the temporal constraint
    txt_file="${QUERY_PATH}${query}.txt"
    if [[ -f "$txt_file" ]]; then
        echo "Updating $txt_file temporal constraint to $SIZE value: $value"
        sed -i "s/{TSTAMPTO_PARAM}/$value/g" "$txt_file"
    else
        echo "File $txt_file non trovato, salto."
    fi
done
