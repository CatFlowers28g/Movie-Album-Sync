# Builds the Windows downloads for Movie Album Sync:
#   dist\MovieAlbumSync-<version>-Setup.exe     installer (what to send to people)
#   dist\MovieAlbumSync-<version>-Portable.zip  no-install version
#
# Usage (from PowerShell):  .\build-windows.ps1
# Needs Python 3 and Inno Setup 6 (winget install JRSoftware.InnoSetup).

param([switch]$SkipInstaller)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # makes Invoke-WebRequest much faster

$root = $PSScriptRoot
# Build files live outside the repo so OneDrive doesn't try to sync thousands of them
$work = Join-Path $env:LOCALAPPDATA 'MovieAlbumSync-build'
$venv = Join-Path $work 'venv'
$python = Join-Path $venv 'Scripts\python.exe'
$ffmpegDir = Join-Path $work 'ffmpeg'
$ffmpegUrl = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
$version = (Select-String -Path "$root\movie_album_sync\__init__.py" -Pattern '__version__ = "(.+)"').Matches[0].Groups[1].Value

function Invoke-Native([scriptblock]$Command) {
    # Tools like pip and unittest write normal output to stderr; judge success by exit code instead
    $ErrorActionPreference = 'Continue'
    & $Command
    if ($LASTEXITCODE) { throw "Command failed with exit code ${LASTEXITCODE}: $Command" }
}

Write-Host "Building Movie Album Sync $version" -ForegroundColor Cyan
New-Item -ItemType Directory -Force $work | Out-Null

# 1. Python environment
if (-not (Test-Path $python)) {
    Write-Host 'Creating Python environment...'
    Invoke-Native { python -m venv $venv }
}
Invoke-Native { & $python -m pip install --disable-pip-version-check -q -r "$root\requirements.txt" -r "$root\requirements-build.txt" }

# 2. Tests
Write-Host 'Running tests...'
Push-Location $root
try { Invoke-Native { & $python -m unittest discover -s tests -q } } finally { Pop-Location }

# 3. ffmpeg (downloaded once, then reused)
if (-not (Test-Path "$ffmpegDir\ffmpeg.exe")) {
    Write-Host "Downloading ffmpeg from $ffmpegUrl ..."
    $zip = Join-Path $work 'ffmpeg.zip'
    $extracted = Join-Path $work 'ffmpeg-extracted'
    Invoke-WebRequest $ffmpegUrl -OutFile $zip -UseBasicParsing
    Remove-Item -Recurse -Force $extracted -ErrorAction SilentlyContinue
    Expand-Archive $zip $extracted
    $build = Get-ChildItem $extracted -Directory | Select-Object -First 1
    New-Item -ItemType Directory -Force $ffmpegDir | Out-Null
    Copy-Item "$($build.FullName)\bin\ffmpeg.exe" $ffmpegDir
    Copy-Item "$($build.FullName)\LICENSE" "$ffmpegDir\LICENSE.txt"
    Remove-Item -Recurse -Force $zip, $extracted
}

# 4. App folder with PyInstaller
Write-Host 'Packaging the app...'
$appDir = Join-Path $work 'dist\MovieAlbumSync'
Invoke-Native {
    & $python -m PyInstaller --noconfirm --clean --windowed --log-level WARN `
        --name MovieAlbumSync `
        --icon "$root\assets\icon.ico" `
        --add-data "$root\assets\icon.ico;assets" `
        --add-binary "$ffmpegDir\ffmpeg.exe;ffmpeg" `
        --add-data "$ffmpegDir\LICENSE.txt;ffmpeg" `
        --distpath "$work\dist" --workpath "$work\pyinstaller" --specpath $work `
        "$root\launch.py"
}

# 5. Downloads
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
$portable = Join-Path $dist "MovieAlbumSync-$version-Portable.zip"
Remove-Item $portable -ErrorAction SilentlyContinue
Compress-Archive -Path $appDir -DestinationPath $portable
Write-Host "Portable zip: $portable" -ForegroundColor Green

if ($SkipInstaller) { return }
$iscc = @(
    (Get-Command iscc -ErrorAction SilentlyContinue).Source,
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup 6 not found. Install it with: winget install JRSoftware.InnoSetup  (or rerun with -SkipInstaller)' }
Invoke-Native { & $iscc /Q "/DAppVersion=$version" "/DSourceDir=$appDir" "/O$dist" "$root\installer.iss" }
Write-Host "Installer: $dist\MovieAlbumSync-$version-Setup.exe" -ForegroundColor Green
