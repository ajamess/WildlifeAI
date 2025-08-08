@echo off
setlocal enabledelayedexpansion

REM Move to repository root
pushd "%~dp0.."

REM Create and activate virtual environment
python -m venv venv
call venv\Scripts\activate
REM Ensure Python dependencies are up to date
python -m pip install --upgrade -r python\runner\requirements.txt || exit /b 1

REM Prepare photo list from test images
set "PHOTO_LIST=%TEMP%\wai_photos.txt"
(for %%F in ("%~dp0..\tests\quick\original\*.ARW") do @echo %%~fF) > "%PHOTO_LIST%"

REM Install dependencies (TensorFlow 2.18) and build runner
pip install --upgrade pip >NUL
type python\runner\requirements.txt | findstr /V onnxruntime-directml | findstr /V tensorflow > requirements.tmp
pip install -r requirements.tmp tensorflow==2.18.* pyinstaller >NUL
del requirements.tmp
pyinstaller python\runner\wai_runner.py --onefile --name kestrel_runner >NUL

REM Run test suite
pytest || exit /b 1

echo Build and test completed
popd
endlocal
