@echo off
setlocal
cd /d "%~dp0"
python tools\run_flow.py all
exit /b %errorlevel%
