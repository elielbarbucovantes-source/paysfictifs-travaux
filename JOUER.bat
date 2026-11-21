@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Pays fictifs - JOUER / PLAY

set "DOTNET_ROLL_FORWARD=LatestMajor"
set "PF_ROOT=%~dp0"
cd /d "!PF_ROOT!" || goto :badroot

echo ============================================================
echo  Pays fictifs - JOUER / PLAY (Windows, one click)
echo  Root: "!PF_ROOT!"
echo ============================================================
echo.

set "PF_ALL_ARGS="
set "PF_LAUNCH_ARGS="
:parse_args
if "%~1"=="" goto :args_done
if /I "%~1"=="--help" (
    echo Usage: JOUER.bat [--no-build] [extra OpenRA arguments...]
    echo   --no-build  skip SDK check and compilation, launch existing binaries.
    exit /b 0
)
if /I "%~1"=="--no-build" (
    set "PF_ALL_ARGS=!PF_ALL_ARGS! "%~1""
    shift
    goto :parse_args
)
if /I "%~1"=="--skip-build" (
    set "PF_ALL_ARGS=!PF_ALL_ARGS! --no-build"
    shift
    goto :parse_args
)
set "PF_ALL_ARGS=!PF_ALL_ARGS! "%~1""
set "PF_LAUNCH_ARGS=!PF_LAUNCH_ARGS! "%~1""
shift
goto :parse_args
:args_done

echo [INFO] Step 1/2 - setup and build / installation et compilation...
call "!PF_ROOT!INSTALL.bat" !PF_ALL_ARGS!
if errorlevel 1 goto :install_failed

echo [INFO] Step 2/2 - starting the game / lancement du jeu...
call "!PF_ROOT!launch-game.cmd" !PF_LAUNCH_ARGS!
set "PF_RC=!errorlevel!"
cd /d "!PF_ROOT!"
if not "!PF_RC!"=="0" goto :game_failed
echo [INFO] Game closed normally / Jeu ferme normalement.
exit /b 0

:badroot
echo [ERREUR/ERROR] Cannot access the mod directory: "!PF_ROOT!"
pause
exit /b 1

:install_failed
echo [ERREUR/ERROR] Setup failed; the game was not started. / Installation echouee.
pause
exit /b 1

:game_failed
echo [ERREUR/ERROR] OpenRA exited with error code !PF_RC!. / Le jeu a plante.
echo [INFO] Check Documents\OpenRA\Logs and the messages above.
pause
exit /b !PF_RC!
