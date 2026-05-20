# Building llama-server for Android

This document describes how to build the llama.cpp server example for Android ARM64.

## Prerequisites

- Android NDK (version 25 or later recommended)
- CMake 3.22.1 or later
- Unix-like shell (Git Bash on Windows, or Linux/macOS)

## Quick Start

### Option 1: Using the build script

```bash
cd android/app/src/main/cpp
./build-llama-android.sh
```

The built binary will be placed in `android/app/src/main/jniLibs/arm64-v8a/libllama-server.so`.

### Option 2: Manual build

```bash
cd android/app/src/main/cpp

# Initialize llama.cpp submodule (if using git submodule approach)
git submodule add https://github.com/ggerganov/llama.cpp.git llama.cpp

# Create build directory
mkdir -p build && cd build

# Configure CMake with Android NDK toolchain
cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-24 \
    -DANDROID_STL=c++_shared \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLAMA_BUILD_SERVER=ON \
    -DBUILD_SHARED_LIBS=OFF

# Build
cmake --build . --config Release --target llama-server -j$(nproc)

# Copy the binary to jniLibs
mkdir -p ../../jniLibs/arm64-v8a
cp llama-server ../../jniLibs/arm64-v8a/libllama-server.so
```

## Build Options

| Option | Description | Default |
|--------|-------------|---------|
| `ANDROID_ABI` | Target ABI | `arm64-v8a` |
| `ANDROID_PLATFORM` | Minimum Android API level | `24` |
| `CMAKE_BUILD_TYPE` | Build configuration | `Release` |
| `LLAMA_BUILD_SERVER` | Build llama-server example | `ON` |
| `BUILD_SHARED_LIBS` | Build shared libraries | `OFF` |

## llama.cpp Source

The build script uses FetchContent to automatically download llama.cpp from GitHub. You can also:

1. **Use a local copy**: Place llama.cpp source in `android/app/src/main/cpp/llama.cpp/`
2. **Use a git submodule**: Run `git submodule add https://github.com/ggerganov/llama.cpp.git android/app/src/main/cpp/llama.cpp`

## Binary Verification

After building, verify the binary is a PIE executable:

```bash
readelf -h android/app/src/main/jniLibs/arm64-v8a/libllama-server.so
```

Look for:
- `Type: DYN` (Position Independent Executable)
- `Class: ELF64`

## Updating llama.cpp

To update to a newer version of llama.cpp:

1. Edit `CMakeLists.txt` and change the `GIT_TAG` in the FetchContent declaration
2. Run `./build-llama-android.sh --clean` to force a clean rebuild
3. Rebuild

## Troubleshooting

### NDK not found

Set the `ANDROID_NDK` environment variable:

```bash
export ANDROID_NDK=$ANDROID_HOME/ndk/27.0.12077973
```

### CMake version too old

Install a newer CMake version or use the one bundled with Android Studio:

```bash
export PATH=$ANDROID_HOME/cmake/3.22.1/bin:$PATH
```

### Linker errors

Ensure you're building with `c++_shared` STL and that `BUILD_SHARED_LIBS=OFF`.

## File Size Optimization

To reduce binary size:

```bash
# Strip debug symbols
$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip \
    android/app/src/main/jniLibs/arm64-v8a/libllama-server.so
```

Expected binary size: 10-25 MB (Release build, CPU-only).
