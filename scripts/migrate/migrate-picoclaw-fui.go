package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"unicode/utf8"
)

// 替换规则 - 按长度降序排列,确保长字符串优先匹配
var replacements = []struct {
	oldStr string
	newStr string
}{
	// Flutter/Dart 包名替换
	{"picoclaw_flutter_ui", "homeocto_app"},
	// Android 包名替换
	{"com.sipeed.picoclaw", "com.homeai.homeocto"},
	// iOS Bundle ID 替换
	{"com.sipeed.picoclaw", "com.homeai.homeocto"},
	// Gradle 应用 ID 替换
	{"com.sipeed.picoclaw", "com.homeai.homeocto"},
}

// 需要拷贝的目录列表
var dirsToCopy = []string{
	"android",
	"ios",
	"linux",
	"macos",
	"lib",
	"test",
	"tools",
	"web",
	"windows",
}

// 需要拷贝的文件列表
var filesToCopy = []string{
	"analysis_options.yaml",
	"devtools_options.yaml",
	"l10n.yaml",
	"pubspec.yaml",
}

// 不替换的路径前缀(外部依赖包)
var skipReplacementPrefixes = []string{
	"node_modules",
	".git",
}

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintf(os.Stderr, "Usage: go run migrate-picoclaw-fui.go <picoclaw-fui-root> <homeocto-app-root>\n")
		fmt.Fprintf(os.Stderr, "Example: go run migrate-picoclaw-fui.go G:\\code\\picoclaw-fui G:\\code\\homeocto-app\n")
		os.Exit(1)
	}

	picoclawRoot := filepath.Clean(os.Args[1])
	homeoctoRoot := filepath.Clean(os.Args[2])

	// 验证源目录存在
	if _, err := os.Stat(picoclawRoot); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "Error: Source directory does not exist: %s\n", picoclawRoot)
		os.Exit(1)
	}

	// 验证目标目录存在
	if _, err := os.Stat(homeoctoRoot); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "Error: Target directory does not exist: %s\n", homeoctoRoot)
		os.Exit(1)
	}

	fmt.Printf("Source (picoclaw-fui): %s\n", picoclawRoot)
	fmt.Printf("Target (homeocto-app): %s\n\n", homeoctoRoot)

	// 检查 homeocto-app 是否有未提交的更改
	fmt.Println("=== Checking Git status for homeocto-app ===")
	if err := checkGitStatus(homeoctoRoot); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		fmt.Fprintf(os.Stderr, "Please commit or stash your changes before running migration.\n")
		os.Exit(1)
	}
	fmt.Println("✓ Git working directory is clean\n")

	// 1. 处理目录
	for _, dir := range dirsToCopy {
		if err := processDirectory(picoclawRoot, homeoctoRoot, dir); err != nil {
			fmt.Fprintf(os.Stderr, "Error processing %s directory: %v\n", dir, err)
			os.Exit(1)
		}
	}

	// 2. 处理文件
	for _, file := range filesToCopy {
		if err := processFile(picoclawRoot, homeoctoRoot, file); err != nil {
			fmt.Fprintf(os.Stderr, "Error processing %s file: %v\n", file, err)
			os.Exit(1)
		}
	}

	fmt.Println("=== Migration completed successfully! ===")
}

// 检查 Git 工作目录是否有未提交的更改
func checkGitStatus(repoPath string) error {
	// 检查是否是 Git 仓库
	gitDir := filepath.Join(repoPath, ".git")
	if _, err := os.Stat(gitDir); os.IsNotExist(err) {
		fmt.Println("⚠ Warning: Not a Git repository, skipping check")
		return nil
	}

	// 执行 git status --porcelain 检查是否有未提交的更改
	cmd := exec.Command("git", "status", "--porcelain")
	cmd.Dir = repoPath
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to run git status: %w", err)
	}

	// 如果输出不为空，说明有未提交的更改
	if len(strings.TrimSpace(string(output))) > 0 {
		fmt.Println("⚠ Found uncommitted changes in homeocto-app:")
		fmt.Println(string(output))
		return fmt.Errorf("working directory has uncommitted changes")
	}

	return nil
}

// 处理目录迁移
func processDirectory(picoclawRoot, homeoctoRoot, dirName string) error {
	srcDir := filepath.Join(picoclawRoot, dirName)
	dstDir := filepath.Join(homeoctoRoot, dirName)

	if _, err := os.Stat(srcDir); os.IsNotExist(err) {
		fmt.Printf("⚠ Warning: %s not found in source, skipping\n", dirName)
		return nil
	}

	fmt.Printf("=== Processing %s -> %s ===\n", dirName, dirName)

	// 先删除 homeocto-app 的目录
	fmt.Printf("  🗑 Cleaning %s directory in homeocto-app...\n", dirName)
	if err := os.RemoveAll(dstDir); err != nil {
		return fmt.Errorf("remove %s directory: %w", dirName, err)
	}

	// 拷贝并替换
	if err := copyDirWithReplace(srcDir, dstDir); err != nil {
		return fmt.Errorf("copy %s directory: %w", dirName, err)
	}

	fmt.Printf("✓ %s directory copied and replaced successfully\n\n", dirName)
	return nil
}

