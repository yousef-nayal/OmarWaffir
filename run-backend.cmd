@echo off
REM Delayed expansion is disabled explicitly: with it on, cmd swallows the "!"
REM in the seeded passwords printed below. Some machines turn it on globally
REM through the Command Processor registry key, so relying on the default is
REM not enough.
setlocal DisableDelayedExpansion

REM ===========================================================================
REM  Waffir backend launcher
REM
REM  Starts PostgreSQL (portable install, not a Windows service) and then the
REM  Laravel API on port 8000.
REM
REM  Just double-click this file, or run it from a terminal:
REM      run-backend.cmd
REM
REM  Once it is running, forward port 8000 in VS Code and set the port
REM  visibility to Public, then point the app at:
REM      https://<your-tunnel>/api/v1
REM
REM  To reset the database to fresh seed data (DESTROYS all local data):
REM      run-backend.cmd --fresh
REM ===========================================================================

REM ── Tool locations. Override any of these before running if you move them. ──
if "%PHP%"==""     set "PHP=F:\devtools\php\php.exe"
if "%PG_BIN%"==""  set "PG_BIN=F:\devtools\pg\pgsql\bin"
if "%PG_DATA%"=="" set "PG_DATA=F:\devtools\pgdata"
if "%PG_LOG%"==""  set "PG_LOG=F:\devtools\pglog\pg.log"
if "%API_PORT%"=="" set "API_PORT=8000"

set "BACKEND_DIR=%~dp0backend"

echo.
echo  ==========================================
echo    Waffir backend
echo  ==========================================
echo.

REM ── 1. Sanity checks ───────────────────────────────────────────────────────
if not exist "%PHP%" (
    echo  [X] PHP not found at:
    echo      %PHP%
    echo.
    echo      Set the PHP variable to your php.exe and run this again.
    goto :failed
)

if not exist "%BACKEND_DIR%\artisan" (
    echo  [X] Laravel not found at:
    echo      %BACKEND_DIR%
    goto :failed
)

REM ── 2. PostgreSQL ──────────────────────────────────────────────────────────
if not exist "%PG_BIN%\pg_ctl.exe" (
    echo  [!] pg_ctl not found at %PG_BIN%
    echo      Skipping the database start - assuming PostgreSQL is already
    echo      running somewhere reachable.
    goto :start_api
)

"%PG_BIN%\pg_ctl.exe" status -D "%PG_DATA%" >nul 2>&1
if errorlevel 1 (
    echo  [*] Starting PostgreSQL...
    for %%L in ("%PG_LOG%") do if not exist "%%~dpL" mkdir "%%~dpL"
    "%PG_BIN%\pg_ctl.exe" -D "%PG_DATA%" -l "%PG_LOG%" -o "-p 5432" -w start >nul
    if errorlevel 1 (
        echo  [X] PostgreSQL failed to start. Last lines of the log:
        echo.
        powershell -NoProfile -Command "Get-Content '%PG_LOG%' -Tail 15" 2>nul
        goto :failed
    )
) else (
    echo  [*] PostgreSQL is already running.
)

"%PG_BIN%\pg_isready.exe" -h 127.0.0.1 -p 5432 >nul 2>&1
if errorlevel 1 (
    echo  [X] PostgreSQL is not accepting connections on 127.0.0.1:5432
    goto :failed
)
echo  [OK] PostgreSQL is accepting connections.

:start_api
cd /d "%BACKEND_DIR%"

REM ── 3. Optional: rebuild the database from the seeders ─────────────────────
REM The prompt lives outside any parenthesised block on purpose, so %CONFIRM%
REM reads back correctly without delayed expansion.
if /i "%~1"=="--fresh" goto :fresh
goto :serve

:fresh
echo.
echo  [!] This will DROP every table in the waffir database and reseed it.
set /p "CONFIRM=     Type YES to continue: "
if /i "%CONFIRM%"=="YES" (
    echo  [*] Rebuilding the database...
    "%PHP%" artisan migrate:fresh --seed --no-interaction
    if errorlevel 1 goto :failed
) else (
    echo  [*] Cancelled - leaving the existing data alone.
)

:serve

REM ── 4. Laravel ─────────────────────────────────────────────────────────────
echo.
echo  ------------------------------------------
echo    Local URL     http://localhost:%API_PORT%
echo    Health check  http://localhost:%API_PORT%/api/v1/health
echo.
echo    VS Code: forward port %API_PORT%, then set its
echo    visibility to Public. The app base URL is the
echo    tunnel URL with /api/v1 on the end.
echo.
echo    User   0990000001 / Password123!
echo    Admin  0990000002 / Password123!
echo    OTP    123456
echo  ------------------------------------------
echo.
echo  Press Ctrl+C to stop the API. PostgreSQL keeps running.
echo.

REM --host=0.0.0.0 so the tunnel (and a phone on the same Wi-Fi) can reach it.
"%PHP%" artisan serve --host=0.0.0.0 --port=%API_PORT%

echo.
echo  [*] API stopped. PostgreSQL is still running; stop it with:
echo      "%PG_BIN%\pg_ctl.exe" -D "%PG_DATA%" stop
echo.
pause
exit /b 0

:failed
echo.
echo  Startup failed - see the message above.
echo.
pause
exit /b 1
