@echo off
cd /d "%~dp0"
for /d %%D in ("%~dp0.tools\node-v*-win-x64") do set "PATH=%%~fD;%PATH%"
node "%~dp0tool\connect-firebase.mjs"
pause
