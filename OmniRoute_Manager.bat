@echo off
pushd "%~dp0"
:: Use START to instantly close this black terminal window, and use maximum PowerShell performance flags
start "" powershell -NoProfile -NoLogo -NonInteractive -Sta -ExecutionPolicy Bypass -WindowStyle Hidden -File "gui.ps1"
