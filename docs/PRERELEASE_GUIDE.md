# Pre-release 发布指南

## 概述

本项目支持三种发布模式：
- **正式版本** - 稳定版本，面向所有用户
- **Pre-release** - 预发布版本，用于测试新功能
- **Draft** - 草稿版本，仅创建者可见

## 发布方式

### 1️⃣ 通过 Git Tag（正式版本）

推送 tag 会自动创建正式版本：

```bash
git tag v0.2.7
git push origin v0.2.7
```

### 2️⃣ 通过 Workflow Dispatch（支持 Pre-release）

手动触发 workflow 时可以选择是否标记为 Pre-release：

**步骤：**
1. 前往 GitHub → Actions → Build and Release APKs
2. 点击 "Run workflow"
3. 填写参数：
   - **Version tag**: `v0.2.7-beta.1`（或其他版本号）
   - **Mark as pre-release**: ✅ 勾选（如果需要）
   - **Create as draft**: ✅ 勾选（如果需要草稿）
4. 点击 "Run workflow"

## Pre-release 使用场景

### ✅ 适合使用 Pre-release 的情况

- Beta 版本测试
- 候选版本（RC - Release Candidate）
- 新功能测试版本
- 内部测试版本
- Alpha 版本

### 版本号命名建议

```bash
# Beta 版本
v0.2.7-beta.1
v0.2.7-beta.2

# Release Candidate
v0.2.7-rc.1
v0.2.7-rc.2

# Alpha 版本
v0.2.7-alpha.1

# Nightly（ nightly build）
v0.2.7-nightly.20260516
```

## Draft 版本

Draft 版本特性：
- ✅ 仅仓库协作者可见
- ✅ 不会通知关注者
- ✅ 可以继续编辑 Release Notes
- ✅ 可以添加更多文件
- ✅ 准备好后可以发布

**使用场景：**
- 准备中的发布
- 需要审核的发布
- 等待其他任务完成的发布

## 三种版本对比

| 特性 | 正式版本 | Pre-release | Draft |
|------|---------|-------------|-------|
| 可见性 | 所有人 | 所有人 | 仅协作者 |
| 通知 | 是 | 是 | 否 |
| 标记 | Latest | Pre-release | Draft |
| 下载 | ✅ | ✅ | （未发布前） |
| 编辑 | ❌ | ✅ | ✅ |

## 示例工作流

### 场景 1：发布 Beta 版本

```bash
# 1. 创建 beta 分支
git checkout -b feature/new-ui

# 2. 开发新功能
# ... 代码开发 ...

# 3. 提交代码
git add .
git commit -m "feat: add new UI components"
git push origin feature/new-ui

# 4. 合并到 develop
git checkout develop
git merge feature/new-ui
git push origin develop

# 5. 手动触发 workflow 创建 Pre-release
# GitHub Actions → Build and Release APKs → Run workflow
# Version: v0.2.8-beta.1
# ✅ Mark as pre-release
```

### 场景 2：发布正式版本

```bash
# 1. 从 develop 创建 release 分支
git checkout -b release/v0.2.8 develop

# 2. 进行最终测试和修复
# ... 测试和修复 ...

# 3. 合并到 main
git checkout main
git merge release/v0.2.8
git push origin main

# 4. 创建 tag
git tag v0.2.8
git push origin v0.2.8

# 5. 自动创建正式 Release
```

### 场景 3：使用 Draft 准备工作

```bash
# 1. 手动触发 workflow 创建 Draft
# GitHub Actions → Build and Release APKs → Run workflow
# Version: v0.2.8
# ✅ Create as draft

# 2. 编辑 Release Notes
# 在 GitHub Releases 页面编辑草稿

# 3. 添加额外文件（如需要）
# 手动上传文档、截图等

# 4. 准备就绪后发布
# 点击 "Publish release" 按钮
```

## 查看和管理版本

### 查看所有版本

访问：https://github.com/你的用户名/homeocto-app/releases

- **Latest**: 最新的正式版本
- **Pre-release**: 预发布版本（橙色标签）
- **Draft**: 草稿版本（灰色标签，仅协作者可见）

### 从 Pre-release 升级为正式版本

1. 测试完成后，创建新的正式版本 tag
2. 或者编辑 Pre-release，取消 "This is a pre-release" 选项

### 删除 Pre-release

```bash
# 删除 tag
git tag -d v0.2.7-beta.1
git push origin --delete v0.2.7-beta.1

# 在 GitHub Releases 页面删除对应的 Release
```

## 最佳实践

### 1. 版本命名规范

遵循语义化版本（Semantic Versioning）：
```
v主版本.次版本.修订版本[-预发布标签][+构建元数据]

示例：
v0.2.7           # 正式版本
v0.2.7-beta.1    # Beta 1
v0.2.7-rc.1      # Release Candidate 1
v0.2.7-nightly   # Nightly build
```

### 2. 发布流程建议

```
develop → 新功能开发
   ↓
创建 beta 版本（Pre-release）
   ↓
内部测试
   ↓
修复问题
   ↓
创建 RC 版本（Pre-release）
   ↓
最终测试
   ↓
合并到 main
   ↓
创建正式版本（Tag）
```

### 3. 文档更新

- Pre-release 应包含已知问题列表
- 说明这是测试版本，不建议生产环境使用
- 提供反馈渠道

## 相关配置

### Workflow 参数说明

在 `.github/workflows/build-release.yml` 中：

```yaml
workflow_dispatch:
  inputs:
    version:
      description: 'Version tag (e.g., v0.2.7)'
      required: true
      type: string
    prerelease:
      description: 'Mark as pre-release'
      required: false
      type: boolean
      default: false
    draft:
      description: 'Create as draft'
      required: false
      type: boolean
      default: false
```

### Release 配置

```yaml
- name: Create Release
  uses: softprops/action-gh-release@v2
  with:
    draft: ${{ github.event_name == 'workflow_dispatch' && github.event.inputs.draft == 'true' }}
    prerelease: ${{ github.event_name == 'workflow_dispatch' && github.event.inputs.prerelease == 'true' }}
    generate_release_notes: true
```

## 常见问题

### Q: Pre-release 会影响 Latest 版本吗？

A: 不会。Pre-release 不会覆盖 Latest 标记，用户仍然会看到最新的正式版本作为 Latest。

### Q: 可以多次发布 Pre-release 吗？

A: 可以。每次使用不同的版本号即可，例如：
- v0.2.7-beta.1
- v0.2.7-beta.2
- v0.2.7-rc.1

### Q: Draft 版本会触发通知吗？

A: 不会。Draft 版本仅对仓库协作者可见，不会发送通知。

### Q: 如何在 Pre-release 中添加额外文件？

A: 
1. 创建 Pre-release 后
2. 前往 GitHub Releases 页面
3. 找到对应的 Pre-release
4. 点击 "Edit"
5. 拖拽上传额外文件
6. 保存更改

### Q: 自动生成的 Release Notes 包含什么？

A: 启用 `generate_release_notes: true` 后，GitHub 会自动生成包含：
- 该版本的所有 Commits
- 合并的 Pull Requests
- 贡献者列表

## 相关文档

- [RELEASE_QUICKSTART.md](../RELEASE_QUICKSTART.md) - 快速发布指南
- [GITHUB_SECRETS_CHECKLIST.md](GITHUB_SECRETS_CHECKLIST.md) - Secrets 配置清单
- [FLAVOR_BUILD_GUIDE.md](FLAVOR_BUILD_GUIDE.md) - Flavor 构建指南

---

**更新时间：** 2026-05-16  
**版本：** HomeOcto v0.2.7
