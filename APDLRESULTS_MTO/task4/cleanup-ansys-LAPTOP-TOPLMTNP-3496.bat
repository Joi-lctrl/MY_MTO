@echo off
set LOCALHOST=%COMPUTERNAME%
if /i "%LOCALHOST%"=="LAPTOP-TOPLMTNP" (taskkill /f /pid 41304)
if /i "%LOCALHOST%"=="LAPTOP-TOPLMTNP" (taskkill /f /pid 3496)

del /F cleanup-ansys-LAPTOP-TOPLMTNP-3496.bat