// 处理文件迁移
func processFile(picoclawRoot, homeoctoRoot, fileName string) error {
	srcFile := filepath.Join(picoclawRoot, fileName)
	dstFile := filepath.Join(homeoctoRoot, fileName)

	if _, err := os.Stat(srcFile); os.IsNotExist(err) {
		fmt.Printf("⚠ Warning: %s not found in source, skipping\n", fileName)
		return nil
	}

	fmt.Printf("=== Processing %s -> %s ===\n", fileName, fileName)

	// 拷贝并替换文件内容
	if err := copyTextFileWithReplace(srcFile, dstFile); err != nil {
		return fmt.Errorf("copy %s file: %w", fileName, err)
	}

	fmt.Printf("✓ %s file copied and replaced successfully\n\n", fileName)
	return nil
}

// 拷贝目录并执行替换
func copyDirWithReplace(srcDir, dstDir string) error {
	return filepath.Walk(srcDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		// 计算相对路径
		relPath, err := filepath.Rel(srcDir, path)
		if err != nil {
			return err
		}

		// 目标路径
		targetPath := filepath.Join(dstDir, relPath)

		if info.IsDir() {
			// 跳过某些目录
			if shouldSkipDirectory(relPath) {
				return filepath.SkipDir
			}
			// 创建目录
			return os.MkdirAll(targetPath, info.Mode())
		}

		// 跳过某些文件
		if shouldSkipFile(relPath) {
			return nil
		}

		// 处理文件
		if isTextFile(relPath) {
			return copyTextFileWithReplace(path, targetPath)
		} else {
			return copyBinaryFile(path, targetPath)
		}
	})
}

// 拷贝文本文件并执行替换
func copyTextFileWithReplace(src, dst string) error {
	// 打开源文件
	srcFile, err := os.Open(src)
	if err != nil {
		return fmt.Errorf("open source file %s: %w", src, err)
	}
	defer srcFile.Close()

	// 创建目标目录
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return fmt.Errorf("create directory %s: %w", filepath.Dir(dst), err)
	}

	// 创建目标文件
	dstFile, err := os.Create(dst)
	if err != nil {
		return fmt.Errorf("create destination file %s: %w", dst, err)
	}
	defer dstFile.Close()

	// 使用带缓冲的读写器
	reader := bufio.NewReader(srcFile)
	writer := bufio.NewWriter(dstFile)
	defer writer.Flush()

	// 逐行读取并替换
	for {
		line, err := reader.ReadString('\n')
		if err != nil && err != io.EOF {
			return fmt.Errorf("read line from %s: %w", src, err)
		}

		// 检查是否为有效的UTF-8
		if !utf8.ValidString(line) {
			// 如果不是UTF-8，直接复制原始内容
			if _, err := writer.WriteString(line); err != nil {
				return fmt.Errorf("write line to %s: %w", dst, err)
			}
		} else {
			// 检查是否包含需要跳过的路径前缀
			shouldSkip := false
			for _, prefix := range skipReplacementPrefixes {
				if strings.Contains(line, prefix) {
					shouldSkip = true
					break
				}
			}

			var replacedLine string
			if shouldSkip {
				replacedLine = line
			} else {
				// 使用替换规则
				replacedLine = line
				for _, rule := range replacements {
					replacedLine = strings.ReplaceAll(replacedLine, rule.oldStr, rule.newStr)
				}
			}

			if _, err := writer.WriteString(replacedLine); err != nil {
				return fmt.Errorf("write line to %s: %w", dst, err)
			}
		}

		if err == io.EOF {
			break
		}
	}

	return nil
}

// 判断是否应该跳过某个目录
func shouldSkipDirectory(relPath string) bool {
	skipDirs := []string{
		"node_modules",
		".git",
		"vendor",
		"dist",
		"build",
		".cache",
		".next",
		".turbo",
		".tanstack",
		"workspace",
		".dart_tool",
		".gradle",
		"Pods",
	}

	for _, skip := range skipDirs {
		if strings.Contains(relPath, skip) {
			return true
		}
	}
	return false
}

// 判断是否应该跳过某个文件
func shouldSkipFile(relPath string) bool {
	skipFiles := []string{
		".DS_Store",
		"Thumbs.db",
		".env.local",
		"pubspec.lock",
		"*.iml",
	}

	filename := filepath.Base(relPath)
	for _, skip := range skipFiles {
		if filename == skip {
			return true
		}
	}
	return false
}

// 判断是否为文本文件
func isTextFile(path string) bool {
	ext := strings.ToLower(filepath.Ext(path))
	textExtensions := map[string]bool{
		".dart":         true,
		".kt":           true,
		".kts":          true,
		".java":         true,
		".swift":        true,
		".m":            true,
		".h":            true,
		".mm":           true,
		".cc":           true,
		".cpp":          true,
		".c":            true,
		".js":           true,
		".jsx":          true,
		".ts":           true,
		".tsx":          true,
		".json":         true,
		".yaml":         true,
		".yml":          true,
		".xml":          true,
		".html":         true,
		".css":          true,
		".scss":         true,
		".md":           true,
		".txt":          true,
		".gradle":       true,
		".properties":   true,
		".plist":        true,
		".xcodeproj":    true,
		".xcconfig":     true,
		".entitlements": true,
		".storyboard":   true,
		".xib":          true,
		".cmake":        true,
	}

	return textExtensions[ext]
}

// 拷贝二进制文件（不执行替换）
func copyBinaryFile(src, dst string) error {
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
