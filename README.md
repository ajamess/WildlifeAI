
# WildlifeAI Lightroom Plugin

WildlifeAI adds machine-learning assisted image analysis to Adobe Lightroom Classic. It
includes a Lua plug‑in that runs inside Lightroom and a Python runner that performs
species detection and image quality estimation. Predictions are stored as custom
metadata fields that can be used for filtering, smart collections and keywords.

## Features

- Detects bird species using an ONNX model
- Estimates image quality with a Keras model
- Writes results to dedicated metadata fields
- Optionally applies hierarchical keywords based on results
- Provides smart collections for quick filtering
- Review generated crop previews directly inside Lightroom
- Stack photos by predicted scene count
- Integrated logging for troubleshooting

## Repository Layout

```
plugin/              Lightroom plug-in written in Lua
python/runner/       Python analysis runner and scripts
models/              Machine learning models (ONNX and Keras)
scripts/             Build scripts for Windows and macOS
```

## Building the Plug‑in

Prebuilt plug-ins are produced by the GitHub Actions workflow. To build locally
install Python 3.11 and run one of the provided scripts:

### Windows

```cmd
scripts\freeze_win.bat
```

### macOS

```bash
./scripts/freeze_mac.sh
```

Both scripts create a virtual environment, install the dependencies from
`python/runner/requirements.txt`, freeze the Python runner with PyInstaller and
package the plug-in as `dist/WildlifeAI.lrplugin.zip`.

## Manual Installation

1. Unzip `WildlifeAI.lrplugin.zip` (or use the folder directly when developing).
2. In Lightroom Classic choose **File > Plug‑in Manager…**.
3. Click **Add** and select the `WildlifeAI.lrplugin` directory.
4. The plug‑in will appear in the list and can be enabled or disabled.

## Using WildlifeAI

1. Select one or more photos in Lightroom.
2. Choose **Library > Plug‑in Extras > WildlifeAI: Analyze Selected Photos**.
3. The plug‑in calls the Python runner which generates JSON files with the
   analysis results. Metadata fields such as *Detected Species* and *Quality*
   are updated automatically.
4. Use **WildlifeAI: Review Crops…** to view generated crop thumbnails.
5. **WildlifeAI: Stack by Scene Count** stacks photos that contain the same
   number of detected scenes.
6. Additional smart collections named *WildlifeAI: Quality ≥ 90* and
   *WildlifeAI: Low Confidence ≤ 50* are created to help with filtering.

## Runner Self‑test

The runner can be tested outside Lightroom:

```bash
python python/runner/wai_runner.py --photo-list list.txt --output-dir out --self-test
```

This writes a sample JSON result in the output directory and exits.

## Troubleshooting

- **Runner missing** – check the paths in **WildlifeAI: Configure…** or rebuild
  the plug‑in using the scripts above.
- **Models missing** – place `model.onnx`, `quality.keras` and `labels.txt` in
the `models/` directory. If absent, dummy predictions are written.
- **See logs** – choose **WildlifeAI: Open Log Folder** to inspect
  `wildlifeai.log`.

Further details about the architecture, build process and usage are available in
the `docs/` directory.

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