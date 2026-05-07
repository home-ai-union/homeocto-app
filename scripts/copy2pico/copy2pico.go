package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// 配置结构体
type SyncConfig struct {
	// 源目录（homeocto-app）
	SrcDir string
	// 目标目录（picoclaw-fui）
	DstDir string
	// 图片输出目录
	ImgDir string
	// 需要同步的文件列表（需要内容替换）
	Files []string
	// 需要同步的目录列表（需要内容替换）
	Dirs []string
	// 图片文件列表（直接拷贝到 imgs 目录，不做内容替换）
	ImageFiles []string
	// 路径替换规则（用于处理不同目录名的情况）
	PathReplacements []PathReplacement
	// 文件内容替换规则
	ContentReplacements []ContentReplacement
}

// 路径替换规则
type PathReplacement struct {
	SrcPrefix string // 源路径前缀
	DstPrefix string // 目标路径前缀
}

// 文件内容替换规则
type ContentReplacement struct {
	Old string
	New string
}

// 默认配置 - 根据 changefile.md 记录的需要同步的文件和目录
func getDefaultConfig() SyncConfig {
	return SyncConfig{
		// 需要内容替换的文件（仅标记 ** 的文件 + 新增文件）
		Files: []string{
			// Dart 文件 - 标记 **
			"lib\\main.dart",
			// 配置文件 - 标记 **
			"pubspec.yaml",
			// Android 配置 - 标记 **
			"android\\app\\build.gradle.kts",
			"android\\app\\src\\main\\AndroidManifest.xml",
			// 本地化文件 - 标记 **
			"lib\\l10n\\app_en.arb",
			"lib\\l10n\\app_zh.arb",
			// Android Kotlin 文件 - 标记 **
			"android\\app\\src\\main\\kotlin\\com\\homeai\\homeocto\\HomeOctoApp.kt",
			"android\\app\\src\\main\\kotlin\\com\\homeai\\homeocto\\HomeOctoMethodChannel.kt",
			"android\\app\\src\\main\\kotlin\\com\\homeai\\homeocto\\service\\HomeOctoService.kt",
			// 新增 Dart 文件
			"lib\\src\\ui\\smart_home_page.dart",
			"lib\\src\\core\\homeocto_client.dart",
			"lib\\src\\core\\smart_home_provider.dart",
		},
		// 需要同步的目录（空，因为都是文件）
		Dirs: []string{},
		// 图片文件（直接拷贝到 imgs 目录，不做内容替换）
		ImageFiles: []string{
			"assets\\app_icon.png",
			"assets\\icon.ico",
			"android\\app\\src\\main\\res\\mipmap-hdpi\\ic_launcher.png",
			"android\\app\\src\\main\\res\\mipmap-mdpi\\ic_launcher.png",
			"android\\app\\src\\main\\res\\mipmap-xhdpi\\ic_launcher.png",
			"android\\app\\src\\main\\res\\mipmap-xxhdpi\\ic_launcher.png",
			"android\\app\\src\\main\\res\\mipmap-xxxhdpi\\ic_launcher.png",
		},
		// 路径替换规则：kotlin 目录路径替换
		PathReplacements: []PathReplacement{
			{
				SrcPrefix: "android\\app\\src\\main\\kotlin\\com\\homeai\\homeocto",
				DstPrefix: "android\\app\\src\\main\\kotlin\\com\\sipeed\\picoclaw",
			},
		},
		// 文件内容替换规则（按优先级顺序）
		ContentReplacements: []ContentReplacement{
			{
				Old: "homeocto_app",
				New: "picoclaw_flutter_ui",
			},
			{
				Old: "com.homeai.homeocto",
				New: "com.sipeed.picoclaw",
			},
		},
	}
}

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintf(os.Stderr, "Usage: go run scripts/copy2pico/copy2pico.go <homeocto-app-root> <picoclaw-fui-root> [config-file]\n")
		fmt.Fprintf(os.Stderr, "Example: go run scripts/copy2pico/copy2pico.go G:\\code\\homeocto-app G:\\code\\picoclaw_fui\n")
		os.Exit(1)
	}

	homeoctoRoot := filepath.Clean(os.Args[1])
	picoclawRoot := filepath.Clean(os.Args[2])

	// 验证源目录存在
	if _, err := os.Stat(homeoctoRoot); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "Error: Source directory does not exist: %s\n", homeoctoRoot)
		os.Exit(1)
	}

	// 验证目标目录存在
	if _, err := os.Stat(picoclawRoot); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "Error: Target directory does not exist: %s\n", picoclawRoot)
		os.Exit(1)
	}

	// 加载配置
	config := loadConfig(homeoctoRoot, picoclawRoot)

	fmt.Printf("Source (homeocto-app): %s\n", homeoctoRoot)
	fmt.Printf("Target (picoclaw-fui): %s\n", picoclawRoot)
	fmt.Printf("Image output: %s\n\n", config.ImgDir)

	// 同步文件
	if err := syncFiles(config); err != nil {
		fmt.Fprintf(os.Stderr, "Error syncing files: %v\n", err)
		os.Exit(1)
	}

	// 同步目录
	if err := syncDirs(config); err != nil {
		fmt.Fprintf(os.Stderr, "Error syncing directories: %v\n", err)
		os.Exit(1)
	}

	// 拷贝图片文件到 imgs 目录
	if err := syncImages(config); err != nil {
		fmt.Fprintf(os.Stderr, "Error syncing images: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("=== Sync completed successfully! ===")
}

// 加载配置（可以从配置文件或默认配置加载）
func loadConfig(homeoctoRoot, picoclawRoot string) SyncConfig {
	config := getDefaultConfig()
	config.SrcDir = homeoctoRoot
	config.DstDir = picoclawRoot
	config.ImgDir = filepath.Join(homeoctoRoot, "docs", "imgs")
	return config
}

// 同步指定的文件
func syncFiles(config SyncConfig) error {
	fmt.Println("=== Syncing files ===")

	for _, file := range config.Files {
		srcPath := filepath.Join(config.SrcDir, file)
		// 应用路径替换规则
		dstFile := applyPathReplacements(file, config.PathReplacements)
		dstPath := filepath.Join(config.DstDir, dstFile)

		if _, err := os.Stat(srcPath); os.IsNotExist(err) {
			fmt.Printf("⚠ Warning: Source file not found: %s\n", srcPath)
			continue
		}

		// 创建目标目录
		if err := os.MkdirAll(filepath.Dir(dstPath), 0o755); err != nil {
			return fmt.Errorf("create directory %s: %w", filepath.Dir(dstPath), err)
		}

		// 拷贝文件并进行内容替换
		if err := copyFileWithReplacement(srcPath, dstPath, config.ContentReplacements); err != nil {
			return fmt.Errorf("copy file %s: %w", file, err)
		}
		fmt.Printf("✓ Copied with replacements: %s -> %s\n", file, dstFile)
	}

	fmt.Println()
	return nil
}

// 应用路径替换规则
func applyPathReplacements(path string, replacements []PathReplacement) string {
	result := path
	for _, rule := range replacements {
		// 检查路径是否以源前缀开头
		if len(result) >= len(rule.SrcPrefix) && result[:len(rule.SrcPrefix)] == rule.SrcPrefix {
			// 替换前缀
			result = rule.DstPrefix + result[len(rule.SrcPrefix):]
		}
	}
	return result
}

// 同步指定的目录
func syncDirs(config SyncConfig) error {
	fmt.Println("=== Syncing directories ===")

	for _, dir := range config.Dirs {
		srcDir := filepath.Join(config.SrcDir, dir)
		dstDir := filepath.Join(config.DstDir, dir)

		if _, err := os.Stat(srcDir); os.IsNotExist(err) {
			fmt.Printf("⚠ Warning: Source directory not found: %s\n", srcDir)
			continue
		}

		// 删除旧目录
		if err := os.RemoveAll(dstDir); err != nil {
			return fmt.Errorf("remove old directory %s: %w", dstDir, err)
		}

		// 拷贝新目录并进行内容替换
		if err := copyDirWithReplacement(srcDir, dstDir, config.ContentReplacements); err != nil {
			return fmt.Errorf("copy directory %s: %w", dir, err)
		}
		fmt.Printf("✓ Copied directory with replacements: %s\n", dir)
	}

	fmt.Println()
	return nil
}

// 同步图片文件到 imgs 目录（不做内容替换）
func syncImages(config SyncConfig) error {
	fmt.Println("=== Syncing images to imgs directory ===")

	// 确保 imgs 目录存在
	if err := os.MkdirAll(config.ImgDir, 0o755); err != nil {
		return fmt.Errorf("create imgs directory %s: %w", config.ImgDir, err)
	}

	for _, file := range config.ImageFiles {
		srcPath := filepath.Join(config.SrcDir, file)
		// 图片文件直接拷贝到 imgs 目录，保持相对路径结构
		dstPath := filepath.Join(config.ImgDir, file)

		if _, err := os.Stat(srcPath); os.IsNotExist(err) {
			fmt.Printf("⚠ Warning: Image file not found: %s\n", srcPath)
			continue
		}

		// 创建目标目录
		if err := os.MkdirAll(filepath.Dir(dstPath), 0o755); err != nil {
			return fmt.Errorf("create directory %s: %w", filepath.Dir(dstPath), err)
		}

		// 直接拷贝文件，不做内容替换
		if err := copyFile(srcPath, dstPath); err != nil {
			return fmt.Errorf("copy image file %s: %w", file, err)
		}
		fmt.Printf("✓ Copied image: %s -> imgs/%s\n", file, file)
	}

	fmt.Println()
	return nil
}

// 判断是否应该跳过某个目录
func shouldSkipDirectory(name string) bool {
	skipDirs := []string{
		"node_modules",
		".git",
		"vendor",
		"dist",
		"build",
		".cache",
		".dart_tool",
		"ephemeral",
	}

	for _, skip := range skipDirs {
		if name == skip {
			return true
		}
	}
	return false
}

// 判断是否应该跳过某个文件（基于扩展名）
func shouldSkipFile(name string) bool {
	skipExtensions := []string{
		".lock", // pubspec.lock 等不同步
	}

	ext := filepath.Ext(name)
	for _, skipExt := range skipExtensions {
		if ext == skipExt {
			return true
		}
	}
	return false
}

// 拷贝整个目录并进行内容替换
func copyDirWithReplacement(src, dst string, replacements []ContentReplacement) error {
	return filepath.Walk(src, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		// 跳过某些目录
		if info.IsDir() && shouldSkipDirectory(info.Name()) {
			return filepath.SkipDir
		}

		// 跳过某些文件
		if !info.IsDir() && shouldSkipFile(info.Name()) {
			return nil
		}

		// 计算相对路径
		relPath, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}

		targetPath := filepath.Join(dst, relPath)

		if info.IsDir() {
			return os.MkdirAll(targetPath, info.Mode())
		}

		return copyFileWithReplacement(path, targetPath, replacements)
	})
}

