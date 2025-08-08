#!/usr/bin/env bash
# Build the WildlifeAI runner and execute the test suite.
set -euo pipefail

# Move to repository root
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies (TensorFlow 2.18) and build runner
pip install --upgrade pip >/dev/null
# onnxruntime-directml is Windows-specific; skip if unavailable and pin TensorFlow
grep -v onnxruntime-directml python/runner/requirements.txt | grep -v tensorflow > "$ROOT_DIR/requirements.tmp"
pip install -r "$ROOT_DIR/requirements.tmp" tensorflow==2.18.* pyinstaller >/dev/null
rm "$ROOT_DIR/requirements.tmp"
pyinstaller python/runner/wai_runner.py --onefile --name kestrel_runner >/dev/null

# Run test suite
pytest

echo "Build and test completed"
