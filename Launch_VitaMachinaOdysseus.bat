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

:: ───── 1. Docker Desktop Check ─────
echo [1/3] Pruefe Docker ...
docker info >nul 2>&1
if errorlevel 1 (
    echo   ⚠ Docker Desktop laeuft nicht!
    echo     Starte Docker Desktop und versuche es erneut.
    echo     → docker compose up wird uebersprungen.
    echo.
    set "DOCKER_SKIPPED=1"
) else (
    echo   ✓ Docker laeuft.
    set "DOCKER_SKIPPED=0"
)

:: ───── 2. Ollama starten ─────
echo.
echo [2/3] Starte Ollama ...

:: Pruefen ob ollama im PATH ist
where ollama >nul 2>&1
if errorlevel 1 (
    echo   ⚠ 'ollama' ist nicht im PATH oder nicht installiert.
    echo     Bitte ollama installieren: https://ollama.com/download
    echo     → Ollama wird uebersprungen.
    echo.
    set "OLLAMA_SKIPPED=1"
) else (
    echo   ✓ ollama.exe gefunden.
    
    :: Pruefen ob bereits ein ollama.exe Prozess laeuft
    tasklist /FI "IMAGENAME eq ollama.exe" 2>NUL | find /I "ollama.exe" >NUL
    if not errorlevel 1 (
        echo   → Ollama laeuft bereits.
    ) else (
        :: Ollama starten — Log-Datei mit Timestamp-Praeambel
        echo --- Ollama gestartet am %DATE% %TIME% --- >"%LOG_DIR%\ollama.log"
        start "OllamaSvc" /B ollama serve >>"%LOG_DIR%\ollama.log" 2>&1
        
        :: Kurz warten und checken ob der Prozess wirklich laeuft
        timeout /t 3 /nobreak >nul
        tasklist /FI "IMAGENAME eq ollama.exe" 2>NUL | find /I "ollama.exe" >NUL
        if errorlevel 1 (
            echo   ⚠ Ollama konnte nicht gestartet werden.
            echo     Pruefe %LOG_DIR%\ollama.log auf Fehler.
        ) else (
            echo   ✓ Ollama gestartet.
        )
    )
    set "OLLAMA_SKIPPED=0"
)

:: ───── 3. Docker Compose (ChromaDB / Odyssey) starten ─────
echo.
if "%DOCKER_SKIPPED%"=="1" (
    echo [3/3] Docker Compose uebersprungen (Docker nicht verfuegbar).
) else (
    echo [3/3] Starte Docker Compose ...
    cd /d "%ROOT%"
    
    :: Log-Datei mit Timestamp-Praeambel
    echo --- Docker Compose gestartet am %DATE% %TIME% --- >"%LOG_DIR%\odysseus.log"
    docker compose up -d >>"%LOG_DIR%\odysseus.log" 2>&1
    
    if errorlevel 1 (
        echo   ⚠ Docker Compose meldet Fehler (siehe %LOG_DIR%\odysseus.log)
    ) else (
        echo   ✓ Docker Compose gestartet.
    )
)

:: ───── 4. Flask-App starten ─────
echo.
echo [4/4] Starte Odysseus Web-App ...
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

:: Ollama per Prozess-Namen killen (nicht per WindowTitle, da /B kein Fenster erzeugt)
taskkill /IM ollama.exe /F >nul 2>&1
if errorlevel 1 (
    echo   → Ollama war nicht aktiv.
) else (
    echo   ✓ Ollama gestoppt.
)

:: Docker Compose stoppen (nur wenn Docker verfuegbar war)
if not "%DOCKER_SKIPPED%"=="1" (
    docker compose down >nul 2>&1
    if errorlevel 1 (
        echo   ⚠ Fehler beim Stoppen von Docker Compose.
    ) else (
        echo   ✓ Docker Compose gestoppt.
    )
) else (
    echo   → Docker Compose uebersprungen.
)

echo.
echo   Alle Dienste beendet.
echo.
pause
