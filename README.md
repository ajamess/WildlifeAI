# WildlifeAI Lightroom Plugin

**WildlifeAI** brings machine‑learning assisted culling to Adobe Lightroom Classic. It detects bird species, estimates image quality and stores the results as searchable metadata. The plug‑in runs entirely offline and requires no external installs beyond the bundled runner binary.

> **Compatibility**
> - **Lightroom Classic** 6.0 or later
> - **Windows 10+** and **macOS** (Intel/Apple Silicon)

---

## Quick Start

1. Download `WildlifeAI.lrplugin.zip` from the [Releases](https://github.com/) page or build it yourself.
2. Extract the archive somewhere permanent.
3. In Lightroom Classic open **File ▸ Plug‑in Manager…** and click **Add…**.
4. Browse to the `WildlifeAI.lrplugin` folder and confirm.
5. (Windows) copy `kestrel_runner.exe` into `WildlifeAI.lrplugin/bin/win/`.
   (macOS) copy `kestrel_runner` into `WildlifeAI.lrplugin/bin/mac/`.
6. The plug‑in now appears in the manager with no red errors.

*Placeholder for screenshot of Lightroom Plug‑in Manager with WildlifeAI added*

---

## Running an Analysis

1. Select one or more photos in the **Library** module.
2. Choose **Library ▸ Plug‑in Extras ▸ WildlifeAI ▸ Analyze Selected Photos**.
3. A progress bar indicates the Python runner is working. When finished a confirmation dialog appears and new metadata is written.

*Placeholder for screenshot of Analyze menu item being chosen*

### Viewing Results

1. Open the right‑hand **Metadata** panel.
2. In the drop‑down choose **WildlifeAI** to reveal the custom fields.
3. Sort or filter based on *Detected Species*, *Quality* and other scores.

*Placeholder for screenshot of Metadata panel showing WildlifeAI fields*

### Reviewing Crops

1. After analysis, choose **Library ▸ Plug‑in Extras ▸ WildlifeAI ▸ Review Crops…**.
2. A dialog displays thumbnail crops of each detection for quick inspection.

*Placeholder for screenshot of the Review Crops dialog*

### Stacking by Scene Count

1. Select analyzed photos.
2. Choose **Library ▸ Plug‑in Extras ▸ WildlifeAI ▸ Stack by Scene Count**.
3. Images with the same detected scene count are stacked with the highest quality image on top.

*Placeholder for screenshot of a photo stack in Lightroom*

### Logging and Preferences

- Open **Library ▸ Plug‑in Extras ▸ WildlifeAI ▸ Configure…** to set runner paths and change options like keyword root, stacking, sidecar writing and crop generation.
- Use **WildlifeAI ▸ Toggle Logging** to quickly enable or disable detailed logging.
- **WildlifeAI ▸ Open Log Folder** opens the directory containing `wildlifeai.log` for troubleshooting.

*Placeholder for screenshot of the configuration dialog*

---

## Building From Source

Prebuilt plug‑ins are produced by the GitHub workflow, but you can build locally with Python 3.11.
Each push to the `main` branch triggers the workflow and uploads `WildlifeAI.lrplugin.zip` as an artifact—see `docs/BUILDING.md` for download steps.

### Windows
```cmd
scripts\freeze_win.bat
```
### macOS
```bash
./scripts/freeze_mac.sh
```
Both scripts create a virtual environment, install `python/runner/requirements.txt`, freeze the runner with PyInstaller and output `dist/WildlifeAI.lrplugin.zip`.

## Testing

Integration tests ensure the runner produces the expected JSON and preview
images. Each folder inside `tests/` contains an `original` directory of input
files plus accompanying `crop`, `export` and `kestrel_database.csv` entries.

Run the full test harness with:

```bash
pytest -s
```
Ensure all Python dependencies are installed before running the tests. The build
scripts create a `venv` directory containing these requirements—activate it
using `venv\Scripts\activate` on Windows or `source venv/bin/activate` on
macOS/Linux, then run `pytest`.

The harness executes the runner for every file and compares each output value to
the database, printing the per‑image results to the console.

---

## Troubleshooting

- **Runner not found** – verify the binary paths in **WildlifeAI ▸ Configure…**.
- **Models missing** – place your ONNX/Keras models in `models/`.
- **Need logs** – open the log folder to view `wildlifeai.log`.

---

## License

WildlifeAI is released under the [MIT License](LICENSE).

