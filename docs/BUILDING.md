# Building WildlifeAI

The build process produces an executable runner and packages the Lightroom
plug-in. The easiest way is to run the provided scripts which handle creation of
a Python virtual environment and execution of PyInstaller.

## Prerequisites

- Python 3.11
- `pip`
- On macOS: Xcode command line tools for compiling Python wheels

## Windows

```cmd
scripts\freeze_win.bat
```

The script creates `venv/`, installs dependencies from
`python\runner\requirements.txt`, runs PyInstaller and copies the resulting
`kestrel_runner.exe` to `plugin\WildlifeAI.lrplugin\bin\win`. Finally the plug-in
is zipped to `dist\WildlifeAI.lrplugin.zip`.

## macOS

```bash
./scripts/freeze_mac.sh
```

The steps mirror the Windows script and produce
`dist/WildlifeAI.lrplugin.zip` containing the macOS binary.

## Manual Packaging

To rebuild the archive after making manual changes to the plug-in files run:

```bash
python scripts/package_plugin.py
```

The archive will be created in the `dist/` directory.
