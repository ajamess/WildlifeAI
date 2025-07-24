#!/usr/bin/env bash
set -euo pipefail
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r python/runner/requirements.txt pyinstaller
pyinstaller python/runner/wai_runner.py --onefile --name kestrel_runner
mkdir -p plugin/WildlifeAI.lrplugin/bin/mac
cp dist/kestrel_runner plugin/WildlifeAI.lrplugin/bin/mac/
python scripts/package_plugin.py
