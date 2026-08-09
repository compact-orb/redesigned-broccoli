$localEbuildDir = Join-Path -Path $PSScriptRoot -ChildPath "..\www-client\google-chrome"

$headers = @{ authorization = "Bearer $env:GITHUB_TOKEN" }

Write-Output -InputObject "Fetching upstream versions..."

$response = Invoke-RestMethod -Uri "https://api.github.com/repos/gentoo/gentoo/contents/www-client/google-chrome" -Headers $headers

$contents = $response | Where-Object { $_.name -like "*.ebuild" }

$manifestRemote = $response | Where-Object { $_.name -eq "Manifest" }

$localFiles = Get-ChildItem -Path $localEbuildDir -Filter "*.ebuild" | Select-Object -ExpandProperty Name

$newEbuilds = $contents | Where-Object { $localFiles -notcontains $_.name }

$oldEbuilds = $localFiles | Where-Object { $contents.name -notcontains $_ }

if (-not $newEbuilds -and -not $oldEbuilds) {
    Write-Output -InputObject "No changes detected. Local ebuilds are up to date."

    exit 0
}

$srcUriReplacement = @"
SRC_URI="
	https://dl.google.com/linux/chrome/deb/pool/main/g/`${MY_PN}/`${MY_P}_amd64.deb
	https://bookish-spork.compact-orb.ovh/local/libwidevinecdm.so
"
"@

$wrapperCode = @"
src_install() {
    upstream_src_install

    einfo "Overwriting libwidevinecdm.so with custom version..."
    
    local target_dir="`${ED}/opt/google/chrome/WidevineCdm/_platform_specific/linux_x64"

    cp "`${DISTDIR}/libwidevinecdm.so" "`${target_dir}/libwidevinecdm.so" || die "Failed to copy custom libwidevinecdm.so"
}
"@

foreach ($ebuild in $newEbuilds) {
    Write-Output -InputObject "Processing $($ebuild.name)..."

    $content = Invoke-RestMethod -Uri $ebuild.download_url -Headers $headers

    # Replace src_install with upstream_src_install
    $patchedContent = $content -replace '(?m)^src_install\s*\(\)', 'upstream_src_install()'
    
    # Replace the SRC_URI block with our custom version that includes widevine
    $patchedContent = $patchedContent -replace '(?s)^SRC_URI=".*?"', $srcUriReplacement

    $finalContent = $patchedContent + "`n" + $wrapperCode

    $outputPath = Join-Path -Path $localEbuildDir -ChildPath $ebuild.name

    $finalContent | Set-Content -Path $outputPath

    Write-Output -InputObject "Saved patched ebuild: $outputPath"
}

foreach ($old in $oldEbuilds) {
    Write-Output -InputObject "Removing old ebuild: $old"

    Remove-Item -Path (Join-Path -Path $localEbuildDir -ChildPath $old)
}

Write-Output -InputObject "Updating Manifest..."

$manifestContent = Invoke-RestMethod -Uri $manifestRemote.download_url -Headers $headers

# Read local Manifest to preserve widevine entry
$localManifestPath = Join-Path -Path $localEbuildDir -ChildPath "Manifest"
$localManifest = Get-Content -Path $localManifestPath -Raw
# Use multiline regex to match the widevine entry (non-versioned filename)
$widevineMatch = [regex]::Match($localManifest, '(?m)^DIST libwidevinecdm\.so .*$')
$widevineEntry = if ($widevineMatch.Success) { $widevineMatch.Value } else { $null }

# Append widevine entry to upstream manifest
if ($widevineEntry) {
    $manifestContent = $manifestContent.TrimEnd() + "`n" + $widevineEntry
}

$manifestContent | Set-Content -Path $localManifestPath

New-Item -Path "ChangesMade" | Out-Null
