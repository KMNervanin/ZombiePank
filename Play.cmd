@echo off
set "GODOT=%LOCALAPPDATA%\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot 4.7.2 was not found. Install it from https://godotengine.org/download/windows/
  echo Or open project.godot in your Godot editor and press F6 or F5.
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0."
