# Script to verify installer contents
# Verify that all required files are included in the Windows installer

$ErrorActionPreference = "Continue"

$releaseDir = "build\windows\x64\runner\Release"
$installerDir = "installer"

Write-Host ""
Write-Host "========================================="
Write-Host "Sanad Windows Installer Verification"
Write-Host "========================================="
Write-Host ""

# Check if release build exists
if (-not (Test-Path $releaseDir)) {
    Write-Host "ERROR: Release build not found at $releaseDir" -ForegroundColor Red
    Write-Host "Please run: fvm flutter build windows --release" -ForegroundColor Yellow
    exit 1
}

$checksPassed = 0
$checksFailed = 0

# Function to check file
function Check-File {
    param($path, $name)
    if (Test-Path $path) {
        $size = (Get-Item $path).Length / 1MB
        Write-Host "[OK] $name ($([Math]::Round($size, 2)) MB)" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "[FAIL] $name - NOT FOUND" -ForegroundColor Red
        return $false
    }
}

# Function to check directory
function Check-Directory {
    param($path, $name)
    if (Test-Path $path) {
        Write-Host "[OK] $name (Directory exists)" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "[FAIL] $name - NOT FOUND" -ForegroundColor Red
        return $false
    }
}

Write-Host "1. Checking Main Executable:" -ForegroundColor Cyan
if (Check-File "$releaseDir\sanad-client.exe" "sanad-client.exe") { $checksPassed++ } else { $checksFailed++ }

Write-Host ""
Write-Host "2. Checking Flutter Runtime:" -ForegroundColor Cyan
if (Check-File "$releaseDir\flutter_windows.dll" "flutter_windows.dll") { $checksPassed++ } else { $checksFailed++ }

Write-Host ""
Write-Host "3. Checking Plugin DLLs:" -ForegroundColor Cyan
$pluginDlls = @(
    "window_manager_plugin.dll",
    "screen_capturer_windows_plugin.dll",
    "screen_retriever_windows_plugin.dll",
    "url_launcher_windows_plugin.dll",
    "connectivity_plus_plugin.dll",
    "bixat_key_mouse.dll"
)

foreach ($dll in $pluginDlls) {
    if (Check-File "$releaseDir\$dll" $dll) { $checksPassed++ } else { $checksFailed++ }
}

Write-Host ""
Write-Host "4. Checking Data Directory:" -ForegroundColor Cyan
if (Check-Directory "$releaseDir\data" "data folder") { $checksPassed++ } else { $checksFailed++ }

Write-Host ""
Write-Host "5. Checking Critical Data Files:" -ForegroundColor Cyan
if (Check-File "$releaseDir\data\icudtl.dat" "icudtl.dat (Unicode)") { $checksPassed++ } else { $checksFailed++ }
if (Check-File "$releaseDir\data\app.so" "app.so (Dart Engine)") { $checksPassed++ } else { $checksFailed++ }

Write-Host ""
Write-Host "6. Checking Flutter Assets:" -ForegroundColor Cyan
if (Check-Directory "$releaseDir\data\flutter_assets" "flutter_assets") { $checksPassed++ } else { $checksFailed++ }
if (Check-File "$releaseDir\data\flutter_assets\.env" ".env (Configuration)") { $checksPassed++ } else { $checksFailed++ }
if (Check-File "$releaseDir\data\flutter_assets\AssetManifest.bin" "AssetManifest.bin") { $checksPassed++ } else { $checksFailed++ }

Write-Host ""
Write-Host "7. Checking Assets Folder:" -ForegroundColor Cyan
$assetsDir = "$releaseDir\data\flutter_assets\assets"
if (Test-Path $assetsDir) {
    $assetFiles = (Get-ChildItem $assetsDir -Recurse).Count
    if ($assetFiles -gt 0) {
        Write-Host "[OK] assets folder ($assetFiles files)" -ForegroundColor Green
        $checksPassed++
    }
    else {
        Write-Host "[FAIL] No assets found" -ForegroundColor Red
        $checksFailed++
    }
}
else {
    Write-Host "[FAIL] assets folder - NOT FOUND" -ForegroundColor Red
    $checksFailed++
}

Write-Host ""
Write-Host "8. Checking Fonts:" -ForegroundColor Cyan
$fontsDir = "$releaseDir\data\flutter_assets\fonts"
if (Test-Path $fontsDir) {
    $fontFiles = (Get-ChildItem $fontsDir -Recurse).Count
    Write-Host "[OK] fonts folder ($fontFiles font files)" -ForegroundColor Green
    $checksPassed++
}
else {
    Write-Host "[WARN] fonts folder not found (optional)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "9. Checking Installer Scripts:" -ForegroundColor Cyan
if (Check-File "$installerDir\sanad_client_installer.nsi" "sanad_client_installer.nsi") { $checksPassed++ } else { $checksFailed++ }
if (Check-File "$installerDir\sanad_client_installer.iss" "sanad_client_installer.iss") { $checksPassed++ } else { $checksFailed++ }

Write-Host ""
Write-Host "========================================="
Write-Host "Verification Results:" -ForegroundColor Cyan
Write-Host "========================================="
Write-Host ""
Write-Host "Total Checks: $($checksPassed + $checksFailed)" -ForegroundColor White
Write-Host "[PASSED] $checksPassed" -ForegroundColor Green
Write-Host "[FAILED] $checksFailed" -ForegroundColor Red

Write-Host ""

if ($checksFailed -eq 0) {
    Write-Host "SUCCESS: All required files are present!" -ForegroundColor Green
    Write-Host ""
    Write-Host "The installer is ready for distribution." -ForegroundColor Green
    Write-Host "File: installer\sanad-client-setup.exe" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "FAILURE: Some required files are missing!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please rebuild the Windows application:" -ForegroundColor Yellow
    Write-Host "  fvm flutter build windows --release" -ForegroundColor Yellow
    exit 1
}
