# Keystore 验证脚本
# 用于验证 keystore 文件和密码是否正确

param(
    [Parameter(Mandatory=$true)]
    [string]$KeystorePath,
    
    [Parameter(Mandatory=$true)]
    [string]$KeystorePassword,
    
    [Parameter(Mandatory=$true)]
    [string]$KeyAlias
)

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Keystore Verification Tool" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 检查 keytool 是否可用
try {
    $keytoolVersion = & keytool -help 2>&1
    Write-Host "[OK] keytool detected" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] keytool not found. Please install JDK." -ForegroundColor Red
    exit 1
}

# 验证 keystore 文件
if (-not (Test-Path $KeystorePath)) {
    Write-Host "[ERROR] Keystore file not found: $KeystorePath" -ForegroundColor Red
    exit 1
}

Write-Host "Keystore file: $KeystorePath" -ForegroundColor White
$fileSize = (Get-Item $KeystorePath).Length
Write-Host "File size: $([math]::Round($fileSize/1KB, 2)) KB" -ForegroundColor White
Write-Host ""

# 尝试列出 keystore 内容
Write-Host "Attempting to list keystore entries..." -ForegroundColor Cyan
Write-Host ""

$keytoolCmd = "keytool -list -keystore `"$KeystorePath`" -storepass `"$KeystorePassword`" -alias `"$KeyAlias`" -v"

try {
    $output = Invoke-Expression $keytoolCmd 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Keystore verification passed!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Key details:" -ForegroundColor Yellow
        Write-Host "  Alias: $KeyAlias" -ForegroundColor White
        Write-Host "  Keystore password: $KeystorePassword" -ForegroundColor White
        Write-Host ""
        Write-Host "Certificate information:" -ForegroundColor Yellow
        
        # 提取关键信息
        $output | Select-String "Owner:|Issuer:|Serial number:|Valid from:|Until:" | ForEach-Object {
            Write-Host "  $_" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Green
        Write-Host "  Verification completed successfully!" -ForegroundColor Green
        Write-Host "==========================================" -ForegroundColor Green
    } else {
        Write-Host "[FAILED] Keystore verification failed!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Error output:" -ForegroundColor Yellow
        $output | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        Write-Host ""
        Write-Host "Possible causes:" -ForegroundColor Yellow
        Write-Host "  1. Incorrect keystore password" -ForegroundColor White
        Write-Host "  2. Incorrect key alias" -ForegroundColor White
        Write-Host "  3. Corrupted keystore file" -ForegroundColor White
    }
} catch {
    Write-Host "[ERROR] Exception occurred: $_" -ForegroundColor Red
}

Write-Host ""
pause