// 拷贝单个文件并进行内容替换
func copyFileWithReplacement(src, dst string, replacements []ContentReplacement) error {
	// 创建目标目录
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return fmt.Errorf("create directory %s: %w", filepath.Dir(dst), err)
	}

	// 读取源文件内容
	content, err := os.ReadFile(src)
	if err != nil {
		return fmt.Errorf("read source file %s: %w", src, err)
	}

	// 应用内容替换
	newContent := string(content)
	for _, replacement := range replacements {
		newContent = strings.ReplaceAll(newContent, replacement.Old, replacement.New)
	}

	// 写入目标文件
	if err := os.WriteFile(dst, []byte(newContent), 0o644); err != nil {
		return fmt.Errorf("write destination file %s: %w", dst, err)
	}

	return nil
}

// 拷贝单个文件（无替换）
func copyFile(src, dst string) error {
	// 创建目标目录
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return fmt.Errorf("create directory %s: %w", filepath.Dir(dst), err)
	}

	srcFile, err := os.Open(src)
	if err != nil {
		return fmt.Errorf("open source file %s: %w", src, err)
	}
	defer srcFile.Close()

	dstFile, err := os.Create(dst)
	if err != nil {
		return fmt.Errorf("create destination file %s: %w", dst, err)
	}
	defer dstFile.Close()

	_, err = io.Copy(dstFile, srcFile)
	if err != nil {
		return fmt.Errorf("copy file %s -> %s: %w", src, dst, err)
	}

	return nil
}
