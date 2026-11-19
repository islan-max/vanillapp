@echo off
cd /d "%~dp0"
echo Atualizando o Vanilla++... (feche o Minecraft antes)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol='Tls12'; iex ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/islan-max/vanillapp/main/atualizar.ps1'))"
if not "%1"=="/auto" pause
