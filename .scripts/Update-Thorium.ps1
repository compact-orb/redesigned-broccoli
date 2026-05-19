$localEbuildDir = Join-Path -Path $PSScriptRoot -ChildPath "..\www-client\thorium-bin"
$repo = "Alex313031/thorium"
$headers = @{ authorization = "Bearer $env:GITHUB_TOKEN" }

Write-Output -InputObject "Fetching latest Thorium release..."

$latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $headers
$latestTag = $latestRelease.tag_name
$latestVersion = $latestTag -replace '^M', ''

$existingEbuilds = Get-ChildItem -Path $localEbuildDir -Filter "thorium-bin-*.ebuild"
$currentEbuild = $existingEbuilds | Sort-Object Name -Descending | Select-Object -First 1
$currentVersion = if ($currentEbuild) { ($currentEbuild.Name -replace 'thorium-bin-', '' -replace '\.ebuild', '') } else { $null }

Write-Output -InputObject "Latest version: $latestVersion"
Write-Output -InputObject "Current version: $currentVersion"

if ($latestVersion -eq $currentVersion) {
    Write-Output -InputObject "Thorium is up to date."
    exit 0
}

Write-Output -InputObject "New version detected: $latestVersion"

# Create new ebuild
$newEbuildName = "thorium-bin-$latestVersion.ebuild"
$newEbuildPath = Join-Path -Path $localEbuildDir -ChildPath $newEbuildName

if ($currentEbuild) {
    Copy-Item -Path $currentEbuild.FullName -Destination $newEbuildPath
    Remove-Item -Path $currentEbuild.FullName
}
else {
    Write-Error -Message "No existing ebuild to copy from."
    exit 1
}

Write-Output -InputObject "Generating Manifest..."

$assets = $latestRelease.assets | Where-Object -FilterScript { $_.name -like "*.deb" -and $_.name -notlike "*i386*" -and ($_.name -match "AVX2|AVX|SSE4|SSE3") }
$manifestEntries = @()
$tempDir = Join-Path -Path $PSScriptRoot -ChildPath "temp_dist"
if (Test-Path -Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir | Out-Null

foreach ($asset in $assets) {
    $destPath = Join-Path -Path $tempDir -ChildPath $asset.name
    Write-Output -InputObject "Downloading $($asset.name)..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $destPath

    $size = (Get-Item $destPath).Length
    $b2sum = (b2sum $destPath).Split(" ")[0]
    $sha512 = (sha512sum $destPath).Split(" ")[0]

    $manifestEntries += "DIST $($asset.name) $size BLAKE2B $b2sum SHA512 $sha512"
    Remove-Item -Path $destPath
}

$manifestEntries | Sort-Object | Set-Content -Path (Join-Path -Path $localEbuildDir -ChildPath "Manifest")
Remove-Item -Path $tempDir -Recurse -Force

New-Item -Path (Join-Path -Path $PSScriptRoot -ChildPath "..\ChangesMade") | Out-Null
Write-Output -InputObject "Prepared update for $latestVersion"
