# --- Authentication for GitHub API ---
$githubPAT = $env:GITHUB_PAT_ValidateBCAppSourceApps
if (-not $githubPAT) {
    Write-Host "GitHub Personal Access Token (PAT) not found in environment variable GITHUB_PAT_ValidateBCAppSourceApps."
    Write-Host "Please set it before running the script: `$env:GITHUB_PAT_ValidateBCAppSourceApps = 'your-pat-here'"
    exit 1
}

# Create authentication headers
$authHeaders = @{
    Authorization = "Bearer $githubPAT"
    Accept = "application/vnd.github.v3+json"
}

# --- Try to get the latest release directly ---
$repoOwner = "9altitudes"
$repoName = "GTM-BC-9AAdvMan-ProjectBased"
$apiUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases/latest"

try {
    $latestRelease = Invoke-RestMethod -Uri $apiUrl -Headers $authHeaders
    $releaseTag = $latestRelease.tag_name
    Write-Host "Found latest release tag: $releaseTag"
} catch {
    Write-Host "Failed to get latest release. Error: $_"
    Write-Host "Unable to proceed without a valid release."
    exit 1
}

# --- Find the correct asset in the release ---
$asset = $latestRelease.assets | Where-Object { $_.name -like "*Apps*.zip" } | Select-Object -First 1
if (-not $asset) {
    Write-Host "No Apps zip asset found in the latest release."
    exit 1
}

$assetApiUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases/assets/$($asset.id)"
$tempZipPath = Join-Path $env:TEMP $asset.name

# Use Accept: application/octet-stream for asset download
$downloadHeaders = @{
    Authorization = "Bearer $githubPAT"
    Accept = "application/octet-stream"
}

try {
    Invoke-WebRequest -Uri $assetApiUrl -OutFile $tempZipPath -Headers $downloadHeaders
} catch {
    Write-Host "Failed to download asset from $assetApiUrl. Error: $_"
    exit 1
}

# Extract the zip to a temp folder
$tempExtractPath = Join-Path $env:TEMP ([System.IO.Path]::GetFileNameWithoutExtension([System.IO.Path]::GetRandomFileName()))
Expand-Archive -Path $tempZipPath -DestinationPath $tempExtractPath -Force

# Find the .app file with the highest version number in the extracted folder
$appFiles = Get-ChildItem -Path $tempExtractPath -Filter '*.app'
if (-not $appFiles) {
    throw "No .app files found in extracted Apps zip."
}
$previousAppPath = $appFiles | Sort-Object {
    if ($_ -match '_(\d+\.\d+\.\d+\.\d+)\.app$') {
        [Version]$matches[1]
    } else {
        [Version]'0.0.0.0'
    }
} -Descending | Select-Object -First 1 | Select-Object -ExpandProperty FullName

# --- Download dependency app from GTM-BC-9AAdvMan-License ---
$depRepoOwner = "9altitudes"
$depRepoName = "GTM-BC-9AAdvMan-License"
$depApiUrl = "https://api.github.com/repos/$depRepoOwner/$depRepoName/releases/latest"

try {
    $depRelease = Invoke-RestMethod -Uri $depApiUrl -Headers $authHeaders
    Write-Host "Found dependency release tag: $($depRelease.tag_name)"
} catch {
    Write-Host "Failed to get dependency release. Error: $_"
    exit 1
}

# Find the .app or .zip asset
$depAsset = $depRelease.assets | Where-Object { $_.name -like "*.app" -or $_.name -like "*.zip" } | Select-Object -First 1
if (-not $depAsset) {
    Write-Host "No .app or .zip asset found in the dependency release."
    exit 1
}

$depAssetApiUrl = "https://api.github.com/repos/$depRepoOwner/$depRepoName/releases/assets/$($depAsset.id)"
$depTempPath = Join-Path $env:TEMP $depAsset.name

$depDownloadHeaders = @{
    Authorization = "Bearer $githubPAT"
    Accept = if ($depAsset.name -like "*.app") { "application/octet-stream" } else { "application/octet-stream" }
}

try {
    Invoke-WebRequest -Uri $depAssetApiUrl -OutFile $depTempPath -Headers $depDownloadHeaders
} catch {
    Write-Host "Failed to download dependency asset from $depAssetApiUrl. Error: $_"
    exit 1
}

# If the asset is a zip, extract the .app file
if ($depAsset.name -like "*.zip") {
    $depExtractPath = Join-Path $env:TEMP ([System.IO.Path]::GetFileNameWithoutExtension([System.IO.Path]::GetRandomFileName()))
    Expand-Archive -Path $depTempPath -DestinationPath $depExtractPath -Force
    $depAppFiles = Get-ChildItem -Path $depExtractPath -Filter '*.app'
    if (-not $depAppFiles) {
        throw "No .app files found in extracted dependency zip."
    }
    $depAppPath = $depAppFiles | Sort-Object {
        if ($_ -match '_(\d+\.\d+\.\d+\.\d+)\.app$') {
            [Version]$matches[1]
        } else {
            [Version]'0.0.0.0'
        }
    } -Descending | Select-Object -First 1 | Select-Object -ExpandProperty FullName
} else {
    $depAppPath = $depTempPath
}

# --- Find current app with highest version number ---
if ([string]::IsNullOrEmpty($PSScriptRoot)) {
    $appFolder = Get-Location
} else {
    $appFolder = Split-Path -Path $PSScriptRoot -Parent
}

# List all .app files and filter for both hyphen and en dash variants
$appFilesAll = Get-ChildItem -Path $appFolder -Filter '*.app'
$pattern1 = '9altitudes_9A Advanced Manufacturing - Project Based_*.app'
$pattern2 = '9altitudes_9A Advanced Manufacturing – Project Based_*.app'
$files = $appFilesAll | Where-Object {
    $_.Name -like $pattern1 -or $_.Name -like $pattern2
}

if (-not $files) {
    throw "No current app files found matching pattern: $pattern1 or $pattern2"
}

$appPath = $files | Sort-Object {
    if ($_ -match '_(\d+\.\d+\.\d+\.\d+)\.app$') {
        [Version]$matches[1]
    } else {
        [Version]'0.0.0.0'
    }
} -Descending | Select-Object -First 1 | Select-Object -ExpandProperty FullName

Run-AlValidation `
    -previousApps $previousAppPath `
    -apps $appPath `
    -installApps $depAppPath `
    -affixes "NALJP " `
    -countries dk `
    -containerName "alvalidate" `
    -skipVerification

