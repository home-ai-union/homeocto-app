# Android Keystore Base64 编码脚本
# 用于将 keystore 文件转换为 Base64，以便配置到 GitHub Secrets

param(
    [Parameter(Mandatory=$true)]
    [string]$KeystorePath
)

# 检查文件是否存在
if (-not (Test-Path $KeystorePath)) {
    Write-Error "Keystore file not found: $KeystorePath"
    exit 1
}

Write-Host "Converting keystore to Base64..." -ForegroundColor Cyan
Write-Host "File: $KeystorePath" -ForegroundColor Cyan

try {
    # 读取文件并转换为 Base64
    $bytes = [IO.File]::ReadAllBytes($KeystorePath)
    $base64 = [Convert]::ToBase64String($bytes)
    
    # 保存到文件
    $outputFile = "keystore_base64.txt"
    $base64 | Out-File -Encoding ASCII $outputFile
    
    $fileSize = (Get-Item $KeystorePath).Length
    $outputSize = (Get-Item $outputFile).Length
    
    Write-Host "`n✅ Conversion successful!" -ForegroundColor Green
    Write-Host "Input file: $KeystorePath ($([math]::Round($fileSize/1KB, 2)) KB)" -ForegroundColor White
    Write-Host "Output file: $outputFile ($([math]::Round($outputSize/1KB, 2)) KB)" -ForegroundColor White
    Write-Host "`n📋 Next steps:" -ForegroundColor Yellow
    Write-Host "1. Copy the content from $outputFile" -ForegroundColor White
    Write-Host "2. Go to GitHub repository settings" -ForegroundColor White
    Write-Host "3. Navigate to: Settings > Secrets and variables > Actions" -ForegroundColor White
    Write-Host "4. Add new secret: ANDROID_KEYSTORE_BASE64" -ForegroundColor White
    Write-Host "5. Paste the Base64 content" -ForegroundColor White
    
} catch {
    Write-Error "Failed to convert keystore: $_"
    exit 1
}
