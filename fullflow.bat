@echo off
setlocal enabledelayedexpansion
title Full Flow

set "ROOT=%~dp0"
set "PROGRESS_FILE=%ROOT%_progress.txt"

echo.
echo [APK Pentest - Full Flow]
echo.
echo   1  Extract APK from BlueStacks
echo   2  Decompile with apktool
echo   3  Patch emulator/root detection
echo   4  Build patched APK
echo   5  Sign + zipalign
echo   6  Install to BlueStacks
echo.

set "START_STEP=1"
set "CURRENT_STEP=1"

if exist "%PROGRESS_FILE%" (
    set /p LAST_STEP=<"%PROGRESS_FILE%"
    if !LAST_STEP! geq 1 if !LAST_STEP! leq 6 (
        echo [*] Previous run stopped at step !LAST_STEP!.
        echo.
        echo   [C]  Continue from step !LAST_STEP!
        echo   [S]  Choose a specific step
        echo   [R]  Restart from step 1
        echo   [Q]  Quit
        echo.
        set "MODE="
        set /p MODE="Choice: "
    )
) else (
    pause
)

:: Handle quit before any other branching so goto fires at top level
if /i "!MODE!"=="q" goto :quit

if exist "%PROGRESS_FILE%" (
    set /p LAST_STEP=<"%PROGRESS_FILE%"
    if !LAST_STEP! geq 1 if !LAST_STEP! leq 6 (
        if /i "!MODE!"=="c" set "START_STEP=!LAST_STEP!"
        if /i "!MODE!"=="s" (
            set /p START_STEP="Enter step number (1-6): "
            if "!START_STEP!"=="" set "START_STEP=1"
        )
        if /i "!MODE!"=="r" (
            set "START_STEP=1"
            del "%PROGRESS_FILE%" >nul 2>&1
        )
        echo [*] Starting from step !START_STEP!...
    )
)

echo.
pushd "%ROOT%"

if !START_STEP! leq 1 (
    set "CURRENT_STEP=1"
    >"%PROGRESS_FILE%" echo 1
    call "1_extract_apk.bat" auto
    if !errorlevel! neq 0 goto :failed
)
if !START_STEP! leq 2 (
    set "CURRENT_STEP=2"
    >"%PROGRESS_FILE%" echo 2
    call "2_decompile_apk.bat" auto
    if !errorlevel! neq 0 goto :failed

    rem Decompile is complete. Save progress at step 3 before waiting, so restarting will not overwrite manual edits.
    >"%PROGRESS_FILE%" echo 3
    echo.
    echo ============================================================
    echo   Manual modification pause
    echo ============================================================
    if exist "%ROOT%_target.txt" (
        set /p TARGET=<"%ROOT%_target.txt"
        echo   Decompiled folder: %ROOT%decompiled\!TARGET!
    ) else (
        echo   Edit the decompiled APK folder before continuing.
    )
    echo.
    echo   Make your changes now. When finished, return here.
    echo.
    set "CONTINUE_AFTER_MODS="
    set /p CONTINUE_AFTER_MODS="Press ENTER to continue with patch, build, sign, and install..."
)
if !START_STEP! leq 3 (
    set "CURRENT_STEP=3"
    >"%PROGRESS_FILE%" echo 3
    call "3_patch.bat" auto
    if !errorlevel! neq 0 goto :failed
)
if !START_STEP! leq 4 (
    set "CURRENT_STEP=4"
    >"%PROGRESS_FILE%" echo 4
    call "4_build.bat" auto
    if !errorlevel! neq 0 goto :failed
)
if !START_STEP! leq 5 (
    set "CURRENT_STEP=5"
    >"%PROGRESS_FILE%" echo 5
    call "5_sign.bat" auto
    if !errorlevel! neq 0 goto :failed
)
if !START_STEP! leq 6 (
    set "CURRENT_STEP=6"
    >"%PROGRESS_FILE%" echo 6
    call "6_install.bat" auto
    if !errorlevel! neq 0 goto :failed
)

popd
del "%PROGRESS_FILE%" >nul 2>&1
echo.
echo [DONE] All steps complete.
echo.
pause
endlocal
exit /b 0

:failed
popd
>"%PROGRESS_FILE%" echo !CURRENT_STEP!
echo.
echo [ERROR] Step !CURRENT_STEP! failed.
echo [INFO]  Re-run fullflow.bat to continue from here, or run !CURRENT_STEP!_*.bat directly.
echo.
pause
endlocal
exit /b 1

:quit
echo Goodbye.
endlocal
exit /b 0
