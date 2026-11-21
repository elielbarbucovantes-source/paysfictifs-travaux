@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "PF_ROOT=%~dp0"
cd /d "!PF_ROOT!" || goto :badroot

for /f "usebackq eol=# tokens=1,* delims==" %%A in ("!PF_ROOT!mod.config") do set "CFG_%%A=%%~B"
if exist "!PF_ROOT!user.config" for /f "usebackq eol=# tokens=1,* delims==" %%A in ("!PF_ROOT!user.config") do set "CFG_%%A=%%~B"
set "MOD_ID=!CFG_MOD_ID!"
set "ENGINE_VERSION=!CFG_ENGINE_VERSION!"
set "ENGINE_DIRECTORY=!CFG_ENGINE_DIRECTORY!"
set "MOD_SEARCH_PATHS=!PF_ROOT!mods,./mods"
set "ENGINE_DIR=.."
if not defined MOD_ID goto :badconfig
if not defined ENGINE_VERSION goto :badconfig
if not defined ENGINE_DIRECTORY goto :badconfig

title OpenRA.Utility.exe !MOD_ID!

set "ENGINE_DIRECTORY=!ENGINE_DIRECTORY:/=\!"
for %%I in ("!ENGINE_DIRECTORY!") do set "ENG_DIR=%%~fI"
if not exist "!ENG_DIR!\bin\OpenRA.exe" goto :noengine
if not exist "!ENG_DIR!\VERSION" goto :noengine
set "ENGINE_FILE_VERSION="
for /f "usebackq delims=" %%V in ("!ENG_DIR!\VERSION") do if not defined ENGINE_FILE_VERSION set "ENGINE_FILE_VERSION=%%V"
if /I not "!ENGINE_FILE_VERSION!"=="!ENGINE_VERSION!" goto :badversion
cd /d "!ENG_DIR!" || goto :noengine

set argC=0
for %%x in (%*) do set /A argC+=1

if %argC% == 0 goto choosemod

if %argC% == 1 (
    set MOD_ID=%1
    goto loop
)

if %argC% GEQ 2 (
    @REM This option is for use by other scripts so we don't want any extra output here - before or after.
    call "!ENG_DIR!\bin\OpenRA.Utility.exe" %*
    set "PF_RC=!errorlevel!"
    cd /d "!PF_ROOT!"
    EXIT /B !PF_RC!
)

:choosemod
echo ----------------------------------------
echo.
call "!ENG_DIR!\bin\OpenRA.Utility.exe"
echo Enter --exit to exit
set /P mod="Please enter a modname: OpenRA.Utility.exe "
if /I "!mod!" EQU "--exit" (exit /b)
set MOD_ID=%mod%
echo.

:loop
echo.
echo ----------------------------------------
echo.
echo Enter a utility command or --exit to exit.
echo Press enter to view a list of valid utility commands.
echo.

set /P command="Please enter a command: OpenRA.Utility.exe !MOD_ID! "
if /I "!command!" EQU "--exit" (cd /d "!PF_ROOT!" & exit /b)
echo.
echo ----------------------------------------
echo.
echo Starting OpenRA.Utility.exe !MOD_ID! !command!
call "!ENG_DIR!\bin\OpenRA.Utility.exe" !MOD_ID! !command!
goto loop

:badroot
echo [ERREUR/ERROR] Cannot access the mod directory: "!PF_ROOT!"
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

:badconfig
echo [ERREUR/ERROR] Required mod.config variables are missing. / Configuration incomplete.
echo [INFO] Check MOD_ID, ENGINE_VERSION and ENGINE_DIRECTORY in mod.config/user.config.
pause
exit /b 1
