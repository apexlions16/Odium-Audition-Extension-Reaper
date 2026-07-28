@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Odium-Reaper.ps1"
if errorlevel 1 (
  echo.
  echo Kurulumda hata olustu.
  pause
  exit /b 1
)
echo.
echo Kurulum tamamlandi.
pause
