@echo off
setlocal enabledelayedexpansion
title Step 4 - Build

set "ROOT=%~dp0"

:: ── Load target ────────────────────────────────────────────
if exist "%ROOT%_target.txt" (
    set /p TARGET=<"%ROOT%_target.txt"
) else (
    set "TARGET="
)
if not "%~1"=="" if /i not "%~1"=="auto" set "TARGET=%~1"

if "!TARGET!"=="" (
    echo [*] No target set. Run 2_decompile_apk.bat first.
    pause & exit /b 1
)

set "DECOMPILED=%ROOT%decompiled\!TARGET!"
set "DIST=%ROOT%dist"
set "OUT_APK=%DIST%\!TARGET!-patched.apk"

if not exist "!DECOMPILED!\AndroidManifest.xml" (
    echo [ERROR] Decompiled folder not found: !DECOMPILED!
    pause & exit /b 1
)

echo.
echo [STEP 4 - Build] !TARGET!
echo.

:: ── Locate apktool ─────────────────────────────────────────
set "APKTOOL="
set "APKTOOL_JAR="
if exist "%ROOT%apktool.jar" (
    set "APKTOOL_JAR=%ROOT%apktool.jar"
    set "APKTOOL=_jar_"
)
if exist "%ROOT%apktool.bat" set "APKTOOL=%ROOT%apktool.bat"
if "!APKTOOL!"=="" (
    where apktool >nul 2>&1
    if not errorlevel 1 set "APKTOOL=apktool"
)
if "!APKTOOL!"=="" ( echo [ERROR] apktool not found. & pause & exit /b 1 )
if "!APKTOOL!"=="_jar_" (
    echo [+] apktool: java -jar !APKTOOL_JAR!
) else (
    echo [+] apktool: !APKTOOL!
)

if not exist "!DIST!" mkdir "!DIST!"

:: ── Clean stale build artifacts ─────────────────────────────
if exist "!DECOMPILED!\build" (
    echo [*] Cleaning stale build cache...
    rd /s /q "!DECOMPILED!\build"
)

:: ── Build ────────────────────────────────────────────────────
echo [*] Building APK...
if "!APKTOOL!"=="_jar_" (
    java -jar "!APKTOOL_JAR!" b "!DECOMPILED!" -o "!OUT_APK!" 2>&1
) else (
    "!APKTOOL!" b "!DECOMPILED!" -o "!OUT_APK!" 2>&1
)

if not exist "!OUT_APK!" (
    echo [*] First build attempt failed. Retrying with --no-crunch...
    if "!APKTOOL!"=="_jar_" (
        java -jar "!APKTOOL_JAR!" b "!DECOMPILED!" -o "!OUT_APK!" --no-crunch 2>&1
    ) else (
        "!APKTOOL!" b "!DECOMPILED!" -o "!OUT_APK!" --no-crunch 2>&1
    )
)

if not exist "!OUT_APK!" (
    echo [ERROR] Build failed. Check apktool output above.
    pause & exit /b 1
)

echo.
echo [+] Built: !OUT_APK!
echo.

:: ── Persist target ─────────────────────────────────────────
echo !TARGET!>"%ROOT%_target.txt"

if "%~1"=="" ( pause )
endlocal
