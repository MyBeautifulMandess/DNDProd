$ErrorActionPreference = 'Stop'

$appName = 'D&D Помощник'
$installDir = Join-Path $env:LOCALAPPDATA 'DNDProd'
$zipPath = Join-Path $PSScriptRoot 'app.zip'

if (-not (Test-Path -LiteralPath $zipPath)) {
  throw "Не найден архив приложения: $zipPath"
}

if (Test-Path -LiteralPath $installDir) {
  Remove-Item -LiteralPath $installDir -Recurse -Force
}
New-Item -ItemType Directory -Path $installDir -Force | Out-Null

Expand-Archive -LiteralPath $zipPath -DestinationPath $installDir -Force

$uninstallSource = Join-Path $PSScriptRoot 'uninstall.ps1'
if (Test-Path -LiteralPath $uninstallSource) {
  Copy-Item -LiteralPath $uninstallSource -Destination (Join-Path $installDir 'uninstall.ps1') -Force
}

$exePath = Join-Path $installDir 'dnd_prod.exe'
if (-not (Test-Path -LiteralPath $exePath)) {
  throw "Не найден исполняемый файл: $exePath"
}

$programs = Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs'
New-Item -ItemType Directory -Path $programs -Force | Out-Null

$shell = New-Object -ComObject WScript.Shell

$shortcut = $shell.CreateShortcut((Join-Path $programs "$appName.lnk"))
$shortcut.TargetPath = $exePath
$shortcut.WorkingDirectory = $installDir
$shortcut.Description = 'Помощник для игроков и мастеров D&D 5e'
$shortcut.Save()

$uninstallPath = Join-Path $installDir 'uninstall.ps1'
$uninstallShortcut = $shell.CreateShortcut((Join-Path $programs "Удалить $appName.lnk"))
$uninstallShortcut.TargetPath = 'powershell.exe'
$uninstallShortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $uninstallPath
$uninstallShortcut.WorkingDirectory = $installDir
$uninstallShortcut.Save()

Write-Host "$appName установлен в $installDir"
