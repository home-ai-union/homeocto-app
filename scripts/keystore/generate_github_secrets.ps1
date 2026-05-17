# 生成 GitHub Secrets 配置信息
# 用于直接复制粘贴到 GitHub

$keystorePath = "G:\bak\android\release.jks"

if (-not (Test-Path $keystorePath)) {
    Write-Host "[ERROR] Keystore not found: $keystorePath" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  GitHub Secrets Configuration" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 读取 Base64
$base64 = Get-Content "g:\code\homeocto-app\keystore_base64.txt" -Raw
$base64 = $base64.Trim()

Write-Host "Please copy the following values to GitHub Secrets:" -ForegroundColor Yellow
Write-Host ""

Write-Host "1. ANDROID_KEYSTORE_BASE64" -ForegroundColor Green
Write-Host "(Copy the ENTIRE content below, make sure NO extra spaces or newlines)" -ForegroundColor Yellow
Write-Host "─" * 80 -ForegroundColor Gray
Write-Host $base64 -ForegroundColor White
Write-Host "─" * 80 -ForegroundColor Gray
Write-Host ""
Write-Host "[INFO] Base64 length: $($base64.Length) characters" -ForegroundColor Cyan
Write-Host ""

Write-Host "2. ANDROID_KEYSTORE_PASSWORD" -ForegroundColor Green
Write-Host "─" * 80 -ForegroundColor Gray
Write-Host "XxkfZymrMKC8T7Y3" -ForegroundColor White
Write-Host "─" * 80 -ForegroundColor Gray
Write-Host ""

Write-Host "3. ANDROID_KEY_ALIAS" -ForegroundColor Green
Write-Host "─" * 80 -ForegroundColor Gray
Write-Host "homeocto_release" -ForegroundColor White
Write-Host "─" * 80 -ForegroundColor Gray
Write-Host ""

Write-Host "4. ANDROID_KEY_PASSWORD" -ForegroundColor Green
Write-Host "─" * 80 -ForegroundColor Gray
Write-Host "bHB4qX6FmMKs01jn" -ForegroundColor White
Write-Host "─" * 80 -ForegroundColor Gray
Write-Host ""

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Important Notes" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "When copying to GitHub:" -ForegroundColor Yellow
Write-Host "  - Copy ONLY the value (no spaces before/after)" -ForegroundColor White
Write-Host "  - Ensure it's a SINGLE LINE (no line breaks)" -ForegroundColor White
Write-Host "  - For ANDROID_KEYSTORE_BASE64, select ALL 3708 characters" -ForegroundColor White
Write-Host ""

Write-Host "GitHub Path:" -ForegroundColor Yellow
Write-Host "  Settings > Secrets and variables > Actions > New repository secret" -ForegroundColor White
Write-Host ""

pause
