@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0switch-git.ps1" %*
