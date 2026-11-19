param(
  [string]$Flutter = 'flutter',
  [string]$IExpress = ''
)

$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$releaseDir = Join-Path $root 'build\windows\x64\runner\Release'
$staging = Join-Path $PSScriptRoot 'staging'
$output = Join-Path $PSScriptRoot 'DNDProd-setup-win-x64.exe'
$sedPath = Join-Path $PSScriptRoot 'setup.sed'

if (-not $IExpress) {
  $x86 = Join-Path $env:SystemRoot 'SysWOW64\iexpress.exe'
  $IExpress = if (Test-Path -LiteralPath $x86) { $x86 } else { Join-Path $env:SystemRoot 'System32\iexpress.exe' }
}

Push-Location $root
try {
  & $Flutter build windows --release
  if ($LASTEXITCODE -ne 0) { throw 'flutter build windows --release завершился с ошибкой' }
}
finally {
  Pop-Location
}

if (-not (Test-Path -LiteralPath $releaseDir)) {
  throw "Не найдена сборка: $releaseDir"
}

Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $staging -Force | Out-Null

Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'install.ps1') -Destination $staging -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'uninstall.ps1') -Destination $staging -Force
Compress-Archive -Path (Join-Path $releaseDir '*') -DestinationPath (Join-Path $staging 'app.zip') -Force

$files = @('app.zip', 'install.ps1', 'uninstall.ps1')
$sed = @(
  '[Version]',
  'Class=IEXPRESS',
  'SEDVersion=3',
  '[Options]',
  'PackagePurpose=InstallApp',
  'ShowInstallProgramWindow=0',
  'HideExtractAnimation=1',
  'UseLongFileName=1',
  'InsideCompressed=0',
  'CAB_FixedSize=0',
  'CAB_ResvCodeSigning=0',
  'RebootMode=N',
  'CheckAdminRights=0',
  'InstallPrompt=%InstallPrompt%',
  'DisplayLicense=%DisplayLicense%',
  'FinishMessage=%FinishMessage%',
  'TargetName=%TargetName%',
  'FriendlyName=%FriendlyName%',
  'AppLaunched=%AppLaunched%',
  'PostInstallCmd=%PostInstallCmd%',
  'AdminQuietInstCmd=%AdminQuietInstCmd%',
  'UserQuietInstCmd=%UserQuietInstCmd%',
  'SourceFiles=SourceFiles',
  '[Strings]',
  'InstallPrompt=',
  'DisplayLicense=',
  'FinishMessage=Installation complete',
  "TargetName=$output",
  'FriendlyName=D&D Assistant',
  'AppLaunched=powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1',
  'PostInstallCmd=<None>',
  'AdminQuietInstCmd=',
  'UserQuietInstCmd='
)

for ($i = 0; $i -lt $files.Count; $i++) {
  $sed += "FILE$i=$($files[$i])"
}
$sed += '[SourceFiles]'
for ($i = 0; $i -lt $files.Count; $i++) {
  $sed += "SourceFiles$i=$staging"
}
for ($i = 0; $i -lt $files.Count; $i++) {
  $sed += "[SourceFiles$i]"
  $sed += "%FILE$i%="
}

Set-Content -LiteralPath $sedPath -Value $sed -Encoding ASCII

Remove-Item -LiteralPath $output -Force -ErrorAction SilentlyContinue
& $IExpress /N /Q $sedPath
if ($LASTEXITCODE -ne 0) { throw "IExpress завершился с кодом $LASTEXITCODE" }

$deadline = (Get-Date).AddSeconds(180)
while (-not (Test-Path -LiteralPath $output) -and (Get-Date) -lt $deadline) {
  Start-Sleep -Milliseconds 500
}
if (-not (Test-Path -LiteralPath $output)) { throw 'Установщик не был создан' }

Write-Host "Установщик: $output"
