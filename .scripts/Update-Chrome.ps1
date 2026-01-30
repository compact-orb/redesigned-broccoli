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

# Widevine CDM version - update this when new version is released
$widevineCdmVersion = "4.10.3029.0"

$srcUriAddition = @"
WIDEVINE_CDM_PV="$widevineCdmVersion"
SRC_URI="
	https://dl.google.com/linux/chrome/deb/pool/main/g/`${MY_PN}/`${MY_P}_amd64.deb
	https://github.com/nichdemos/widevine-chromeos/releases/download/v`${WIDEVINE_CDM_PV}/libwidevinecdm.so -> libwidevinecdm-`${WIDEVINE_CDM_PV}.so
"
"@

$wrapperCode = @"
src_install() {
    upstream_src_install

    einfo "Overwriting libwidevinecdm.so with custom version..."
    
    local target_dir="`${ED}/opt/google/chrome/WidevineCdm/_platform_specific/linux_x64"

    cp "`${DISTDIR}/libwidevinecdm-`${WIDEVINE_CDM_PV}.so" "`${target_dir}/libwidevinecdm.so" || die "Failed to copy custom libwidevinecdm.so"
}
"@

foreach ($ebuild in $newEbuilds) {
    Write-Output -InputObject "Processing $($ebuild.name)..."

    $content = Invoke-RestMethod -Uri $ebuild.download_url -Headers $headers

    # Replace src_install with upstream_src_install
    $patchedContent = $content -replace '(?m)^src_install\s*\(\)', 'upstream_src_install()'
    
    # Replace the SRC_URI line with our custom version that includes widevine
    $patchedContent = $patchedContent -replace '(?m)^SRC_URI=.*$', $srcUriAddition

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
$widevineEntry = $localManifest | Select-String -Pattern "^DIST libwidevinecdm-.*$" -AllMatches | ForEach-Object { $_.Matches.Value }

# Append widevine entry to upstream manifest
if ($widevineEntry) {
    $manifestContent = $manifestContent.TrimEnd() + "`n" + $widevineEntry + "`n"
}

$manifestContent | Set-Content -Path $localManifestPath

New-Item -Path "ChangesMade" | Out-Null
