@echo off
setlocal
set SCRIPT_DIR=%~dp0
rem Remove trailing backslash if present
if "%SCRIPT_DIR:~-1%"=="\" set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%

cmake -P "%SCRIPT_DIR%\spm.cmake" -- %*
endlocal
