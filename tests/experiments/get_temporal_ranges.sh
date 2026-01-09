#!/bin/bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <config.yaml> <constraintType> <queryName> <datasetSize>"
  exit 1
fi

CONFIG_FILE="$1"
CONSTRAINT="$2"
QUERY="$3"
SIZE="$4"

python3 - <<EOF
import sys, yaml

CONSTRAINT = "${CONSTRAINT}"
QUERY = "${QUERY}"
SIZE = "${SIZE}"
CONFIG_FILE = "${CONFIG_FILE}"

with open(CONFIG_FILE) as f:
    data = yaml.safe_load(f)

try:
    dataset = data["temporalConstraints"][CONSTRAINT][QUERY][SIZE]
except KeyError:
    sys.exit(f"No data found for {CONSTRAINT} -> {QUERY} -> {SIZE}")

for k, v in dataset.items():
    print(f"{k} {v}")
EOF