@echo off
setlocal enabledelayedexpansion

set "ROOT_DIR=%~dp0"
set "ASM_DIR=%ROOT_DIR%asm"
set "BUILD_DIR=%ROOT_DIR%build"
set "DOS_DIR=%ROOT_DIR%dos"
set "WEB_DIR=%ROOT_DIR%web"

set "COM_FILE=%BUILD_DIR%\snake.com"
set "DOS_COM_FILE=%DOS_DIR%\SNAKE.COM"
set "JSDOS_FILE=%WEB_DIR%\snake.jsdos"

echo ========================================
echo  Building Snake
echo ========================================

where nasm >nul 2>nul
if errorlevel 1 (
    echo Error: NASM is not installed.
    echo Install it with one of:
    echo.
    echo     choco install nasm
    echo     scoop install nasm
    echo     winget install NASM.NASM
    echo.
    echo Or download from https://www.nasm.us/
    exit /b 1
)

where powershell >nul 2>nul
if errorlevel 1 (
    echo Error: PowerShell is required to create the .jsdos bundle, but was not found.
    exit /b 1
)

if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"
if not exist "%DOS_DIR%" mkdir "%DOS_DIR%"
if not exist "%WEB_DIR%" mkdir "%WEB_DIR%"

echo.
echo [1/4] Assembling snake.asm...

nasm -f bin "%ASM_DIR%\snake.asm" -o "%COM_FILE%"
if errorlevel 1 exit /b 1

echo       Created: %COM_FILE%

echo.
echo [2/4] Copying DOS executable...

copy /y "%COM_FILE%" "%DOS_COM_FILE%" >nul

echo       Created: %DOS_COM_FILE%

echo.
echo [3/4] Creating js-dos bundle...

set "TEMP_DIR=%TEMP%\snake-jsdos-%RANDOM%"
mkdir "%TEMP_DIR%\.jsdos"

copy /y "%DOS_DIR%\dosbox.conf" "%TEMP_DIR%\.jsdos\dosbox.conf" >nul

rem The DOS executable must be at the root of the js-dos bundle.
copy /y "%DOS_COM_FILE%" "%TEMP_DIR%\SNAKE.COM" >nul

if exist "%JSDOS_FILE%" del /f /q "%JSDOS_FILE%"
if exist "%JSDOS_FILE%.zip" del /f /q "%JSDOS_FILE%.zip"

powershell -NoProfile -Command "Compress-Archive -Path '%TEMP_DIR%\.jsdos','%TEMP_DIR%\SNAKE.COM' -DestinationPath '%JSDOS_FILE%.zip' -Force"
if errorlevel 1 exit /b 1

move /y "%JSDOS_FILE%.zip" "%JSDOS_FILE%" >nul
rmdir /s /q "%TEMP_DIR%"

echo       Created: %JSDOS_FILE%

echo.
echo ========================================
echo  Build complete.
echo ========================================
echo.
echo Files:
dir /b "%COM_FILE%" "%DOS_COM_FILE%" "%JSDOS_FILE%"
echo.
echo Run the web server with:
echo.
echo     server.bat
echo.
echo Then open:
echo.
echo     http://localhost:8080

endlocal
