@echo off
setlocal enabledelayedexpansion
title BlueStacks APK Extractor

:: ─────────────────────────────────────────────
:: 1. Locate ADB
:: ─────────────────────────────────────────────
set "ADB="

:: 1. Prefer Android SDK adb already in PATH (highest priority)
where adb >nul 2>&1
if %errorlevel%==0 (
    set "ADB=adb"
    goto :adb_found
)

:: 2. Common BlueStacks install paths (fallback)
for %%P in (
    "C:\Program Files\BlueStacks_nxt\HD-Adb.exe"
    "C:\Program Files (x86)\BlueStacks_nxt\HD-Adb.exe"
    "C:\ProgramData\BlueStacks_nxt\Engine\UserData\InputMapper\HD-Adb.exe"
    "C:\Program Files\BlueStacks\HD-Adb.exe"
    "C:\Program Files (x86)\BlueStacks\HD-Adb.exe"
    "C:\Program Files\BlueStacks_4\HD-Adb.exe"
    "C:\Program Files (x86)\BlueStacks_4\HD-Adb.exe"
) do (
    if exist %%P (
        set "ADB=%%~P"
        goto :adb_found
    )
)

:: 3. Search registry for BlueStacks install dir (last resort)
for /f "tokens=2*" %%A in ('reg query "HKLM\SOFTWARE\BlueStacks_nxt" /v "InstallDir" 2^>nul') do (
    if exist "%%B\HD-Adb.exe" (
        set "ADB=%%B\HD-Adb.exe"
        goto :adb_found
    )
)
for /f "tokens=2*" %%A in ('reg query "HKLM\SOFTWARE\WOW6432Node\BlueStacks_nxt" /v "InstallDir" 2^>nul') do (
    if exist "%%B\HD-Adb.exe" (
        set "ADB=%%B\HD-Adb.exe"
        goto :adb_found
    )
)

echo [ERROR] Could not locate ADB. Make sure BlueStacks is installed,
echo         or install Android SDK Platform-Tools and add adb to PATH.
pause
exit /b 1

:adb_found
echo [OK] ADB found: %ADB%
echo.

:: ─────────────────────────────────────────────
:: 2. Connect to BlueStacks
:: ─────────────────────────────────────────────
echo [*] Connecting to BlueStacks...

:: Try common ports (5555, 5556, 5565)
set "BS_PORT="
for %%R in (5555 5556 5565 5575) do (
    "%ADB%" connect 127.0.0.1:%%R >nul 2>&1
    for /f "tokens=*" %%L in ('"%ADB%" devices 2^>nul') do (
        echo %%L | findstr /i "127.0.0.1:%%R" >nul 2>&1
        if !errorlevel!==0 (
            echo %%L | findstr /i "offline" >nul 2>&1
            if !errorlevel! neq 0 (
                set "BS_PORT=%%R"
                goto :connected
            )
        )
    )
)

echo [ERROR] Could not connect to BlueStacks. Make sure BlueStacks is running.
echo         You can also check the port in BlueStacks Settings ^> About.
pause
exit /b 1

:connected
set "DEVICE=127.0.0.1:%BS_PORT%"
echo [OK] Connected to %DEVICE%
echo.

:: ─────────────────────────────────────────────
:: 3. List installed packages (non-system)
:: ─────────────────────────────────────────────
echo [*] Fetching installed apps (this may take a moment)...
echo.

:: Dump all third-party packages into a temp file.
:: Pipe through findstr to strip \r (CRLF -> LF) that ADB shell adds on Windows.
set "TMPLIST=%TEMP%\bs_packages.txt"
"%ADB%" -s %DEVICE% shell pm list packages -3 2>nul | findstr /r "." | sort > "%TMPLIST%"

:: Count entries
set /a COUNT=0
for /f %%L in (%TMPLIST%) do set /a COUNT+=1

if %COUNT%==0 (
    echo [INFO] No third-party apps found. Listing ALL packages instead...
    "%ADB%" -s %DEVICE% shell pm list packages 2>nul | findstr /r "." | sort > "%TMPLIST%"
    for /f %%L in (%TMPLIST%) do set /a COUNT+=1
)

if %COUNT%==0 (
    echo [ERROR] No packages found. Check ADB connection.
    pause
    exit /b 1
)

