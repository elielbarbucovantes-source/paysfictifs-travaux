@echo off
setlocal EnableExtensions EnableDelayedExpansion
title OpenRA - Pays fictifs

set "DOTNET_ROLL_FORWARD=LatestMajor"

set "PF_ROOT=%~dp0"
cd /d "!PF_ROOT!" || goto :badroot

set "TEMPLATE_LAUNCHER=%~f0"
set "MOD_SEARCH_PATHS=!PF_ROOT!mods,./mods"

if not exist "!PF_ROOT!mod.config" goto :badconfig
for /f "usebackq eol=# tokens=1,* delims==" %%A in ("!PF_ROOT!mod.config") do set "CFG_%%A=%%~B"
if exist "!PF_ROOT!user.config" for /f "usebackq eol=# tokens=1,* delims==" %%A in ("!PF_ROOT!user.config") do set "CFG_%%A=%%~B"

set "MOD_ID=!CFG_MOD_ID!"
set "ENGINE_VERSION=!CFG_ENGINE_VERSION!"
set "ENGINE_DIRECTORY=!CFG_ENGINE_DIRECTORY!"
if not defined MOD_ID goto :badconfig
if not defined ENGINE_VERSION goto :badconfig
if not defined ENGINE_DIRECTORY goto :badconfig

set "ENGINE_DIRECTORY=!ENGINE_DIRECTORY:/=\!"
for %%I in ("!ENGINE_DIRECTORY!") do set "ENG_DIR=%%~fI"
if not exist "!ENG_DIR!\bin\OpenRA.exe" goto :noengine
if not exist "!ENG_DIR!\VERSION" goto :noengine

set "ENGINE_FILE_VERSION="
for /f "usebackq delims=" %%V in ("!ENG_DIR!\VERSION") do if not defined ENGINE_FILE_VERSION set "ENGINE_FILE_VERSION=%%V"
if /I not "!ENGINE_FILE_VERSION!"=="!ENGINE_VERSION!" goto :badversion

cd /d "!ENG_DIR!" || goto :noengine
"!ENG_DIR!\bin\OpenRA.exe" Game.Mod=!MOD_ID! Engine.EngineDir=".." Engine.LaunchPath="!TEMPLATE_LAUNCHER!" Engine.ModSearchPaths="!MOD_SEARCH_PATHS!" %*
set "PF_RC=!errorlevel!"
cd /d "!PF_ROOT!"
if not "!PF_RC!"=="0" goto :crashdialog
exit /b 0

:badroot
echo [ERREUR/ERROR] Cannot access the mod directory: "!PF_ROOT!"
pause
exit /b 1

:badconfig
echo [ERREUR/ERROR] Required mod.config variables are missing. / Configuration incomplete.
echo [INFO] Check MOD_ID, ENGINE_VERSION and ENGINE_DIRECTORY in mod.config/user.config.
pause
exit /b 1

:noengine
echo [ERREUR/ERROR] Required engine files not found: "!ENG_DIR!\bin\OpenRA.exe" or VERSION.
echo [INFO] Run INSTALL.bat (or make.cmd all) in the mod directory first.
pause
exit /b 1

:badversion
echo [ERREUR/ERROR] Engine version mismatch / Version du moteur incorrecte.
echo [INFO] mod.config wants "!ENGINE_VERSION!", engine/VERSION says "!ENGINE_FILE_VERSION!".
echo [INFO] Run INSTALL.bat (or make.cmd all) to fetch the correct engine.
pause
exit /b 1

:crashdialog
echo ----------------------------------------
echo OpenRA has encountered a fatal error. / Le jeu a plante.
echo   * Log Files are available in Documents\OpenRA\Logs
echo   * FAQ is available at https://github.com/OpenRA/OpenRA/wiki/FAQ
echo ----------------------------------------
pause
exit /b !PF_RC!
