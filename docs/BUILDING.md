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
scripts\freeze_wildlifeai_win.bat
```

The script creates `venv/`, installs dependencies from
`python\runner\requirements.txt`, runs PyInstaller and copies the resulting
`wildlifeai_runner_cpu.exe` to `plugin\WildlifeAI.lrplugin\bin\win`. For compatibility,
it also creates a copy named `kestrel_runner.exe` in the same directory. Finally the plug-in
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

## Build and Test

For an end-to-end build followed by a quick inference test, run:

```bash
scripts/build_and_test.sh
```

The script builds the runner with PyInstaller, packages the plug-in, and runs
`python/runner/wai_runner.py` on the sample images in `tests/quick/original/`.
It then verifies that a JSON file is produced for each image.
