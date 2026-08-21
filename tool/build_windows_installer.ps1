# PowerShell Build Script for ShopFlow POS Windows Installer
# Usage: .\tool\build_windows_installer.ps1

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Building ShopFlow POS for Windows...  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. Read app version from pubspec.yaml
$pubspecVersion = (Select-String -Path "pubspec.yaml" -Pattern '^version:\s*([^+\s]+)' | Select-Object -First 1).Matches.Groups[1].Value
$pubspecFullVersion = (Select-String -Path "pubspec.yaml" -Pattern '^version:\s*(\S+)' | Select-Object -First 1).Matches.Groups[1].Value
if (-not $pubspecVersion) {
    Write-Error "Could not read the app version from pubspec.yaml."
    exit 1
}
Write-Host "Target App Version: $pubspecFullVersion (Base: $pubspecVersion)" -ForegroundColor White

# 2. Build Flutter Release for Windows (Cleaning old runner output to ensure version sync)
Write-Host "`n[1/4] Building Flutter Windows Release..." -ForegroundColor Yellow

# Remove backend directories left by older builds. Backend files are packaged
# directly into the ProgramData backend directory and must not remain beside
# the frontend executable.
$frontendBuildDir = "build\windows\x64\runner"
foreach ($staleDirName in @("pb_data", "pb_hooks", "pb_migrations")) {
    $staleDir = Join-Path $frontendBuildDir $staleDirName
    if (Test-Path -LiteralPath $staleDir) {
        Remove-Item -LiteralPath $staleDir -Recurse -Force
        Write-Host "Removed stale frontend backend directory: $staleDir" -ForegroundColor DarkGray
    }
}

flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter build failed!"
    exit $LASTEXITCODE
}
Write-Host "Flutter release build completed successfully." -ForegroundColor Green

# 3. Verify compiled executable ProductVersion
Write-Host "`n[2/4] Verifying Compiled Binary Version..." -ForegroundColor Yellow
$compiledExe = "build\windows\x64\runner\pos_system.exe"
if (-not (Test-Path $compiledExe)) {
    Write-Error "Compiled executable not found at $compiledExe"
    exit 1
}

$exeVersion = (Get-Item $compiledExe).VersionInfo.ProductVersion
Write-Host "Compiled binary ProductVersion: $exeVersion" -ForegroundColor White

if (-not $exeVersion.StartsWith($pubspecVersion)) {
    Write-Error "Binary ProductVersion ($exeVersion) does not match pubspec version ($pubspecVersion)! Packaging aborted to prevent stale release."
    exit 1
}
Write-Host "Binary version verified successfully against pubspec.yaml." -ForegroundColor Green

# 4. Locate Inno Setup Compiler (ISCC.exe)
Write-Host "`n[3/4] Searching for Inno Setup Compiler (iscc.exe)..." -ForegroundColor Yellow

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
    exit 0
}

Write-Host "Found Inno Setup Compiler at: $isccPath" -ForegroundColor Green

# 5. Compile Inno Setup Script
Write-Host "`n[4/4] Generating Setup.exe Installer..." -ForegroundColor Yellow
& "$isccPath" "/DMyAppVersion=$pubspecVersion" "windows\installer.iss"

if ($LASTEXITCODE -eq 0) {
    $installerPath = "build\windows\installer\ShopFlow_POS_Setup_v$pubspecVersion.exe"
    if (-not (Test-Path $installerPath)) {
        Write-Error "Installer file was not found after compilation at: $installerPath"
        exit 1
    }
    $installerSize = (Get-Item $installerPath).Length / 1MB
    $installerHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash

    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host " BUILD & PACKAGING SUCCESSFUL!          " -ForegroundColor Green
    Write-Host " Installer created at:                 " -ForegroundColor Green
    Write-Host " $installerPath" -ForegroundColor Cyan
    Write-Host " Size:   $([math]::Round($installerSize, 2)) MB" -ForegroundColor White
    Write-Host " SHA256: $installerHash" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Green
} else {
    Write-Error "Inno Setup compilation failed!"
}
