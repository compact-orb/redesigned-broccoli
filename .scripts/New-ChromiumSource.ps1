param (
    [Parameter(Mandatory = $true)]
    [string]$Version
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$workingDir = Get-Location
$depotToolsDir = Join-Path -Path $workingDir -ChildPath "depot_tools"
$chromiumDir = Join-Path -Path $workingDir -ChildPath "chromium"
$tarballName = "chromium-$Version-linux.tar.zst"

Write-Host -Object "--- Creating Tarball for Chromium $Version ---"

# 1. Install depot_tools
if (-not (Test-Path $depotToolsDir)) {
    Write-Host -Object "Cloning depot_tools..."
    git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git $depotToolsDir
}

$env:PATH = "$depotToolsDir" + [IO.Path]::PathSeparator + $env:PATH
$env:DEPOT_TOOLS_WIN_TOOLCHAIN = "0"

# 2. Fetch Chromium (Shallow)
if (-not (Test-Path -Path $chromiumDir)) {
    New-Item -ItemType Directory -Path $chromiumDir | Out-Null
}
Set-Location -Path $chromiumDir

Write-Host -Object "Fetching Chromium source..."
& fetch --nohooks --no-history chromium

Set-Location -Path "src"

Write-Host -Object "Checking out tag $Version..."
git fetch --tags origin $Version
git checkout -f "tags/$Version"

Write-Host -Object "Syncing dependencies with gclient..."
& gclient sync --with_branch_heads --with_tags --nohooks --no-history --force --reset --delete_unversioned_trees

# 3. Cleanup to save space before tarballing
Write-Host -Object "Cleaning up .git directories to save space..."
Get-ChildItem -Path . -Filter ".git" -Recurse -Hidden | Remove-Item -Recurse -Force

Write-Host -Object "Creating tarball $tarballName with zstd (long=31)..."
# We move up and tar the 'src' directory but rename it in the archive to match Gentoo expectations
Set-Location -Path ..
Move-Item -Path "src" -Destination "chromium-$Version"

tar --create --file=- "chromium-$Version" | zstd --long=31 -19 -T0 -o "../$tarballName"

Set-Location -Path $workingDir

if (Test-Path -Path $tarballName) {
    $size = (Get-Item -Path $tarballName).Length / 1GB
    Write-Host -Object "Successfully created $tarballName ($([math]::Round($size, 2)) MB)"
}
else {
    throw "Failed to create tarball."
}
