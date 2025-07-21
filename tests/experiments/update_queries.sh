#!/bin/bash

set -euo pipefail

# Controllo del parametro
if [[ $# -ne 1 ]]; then
    echo "Uso: $0 <size: small | large | big>"
    exit 1
fi

SIZE="$1"
CONFIG_FILE="time_constraints.yaml"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "File $CONFIG_FILE non trovato!"
    exit 1
fi

# Estrai tutte le chiavi principali dallo YAML
query_names=$(grep '^[A-Za-z]' "$CONFIG_FILE" | sed 's/://')

for query in $query_names; do
    # Estrai il valore corrispondente alla size dalla sezione della query
    value=$(awk -v q="$query" -v s="$SIZE" '
        $1 == q":" {found=1}
        found && $1 == s":" {gsub(/[ \t]*:$/, "", $2); print $2; exit}
    ' "$CONFIG_FILE")

    # Verifica se il file esiste
    txt_file="${query}.txt"
    if [[ -f "$txt_file" ]]; then
        echo "Aggiorno $txt_file con $value"
        sed -i "s/{TSTAMPTO_PARAM}/$value/g" "$txt_file"
    else
        echo "File $txt_file non trovato, salto."
    fi
done
