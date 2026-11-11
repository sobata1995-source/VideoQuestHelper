@echo off
setlocal
set "VQH_INSTALL_SOURCE=%~dp0VideoQuestHelper.exe"
if not exist "%VQH_INSTALL_SOURCE%" (
    echo Extract the entire Windows ZIP before running this installer.
    pause
    exit /b 1
)

echo This installs Video Quest Helper for your Windows account.
echo It starts the helper in the background now and at future sign-ins.
choice /C YN /N /M "Install the helper? [Y/N] "
if errorlevel 2 exit /b 0
if not errorlevel 1 exit /b 1

powershell.exe -NoProfile -NonInteractive -Command "$ErrorActionPreference = 'Stop'; $folder = Join-Path $env:LOCALAPPDATA 'VideoQuestHelper'; New-Item -ItemType Directory -Force -Path $folder | Out-Null; $exe = Join-Path $folder 'VideoQuestHelperBackground.exe'; $startup = [Environment]::GetFolderPath('Startup'); if (-not $startup) { throw 'Windows Startup folder is unavailable.' }; $existing = @(Get-Process -Name VideoQuestHelperBackground -ErrorAction SilentlyContinue | Where-Object Path -eq $exe); if ($existing.Count) { $existing | Stop-Process; $existing | Wait-Process -ErrorAction SilentlyContinue }; Copy-Item -LiteralPath $env:VQH_INSTALL_SOURCE -Destination $exe -Force; $shell = New-Object -ComObject WScript.Shell; $link = $shell.CreateShortcut((Join-Path $startup 'Video Quest Helper.lnk')); $link.TargetPath = $exe; $link.WorkingDirectory = $folder; $link.Save(); Start-Process -FilePath $exe -WindowStyle Hidden"
if errorlevel 1 (
    echo Setup failed. See the error above.
    pause
    exit /b 1
)

echo Setup complete. Open WoW Forever, or type /reload if it is already running.
pause
