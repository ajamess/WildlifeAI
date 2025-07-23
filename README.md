# WildlifeAI Lightroom Plugin

A standalone Adobe Lightroom Classic plug‑in that runs the **ProjectKestrel** TensorFlow bird detector on selected photos, writes results into custom, sortable metadata fields, optionally stacks related shots, and mirrors the standard `.kestrel` output for offline browsing.

> **Platforms:** Windows 10+ & macOS (Intel/ARM)  
> **Lightroom:** Classic 6.0+ (tested on latest Classic)  
> **Status:** Production‑ready; all dependencies can be shipped inside the plug‑in bundle.

---

## Table of Contents

1. [Quick Start (User Install)](#quick-start-user-install)  
2. [Features](#features)  
3. [Repo / Folder Structure](#repo--folder-structure)  
4. [Build From Source](#build-from-source)  
5. [Install the Plug‑in in Lightroom](#install-the-plug-in-in-lightroom)  
6. [Run an Analysis](#run-an-analysis)  
7. [View & Use Metadata](#view--use-metadata)  
8. [Stacking & Smart Collections](#stacking--smart-collections)  
9. [Configuration & Logging](#configuration--logging)  
10. [Troubleshooting](#troubleshooting)  
11. [CI / GitHub Actions (optional)](#ci--github-actions-optional)  
12. [License](#license)

---

## Quick Start (User Install)

1. **Download** the latest `WildlifeAI.lrplugin.zip` from Releases (or from `dist/` after you build).  
2. **Unzip** it to a stable folder (not your temp folder).  
3. **Windows:** copy `kestrel_runner.exe` into `WildlifeAI.lrplugin/bin/win/`  
   **macOS:** copy `kestrel_runner` into `WildlifeAI.lrplugin/bin/mac/`  
4. In Lightroom Classic:  
   `File ▸ Plug‑in Manager… ▸ Add…` → select the `WildlifeAI.lrplugin` folder.  
5. (Optional) Go to **Plug‑in Extras ▸ Configure WildlifeAI…** and enable logging / tweak options.  
6. Select photos → **Plug‑in Extras ▸ Analyze Selected Photos with WildlifeAI**.

---

## Features

- **TensorFlow Bird Detection** via ProjectKestrel runner (PyInstaller one‑file binary).  
- **Custom Lightroom Metadata Fields** (all stored as strings so they’re searchable/browsable):  
  - Detected Species  
  - Species Confidence (0–100)  
  - Quality (0–100)  
  - Rating (0–100)  
  - Scene Count  
  - Feature Similarity (0–100)  
  - Color Similarity (0–100)  
  - Color Confidence (0–100)  
  - JSON Result Path (URL)  
- **Keyword Hierarchies:** e.g. `WildlifeAI|Species|American Kestrel`, `WildlifeAI|Quality|90-99`.  
- **Scene Stacking:** Stack images by Scene Count, highest Quality at the top.  
- **.kestrel Output:** Keeps JSON results in a `.kestrel` folder for offline review.  
- **Verbose Logging:** Toggleable file log at `logs/wildlifeai.log` with a menu shortcut.  
- **Cull Panel & Smart Collections:** Quick list sorted by Quality/Confidence and helper smart collections.  
- **Standalone:** Ships with all Lua, Python, models/binaries—no user installs Python/TensorFlow.

---

## Repo / Folder Structure

```
WildlifeAI/
├─ plugin/
│  └─ WildlifeAI.lrplugin/
│     ├─ Info.lua
│     ├─ PluginInit.lua
│     ├─ MetadataDefinition.lua
│     ├─ Tagset.lua
│     ├─ KestrelBridge.lua
│     ├─ Tasks.lua
│     ├─ QualityStack.lua
│     ├─ SmartCollections.lua
│     ├─ KeywordHelper.lua
│     ├─ utils/
│     │   ├─ dkjson.lua
│     │   └─ Log.lua
│     ├─ UI/
│     │   ├─ ConfigDialog.lua
│     │   ├─ ToggleLogging.lua
│     │   ├─ OpenLogFolder.lua
│     │   └─ CullPanel.lua
│     ├─ bin/
│     │   ├─ win/kestrel_runner.exe
│     │   └─ mac/kestrel_runner
│     └─ logs/   (created at runtime)
├─ python/
│  └─ runner/
│     ├─ kestrel_runner.py
│     ├─ kestrel_parser.py
│     ├─ requirements.txt
│     └─ (vendored ProjectKestrel code)
├─ scripts/
│  ├─ freeze_win.bat
│  └─ package_plugin.py
├─ docs/
│  ├─ BUILDING.md
│  ├─ USER_GUIDE.md
│  └─ screenshots/
│      ├─ plugin_manager_add.png
│      ├─ config_dialog.png
│      ├─ metadata_panel.png
│      └─ log_folder.png
├─ .github/workflows/ (optional CI)
├─ LICENSE
├─ README.md
└─ .gitignore
```

---

## Build From Source

### Windows 10+

```powershell
# From repo root
py -3.11 -m venv venv
venv\Scripts\activate

python -m pip install --upgrade pip
pip install -r python\runner\requirements.txt pyinstaller

# Build the ProjectKestrel runner
pyinstaller python\runner\kestrel_runner.py --onefile --name kestrel_runner

# Put runner into plugin
copy dist\kestrel_runner.exe plugin\WildlifeAI.lrplugin\bin\win\

# Package plugin
python scripts\package_plugin.py
# => dist\WildlifeAI.lrplugin.zip
```

### macOS

```bash
python3 -m venv venv && source venv/bin/activate
pip install --upgrade pip
pip install -r python/runner/requirements.txt pyinstaller

pyinstaller python/runner/kestrel_runner.py --onefile --name kestrel_runner
cp dist/kestrel_runner plugin/WildlifeAI.lrplugin/bin/mac/

python scripts/package_plugin.py
# => dist/WildlifeAI.lrplugin.zip
```

*(Sign / notarize the mac binary if you plan to distribute broadly.)*

---

## Install the Plug‑in in Lightroom

1. Unzip `WildlifeAI.lrplugin.zip` somewhere permanent.  
2. In LR Classic: `File ▸ Plug‑in Manager… ▸ Add…` → select that folder.  
3. Ensure there are **no red error messages** in the Plug‑in Manager.

![Add plug‑in](docs/screenshots/plugin_manager_add.png)

---

## Run an Analysis

1. Select one or more photos in Library.  
2. `Library ▸ Plug‑in Extras ▸ WildlifeAI ▸ Analyze Selected Photos with WildlifeAI`.  
3. A progress scope appears; results are written to metadata and JSON files.  
4. You get a completion dialog when finished.

---

## View & Use Metadata

- In the right panel (Library), open the **Metadata** section.  
- From the drop‑down, choose **WildlifeAI**.  
- Fields populate after analysis:

![Metadata panel](docs/screenshots/metadata_panel.png)

### Field Reference

| Field               | Meaning                                   | Range     |
|---------------------|--------------------------------------------|-----------|
| Detected Species    | Best species guess                         | text      |
| Species Confidence  | Model confidence (%)                       | 0–100     |
| Quality             | Image quality score (%)                    | 0–100     |
| Rating              | Supplemental rank (0–100)                  | 0–100     |
| Scene Count         | Number of frames/scene matches             | int       |
| Feature Similarity  | Feature vector similarity (%)              | 0–100     |
| Color Similarity    | Color-space similarity (%)                 | 0–100     |
| Color Confidence    | Color prediction confidence (%)            | 0–100     |
| JSON Result Path    | File URL to raw JSON                       | url       |

> Lightroom cannot sort by plug‑in fields in the Grid sort menu. Use Smart Collections or mirror values to IPTC (see Config) if you need sort.

---

## Stacking & Smart Collections

**Stack images:**  
`Plug‑in Extras ▸ WildlifeAI ▸ Stack by Scene Count`  
- Groups by `Scene Count`  
- Highest `Quality` becomes the stack head

**Smart Collections:**  
`Plug‑in Extras ▸ WildlifeAI ▸ Generate Smart Collections` creates:

- `WildlifeAI: Quality ≥ 90`  
- `WildlifeAI: Low Confidence ≤ 50`

Feel free to edit `SmartCollections.lua` to add more.

---

## Configuration & Logging

**Open dialog:**  
`Plug‑in Extras ▸ WildlifeAI ▸ Configure WildlifeAI…`

Options include:

- Windows Runner EXE / macOS Runner Bin path  
- Keyword Root (hierarchy base)  
- Enable stacking after analysis  
- Write XMP sidecars after metadata write  
- Mirror numeric fields to IPTC Job Identifier (sortable workaround)  
- **Enable verbose logging** (default OFF)

![Config dialog](docs/screenshots/config_dialog.png)

**Toggle logging quickly:**  
`Plug‑in Extras ▸ WildlifeAI ▸ Toggle Logging On/Off`

**Open log folder:**  
`Plug‑in Extras ▸ WildlifeAI ▸ Open Log Folder`  
Log file: `plugin/WildlifeAI.lrplugin/logs/wildlifeai.log`

![Log folder](docs/screenshots/log_folder.png)

---

## Troubleshooting

| Symptom | Cause | Fix |
|--------|-------|-----|
| Tagset shows but panel is blank | Tagset/metadata schema not loaded | Bump `schemaVersion`, remove/re‑add plug‑in |
| “Could not find namespace: LrMetadataTagsetFactory” | Import failing | Use table fallback (already implemented) |
| `utils.dkjson` not found | `require` sandboxed | We load via `dofile()` with full path |
| `withWriteAccessDo` blocked / deadlock | Nested write blocks | We now use a single write block w/ timeout |
| Runner path nil / not found | Prefs not set; binary missing | Copy EXE/bin and set path in Configure dialog |
| No log file | Logging disabled | Enable in Configure dialog or Toggle Logging |
| Nothing happens on analysis | Runner crash or error | Check `logs/wildlifeai.log` and LR Plug‑in Manager pane |

If stuck, enable logging, reproduce, then share `logs/wildlifeai.log`.

---

## CI / GitHub Actions (optional)

A sample workflow (`.github/workflows/build.yml`) builds the runner and zips the plug‑in when you push a tag (e.g., `v1.0.1`) and attaches it to the release.

---

## License

MIT (replace if ProjectKestrel’s license requires otherwise).

```
MIT License
Copyright (c) 2025 <Your Name>
Permission is hereby granted, free of charge, to any person obtaining a copy...
```

---

## Contributing

1. Fork & clone.  
2. Create a feature branch.  
3. Test in LR (enable logging).  
4. Submit a PR.

---

## Git Commands to Push This Repo

```bash
git init
git add .
git commit -m "Initial commit: WildlifeAI Lightroom plugin + runner"
git remote add origin git@github.com:<YOU>/WildlifeAI.git
git push -u origin main

# Tag a release
git tag v1.0.0
git push origin v1.0.0
```

---

## Screenshot Placeholders

Put these in `docs/screenshots/` and update paths above:

- `plugin_manager_add.png` – Adding the plug‑in in Plug‑in Manager  
- `config_dialog.png` – Configuration dialog screenshot  
- `metadata_panel.png` – Metadata panel with fields populated  
- `log_folder.png` – Explorer/Finder window showing `logs/` folder

---

Happy birding! 🐦
