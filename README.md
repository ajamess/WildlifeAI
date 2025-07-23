# WildlifeAI Lightroom Plugin (Fixed)

All Lua fixes applied: numeric fields stored as strings, Tagset loads, require paths use dots, and packaging script works.

## Build (Windows 10)

```powershell
py -3.11 -m venv venv
venv\Scripts\activate
python -m pip install --upgrade pip
pip install -r python\runner\requirements.txt pyinstaller
pyinstaller python\runner\kestrel_runner.py --onefile --name kestrel_runner
copy dist\kestrel_runner.exe plugin\WildlifeAI.lrplugin\bin\win\
python scripts\package_plugin.py
```

Install the resulting `dist/WildlifeAI.lrplugin.zip` in Lightroom (unzip first, then Add via Plug‑in Manager).

## GitHub Push

See docs/BUILDING.md or run standard init/add/commit/push.
