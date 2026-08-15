# PowerShell Build Script for ShopFlow POS Windows Installer
# Usage: .\tool\build_windows_installer.ps1

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Building ShopFlow POS for Windows...  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. Build Flutter Release for Windows
Write-Host "`n[1/3] Running Flutter Release Build..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter build failed!"
    exit $LASTEXITCODE
}
Write-Host "Flutter release build completed successfully." -ForegroundColor Green

# 2. Locate Inno Setup Compiler (ISCC.exe)
Write-Host "`n[2/3] Searching for Inno Setup Compiler (iscc.exe)..." -ForegroundColor Yellow

$isccPath = (Get-Command iscc -ErrorAction SilentlyContinue).Path

if (-not $isccPath) {
    $possiblePaths = @(
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe",
        "${env:LocalAppData}\Programs\Inno Setup 6\ISCC.exe"
    )
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $isccPath = $path
            break
        }
    }
}

if (-not $isccPath) {
    Write-Host "`n[WARNING] Inno Setup (ISCC.exe) was not found on your system." -ForegroundColor Yellow
    Write-Host "To automatically create the Setup.exe installer:" -ForegroundColor White
    Write-Host "1. Download and install Inno Setup 6 from: https://jrsoftware.org/isdl.php" -ForegroundColor Cyan
    Write-Host "   OR run: winget install JRSoftware.InnoSetup" -ForegroundColor Cyan
    Write-Host "2. Re-run this script after installing.`n" -ForegroundColor White
    Write-Host "Your compiled raw app files are located at: build\windows\x64\runner\Release\" -ForegroundColor Green
    exit 0
}

Write-Host "Found Inno Setup Compiler at: $isccPath" -ForegroundColor Green

# 3. Compile Inno Setup Script
Write-Host "`n[3/3] Generating Setup.exe Installer..." -ForegroundColor Yellow
$pubspecVersion = (Select-String -Path "pubspec.yaml" -Pattern '^version:\s*([^+\s]+)' | Select-Object -First 1).Matches.Groups[1].Value
if (-not $pubspecVersion) {
    Write-Error "Could not read the app version from pubspec.yaml."
    exit 1
}
Write-Host "Using installer version: $pubspecVersion" -ForegroundColor White
& "$isccPath" "/DMyAppVersion=$pubspecVersion" "windows\installer.iss"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host " BUILD SUCCESSFUL!                      " -ForegroundColor Green
    Write-Host " Installer created at:                 " -ForegroundColor Green
    Write-Host " build\windows\installer\ShopFlow_POS_Setup_v$pubspecVersion.exe" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Green
} else {
    Write-Error "Inno Setup compilation failed!"
}
