@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Pays fictifs - Setup / Installation

set "PF_ROOT=%~dp0"
cd /d "!PF_ROOT!" || goto :badroot

echo ============================================================
echo  Pays fictifs - INSTALL / INSTALLATION (Windows)
echo  Root: "!PF_ROOT!"
echo ============================================================
echo.

set "PF_SKIP_BUILD="
set "PF_ALL_ARGS="
:parse_args
if "%~1"=="" goto :args_done
if /I "%~1"=="--no-build" (
    set "PF_SKIP_BUILD=1"
    set "PF_ALL_ARGS=!PF_ALL_ARGS! "%~1""
    shift
    goto :parse_args
)
if /I "%~1"=="--skip-build" (
    set "PF_SKIP_BUILD=1"
    set "PF_ALL_ARGS=!PF_ALL_ARGS! "%~1""
    shift
    goto :parse_args
)
set "PF_ALL_ARGS=!PF_ALL_ARGS! "%~1""
shift
goto :parse_args
:args_done

echo [1/3] Configuration check / verification de la configuration
if not exist "!PF_ROOT!mod.config" goto :badconfig
if not exist "!PF_ROOT!PaysFictifs.sln" goto :badconfig

set "CFG_MOD_ID="
set "CFG_ENGINE_VERSION="
set "CFG_ENGINE_DIRECTORY="
for /f "usebackq eol=# tokens=1,* delims==" %%A in ("!PF_ROOT!mod.config") do set "CFG_%%A=%%~B"
if exist "!PF_ROOT!user.config" for /f "usebackq eol=# tokens=1,* delims==" %%A in ("!PF_ROOT!user.config") do set "CFG_%%A=%%~B"
set "MOD_ID=!CFG_MOD_ID!"
set "ENGINE_VERSION=!CFG_ENGINE_VERSION!"
set "ENGINE_DIRECTORY=!CFG_ENGINE_DIRECTORY!"
if not defined MOD_ID goto :badconfig
if not defined ENGINE_VERSION goto :badconfig
if not defined ENGINE_DIRECTORY goto :badconfig

if defined PF_SKIP_BUILD (
    echo [INFO] --no-build: SDK check and compilation skipped.
    goto :done
)

echo [2/3] .NET SDK check / verification du SDK .NET
call :CheckSDK
if errorlevel 1 goto :dotnet_failed

echo [3/3] Build / Compilation
call :NeedBuild
if not defined PF_NEED_BUILD (
    echo [INFO] Engine and mod binaries are up to date: skipping compilation.
    goto :done
)
echo [INFO] Building with make.cmd all (about 1-2 minutes)... / Compilation en cours...
call "!PF_ROOT!make.cmd" all !PF_ALL_ARGS!
if errorlevel 1 goto :build_failed
echo [INFO] Build succeeded / Compilation reussie.
goto :done

:CheckSDK
set "PF_DOTNET="
for /f "delims=" %%P in ('where dotnet 2^>nul') do if not defined PF_DOTNET set "PF_DOTNET=%%P"
if not defined PF_DOTNET if exist "%ProgramFiles%\dotnet\dotnet.exe" set "PF_DOTNET=%ProgramFiles%\dotnet\dotnet.exe"
if not defined PF_DOTNET goto :no_dotnet
for %%D in ("!PF_DOTNET!") do set "PATH=%%~dpD;!PATH!"
set "PF_SDK6="
set "PF_SDK8="
for /f "tokens=1 delims= " %%V in ('dotnet --list-sdks 2^>nul') do (
    for /f "tokens=1 delims=." %%M in ("%%V") do (
        if "%%M"=="8" set "PF_SDK8=1"
        if "%%M"=="6" set "PF_SDK6=1"
    )
)
if defined PF_SDK8 (
    set "DOTNET_ROLL_FORWARD=LatestMajor"
    echo [INFO] .NET 8 SDK detected; roll-forward to net6 enabled.
    exit /b 0
)
if defined PF_SDK6 (
    set "DOTNET_ROLL_FORWARD=LatestMajor"
    echo [WARN] Only the .NET 6 SDK was found. .NET 8 SDK is recommended:
    echo         https://dotnet.microsoft.com/download/dotnet/8.0
    exit /b 0
)
goto :no_dotnet

