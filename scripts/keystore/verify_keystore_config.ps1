# Verify Keystore Configuration Script
# This script helps verify your keystore file and credentials before configuring GitHub Secrets

param(
    [Parameter(Mandatory=$true)]
    [string]$KeystorePath,
    
    [Parameter(Mandatory=$true)]
    [string]$KeystorePassword,
    
    [Parameter(Mandatory=$true)]
    [string]$KeyAlias,
    
    [Parameter(Mandatory=$true)]
    [string]$KeyPassword
)

# Colors for output
$ErrorColor = "Red"
$SuccessColor = "Green"
$InfoColor = "Cyan"
$WarningColor = "Yellow"

Write-Host "`n========================================" -ForegroundColor $InfoColor
Write-Host "  Keystore Configuration Verifier" -ForegroundColor $InfoColor
Write-Host "========================================`n" -ForegroundColor $InfoColor

# Check if keystore file exists
if (-not (Test-Path $KeystorePath)) {
    Write-Host "[ERROR] Keystore file not found: $KeystorePath" -ForegroundColor $ErrorColor
    exit 1
}

Write-Host "[INFO] Keystore file found: $KeystorePath" -ForegroundColor $SuccessColor

# 1. Calculate MD5 of the keystore file
Write-Host "`n[1] Calculating MD5 hash of keystore file..." -ForegroundColor $InfoColor
$keystoreBytes = [System.IO.File]::ReadAllBytes($KeystorePath)
$md5 = [System.Security.Cryptography.MD5]::Create()
$md5Hash = $md5.ComputeHash($keystoreBytes)
$md5String = [System.BitConverter]::ToString($md5Hash) -replace '-', ''
Write-Host "    MD5: $md5String" -ForegroundColor $SuccessColor

# 2. Calculate Base64 of the keystore file
Write-Host "`n[2] Generating Base64 encoding..." -ForegroundColor $InfoColor
$base64String = [Convert]::ToBase64String($keystoreBytes)
$base64Md5 = [System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($base64String))
$base64Md5String = [System.BitConverter]::ToString($base64Md5) -replace '-', ''
Write-Host "    Base64 length: $($base64String.Length) characters" -ForegroundColor $SuccessColor
Write-Host "    Base64 MD5: $base64Md5String" -ForegroundColor $SuccessColor
Write-Host "`n    [TIP] Use this Base64 string for ANDROID_KEYSTORE_BASE64 secret" -ForegroundColor $WarningColor
Write-Host "    First 50 chars: $($base64String.Substring(0, [Math]::Min(50, $base64String.Length)))..." -ForegroundColor $InfoColor

# 3. Calculate MD5 of passwords
Write-Host "`n[3] Calculating MD5 hashes of credentials..." -ForegroundColor $InfoColor

$keystorePassMd5 = [System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($KeystorePassword))
$keystorePassMd5String = [System.BitConverter]::ToString($keystorePassMd5) -replace '-', ''
Write-Host "    Keystore Password MD5: $keystorePassMd5String" -ForegroundColor $SuccessColor

$keyAliasMd5 = [System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($KeyAlias))
$keyAliasMd5String = [System.BitConverter]::ToString($keyAliasMd5) -replace '-', ''
Write-Host "    Key Alias MD5: $keyAliasMd5String" -ForegroundColor $SuccessColor

$keyPassMd5 = [System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($KeyPassword))
$keyPassMd5String = [System.BitConverter]::ToString($keyPassMd5) -replace '-', ''
Write-Host "    Key Password MD5: $keyPassMd5String" -ForegroundColor $SuccessColor

# 4. Verify keystore can be loaded
Write-Host "`n[4] Verifying keystore can be loaded..." -ForegroundColor $InfoColor