:: ─────────────────────────────────────────────
:: 4. Display numbered list
:: ─────────────────────────────────────────────
echo ============================================================
echo   Installed Apps (%COUNT% found)
echo ============================================================
set /a IDX=0
for /f "tokens=2 delims=:" %%P in (%TMPLIST%) do (
    set /a IDX+=1
    set "PKG_!IDX!=%%P"
    if !IDX! lss 10   echo   [!IDX!]  %%P
    if !IDX! geq 10  if !IDX! lss 100  echo  [!IDX!]  %%P
    if !IDX! geq 100 echo [!IDX!]  %%P
)
echo ============================================================
echo.

:: ─────────────────────────────────────────────
:: 5. User selection
:: ─────────────────────────────────────────────
:ask_selection
set "CHOICE="
set /p CHOICE="Enter number(s) to extract (e.g. 3  or  1 5 12), or 0 to exit: "

if "%CHOICE%"=="0" goto :done
if "%CHOICE%"=="" goto :ask_selection

:: ─────────────────────────────────────────────
:: 6. Extract each selected APK
:: ─────────────────────────────────────────────
set "OUTDIR=%~dp0extracted_apks"
if not exist "%OUTDIR%" mkdir "%OUTDIR%"

for %%N in (%CHOICE%) do (
    rem Validate numeric
    set "VALID=0"
    for /l %%I in (1,1,%COUNT%) do (
        if %%I==%%N set "VALID=1"
    )
    if "!VALID!"=="0" (
        echo [SKIP] "%%N" is not a valid number.
    ) else (
        set "PKG=!PKG_%%N!"
        echo.
        echo [*] Extracting: !PKG!

        rem Collect all APK paths for this package.
        rem Pipe through findstr to strip \r from ADB shell output.
        set "TMPAPKS=%TEMP%\bs_apkpaths.txt"
        "%ADB%" -s %DEVICE% shell pm path !PKG! 2>nul | findstr /r "." > "!TMPAPKS!"

        rem Count split paths
        set /a APKCOUNT=0
        for /f "usebackq tokens=*" %%L in ("!TMPAPKS!") do set /a APKCOUNT+=1

        if !APKCOUNT!==0 (
            echo [ERROR] Could not find APK path for !PKG!
        ) else if !APKCOUNT!==1 (
            rem Single APK - save as flat file
            for /f "usebackq tokens=2 delims=:" %%A in ("!TMPAPKS!") do (
                set "APKPATH=%%A"
                set "APKPATH=!APKPATH: =!"
            )
            set "OUTFILE=%OUTDIR%\!PKG!.apk"
            echo [*] Pulling !APKPATH!
            "%ADB%" -s %DEVICE% pull "!APKPATH!" "!OUTFILE!" 2>&1
            if exist "!OUTFILE!" ( echo [OK] Saved to: !OUTFILE! ) else ( echo [ERROR] Pull failed. )
        ) else (
            rem Split APK - pull all into a named subfolder
            set "PKGDIR=%OUTDIR%\!PKG!"
            if not exist "!PKGDIR!" mkdir "!PKGDIR!"
            echo [*] Split APK detected: !APKCOUNT! parts - saving to !PKGDIR!
            for /f "usebackq tokens=2 delims=:" %%A in ("!TMPAPKS!") do (
                set "APKPATH=%%A"
                set "APKPATH=!APKPATH: =!"
                rem Extract just the filename from the remote path
                for %%F in ("!APKPATH!") do set "APKNAME=%%~nxF"
                echo [*] Pulling !APKNAME!
                "%ADB%" -s %DEVICE% pull "!APKPATH!" "!PKGDIR!\!APKNAME!" 2>&1
            )
            echo [OK] All splits saved to: !PKGDIR!
        )
    )
)

echo.
echo ============================================================
echo   Done. APKs saved to: %OUTDIR%
echo ============================================================
echo.
if /i "%~1"=="auto" goto :done
set /p AGAIN="Extract more apps? (y/n): "
if /i "%AGAIN%"=="y" goto :ask_selection

:done
echo.
echo Goodbye.
if /i "%~1"=="auto" exit /b 0
timeout /t 3 >nul
endlocal
