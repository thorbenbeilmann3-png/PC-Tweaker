@echo off
setlocal
cd /d "%~dp0"
echo === PC-Tweaker starten ===
where py >nul 2>nul
if errorlevel 1 (
  echo Python wurde nicht gefunden. Bitte Python 3.11 oder neuer installieren:
  start "" https://www.python.org/downloads/windows/
  pause
  exit /b 1
)
if not exist .venv py -3 -m venv .venv
call .venv\Scripts\activate.bat
python -m pip install --upgrade pip
if errorlevel 1 goto :error
pip install -e .
if errorlevel 1 goto :error
python -m pc_tweaker.main
if errorlevel 1 goto :error
exit /b 0
:error
echo Fehler beim Einrichten oder Starten. Details stehen oben.
pause
exit /b 1
