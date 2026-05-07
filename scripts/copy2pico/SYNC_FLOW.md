# 完整同步流程

## 步骤 1：运行主同步脚本

```powershell
# 方式一：双击运行
双击 scripts\copy2pico\copy2pico.bat

# 方式二：PowerShell
.\scripts\copy2pico\copy2pico.ps1
```

这会：
- ✅ 拷贝标记 ** 的文件（9 个）
- ✅ 拷贝新增文件（3 个）
- ✅ 提取图片到 docs/imgs/（7 个）
- ✅ 自动替换包名和命名空间

## 步骤 2：修复新增文件的 import 引用

由于内容替换规则会影响新增文件中的 import 语句，需要运行修复脚本：

```powershell
.\scripts\copy2pico\fix_imports.ps1
```

这会修正：
- `smart_home_provider.dart` 中的 `import 'picoclaw_client.dart'` → `import 'homeocto_client.dart'`

## 步骤 3：验证同步结果

```powershell
cd G:\code\picoclaw_fui

# 检查新增文件
ls lib\src\ui\smart_home_page.dart
ls lib\src\core\homeocto_client.dart
ls lib\src\core\smart_home_provider.dart

# 检查修改的文件
ls lib\main.dart
ls pubspec.yaml
ls android\app\build.gradle.kts
```

## 步骤 4：处理图片文件

图片已提取到 `docs/imgs/` 目录，需要手动替换：

```powershell
# 查看提取的图片
cd G:\code\homeocto-app\docs\imgs

# 手动拷贝到 picoclaw-fui
# 例如：
# cp docs\imgs\assets\app_icon.png G:\code\picoclaw_fui\assets\app_icon.png
```

## 步骤 5：更新依赖并测试

```powershell
cd G:\code\picoclaw_fui

# 更新依赖
flutter pub get

# 运行测试
flutter run
```

## 同步的文件清单

### 标记 ** 的文件（9 个）
1. `lib/main.dart`
2. `pubspec.yaml`
3. `android/app/build.gradle.kts`
4. `android/app/src/main/AndroidManifest.xml`
5. `lib/l10n/app_en.arb`
6. `lib/l10n/app_zh.arb`
7. `android/app/src/main/kotlin/com/homeai/homeocto/HomeOctoApp.kt`
8. `android/app/src/main/kotlin/com/homeai/homeocto/HomeOctoMethodChannel.kt`
9. `android/app/src/main/kotlin/com/homeai/homeocto/service/HomeOctoService.kt`

### 新增文件（3 个）
1. `lib/src/ui/smart_home_page.dart`
2. `lib/src/core/homeocto_client.dart`
3. `lib/src/core/smart_home_provider.dart`

### 图片文件（7 个，提取到 docs/imgs/）
1. `assets/app_icon.png`
2. `assets/icon.ico`
3. `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
4. `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
5. `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
6. `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
7. `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`

## 注意事项

1. **备份目标项目**：同步会覆盖 picoclaw-fui 中的同名文件
2. **运行修复脚本**：必须在主同步脚本后运行 `fix_imports.ps1`
3. **手动处理图片**：图片文件需要手动从 docs/imgs/ 拷贝
4. **检查替换结果**：验证包名、类名等是否正确替换
