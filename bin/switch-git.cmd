@echo off
powershell.exe -NoProfile -InputFormat None -ExecutionPolicy Bypass -File "%~dp0git-account-switcher.ps1" %*
