# WildlifeAI Lightroom Plugin

Standalone Lightroom Classic plugin that runs ProjectKestrel (TensorFlow) on selected photos, writes sortable metadata, stacks by scene, and mirrors `.kestrel` output.

## Quick Start (Local Windows Build)

```bat
py -3.11 -m venv venv
venv\Scripts\activate
pip install -r python\runner\requirements.txt pyinstaller
pyinstaller python\runner\kestrel_runner.py --onefile --name kestrel_runner
copy dist\kestrel_runner.exe plugin\WildlifeAI.lrplugin\bin\win\
python scripts\package_plugin.py
```

Then unzip `dist/WildlifeAI.lrplugin.zip` somewhere and add it via Lightroom's Plug‑in Manager.

## One-click CI
Tag a release (`v1.0.0`) and GitHub Actions in `.github/workflows/build-win-mac.yml` will build and attach zips.
