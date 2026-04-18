@echo off
set LOCALHOST=%COMPUTERNAME%
if /i "%LOCALHOST%"=="LAPTOP-TOPLMTNP" (taskkill /f /pid 2292)
if /i "%LOCALHOST%"=="LAPTOP-TOPLMTNP" (taskkill /f /pid 14912)

del /F cleanup-ansys-LAPTOP-TOPLMTNP-14912.bat
