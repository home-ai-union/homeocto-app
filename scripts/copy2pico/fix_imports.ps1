# 修复新增文件中的 import 引用
# 运行此脚本修正 copy2pico 同步后的错误引用

$ErrorActionPreference = "Stop"

$PicoclawRoot = "G:\code\picoclaw_fui"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Fixing import references in new files" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 需要修复的文件列表
$filesToFix = @(
    "lib\src\core\smart_home_provider.dart"
)

# 替换规则
$replacements = @(
    @{Old = "import 'picoclaw_client.dart'"; New = "import 'homeocto_client.dart'"}
)

foreach ($file in $filesToFix) {
    $filePath = Join-Path $PicoclawRoot $file
    
    if (-not (Test-Path $filePath)) {
        Write-Host "⚠ Warning: File not found: $filePath" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "Fixing: $file" -ForegroundColor Green
    
    $content = Get-Content $filePath -Raw -Encoding UTF8
    $originalContent = $content
    
    foreach ($replacement in $replacements) {
        $content = $content -replace [regex]::Escape($replacement.Old), $replacement.New
    }
    
    if ($content -ne $originalContent) {
        Set-Content -Path $filePath -Value $content -Encoding UTF8 -NoNewline
        Write-Host "  ✓ Fixed import references" -ForegroundColor Green
    } else {
        Write-Host "  - No changes needed" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Fix completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
