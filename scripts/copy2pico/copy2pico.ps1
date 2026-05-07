# Homeocto-App to Picoclaw-FUI Sync Script
# Uses Go to handle file copying with keyword replacement

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Homeocto-App -> Picoclaw-FUI Sync Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Define paths
$HomeoctoRoot = "G:\code\homeocto-app"
$PicoclawRoot = "G:\code\picoclaw_fui"

# Check if source directory exists
if (-not (Test-Path $HomeoctoRoot)) {
    Write-Host "Error: Source directory not found: $HomeoctoRoot" -ForegroundColor Red
    exit 1
}

# Check if target directory exists
if (-not (Test-Path $PicoclawRoot)) {
    Write-Host "Error: Target directory not found: $PicoclawRoot" -ForegroundColor Red
    exit 1
}

Write-Host "Source (homeocto-app): $HomeoctoRoot" -ForegroundColor Green
Write-Host "Target (picoclaw-fui): $PicoclawRoot" -ForegroundColor Green
Write-Host ""

# Confirm before proceeding
Write-Host "WARNING: This operation will copy files from homeocto-app to picoclaw-fui!" -ForegroundColor Yellow
Write-Host "The following replacements will be made:" -ForegroundColor Yellow
Write-Host "  - homeocto_app -> picoclaw_flutter_ui" -ForegroundColor Yellow
Write-Host "  - com.homeai.homeocto -> com.sipeed.picoclaw" -ForegroundColor Yellow
Write-Host "  - HomeOcto -> Picoclaw" -ForegroundColor Yellow
Write-Host "  - homeocto -> picoclaw" -ForegroundColor Yellow
Write-Host ""
Write-Host "NOTE: Image files will be extracted to docs/imgs/ directory" -ForegroundColor Cyan
Write-Host "      (You need to manually replace images in picoclaw-fui after sync)" -ForegroundColor Cyan
Write-Host ""

$confirm = Read-Host "Continue? (y/N)"

if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "Operation cancelled" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Starting sync..." -ForegroundColor Cyan
Write-Host ""

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Save current directory
$OriginalDir = Get-Location

# Change to script directory to use the correct go.mod
Set-Location $ScriptDir

# Run Go sync script
$goScript = Join-Path $ScriptDir "copy2pico.go"

Write-Host "Working directory: $ScriptDir" -ForegroundColor Gray
Write-Host "Executing: go run $goScript $HomeoctoRoot $PicoclawRoot" -ForegroundColor Gray
Write-Host ""

go run $goScript $HomeoctoRoot $PicoclawRoot

# Restore original directory
Set-Location $OriginalDir

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Sync Completed Successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Check picoclaw-fui project: cd G:\code\picoclaw_fui" -ForegroundColor White
    Write-Host "2. Verify copied files and replacements" -ForegroundColor White
    Write-Host "3. Handle image files from docs/imgs/ directory" -ForegroundColor White
    Write-Host "4. Run flutter pub get to update dependencies" -ForegroundColor White
    Write-Host "5. Build and test the application" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  Sync Failed!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    exit $LASTEXITCODE
}
