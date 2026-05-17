package main

import (
	"encoding/base64"
	"fmt"
	"os"
	"path/filepath"
)

// keystoreToBase64 converts a keystore file to base64 encoding
func keystoreToBase64(inputPath string) (string, error) {
	// Read the keystore file
	data, err := os.ReadFile(inputPath)
	if err != nil {
		return "", fmt.Errorf("failed to read file: %w", err)
	}

	// Encode to base64
	encoded := base64.StdEncoding.EncodeToString(data)
	return encoded, nil
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: keystore_to_base64 <keystore_file_path> [output_file]")
		fmt.Println("\nExamples:")
		fmt.Println("  keystore_to_base64 android/app/release.jks")
		fmt.Println("  keystore_to_base64 android/app/release.jks my_keystore_base64.txt")
		os.Exit(1)
	}

	inputPath := os.Args[1]
	
	// Check if input file exists
	if _, err := os.Stat(inputPath); os.IsNotExist(err) {
		fmt.Printf("Error: File not found: %s\n", inputPath)
		os.Exit(1)
	}

	fmt.Printf("Converting keystore to Base64...\n")
	fmt.Printf("Input file: %s\n", inputPath)

	// Convert to base64
	encoded, err := keystoreToBase64(inputPath)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}

	// Determine output file path
	outputFile := "keystore_base64.txt"
	if len(os.Args) >= 3 {
		outputFile = os.Args[2]
	}

	// Write to output file
	err = os.WriteFile(outputFile, []byte(encoded), 0644)
	if err != nil {
		fmt.Printf("Error writing to file: %v\n", err)
		os.Exit(1)
	}

	// Get file sizes
	inputInfo, _ := os.Stat(inputPath)
	outputInfo, _ := os.Stat(outputFile)

	fmt.Printf("\n✅ Conversion successful!\n")
	fmt.Printf("Input file: %s (%.2f KB)\n", inputPath, float64(inputInfo.Size())/1024.0)
	fmt.Printf("Output file: %s (%.2f KB)\n", outputFile, float64(outputInfo.Size())/1024.0)
	
	absPath, _ := filepath.Abs(outputFile)
	fmt.Printf("\n📋 Next steps:\n")
	fmt.Printf("1. Copy the content from %s\n", absPath)
	fmt.Printf("2. Go to GitHub repository settings\n")
	fmt.Printf("3. Navigate to: Settings > Secrets and variables > Actions\n")
	fmt.Printf("4. Add new secret: ANDROID_KEYSTORE_BASE64\n")
	fmt.Printf("5. Paste the Base64 content (ensure it's a single line with no spaces or newlines)\n")
	
	// Also print first 50 chars for verification
	if len(encoded) > 50 {
		fmt.Printf("\n🔍 First 50 chars of Base64: %s...\n", encoded[:50])
	} else {
		fmt.Printf("\n🔍 Base64 content: %s\n", encoded)
	}
	fmt.Printf("📏 Total Base64 length: %d characters\n", len(encoded))
}
