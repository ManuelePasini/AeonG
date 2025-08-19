#!/bin/bash

# Directory da processare (modifica se necessario)
DIR="."

# Ciclo su tutti i file che contengono "MaintenanceOwners" nel nome
for file in "$DIR"/*MaintenanceOwners*; do
    # Controlla se è un file regolare
    if [[ -f "$file" ]]; then
        # Mantiene solo la prima riga e sovrascrive il file
        head -n 1 "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
        echo "Processato: $file"
    fi
done