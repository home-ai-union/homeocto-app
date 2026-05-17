# Keystore 密码问题修复说明

## 问题现象

GitHub Actions 构建时出现错误：
```
Failed to read key *** from store "release.jks": 
Get Key failed: Given final block not properly padded. 
Such issues can arise if a bad key is used during decryption.
```

## 根本原因

Keystore 文件使用的是 **PKCS12** 格式（而非 JKS 格式）。

在 PKCS12 格式中：
- **Keystore 密码（storepass）和 Key 密码（keypass）必须相同**
- 这是 PKCS12 格式的强制要求

## 验证方法

```bash
# 查看 keystore 格式
keytool -list -keystore release.jks -storepass YOUR_PASSWORD

# 输出会显示：
# 密钥库类型: PKCS12  ← 这就是问题所在
```

## 修复方案

### 方案 1: 修改 GitHub Secrets（推荐）

将 `ANDROID_KEY_PASSWORD` 改为与 `ANDROID_KEYSTORE_PASSWORD` 相同：

| Secret 名称 | 原值 | 新值 |
|------------|------|------|
| `ANDROID_KEYSTORE_PASSWORD` | `XxkfZymrMKC8T7Y3` | `XxkfZymrMKC8T7Y3` (不变) |
| `ANDROID_KEY_PASSWORD` | `bHB4qX6FmMKs01jn` | **`XxkfZymrMKC8T7Y3`** (改为相同) |

### 方案 2: 重新生成 Keystore（如果需要不同密码）

如果确实需要不同的密码，需要重新生成 JKS 格式的 Keystore：

```bash
keytool -genkeypair \
  -alias homeocto_release \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -keystore release.jks \
  -storetype JKS \
  -storepass XxkfZymrMKC8T7Y3 \
  -keypass bHB4qX6FmMKs01jn
```

但这样会导致：
- ⚠️ 旧的 Keystore 无法继续使用
- ⚠️ 已发布的应用无法更新（必须使用相同的签名）

## 推荐操作

**立即执行方案 1**：

1. 前往 GitHub 仓库：Settings → Secrets and variables → Actions
2. 编辑 `ANDROID_KEY_PASSWORD`
3. 将值改为：`XxkfZymrMKC8T7Y3`
4. 保存
5. 重新触发构建

## 技术说明

### JKS vs PKCS12

| 特性 | JKS | PKCS12 |
|------|-----|--------|
| 格式 | Java 专有 | 行业标准 |
| 密码要求 | 可以不同 | **必须相同** |
| 默认格式 | Java 8 及以前 | Java 9 及以后 |
| 兼容性 | 仅 Java | 跨平台 |

从 Java 9 开始，`keytool` 默认生成 PKCS12 格式的 Keystore，这就是为什么你现在的 Keystore 是 PKCS12 格式。

## 验证清单

- [x] Keystore 格式确认为 PKCS12
- [x] Keystore 密码验证通过：`XxkfZymrMKC8T7Y3`
- [x] Key Alias 确认：`homeocto_release`
- [ ] 修改 `ANDROID_KEY_PASSWORD` 为 `XxkfZymrMKC8T7Y3`
- [ ] 重新触发 GitHub Actions 构建
- [ ] 构建成功

---

**创建时间**: 2026-05-17
**问题状态**: 待修复
