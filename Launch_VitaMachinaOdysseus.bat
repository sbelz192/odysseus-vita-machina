@echo off
chcp 65001 >nul
title Vita Machina Odyssey Launcher

:: ───── Pfade ─────
set "ROOT=%~dp0"
set "DATA_DIR=%~dp0data"
set "LOG_DIR=%~dp0data\logs"

:: Log-Verzeichnis anlegen
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

echo ════════════════════════════════════════════
echo   Vita Machina — Odyssey Launcher
echo ════════════════════════════════════════════
echo.
echo Logs: %LOG_DIR%
echo.

:: ───── 1. Ollama starten ─────
echo [1/3] Starte Ollama ...
tasklist /FI "IMAGENAME eq ollama.exe" 2>NUL | find /I "ollama.exe" >NUL
if "%ERRORLEVEL%"=="0" (
    echo   → Ollama läuft bereits.
) else (
    start "Ollama" /B ollama serve >"%LOG_DIR%\ollama.log" 2>&1
    if errorlevel 1 (
        echo   ⚠ Fehler beim Starten von Ollama
    ) else (
        echo   → Ollama gestartet (PID via Task-Manager)
    )
)

:: ───── 2. Docker Compose (ChromaDB / Odyssey) starten ─────
echo [2/3] Starte Docker Compose ...
cd /d "%ROOT%"
docker compose up -d >"%LOG_DIR%\odysseus.log" 2>&1
if errorlevel 1 (
    echo   ⚠ Docker Compose meldet Fehler (siehe Log)
) else (
    echo   → Docker Compose gestartet
)

:: ───── 3. Flask-App starten ─────
echo [3/3] Starte Odysseus Web-App ...
echo.
echo ════════════════════════════════════════════
echo   App: http://127.0.0.1:7000
echo   Logs: %LOG_DIR%
echo ════════════════════════════════════════════
echo.
cd /d "%ROOT%"

:: launch-windows.ps1 rufen (falls vorhanden)
if exist "%ROOT%launch-windows.ps1" (
    powershell -ExecutionPolicy Bypass -File "%ROOT%launch-windows.ps1"
) else (
    :: Fallback: Direkt via uvicorn
    if exist "%ROOT%venv\Scripts\python.exe" (
        "%ROOT%venv\Scripts\python.exe" -m uvicorn app:app --host 127.0.0.1 --port 7000
    ) else (
        python -m uvicorn app:app --host 127.0.0.1 --port 7000
    )
)

:: ───── Shutdown ─────
echo.
echo ════════════════════════════════════════════
echo   Shutdown ...
echo ════════════════════════════════════════════
taskkill /FI "WINDOWTITLE eq Ollama" /F >nul 2>&1
docker compose down >nul 2>&1
echo   Ollama + Docker Compose gestoppt.
echo.
pause
