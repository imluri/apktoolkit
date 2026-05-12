@echo off
setlocal enabledelayedexpansion
title APKTool Decompiler

:: ─────────────────────────────────────────────
:: 1. Locate apktool
:: ─────────────────────────────────────────────
set "APKTOOL="

:: Check PATH first
where apktool >nul 2>&1
if %errorlevel%==0 ( set "APKTOOL=apktool" & goto :apktool_found )
where apktool.bat >nul 2>&1
if %errorlevel%==0 ( set "APKTOOL=apktool.bat" & goto :apktool_found )

:: Check common local locations relative to this script
for %%P in (
    "%~dp0apktool.bat"
    "%~dp0apktool.jar"
    "%~dp0tools\apktool.bat"
    "%~dp0tools\apktool.jar"
    "C:\apktool\apktool.bat"
    "C:\tools\apktool.bat"
) do (
    if exist %%P ( set "APKTOOL=%%~P" & goto :apktool_found )
)

echo [ERROR] apktool not found in PATH or common locations.
echo         Place apktool.bat (and apktool.jar) next to this script, or add it to PATH.
pause
exit /b 1

:apktool_found
echo [OK] apktool: %APKTOOL%
echo.

:: ─────────────────────────────────────────────
:: 2. List APKs in extracted_apks\
:: ─────────────────────────────────────────────
set "APKDIR=%~dp0extracted_apks"

if not exist "%APKDIR%" (
    echo [ERROR] Folder not found: %APKDIR%
    echo         Run extract_apk.bat first to pull APKs from BlueStacks.
    pause
    exit /b 1
)

set /a COUNT=0

:: List flat .apk files
for %%F in ("%APKDIR%\*.apk") do (
    set /a COUNT+=1
    set "FILE_!COUNT!=%%~nxF"
    set "PATH_!COUNT!=%%~fF"
    set "ISSPLIT_!COUNT!=0"
)

:: List split APK subfolders (contain base.apk inside)
for /d %%D in ("%APKDIR%\*") do (
    if exist "%%D\base.apk" (
        set /a COUNT+=1
        set "FILE_!COUNT!=%%~nxD  [split]"
        set "PATH_!COUNT!=%%~fD\base.apk"
        set "ISSPLIT_!COUNT!=1"
        set "SPLITDIR_!COUNT!=%%~fD"
        set "SPLITNAME_!COUNT!=%%~nxD"
    )
)

if %COUNT%==0 (
    echo [ERROR] No APKs found in: %APKDIR%
    pause
    exit /b 1
)

:show_list
cls
echo ============================================================
echo   APKs available in extracted_apks\  (%COUNT% found)
echo ============================================================
for /l %%I in (1,1,%COUNT%) do (
    echo   [%%I]  !FILE_%%I!
)
echo ============================================================
echo.

:: ─────────────────────────────────────────────
:: 3. User selection
:: ─────────────────────────────────────────────
:ask_selection
set "CHOICE="
set /p CHOICE="Select APK number to decompile (or 0 to exit): "

if "%CHOICE%"=="0" goto :done
if "%CHOICE%"=="" goto :ask_selection

:: Validate
set "VALID=0"
for /l %%I in (1,1,%COUNT%) do ( if "%%I"=="%CHOICE%" set "VALID=1" )
if "%VALID%"=="0" ( echo [*] Invalid selection. & goto :ask_selection )

set "SELECTED_FILE=!FILE_%CHOICE%!"
set "SELECTED_PATH=!PATH_%CHOICE%!"
set "SELECTED_ISSPLIT=!ISSPLIT_%CHOICE%!"

:: ─────────────────────────────────────────────
:: 4. Output directory
:: ─────────────────────────────────────────────
set "OUTBASE=%~dp0decompiled"

if "!SELECTED_ISSPLIT!"=="1" (
    set "APKNAME=!SPLITNAME_%CHOICE%!"
) else (
    set "APKNAME=!SELECTED_FILE:.apk=!"
)
set "OUTDIR=%OUTBASE%\!APKNAME!"

echo.
echo [*] Selected : !SELECTED_FILE!
echo [*] Output   : !OUTDIR!
echo.

if exist "!OUTDIR!" (
    echo.
    echo [WARN] Output folder already exists: !OUTDIR!
    echo     Deleting it will destroy any manual edits you have made.
    echo.
    set "OVERWRITE="
    set /p OVERWRITE="Overwrite and re-decompile? (y/n): "
    if /i "!OVERWRITE!" neq "y" (
        echo [*] Keeping existing folder. Skipping decompile.
        echo !APKNAME!>"%~dp0_target.txt"
        goto :done
    )
    echo [*] Removing old output...
    rd /s /q "!OUTDIR!"
)

:: ─────────────────────────────────────────────
:: 5. Run apktool
:: ─────────────────────────────────────────────
echo [*] Decompiling with apktool...
echo.

if "%APKTOOL:~-4%"==".jar" (
    java -jar "%APKTOOL%" d "!SELECTED_PATH!" -o "!OUTDIR!"
) else (
    "%APKTOOL%" d "!SELECTED_PATH!" -o "!OUTDIR!"
)

echo.
if exist "!OUTDIR!\AndroidManifest.xml" (
    echo [OK] Decompile complete.
    echo      Output: !OUTDIR!
    :: Save target for next steps
    echo !APKNAME!>"%~dp0_target.txt"
    echo [OK] Target saved: !APKNAME!
) else (
    echo [WARN] apktool finished but output looks incomplete. Check for errors above.
)

echo.
if /i "%~1"=="auto" goto :done
set "AGAIN="
set /p AGAIN="Decompile another APK? (y/n): "
if /i "%AGAIN%"=="y" goto :show_list

:done
echo.
echo Goodbye.
timeout /t 3 >nul
endlocal
