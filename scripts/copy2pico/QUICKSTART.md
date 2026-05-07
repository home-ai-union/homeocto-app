# copy2pico 脚本使用说明

## 快速开始

### 方式一：双击运行（推荐）
```
双击 scripts\copy2pico\copy2pico.bat
```

### 方式二：PowerShell
```powershell
.\scripts\copy2pico\copy2pico.ps1
```

### 方式三：命令行
```powershell
go run scripts/copy2pico/copy2pico.go G:\code\homeocto-app G:\code\picoclaw_fui
```

## 功能说明

### 1. 代码文件同步（带内容替换）

根据 `docs/changefile.md` 记录的文件列表，将 homeocto-app 的代码同步到 picoclaw-fui，并自动进行以下替换：

| 原始文本 | 替换为 | 说明 |
|---------|--------|------|
| `homeocto_app` | `picoclaw_flutter_ui` | Flutter 包名 |
| `com.homeai.homeocto` | `com.sipeed.picoclaw` | Android namespace/applicationId |
| `HomeOcto` | `Picoclaw` | 应用名称（大小写敏感） |
| `homeocto` | `picoclaw` | 通用名称 |

**同步的文件包括：**
- Dart 源文件（lib/）
- 配置文件（pubspec.yaml、build.gradle.kts、AndroidManifest.xml）
- 本地化文件（lib/l10n/*.arb）
- Android Kotlin 文件

**路径自动替换：**
- Kotlin 文件从 `com/homeai/homeocto/` 自动拷贝到 `com/sipeed/picoclaw/`

### 2. 图片文件提取（不做替换）

图片文件会单独提取到 `docs/imgs/` 目录，保持原有目录结构，**不做任何内容替换**。

**提取的图片包括：**
- `assets/app_icon.png`
- `assets/icon.ico`
- `android/app/src/main/res/mipmap-*/ic_launcher.png`（5 种分辨率）

### 3. 智能跳过

自动跳过以下目录和文件：
- 目录：`node_modules`、`.git`、`build`、`.dart_tool`、`ephemeral` 等
- 文件：`.lock` 文件（如 `pubspec.lock`）

## 同步后处理

### 步骤 1：验证代码
```powershell
cd G:\code\picoclaw_fui
# 检查同步的文件是否正确
```

### 步骤 2：处理图片
```powershell
# 查看提取的图片
cd G:\code\homeocto-app\docs\imgs

# 手动替换 picoclaw-fui 中的图片
# 从 docs/imgs/ 目录拷贝对应图片覆盖到 picoclaw-fui 项目
```

### 步骤 3：更新依赖
```powershell
cd G:\code\picoclaw_fui
flutter pub get
```

### 步骤 4：构建测试
```powershell
flutter run
```

## 配置修改

如需修改同步的文件列表或替换规则，编辑 `scripts/copy2pico/copy2pico.go` 中的 `getDefaultConfig()` 函数：

```go
func getDefaultConfig() SyncConfig {
    return SyncConfig{
        Files: []string{
            // 需要同步的文件列表
        },
        Dirs: []string{
            // 需要同步的目录列表
        },
        ImageFiles: []string{
            // 需要提取的图片文件列表
        },
        PathReplacements: []PathReplacement{
            // 路径替换规则
        },
        ContentReplacements: []ContentReplacement{
            // 内容替换规则
        },
    }
}
```

## 注意事项

1. **备份目标项目**：同步会覆盖 picoclaw-fui 中的同名文件
2. **图片需手动处理**：图片文件不会自动覆盖，需要手动从 `docs/imgs/` 目录拷贝
3. **检查替换结果**：同步后务必验证文件内容和路径是否正确
4. **重新生成代码**：如有需要，运行 `flutter pub run build_runner build` 重新生成代码

## 文件结构

```
scripts/copy2pico/
├── copy2pico.go      # Go 核心脚本
├── copy2pico.ps1     # PowerShell 包装脚本
├── copy2pico.bat     # Windows 批处理脚本
├── go.mod            # Go 模块配置
└── README.md         # 详细文档
```
