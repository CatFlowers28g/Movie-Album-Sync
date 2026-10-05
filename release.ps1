# Publishes a new version of Movie Album Sync.
#
#   .\release.ps1 1.2.0 "Added a Star Wars theme and fixed the preview button"
#
# Sets the app's version, commits it, and pushes a v1.2.0 tag carrying your notes. GitHub then builds the
# Windows and Mac downloads and publishes them as a Release, and the notes appear in the app's update popup.
# Write the notes for the people using the app.

param(
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$Notes
)

$ErrorActionPreference = 'Stop'
$repo = 'https://github.com/CatFlowers28g/Movie-Album-Sync'
$init = Join-Path $PSScriptRoot 'desktop-app\movie_album_sync\__init__.py'

function Invoke-Git {
    $ErrorActionPreference = 'Continue'  # git prints progress to stderr; judge success by exit code
    & git -C $PSScriptRoot @args
    if ($LASTEXITCODE) { throw "git $args failed" }
}

if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "The version should look like 1.2.0" }
$current = (Select-String -Path $init -Pattern '__version__ = "(.+)"').Matches[0].Groups[1].Value
if ([version]$Version -le [version]$current) { throw "The new version must be higher than the current one ($current)" }
if ((git -C $PSScriptRoot branch --show-current) -ne 'main') { throw "Switch to the main branch first" }
if (git -C $PSScriptRoot status --porcelain) { throw "Commit or discard your other changes first" }

Invoke-Git pull --ff-only --quiet
$text = [IO.File]::ReadAllText($init) -replace '__version__ = ".+"', "__version__ = `"$Version`""
[IO.File]::WriteAllText($init, $text, (New-Object Text.UTF8Encoding $false))
Invoke-Git commit --quiet -m "Release $Version" -- $init
Invoke-Git tag -a "v$Version" -m $Notes
Invoke-Git push --quiet origin main "v$Version"

Write-Host "Released v$Version. GitHub is building it now (about 10 minutes):" -ForegroundColor Green
Write-Host "  Progress: $repo/actions"
Write-Host "  Release:  $repo/releases/tag/v$Version"
