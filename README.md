# WildlifeAI

This repository contains the sample code for the WildlifeAI Lightroom plugin.

## Building the Plugin

The plugin is built on Windows using PyInstaller. Run `scripts/freeze_win.bat`
to create `dist/WildlifeAI.lrplugin.zip` which can be installed into Lightroom.

## Running Tests

Tests use `pytest`. They validate that the Python runner can reproduce the
results stored in `tests/quick/kestrel_database.csv`.

```
pytest
```

## Self Test

The runner includes a self test mode which reads `kestrel_database.csv` and
writes `selftest.json` files for each entry. Example:

```
python python/runner/wai_runner.py --self-test \
    --photo-list tests/quick/kestrel_database.csv \
    --output-dir output_test
```

## Local Development

Clone the repository and install the Python requirements, then run the tests:

```
pip install -r python/runner/requirements.txt
pytest
```

