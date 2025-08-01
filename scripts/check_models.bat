REM Save this as: scripts/check_models.bat
@echo off
echo Checking model file locations...
echo.

echo 1. Root models directory:
if exist "models" (
    echo   ✓ models\ exists
    dir models\ /b
) else (
    echo   ✗ models\ does not exist
)

echo.
echo 2. Plugin models directory:
if exist "plugin\WildlifeAI.lrplugin\bin\win" (
    echo   ✓ plugin\WildlifeAI.lrplugin\bin\win\ exists
    dir plugin\WildlifeAI.lrplugin\bin\win\ /b
) else (
    echo   ✗ plugin\WildlifeAI.lrplugin\bin\win\ does not exist
)

echo.
echo 3. Looking for model files anywhere:
echo Searching for model.onnx...
for /r . %%i in (model.onnx) do echo   Found: %%i
echo.
echo Searching for quality.keras...
for /r . %%i in (quality.keras) do echo   Found: %%i
echo.
echo Searching for labels.txt...
for /r . %%i in (labels.txt) do echo   Found: %%i