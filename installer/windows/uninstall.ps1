$ErrorActionPreference = 'Stop'

$appName = 'D&D Помощник'
$installDir = Join-Path $env:LOCALAPPDATA 'DNDProd'
$programs = Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs'

Remove-Item -LiteralPath (Join-Path $programs "$appName.lnk") -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $programs "Удалить $appName.lnk") -Force -ErrorAction SilentlyContinue

if (Test-Path -LiteralPath $installDir) {
  Remove-Item -LiteralPath $installDir -Recurse -Force
}

Write-Host "$appName удалён. Данные персонажей и приключений в Документах сохранены."
