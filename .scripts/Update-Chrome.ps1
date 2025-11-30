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

$wrapperCode = @"
src_install() {
    upstream_src_install

    einfo "Overwriting libwidevinecdm.so with custom version..."
    
    local target_dir="`${ED}/opt/google/chrome/WidevineCdm/_platform_specific/linux_x64"

    cp "`${FILESDIR}/libwidevinecdm.so" "`${target_dir}/libwidevinecdm.so" || die "Failed to copy custom libwidevinecdm.so"
}
"@

foreach ($ebuild in $newEbuilds) {
    Write-Output -InputObject "Processing $($ebuild.name)..."

    $content = Invoke-RestMethod -Uri $ebuild.download_url -Headers $headers

    $patchedContent = $content -replace '(?m)^src_install\s*\(\)', 'upstream_src_install()'

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

$manifestPath = Join-Path -Path $localEbuildDir -ChildPath "Manifest"

$manifestContent | Set-Content -Path $manifestPath

New-Item -Path "ChangesMade" | Out-Null
