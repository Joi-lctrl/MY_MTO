@echo off
set LOCALHOST=%COMPUTERNAME%
if /i "%LOCALHOST%"=="LAPTOP-TOPLMTNP" (taskkill /f /pid 35888)
if /i "%LOCALHOST%"=="LAPTOP-TOPLMTNP" (taskkill /f /pid 10092)
if /i "%LOCALHOST%"=="LAPTOP-TOPLMTNP" (taskkill /f /pid 21532)
if /i "%LOCALHOST%"=="LAPTOP-TOPLMTNP" (taskkill /f /pid 37492)

del /F cleanup-ansys-LAPTOP-TOPLMTNP-37492.bat
