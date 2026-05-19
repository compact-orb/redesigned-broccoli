param (
    [Parameter(Mandatory = $true)]
    [string]$Version
)

$ErrorActionPreference = "Stop"

$workingDir = Get-Location
$depotToolsDir = Join-Path -Path $workingDir -ChildPath "depot_tools"
$chromiumDir = Join-Path -Path $workingDir -ChildPath "chromium"

Write-Host -Object "--- Preparing Sources for Chromium $Version ---"

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

Write-Host -Object "Fetching Chromium source (Approx 20-30GB)..."
& fetch --nohooks --no-history chromium

Set-Location -Path "src"

Write-Host -Object "Checking out tag $Version..."
git fetch --tags origin $Version
git checkout -f "tags/$Version"

Write-Host -Object "Syncing dependencies with gclient..."
& gclient sync --with_branch_heads --with_tags --nohooks --no-history --force --reset --delete_unversioned_trees

# 3. Cleanup to save space and keep git clean
Write-Host -Object "Cleaning up all .git directories to prepare for push..."
Get-ChildItem -Path . -Filter ".git" -Recurse -Hidden | Remove-Item -Recurse -Force

# 4. Prepare for Push to Branch
Write-Host -Object "Initializing temporary git repo to push to branch..."
git init
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git add .
git commit -m "Chromium $Version sources"

$repoUrl = "https://x-access-token:$($env:GITHUB_TOKEN)@github.com/$($env:GITHUB_REPOSITORY).git"
$branchName = "sources/chromium-$Version"
$tagName = "chromium-$Version"

Write-Host -Object "Pushing sources to branch $branchName..."
git push $repoUrl "HEAD:refs/heads/$branchName" --force --tags

Write-Host -Object "Tagging the release..."
git tag $tagName
git push $repoUrl $tagName --force

Write-Host -Object "Successfully pushed Chromium $Version sources to branch and tag."
