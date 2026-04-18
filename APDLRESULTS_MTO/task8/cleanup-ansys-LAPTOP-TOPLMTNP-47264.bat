@echo off
set LOCALHOST=%COMPUTERNAME%
if /i "%LOCALHOST%"=="LAPTOP-TOPLMTNP" (taskkill /f /pid 23304)
if /i "%LOCALHOST%"=="LAPTOP-TOPLMTNP" (taskkill /f /pid 47264)

del /F cleanup-ansys-LAPTOP-TOPLMTNP-47264.bat
