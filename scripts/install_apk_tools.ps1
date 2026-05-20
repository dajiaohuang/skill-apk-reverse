param(
  [string]$Workspace = (Get-Location).Path,
  [switch]$Force,
  [switch]$NoJadx,
  [switch]$NoApktool,
  [switch]$NoJre
)

$ErrorActionPreference = 'Stop'

function Resolve-AbsolutePath([string]$Path) {
  if (Test-Path -LiteralPath $Path) {
    return (Resolve-Path -LiteralPath $Path).Path
  }
  $parent = Split-Path -Parent $Path
  $leaf = Split-Path -Leaf $Path
  if (-not $parent) { $parent = (Get-Location).Path }
  $parentResolved = (Resolve-Path -LiteralPath $parent).Path
  return (Join-Path $parentResolved $leaf)
}

function Assert-ChildPath([string]$Child, [string]$Parent) {
  $childFull = [System.IO.Path]::GetFullPath($Child)
  $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\') + '\'
  if (-not $childFull.StartsWith($parentFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to operate outside intended directory. Child=$childFull Parent=$parentFull"
  }
}

function Invoke-CurlDownload([string]$Url, [string]$OutFile) {
  $curl = Get-Command curl.exe -ErrorAction Stop
  & $curl.Source -L --fail -o $OutFile $Url
  if ($LASTEXITCODE -ne 0) {
    throw "Download failed: $Url"
  }
}

function Expand-ArchiveWithTar([string]$Archive, [string]$Destination) {
  $tar = Get-Command tar.exe -ErrorAction Stop
  New-Item -ItemType Directory -Force -Path $Destination | Out-Null
  & $tar.Source -xf $Archive -C $Destination
  if ($LASTEXITCODE -ne 0) {
    throw "Extraction failed: $Archive"
  }
}

function Remove-DirectoryIfRequested([string]$Path, [string]$Root) {
  if ((Test-Path -LiteralPath $Path) -and $Force) {
    Assert-ChildPath $Path $Root
    Remove-Item -LiteralPath $Path -Recurse -Force
  }
}

$workspaceRoot = Resolve-AbsolutePath $Workspace
if (-not (Test-Path -LiteralPath $workspaceRoot)) {
  New-Item -ItemType Directory -Force -Path $workspaceRoot | Out-Null
  $workspaceRoot = Resolve-AbsolutePath $Workspace
}

$tools = Join-Path $workspaceRoot '_tools'
$downloads = Join-Path $tools 'downloads'
$bin = Join-Path $tools 'bin'
New-Item -ItemType Directory -Force -Path $tools, $downloads, $bin | Out-Null

$headers = @{ 'User-Agent' = 'codex-apk-reverse-tools' }

if (-not $NoJadx) {
  $jadxDir = Join-Path $tools 'jadx'
  $jadxCmd = Join-Path $bin 'jadx.cmd'
  if ($Force -or -not (Test-Path -LiteralPath $jadxCmd)) {
    Remove-DirectoryIfRequested $jadxDir $tools
    New-Item -ItemType Directory -Force -Path $jadxDir | Out-Null
    Write-Host 'Resolving latest jadx release...'
    $jadxRelease = Invoke-RestMethod -Headers $headers -Uri 'https://api.github.com/repos/skylot/jadx/releases/latest'
    $jadxAsset = $jadxRelease.assets | Where-Object { $_.name -match '^jadx-.*\.zip$' } | Select-Object -First 1
    if (-not $jadxAsset) { throw 'Could not find jadx zip asset in latest release.' }
    $jadxZip = Join-Path $downloads $jadxAsset.name
    Write-Host "Downloading $($jadxAsset.name)..."
    Invoke-CurlDownload $jadxAsset.browser_download_url $jadxZip
    Expand-ArchiveWithTar $jadxZip $jadxDir
  }
}

if (-not $NoApktool) {
  $apktoolJar = Join-Path $tools 'apktool.jar'
  if ($Force -or -not (Test-Path -LiteralPath $apktoolJar)) {
    Write-Host 'Resolving latest apktool release...'
    $apktoolRelease = Invoke-RestMethod -Headers $headers -Uri 'https://api.github.com/repos/iBotPeaches/Apktool/releases/latest'
    $apktoolAsset = $apktoolRelease.assets | Where-Object { $_.name -match '^apktool.*\.jar$' } | Select-Object -First 1
    if (-not $apktoolAsset) { throw 'Could not find apktool jar asset in latest release.' }
    Write-Host "Downloading $($apktoolAsset.name)..."
    Invoke-CurlDownload $apktoolAsset.browser_download_url $apktoolJar
  }
}

if (-not $NoJre) {
  $jreParent = Join-Path $tools 'jre'
  $javaCmd = Join-Path $bin 'java.cmd'
  if ($Force -or -not (Test-Path -LiteralPath $javaCmd)) {
    Remove-DirectoryIfRequested $jreParent $tools
    New-Item -ItemType Directory -Force -Path $jreParent | Out-Null
    $jreZip = Join-Path $downloads 'temurin-jre21-windows-x64.zip'
    Write-Host 'Downloading portable Temurin JRE 21...'
    Invoke-CurlDownload 'https://api.adoptium.net/v3/binary/latest/21/ga/windows/x64/jre/hotspot/normal/eclipse?project=jdk' $jreZip
    Expand-ArchiveWithTar $jreZip $jreParent
  }
}

$jreHome = Get-ChildItem (Join-Path $tools 'jre') -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
$javaExe = if ($jreHome) { Join-Path $jreHome.FullName 'bin\java.exe' } else { $null }
if (-not $javaExe -or -not (Test-Path -LiteralPath $javaExe)) {
  $pathJava = Get-Command java.exe -ErrorAction SilentlyContinue
  if ($pathJava) { $javaExe = $pathJava.Source }
}
if (-not $javaExe -or -not (Test-Path -LiteralPath $javaExe)) {
  throw 'No Java runtime found. Re-run without -NoJre or install Java.'
}

$jadxBat = Get-ChildItem (Join-Path $tools 'jadx') -Recurse -Filter 'jadx.bat' -ErrorAction SilentlyContinue | Select-Object -First 1
$jadxGuiBat = Get-ChildItem (Join-Path $tools 'jadx') -Recurse -Filter 'jadx-gui.bat' -ErrorAction SilentlyContinue | Select-Object -First 1

Set-Content -Encoding ASCII -Path (Join-Path $bin 'java.cmd') -Value "@echo off`r`n`"$javaExe`" %*`r`n"

if ($jadxBat) {
  $javaHomeLine = if ($jreHome) { "set JAVA_HOME=$($jreHome.FullName)" } else { "set JAVA_HOME=" }
  Set-Content -Encoding ASCII -Path (Join-Path $bin 'jadx.cmd') -Value "@echo off`r`n$javaHomeLine`r`nif not `"%JAVA_HOME%`"==`"`" set PATH=%JAVA_HOME%\bin;%PATH%`r`ncall `"$($jadxBat.FullName)`" %*`r`n"
}

if ($jadxGuiBat) {
  $javaHomeLine = if ($jreHome) { "set JAVA_HOME=$($jreHome.FullName)" } else { "set JAVA_HOME=" }
  Set-Content -Encoding ASCII -Path (Join-Path $bin 'jadx-gui.cmd') -Value "@echo off`r`n$javaHomeLine`r`nif not `"%JAVA_HOME%`"==`"`" set PATH=%JAVA_HOME%\bin;%PATH%`r`ncall `"$($jadxGuiBat.FullName)`" %*`r`n"
}

$apktoolJar = Join-Path $tools 'apktool.jar'
if (Test-Path -LiteralPath $apktoolJar) {
  Set-Content -Encoding ASCII -Path (Join-Path $bin 'apktool.cmd') -Value "@echo off`r`n`"$javaExe`" -jar `"$apktoolJar`" %*`r`n"
}

Write-Host 'Installed tool wrappers:'
Get-ChildItem -LiteralPath $bin -Filter '*.cmd' | ForEach-Object { Write-Host " - $($_.FullName)" }

Write-Host 'Verification:'
& (Join-Path $bin 'java.cmd') -version
if (Test-Path -LiteralPath (Join-Path $bin 'jadx.cmd')) { & (Join-Path $bin 'jadx.cmd') --version }
if (Test-Path -LiteralPath (Join-Path $bin 'apktool.cmd')) { & (Join-Path $bin 'apktool.cmd') --version }
