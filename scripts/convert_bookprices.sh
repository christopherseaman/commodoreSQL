#!/bin/bash
# Convert bookprices Excel files to CSV for import

set -e

# Load environment configuration for file paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/dot.env"

echo "Converting bookprices Excel files to CSV..."

# Clone xlsx2csv if not already present
if [ ! -d "/tmp/xlsx2csv" ]; then
    echo "Installing xlsx2csv converter..."
    cd /tmp
    git clone --depth 1 https://github.com/dilshod/xlsx2csv.git 2>&1 | grep -v "^remote:"
fi

# Convert institutional bookstore pricing
echo "Converting institutional bookstore pricing..."
python3 /tmp/xlsx2csv/xlsx2csv.py \
    "${BOOKPRICES_INSTITUTIONAL_XLSX}" \
    /tmp/bookpricing_sample.csv

echo "  -> /tmp/bookpricing_sample.csv ($(wc -l < /tmp/bookpricing_sample.csv) rows)"

# Convert publisher pricing
echo "Converting publisher list pricing..."
python3 /tmp/xlsx2csv/xlsx2csv.py \
    "${BOOKPRICES_PUBLISHER_XLSX}" \
    /tmp/publisher_pricing_sample.csv

echo "  -> /tmp/publisher_pricing_sample.csv ($(wc -l < /tmp/publisher_pricing_sample.csv) rows)"

echo "Conversion complete!"
