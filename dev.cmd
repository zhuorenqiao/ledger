@echo off
rem Thin wrapper so the script works from a double-click or "dev" in cmd,
rem without touching the machine-wide execution policy.
rem Any argument is forwarded to dev.ps1, e.g.: dev.cmd -Target android
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0dev.ps1" %*
