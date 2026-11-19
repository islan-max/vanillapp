@echo off
cd /d "%~dp0"
echo Atualizando o Vanilla++... (feche o Minecraft antes)
curl.exe -fsSL -o "%TEMP%\vanillapp-atualizar.ps1" "https://raw.githubusercontent.com/islan-max/vanillapp/main/atualizar.ps1"
if errorlevel 1 (
  echo Nao consegui baixar o atualizador. Confere a internet.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\vanillapp-atualizar.ps1"
if not "%1"=="/auto" pause
