@echo off
setlocal enabledelayedexpansion

REM Build the runner and package the plugin
call "%~dp0freeze_wildlifeai_win.bat" || exit /b 1

REM Prepare photo list from test images
set "PHOTO_LIST=%TEMP%\wai_photos.txt"
(for %%F in ("%~dp0..\tests\quick\original\*.ARW") do @echo %%~fF) > "%PHOTO_LIST%"

REM Run the runner on the test images
set "OUT_DIR=%TEMP%\wai_output"
if exist "%OUT_DIR%" rmdir /s /q "%OUT_DIR%"
mkdir "%OUT_DIR%"
python python\runner\wai_runner.py --photo-list "%PHOTO_LIST%" --output-dir "%OUT_DIR%" --no-crop || exit /b 1

REM Verify JSON outputs
for %%F in ("%~dp0..\tests\quick\original\*.ARW") do (
    set "JSON=%OUT_DIR%\%%~nxF.json"
    if not exist "!JSON!" (
        echo Missing output for %%F
        exit /b 1
    )
    python -c "import json,sys; p=sys.argv[1]; d=json.load(open(p)); assert d.get('json_path')==p" "!JSON!" || exit /b 1
)

echo Build and test completed. JSON files are in %OUT_DIR%
endlocal
