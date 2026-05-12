@echo off
setlocal enabledelayedexpansion
title Step 5 - Sign

set "ROOT=%~dp0"
set "KEYSTORE=%ROOT%testkey.jks"
set "KEY_ALIAS=testkey"
set "KEY_PASS=android"

:: ── Load target ────────────────────────────────────────────
if exist "%ROOT%_target.txt" (
    set /p TARGET=<"%ROOT%_target.txt"
) else (
    set "TARGET="
)
if not "%~1"=="" if /i not "%~1"=="auto" set "TARGET=%~1"

if "!TARGET!"=="" (
    echo [*] No target set. Run 4_build.bat first.
    pause & exit /b 1
)

set "PATCHED_APK=%ROOT%dist\!TARGET!-patched.apk"
set "SIGNED_DIR=%ROOT%dist\signed"

if not exist "!PATCHED_APK!" (
    echo [ERROR] Patched APK not found: !PATCHED_APK!
    echo         Run 4_build.bat first.
    pause & exit /b 1
)

echo.
echo [STEP 5 - Sign] !TARGET!
echo.

:: ── Locate uber-apk-signer ─────────────────────────────────
set "SIGNER="
if exist "%ROOT%uber-apk-signer.jar" set "SIGNER=%ROOT%uber-apk-signer.jar"
if "!SIGNER!"=="" ( echo [ERROR] uber-apk-signer.jar not found. & pause & exit /b 1 )
echo [+] Signer: !SIGNER!

:: ── Generate keystore if needed ────────────────────────────
if exist "%KEYSTORE%" goto :have_keystore

echo [*] Generating test keystore...
keytool -genkeypair -v ^
    -keystore "%KEYSTORE%" -alias %KEY_ALIAS% ^
    -keyalg RSA -keysize 2048 -validity 10000 ^
    -storepass %KEY_PASS% -keypass %KEY_PASS% ^
    -dname "CN=PenTest, OU=Security, O=Research, L=KL, S=WP, C=MY" >nul 2>&1
if not exist "%KEYSTORE%" (
    echo [ERROR] keytool failed. Ensure JDK (not JRE) is installed.
    pause & exit /b 1
)
echo [+] Keystore created: %KEYSTORE%
goto :keystore_ready

:have_keystore
echo [+] Keystore: %KEYSTORE%

:keystore_ready

:: ── Stage APKs to sign ──────────────────────────────────────
set "STAGE_DIR=%ROOT%dist\to_sign"
if exist "!STAGE_DIR!" rd /s /q "!STAGE_DIR!"
mkdir "!STAGE_DIR!"

:: Always include the patched base APK
copy "!PATCHED_APK!" "!STAGE_DIR!\base.apk" >nul

:: If this was a split APK, copy the other splits too so they
:: get resigned with the same cert — otherwise install-multiple fails
set "SPLIT_SRC=%ROOT%extracted_apks\!TARGET!"
set "IS_SPLIT=0"
if exist "!SPLIT_SRC!\base.apk" (
    set "IS_SPLIT=1"
    echo [*] Split APK detected - staging config splits for resign...
    for %%F in ("!SPLIT_SRC!\*.apk") do (
        if /i not "%%~nxF"=="base.apk" (
            copy "%%F" "!STAGE_DIR!\%%~nxF" >nul
            echo     + %%~nxF
        )
    )
)
echo !IS_SPLIT!>"%ROOT%_is_split.txt"

:: ── Sign + zipalign ─────────────────────────────────────────
if not exist "!SIGNED_DIR!" mkdir "!SIGNED_DIR!"

echo [*] Signing and zipaligning...
java -jar "!SIGNER!" ^
    --apks "!STAGE_DIR!" ^
    --ks "%KEYSTORE%" ^
    --ksAlias %KEY_ALIAS% ^
    --ksPass %KEY_PASS% ^
    --ksKeyPass %KEY_PASS% ^
    --out "!SIGNED_DIR!" ^
    --allowResign 2>&1

:: ── Find output ─────────────────────────────────────────────
set "SIGNED_APK="
set "SIGNED_COUNT=0"
for %%F in ("!SIGNED_DIR!\*signed*.apk" "!SIGNED_DIR!\*.apk") do (
    if "!SIGNED_APK!"=="" set "SIGNED_APK=%%~fF"
    set /a SIGNED_COUNT+=1
)

if "!SIGNED_APK!"=="" (
    echo [ERROR] Signing failed - no output APK in !SIGNED_DIR!
    pause & exit /b 1
)

echo.
if "!IS_SPLIT!"=="1" (
    echo [+] Signed !SIGNED_COUNT! APKs to: !SIGNED_DIR!
) else (
    echo [+] Signed APK: !SIGNED_APK!
)
echo.

:: ── Persist target ─────────────────────────────────────────
echo !TARGET!>"%ROOT%_target.txt"

if "%~1"=="" ( pause )
endlocal
