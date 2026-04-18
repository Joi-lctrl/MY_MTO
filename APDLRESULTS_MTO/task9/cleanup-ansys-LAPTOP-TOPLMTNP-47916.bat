@echo off
set LOCALHOST=%COMPUTERNAME%
if /i "%LOCALHOST%"=="LAPTOP-TOPLMTNP" (taskkill /f /pid 39692)
if /i "%LOCALHOST%"=="LAPTOP-TOPLMTNP" (taskkill /f /pid 47916)

del /F cleanup-ansys-LAPTOP-TOPLMTNP-47916.bat