try {
    # Check if keytool is available
    $keytoolResult = Get-Command keytool -ErrorAction SilentlyContinue
    if (-not $keytoolResult) {
        Write-Host "    [WARNING] keytool not found in PATH" -ForegroundColor $WarningColor
        Write-Host "    Please ensure JDK is installed and JAVA_HOME/bin is in PATH" -ForegroundColor $WarningColor
    } else {
        # Use keytool to verify keystore
        $tempOutput = [System.IO.Path]::GetTempFileName()
        $keytoolArgs = @(
            '-list',
            '-v',
            '-keystore', $KeystorePath,
            '-storepass', $KeystorePassword,
            '-alias', $KeyAlias,
            '-keypass', $KeyPassword
        )
        
        $process = Start-Process -FilePath "keytool" `
            -ArgumentList $keytoolArgs `
            -RedirectStandardOutput $tempOutput `
            -RedirectStandardError "$tempOutput.err" `
            -NoNewWindow `
            -Wait `
            -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-Host "    [OK] Keystore loaded successfully!" -ForegroundColor $SuccessColor
            
            # Show certificate info
            $certInfo = Get-Content $tempOutput
            $cnLine = $certInfo | Select-String "Owner:" | Select-Object -First 1
            if ($cnLine) {
                Write-Host "    Certificate Owner: $($cnLine.Line)" -ForegroundColor $InfoColor
            }
            
            $validFrom = $certInfo | Select-String "Valid from:" | Select-Object -First 1
            if ($validFrom) {
                Write-Host "    $validFrom" -ForegroundColor $InfoColor
            }
        } else {
            Write-Host "    [ERROR] Failed to load keystore" -ForegroundColor $ErrorColor
            $errorContent = Get-Content "$tempOutput.err" -ErrorAction SilentlyContinue
            if ($errorContent) {
                Write-Host "    Error details: $($errorContent -join ' ')" -ForegroundColor $ErrorColor
            }
        }
        
        # Cleanup temp files
        Remove-Item $tempOutput -ErrorAction SilentlyContinue
        Remove-Item "$tempOutput.err" -ErrorAction SilentlyContinue
    }
} catch {
    Write-Host "    [ERROR] Exception during verification: $_" -ForegroundColor $ErrorColor
}

# 5. Check PKCS12 password consistency
Write-Host "`n[5] Checking PKCS12 password consistency..." -ForegroundColor $InfoColor
if ($KeystorePassword -ne $KeyPassword) {
    Write-Host "    [WARNING] Keystore password and Key password are DIFFERENT!" -ForegroundColor $WarningColor
    Write-Host "    If using PKCS12 format, they MUST be the same" -ForegroundColor $WarningColor
    Write-Host "    This may cause 'Given final block not properly padded' error during signing" -ForegroundColor $WarningColor
} else {
    Write-Host "    [OK] Keystore password and Key password are the same" -ForegroundColor $SuccessColor
}

# 6. Summary for GitHub Secrets
Write-Host "`n========================================" -ForegroundColor $InfoColor
Write-Host "  GitHub Secrets Configuration" -ForegroundColor $InfoColor
Write-Host "========================================`n" -ForegroundColor $InfoColor

Write-Host "Please configure the following secrets in your GitHub repository:" -ForegroundColor $InfoColor
Write-Host "Settings → Secrets and variables → Actions → New repository secret`n" -ForegroundColor $InfoColor

Write-Host "Secret Name: ANDROID_KEYSTORE_BASE64" -ForegroundColor $SuccessColor
Write-Host "Value: (The Base64 string generated above)" -ForegroundColor $InfoColor
Write-Host "Base64 MD5: $base64Md5String`n" -ForegroundColor $SuccessColor

Write-Host "Secret Name: ANDROID_KEYSTORE_PASSWORD" -ForegroundColor $SuccessColor
Write-Host "MD5: $keystorePassMd5String`n" -ForegroundColor $SuccessColor

Write-Host "Secret Name: ANDROID_KEY_ALIAS" -ForegroundColor $SuccessColor
Write-Host "Value: $KeyAlias" -ForegroundColor $InfoColor
Write-Host "MD5: $keyAliasMd5String`n" -ForegroundColor $SuccessColor

Write-Host "Secret Name: ANDROID_KEY_PASSWORD" -ForegroundColor $SuccessColor
Write-Host "MD5: $keyPassMd5String`n" -ForegroundColor $SuccessColor

Write-Host "========================================" -ForegroundColor $InfoColor
Write-Host "  Verification Complete" -ForegroundColor $InfoColor
Write-Host "========================================`n" -ForegroundColor $InfoColor

# Generate a verification file
$reportPath = "keystore_verification_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$report = @"
Keystore Verification Report
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

File: $KeystorePath
MD5: $md5String
Base64 MD5: $base64Md5String

Credentials MD5 Hashes:
- Keystore Password: $keystorePassMd5String
- Key Alias: $keyAliasMd5String
- Key Password: $keyPassMd5String

PKCS12 Password Consistency: $(if ($KeystorePassword -eq $KeyPassword) {"OK - Same"} else {"WARNING - Different"})

GitHub Secrets to Configure:
1. ANDROID_KEYSTORE_BASE64 (Base64 MD5: $base64Md5String)
2. ANDROID_KEYSTORE_PASSWORD (MD5: $keystorePassMd5String)
3. ANDROID_KEY_ALIAS (MD5: $keyAliasMd5String)
4. ANDROID_KEY_PASSWORD (MD5: $keyPassMd5String)
"@

$report | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "Verification report saved to: $reportPath`n" -ForegroundColor $SuccessColor
