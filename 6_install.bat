@echo off
setlocal enabledelayedexpansion
title Step 6 - Install

set "ROOT=%~dp0"

:: ── Load target ────────────────────────────────────────────
if exist "%ROOT%_target.txt" (
    set /p TARGET=<"%ROOT%_target.txt"
) else (
    set "TARGET="
)
if not "%~1"=="" if /i not "%~1"=="auto" set "TARGET=%~1"

if "!TARGET!"=="" (
    echo [*] No target set. Run 5_sign.bat first.
    pause & exit /b 1
)

set "SIGNED_DIR=%ROOT%dist\signed"
set "SIGNED_APK="
set "IS_SPLIT=0"
if exist "%ROOT%_is_split.txt" set /p IS_SPLIT=<"%ROOT%_is_split.txt"

for %%F in ("!SIGNED_DIR!\*signed*.apk" "!SIGNED_DIR!\*.apk") do (
    if "!SIGNED_APK!"=="" set "SIGNED_APK=%%~fF"
)

if "!SIGNED_APK!"=="" (
    echo [ERROR] No signed APK found in: !SIGNED_DIR!
    echo         Run 5_sign.bat first.
    pause & exit /b 1
)

echo.
echo [STEP 6 - Install] !TARGET!
echo.
echo [+] APK to install: !SIGNED_APK!
echo.

:: ── Locate ADB ─────────────────────────────────────────────
set "ADB="
for %%P in (
    "C:\Program Files\BlueStacks_nxt\HD-Adb.exe"
    "C:\Program Files (x86)\BlueStacks_nxt\HD-Adb.exe"
    "C:\Program Files\BlueStacks\HD-Adb.exe"
) do ( if exist %%P ( set "ADB=%%~P" & goto :adb_ok ) )
where adb >nul 2>&1 && set "ADB=adb"
:adb_ok
if "!ADB!"=="" (
    echo [ERROR] ADB not found.
    echo         Install BlueStacks or Android SDK Platform-Tools.
    pause & exit /b 1
)
echo [+] ADB: !ADB!

:: ── Connect to BlueStacks ──────────────────────────────────
echo [*] Connecting to BlueStacks...
set "DEVICE="
for %%R in (5555 5556 5565 5575) do (
    if "!DEVICE!"=="" (
        "!ADB!" connect 127.0.0.1:%%R >nul 2>&1
        for /f "tokens=*" %%L in ('"!ADB!" devices') do (
            echo %%L | findstr /i "127.0.0.1:%%R" >nul 2>&1
            if !errorlevel!==0 (
                echo %%L | findstr /i "offline" >nul 2>&1
                if !errorlevel! neq 0 set "DEVICE=127.0.0.1:%%R"
            )
        )
    )
)

if "!DEVICE!"=="" (
    echo [ERROR] BlueStacks not connected. Make sure BlueStacks is running.
    pause & exit /b 1
)
echo [+] Connected: !DEVICE!

:: ── Get package name from target (strip split suffix if any) ──
set "PKG=!TARGET!"
for /f "tokens=1 delims= " %%P in ("!TARGET!") do set "PKG=%%P"

:: ── Uninstall original ─────────────────────────────────────
echo [*] Uninstalling original app...
"!ADB!" -s !DEVICE! uninstall !PKG! >nul 2>&1

:: ── Install ────────────────────────────────────────────────
echo [*] Installing patched APK...
if "!IS_SPLIT!"=="1" (
    echo [*] Split APK - using install-multiple...
    set "APKLIST="
    for %%F in ("!SIGNED_DIR!\*.apk") do set "APKLIST=!APKLIST! "%%~fF""
    "!ADB!" -s !DEVICE! install-multiple -r !APKLIST!
) else (
    "!ADB!" -s !DEVICE! install -r "!SIGNED_APK!"
    if !errorlevel! neq 0 (
        echo [*] Retrying with -t flag...
        "!ADB!" -s !DEVICE! install -r -t "!SIGNED_APK!"
    )
)

if !errorlevel!==0 (
    echo.
    echo [+] Installed successfully.
    echo [*] Launching app...
    "!ADB!" -s !DEVICE! shell monkey -p !PKG! -c android.intent.category.LAUNCHER 1 >nul 2>&1
    echo [+] Done.
) else (
    echo.
    echo [ERROR] Install failed. The APK may have a build error.
    echo         Check 4_build.bat output or try rebuilding with --use-aapt2.
)

echo.
if "%~1"=="" ( pause )
endlocal
