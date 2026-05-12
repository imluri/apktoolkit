@echo off
setlocal enabledelayedexpansion
title Step 3 - Patch

set "ROOT=%~dp0"

:: ── Load target ────────────────────────────────────────────
if exist "%ROOT%_target.txt" (
    set /p TARGET=<"%ROOT%_target.txt"
) else (
    set "TARGET="
)

:: ── If no target or caller passed one as arg ───────────────
if not "%~1"=="" if /i not "%~1"=="auto" set "TARGET=%~1"

if "!TARGET!"=="" (
    echo [*] No target set. Run 2_decompile_apk.bat first, or pass folder name as argument.
    echo     Example: 3_patch.bat my.com.tngdigital.ewallet
    pause & exit /b 1
)

set "DECOMPILED=%ROOT%decompiled\!TARGET!"
if not exist "!DECOMPILED!\AndroidManifest.xml" (
    echo [ERROR] Decompiled folder not found: !DECOMPILED!
    echo         Run 2_decompile_apk.bat first.
    pause & exit /b 1
)

echo.
echo [STEP 3 - Patch] !TARGET!
echo.

:: ── Check Python ───────────────────────────────────────────
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python not found in PATH.
    pause & exit /b 1
)

:: ── Patch manifest ─────────────────────────────────────────
echo [*] Patching AndroidManifest.xml...
python "%ROOT%patch_manifest.py" "!DECOMPILED!\AndroidManifest.xml"
if %errorlevel% neq 0 ( echo [ERROR] patch_manifest.py failed. & pause & exit /b 1 )

:: ── Patch smali ────────────────────────────────────────────
echo.
echo [*] Scanning smali for root/emulator detection methods...
set /a HIT=0

for %%D in (smali smali_classes2 smali_classes3 smali_classes4 smali_classes5
            smali_classes6 smali_classes7 smali_classes8 smali_classes9
            smali_classes10 smali_classes11 smali_classes12 smali_classes13
            smali_classes14) do (
    if exist "!DECOMPILED!\%%D" (
        for /r "!DECOMPILED!\%%D" %%F in (*.smali) do (
            findstr /i /c:"isRooted" /c:"checkRoot" /c:"detectRoot" ^
                       /c:"isEmulator" /c:"checkEmulator" /c:"RootBeer" ^
                       /c:"test-keys" /c:"Build.FINGERPRINT" "%%F" >nul 2>&1
            if !errorlevel!==0 (
                python "%ROOT%patch_smali.py" "%%F"
                set /a HIT+=1
            )
        )
    )
)

echo.
echo [+] Patch complete. Smali files processed: !HIT!
echo.

:: ── Persist target ─────────────────────────────────────────
echo !TARGET!>"%ROOT%_target.txt"

if "%~1"=="" ( pause )
endlocal
