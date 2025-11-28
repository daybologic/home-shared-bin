#!/bin/bash

set -euo pipefail

# Get today's date in YYYY-MM-DD format
date_str=$(date +%F)

for f in *.*; do
    # Skip if not a regular file
    [ -f "$f" ] || continue

    base="${f%.*}"
    ext="${f##*.}"

    mv "$f" "${base}-${date_str}.${ext}"
done
