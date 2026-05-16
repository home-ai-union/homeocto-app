#!/usr/bin/env python3
"""
Generate Android mipmap icons from app_icon.png
"""

from PIL import Image
import os

# Source icon
SOURCE_ICON = os.path.join(os.path.dirname(__file__), '..', 'docs', 'imgs', 'assets', 'app_icon.png')

# Target directory
TARGET_DIR = os.path.join(os.path.dirname(__file__), '..', 'docs', 'imgs', 'android', 'app', 'src', 'main', 'res')

# Android mipmap sizes
MIPMAP_SIZES = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

def generate_icons():
    """Generate all mipmap icons from source"""
    print("=== Generating Android Mipmap Icons ===\n")
    
    # Check source icon exists
    if not os.path.exists(SOURCE_ICON):
        print(f"❌ Error: Source icon not found: {SOURCE_ICON}")
        return False
    
    # Open source icon
    print(f"📷 Loading source icon: {SOURCE_ICON}")
    source_img = Image.open(SOURCE_ICON)
    print(f"   Original size: {source_img.size}")
    
    # Generate each size
    for mipmap_dir, size in MIPMAP_SIZES.items():
        # Create target directory
        target_path = os.path.join(TARGET_DIR, mipmap_dir)
        os.makedirs(target_path, exist_ok=True)
        
        # Resize icon
        resized_img = source_img.resize((size, size), Image.Resampling.LANCZOS)
        
        # Save icon
        output_file = os.path.join(target_path, 'ic_launcher.png')
        resized_img.save(output_file, 'PNG')
        
        # Get file size
        file_size = os.path.getsize(output_file)
        print(f"✓ Generated {mipmap_dir}: {size}x{size} ({file_size:,} bytes)")
    
    print(f"\n✅ All icons generated successfully!")
    print(f"   Output directory: {TARGET_DIR}")
    return True

if __name__ == '__main__':
    try:
        success = generate_icons()
        exit(0 if success else 1)
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        exit(1)
