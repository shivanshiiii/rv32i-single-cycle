@echo off
setlocal
cd /d "%~dp0"
python tools\run_flow.py test
exit /b %errorlevel%
