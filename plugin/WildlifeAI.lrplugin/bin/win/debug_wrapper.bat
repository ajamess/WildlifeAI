@echo off
setlocal enabledelayedexpansion

rem Debug wrapper to capture early failures from Lightroom
set "TIMESTAMP=%date:~-4,4%-%date:~-10,2%-%date:~-7,2%_%time:~0,2%-%time:~3,2%-%time:~6,2%"
set "TIMESTAMP=%TIMESTAMP: =0%"

set "DEBUG_LOG=C:\temp\lightroom_debug_%TIMESTAMP%.log"
set "ENV_LOG=C:\temp\lightroom_env_%TIMESTAMP%.log"

echo === LIGHTROOM DEBUG WRAPPER STARTING === > "%DEBUG_LOG%"
echo Timestamp: %TIMESTAMP% >> "%DEBUG_LOG%"
echo Command line args: %* >> "%DEBUG_LOG%"
echo Current directory: %CD% >> "%DEBUG_LOG%"

rem Capture environment
echo === ENVIRONMENT VARIABLES === > "%ENV_LOG%"
echo PATH=%PATH% >> "%ENV_LOG%"
echo TEMP=%TEMP% >> "%ENV_LOG%"
echo USERNAME=%USERNAME% >> "%ENV_LOG%"

rem Get the directory where this batch file is located
set "SCRIPT_DIR=%~dp0"
set "RUNNER_EXE=%SCRIPT_DIR%wildlifeai_runner_cpu.exe"

echo Script directory: %SCRIPT_DIR% >> "%DEBUG_LOG%"
echo Runner executable: %RUNNER_EXE% >> "%DEBUG_LOG%"

rem Check if the executable exists
if not exist "%RUNNER_EXE%" (
    echo ERROR: executable not found >> "%DEBUG_LOG%"
    exit /b 1
)

echo Executable found, attempting to run... >> "%DEBUG_LOG%"
echo Full command: "%RUNNER_EXE%" %* >> "%DEBUG_LOG%"

rem Try to execute the runner and capture both stdout and stderr
"%RUNNER_EXE%" %* 2>&1 >> "%DEBUG_LOG%"

rem Capture the exit code
set EXIT_CODE=%ERRORLEVEL%

echo Exit code: %EXIT_CODE% >> "%DEBUG_LOG%"
echo === LIGHTROOM DEBUG WRAPPER ENDING === >> "%DEBUG_LOG%"

rem Always copy debug log to multiple locations for safety
copy "%DEBUG_LOG%" "C:\temp\latest_lightroom_debug.log" > nul 2>&1
copy "%ENV_LOG%" "C:\temp\latest_lightroom_env.log" > nul 2>&1

rem Return the actual exit code
exit /b %EXIT_CODE%
