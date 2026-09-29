@echo off
set "GODOT=%LOCALAPPDATA%\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Install Godot 4.7.2 and open project.godot.
  pause
  exit /b 1
)
start "" "%GODOT%" --editor --path "%~dp0."
