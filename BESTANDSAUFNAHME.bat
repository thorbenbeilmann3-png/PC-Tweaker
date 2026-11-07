@echo off
setlocal
cd /d "%~dp0"
echo === NOXARION Phase 1: PC-Bestandsaufnahme (rein lesend) ===
echo Es wird nichts geloescht, deinstalliert oder umgestellt.
echo Optional: Rechtsklick ^> "Als Administrator ausfuehren" fuer Wiederherstellungspunkte/BitLocker.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Bestandsaufnahme.ps1" -Anonymisieren
echo.
pause
