@echo off
setlocal

set "ROOT_DIR=%~dp0"
set "WEB_DIR=%ROOT_DIR%web"
set "PORT=8080"

where python >nul 2>nul
if not errorlevel 1 (
    set "PYTHON=python"
    goto :serve
)

where python3 >nul 2>nul
if not errorlevel 1 (
    set "PYTHON=python3"
    goto :serve
)

echo Error: Python is not installed.
echo Install it with one of:
echo.
echo     winget install Python.Python.3
echo     choco install python
echo     scoop install python
echo.
echo Or download from https://www.python.org/downloads/
exit /b 1

:serve
cd /d "%WEB_DIR%"

echo Serving %WEB_DIR% at http://localhost:%PORT%

"%PYTHON%" -m http.server %PORT%

endlocal