:NeedBuild
set "PF_NEED_BUILD="
set "ENG_PATH=!ENGINE_DIRECTORY:/=\!"
for %%I in ("!ENG_PATH!") do set "ENG_ABS=%%~fI"
if not exist "!ENG_ABS!\bin\OpenRA.exe" set "PF_NEED_BUILD=1"
if not exist "!ENG_ABS!\bin\OpenRA.Mods.Fictifs.dll" set "PF_NEED_BUILD=1"
if not exist "!ENG_ABS!\VERSION" (
    set "PF_NEED_BUILD=1"
) else (
    set "ENG_FILE_VERSION="
    for /f "usebackq delims=" %%V in ("!ENG_ABS!\VERSION") do if not defined ENG_FILE_VERSION set "ENG_FILE_VERSION=%%V"
    if /I not "!ENG_FILE_VERSION!"=="!ENGINE_VERSION!" set "PF_NEED_BUILD=1"
)
if defined PF_NEED_BUILD exit /b 0
powershell -NoProfile -Command "$out=Get-Item -LiteralPath '!ENG_ABS!\bin\OpenRA.Mods.Fictifs.dll'; $src=@('!PF_ROOT!OpenRA.Mods.Fictifs','!PF_ROOT!PaysFictifs.sln','!PF_ROOT!mod.config'); $new=Get-ChildItem -LiteralPath $src -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $out.LastWriteTime }; if ($new) { exit 1 }"
if errorlevel 1 set "PF_NEED_BUILD=1"
exit /b 0

:done
echo [INFO] Setup complete / Installation terminee.
exit /b 0

:badroot
echo [ERREUR/ERROR] Cannot access the mod directory: "!PF_ROOT!"
pause
exit /b 1

:badconfig
echo [ERREUR/ERROR] Missing mod.config or PaysFictifs.sln in "!PF_ROOT!"
echo [INFO] Required config values: MOD_ID, ENGINE_VERSION, ENGINE_DIRECTORY.
pause
exit /b 1

:no_dotnet
echo [ERREUR/ERROR] No .NET SDK found (8 recommended, 6 accepted). / SDK .NET introuvable.
echo [INFO] Option 1 - automatic install with winget:
echo          winget install --id Microsoft.DotNet.SDK.8 -e
echo [INFO] Option 2 - manual download: https://dotnet.microsoft.com/download/dotnet/8.0
where winget >nul 2>&1
if errorlevel 1 goto :no_dotnet_manual
set "PF_ANSWER="
set /P "PF_ANSWER=Install .NET 8 SDK with winget now? [y/N] "
if /I not "!PF_ANSWER!"=="y" goto :no_dotnet_manual
winget install --id Microsoft.DotNet.SDK.8 -e --accept-source-agreements --accept-package-agreements
if errorlevel 1 (
    echo [ERREUR/ERROR] winget installation failed. Use the manual URL above.
    pause
    exit /b 1
)
echo [INFO] .NET 8 SDK installed. Close this window and run JOUER.bat again,
echo        so the updated PATH is picked up by make.cmd. / Relancez JOUER.bat.
pause
exit /b 1

:no_dotnet_manual
echo [INFO] Install the SDK using the URL above, then run JOUER.bat again.
pause
exit /b 1

:dotnet_failed
echo [ERREUR/ERROR] .NET SDK setup failed / Echec de l'installation du SDK .NET.
pause
exit /b 1

:build_failed
echo [ERREUR/ERROR] make.cmd all failed. See the messages above. / Echec de compilation.
echo [INFO] Check network access and the .NET SDK, then run INSTALL.bat again.
pause
exit /b 1
