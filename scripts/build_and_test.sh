#!/usr/bin/env bash
# Build the WildlifeAI runner and run a sample inference
# using the quick test images. The script verifies that
# JSON outputs are produced for each image and that the
# "json_path" field matches the file location.
set -euo pipefail

# Move to repository root
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies and build runner
pip install --upgrade pip >/dev/null
# onnxruntime-directml is Windows-specific; skip if unavailable
grep -v onnxruntime-directml python/runner/requirements.txt > "$ROOT_DIR/requirements.tmp"
pip install -r "$ROOT_DIR/requirements.tmp" pyinstaller >/dev/null
pyinstaller python/runner/wai_runner.py --onefile --name kestrel_runner >/dev/null

# Package plugin with built runner
mkdir -p plugin/WildlifeAI.lrplugin/bin/mac
cp dist/kestrel_runner plugin/WildlifeAI.lrplugin/bin/mac/
python scripts/package_plugin.py >/dev/null

# Run the runner in self-test mode using the quick test CSV
OUT_DIR=$(mktemp -d)
python python/runner/wai_runner.py --self-test --photo-list tests/quick/kestrel_database.csv --output-dir "$OUT_DIR" >/dev/null

# Verify JSON outputs
python - <<'PY'
import csv, json, pathlib, sys
out_dir = pathlib.Path(sys.argv[1])
csv_path = pathlib.Path(sys.argv[2])
with open(csv_path, newline="") as f:
    reader = csv.DictReader(f)
    rows = list(reader)
for row in rows:
    stem = pathlib.Path(row['filename']).name
    json_path = out_dir / f"{stem}.json"
    if not json_path.exists():
        raise SystemExit(f"Missing output for {stem}")
    data = json.loads(json_path.read_text())
    if data.get('json_path') != str(json_path):
        raise SystemExit(f"json_path mismatch for {json_path}")
    if data.get('detected_species') != row.get('species', ''):
        raise SystemExit(f"detected_species mismatch for {stem}")
print('All JSON files verified')
PY "$OUT_DIR" tests/quick/kestrel_database.csv

echo "Build and test completed. JSON files are in $OUT_DIR"
