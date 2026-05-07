# Picoclaw-FUI to Homeocto-App Migration Script
# Uses Go to handle file replacement to avoid Chinese character encoding issues

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Picoclaw-FUI -> Homeocto-App Migration Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Define paths
$PicoclawRoot = "G:\code\picoclaw-fui"
$HomeoctoRoot = "G:\code\homeocto-app"

# Check if source directory exists
if (-not (Test-Path $PicoclawRoot)) {
    Write-Host "Error: Source directory not found: $PicoclawRoot" -ForegroundColor Red
    exit 1
}

# Check if target directory exists
if (-not (Test-Path $HomeoctoRoot)) {
    Write-Host "Error: Target directory not found: $HomeoctoRoot" -ForegroundColor Red
    exit 1
}

Write-Host "Source (picoclaw-fui): $PicoclawRoot" -ForegroundColor Green
Write-Host "Target (homeocto-app): $HomeoctoRoot" -ForegroundColor Green
Write-Host ""

# Confirm before proceeding
Write-Host "WARNING: This operation will overwrite files in the target directory!" -ForegroundColor Yellow
Write-Host "The following directories and files will be replaced:" -ForegroundColor Yellow
Write-Host "  - android, ios, linux, macos, lib, test, tools, web, windows" -ForegroundColor Yellow
Write-Host "  - analysis_options.yaml, devtools_options.yaml, l10n.yaml, pubspec.yaml" -ForegroundColor Yellow
Write-Host ""
$confirm = Read-Host "Continue? (y/N)"

if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "Operation cancelled" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Starting migration..." -ForegroundColor Cyan
Write-Host ""

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Save current directory
$OriginalDir = Get-Location

# Change to script directory to use the correct go.mod
Set-Location $ScriptDir

# Run Go migration script
$goScript = Join-Path $ScriptDir "migrate-picoclaw-fui.go"

Write-Host "Working directory: $ScriptDir" -ForegroundColor Gray
Write-Host "Executing: go run $goScript $PicoclawRoot $HomeoctoRoot" -ForegroundColor Gray
Write-Host ""

go run $goScript $PicoclawRoot $HomeoctoRoot

# Restore original directory
Set-Location $OriginalDir

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Migration Completed Successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Run: flutter pub get" -ForegroundColor White
    Write-Host "2. Check for remaining keywords: Select-String -Path '**/*.dart' -Pattern 'picoclaw' -CaseSensitive" -ForegroundColor White
    Write-Host "3. Verify Chinese comments display correctly" -ForegroundColor White
    Write-Host "4. Run: flutter analyze" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  Migration Failed!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    exit $LASTEXITCODE
}
