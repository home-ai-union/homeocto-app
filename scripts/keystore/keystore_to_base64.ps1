# Keystore to Base64 Converter - PowerShell Wrapper
# This script calls the Go utility to convert Android Keystore to Base64

param(
    [Parameter(Mandatory=$true, HelpMessage="Path to the Android Keystore file (.jks or .keystore)")]
    [string]$KeystorePath,
    
    [Parameter(Mandatory=$false, HelpMessage="Output file path for Base64 content (default: keystore_base64.txt)")]
    [string]$OutputFile
)

# Display header
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Android Keystore to Base64 Converter" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Go is installed
try {
    $goVersion = go version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Go not found"
    }
    Write-Host "[OK] Go detected: $goVersion" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Go is not installed or not in PATH" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Go from: https://golang.org/dl/" -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}

# Validate keystore file exists
if (-not (Test-Path $KeystorePath)) {
    Write-Host "[ERROR] Keystore file not found: $KeystorePath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please check the file path and try again." -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}

# Validate file extension
$extension = [System.IO.Path]::GetExtension($KeystorePath).ToLower()
if ($extension -ne ".jks" -and $extension -ne ".keystore") {
    Write-Host "[WARN] File extension '$extension' is not typical for keystore files" -ForegroundColor Yellow
    Write-Host "  Expected: .jks or .keystore" -ForegroundColor Yellow
    Write-Host ""
}

# Get the script directory and build Go script path
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$goScriptPath = Join-Path $scriptDir "keystore_to_base64.go"

# Verify Go script exists
if (-not (Test-Path $goScriptPath)) {
    Write-Host "[ERROR] Go script not found: $goScriptPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure keystore_to_base64.go is in the same directory." -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}

Write-Host "Input file: $KeystorePath" -ForegroundColor White
if ($OutputFile) {
    Write-Host "Output file: $OutputFile" -ForegroundColor White
} else {
    Write-Host "Output file: keystore_base64.txt (default)" -ForegroundColor White
}
Write-Host ""
Write-Host "Running Go utility..." -ForegroundColor Cyan
Write-Host ""

# Execute the Go script
if ($OutputFile) {
    & go run $goScriptPath $KeystorePath $OutputFile
} else {
    & go run $goScriptPath $KeystorePath
}

# Check if Go script executed successfully
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[ERROR] Failed to convert keystore" -ForegroundColor Red
    Write-Host ""
    pause
    exit 1
}

# Display success message
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  [SUCCESS] Conversion completed!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

# Display next steps
Write-Host "[INFO] Next Steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Copy the Base64 content from the output file" -ForegroundColor White
Write-Host "2. Go to your GitHub repository" -ForegroundColor White
Write-Host "3. Navigate to: Settings > Secrets and variables > Actions" -ForegroundColor White
Write-Host "4. Add these secrets:" -ForegroundColor White
Write-Host "   - ANDROID_KEYSTORE_BASE64  (the Base64 content)" -ForegroundColor Cyan
Write-Host "   - ANDROID_KEYSTORE_PASSWORD (your keystore password)" -ForegroundColor Cyan
Write-Host "   - ANDROID_KEY_ALIAS        (your key alias)" -ForegroundColor Cyan
Write-Host "   - ANDROID_KEY_PASSWORD     (your key password)" -ForegroundColor Cyan
Write-Host ""
Write-Host "[SECURITY] Reminder:" -ForegroundColor Yellow
Write-Host "   Never commit keystore files or Base64 content to version control!" -ForegroundColor Yellow
Write-Host ""

pause
