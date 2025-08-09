REM WildlifeAI Windows Build Script
@echo off
setlocal enabledelayedexpansion

echo Building WildlifeAI Runner for Windows...

:: Change to the root directory
cd /d "%~dp0\.."

:: Check if models directory exists, create if not
if not exist "models" (
    echo Creating models directory...
    mkdir models
    echo # Model files should be placed here > models\README.md
    echo # - model.onnx: ONNX species detection model >> models\README.md
    echo # - quality.keras: Keras quality assessment model >> models\README.md
    echo # - labels.txt: Species labels file >> models\README.md
)

:: List what's in models directory
echo Models directory contents:
dir models

:: Use existing virtual environment (.venv) or create a new one (venv)
if exist .venv (
    echo Using existing .venv virtual environment...
    call .venv\Scripts\activate
) else (
    echo Creating new venv virtual environment...
    if exist venv rmdir /s /q venv
    python -m venv venv
    call venv\Scripts\activate
)

:: Upgrade pip and install dependencies
pip install --upgrade pip
pip install -r python\runner\requirements.txt
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu

:: Check if WildlifeAI runner exists
if not exist "python\runner\wildlifeai_runner.py" (
    echo ERROR: WildlifeAI runner not found!
    goto :error
)

:: Create directories if they don't exist
if not exist "plugin\WildlifeAI.lrplugin\bin\win" mkdir "plugin\WildlifeAI.lrplugin\bin\win"

:: Clean previous builds
if exist dist rmdir /s /q dist
if exist build rmdir /s /q build

:: Use existing spec file
echo Using existing PyInstaller spec file...
if not exist "wildlifeai_runner_cpu.spec" (
    echo ERROR: PyInstaller spec file not found: wildlifeai_runner_cpu.spec
    goto :error
)

:: Build using the spec file
echo Building executable with spec file...
pyinstaller wildlifeai_runner_cpu.spec --distpath=dist --workpath=build

:: Check if the executable was created
if not exist "dist\wildlifeai_runner_cpu.exe" (
    echo ERROR: Failed to create CPU executable!
    echo.
    echo Debugging information:
    echo Current directory: %CD%
    echo Dist directory contents:
    if exist dist (dir dist) else (echo Dist directory does not exist)
    echo.
    echo Build directory contents:
    if exist build (dir build) else (echo Build directory does not exist)
    goto :error
)

echo CPU executable created successfully!

:: Copy CPU runner to plugin directory
copy "dist\wildlifeai_runner_cpu.exe" "plugin\WildlifeAI.lrplugin\bin\win\"
echo CPU runner copied to plugin directory

:: Create compatibility symlink
copy "dist\wildlifeai_runner_cpu.exe" "plugin\WildlifeAI.lrplugin\bin\win\kestrel_runner.exe"
echo Compatibility runner created

:: Test the executable
echo Testing executable...
"dist\wildlifeai_runner_cpu.exe" --help >nul 2>&1
if !errorlevel! == 0 (
    echo ✓ Executable test passed
) else (
    echo WARNING: Executable test failed, but continuing...
)

:: GPU version (optional)
echo Checking for CUDA availability...
python - <<'PY' > cuda_check.txt
try:
    import onnxruntime as ort
    print("CUDA available:", "CUDAExecutionProvider" in ort.get_available_providers())
except Exception:
    print("CUDA available: False")
PY
findstr /c:"CUDA available: True" cuda_check.txt >nul
if !errorlevel! == 0 (
    echo Creating GPU version...
    pip install onnxruntime-gpu
    
    :: Create GPU spec file by copying CPU spec
    copy "wildlifeai_runner_cpu.spec" "wildlifeai_runner_gpu.spec" >nul
    python -c "with open('wildlifeai_runner_gpu.spec', 'r') as f: content = f.read(); content = content.replace('wildlifeai_runner_cpu', 'wildlifeai_runner_gpu'); f.close(); f = open('wildlifeai_runner_gpu.spec', 'w'); f.write(content); f.close(); print('GPU spec file created')"
    
    pyinstaller wildlifeai_runner_gpu.spec --distpath=dist --workpath=build
    
    if exist "dist\wildlifeai_runner_gpu.exe" (
        copy "dist\wildlifeai_runner_gpu.exe" "plugin\WildlifeAI.lrplugin\bin\win\"
        echo GPU runner created and copied
    ) else (
        echo WARNING: GPU executable creation failed
    )
) else (
    echo CUDA not available, skipping GPU build
)

:: Package the plugin
echo Packaging plugin...
python scripts\package_plugin.py

:: Cleanup
if exist cuda_check.txt del cuda_check.txt
:: Keep the spec files - don't delete them
deactivate

echo.
echo ===== BUILD COMPLETE =====
echo CPU runner: plugin\WildlifeAI.lrplugin\bin\win\wildlifeai_runner_cpu.exe
if exist "plugin\WildlifeAI.lrplugin\bin\win\wildlifeai_runner_gpu.exe" (
    echo GPU runner: plugin\WildlifeAI.lrplugin\bin\win\wildlifeai_runner_gpu.exe
)
echo Compatibility: plugin\WildlifeAI.lrplugin\bin\win\kestrel_runner.exe

goto :end

:error
echo.
echo ===== BUILD FAILED =====
echo Check the error messages above for details.
if exist venv\Scripts\deactivate.bat call venv\Scripts\deactivate.bat
exit /b 1

:end
endlocal
