@echo off
setlocal
cd /d "%~dp0"
where py >nul 2>nul || (echo Python 3.11+ fehlt.& pause & exit /b 1)
if not exist .venv py -3 -m venv .venv
call .venv\Scripts\activate.bat
python -m pip install --upgrade pip
pip install -e ".[dev]"
if errorlevel 1 goto :error
pyinstaller --noconfirm --clean --windowed --name PC-Tweaker --paths src src\pc_tweaker\main.py
if errorlevel 1 goto :error
echo EXE erstellt unter dist\PC-Tweaker\
pause
exit /b 0
:error
echo EXE-Build fehlgeschlagen.
pause
exit /b 1
