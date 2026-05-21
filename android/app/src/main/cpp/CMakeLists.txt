cmake_minimum_required(VERSION 3.22.1)
project("homeocto_llama")

# llama.cpp source location (4 levels up from this file)
set(LLAMA_SRC ${CMAKE_CURRENT_LIST_DIR}/../../../../llama.cpp)

if(NOT EXISTS ${LLAMA_SRC}/CMakeLists.txt)
    message(FATAL_ERROR "llama.cpp not found at ${LLAMA_SRC}. Run `git submodule update --init --recursive`")
endif()

# Architecture-specific optimization
if(ANDROID_ABI STREQUAL "arm64-v8a")
    set(GGML_SYSTEM_ARCH ARM)
    set(GGML_CPU_KLEIDIAI ON)
    set(GGML_OPENMP ON)
else()
    set(GGML_SYSTEM_ARCH x86)
    set(GGML_CPU_KLEIDIAI OFF)
    set(GGML_OPENMP OFF)
endif()

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

# Add llama.cpp subdirectories
add_subdirectory(${LLAMA_SRC} ${CMAKE_BINARY_DIR}/build-llama)
add_subdirectory(${LLAMA_SRC}/tools/mtmd ${CMAKE_BINARY_DIR}/build-mtmd)

# Build JNI shared library
add_library(${CMAKE_PROJECT_NAME} SHARED llama_jni.cpp)

target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
    ${LLAMA_SRC}
    ${LLAMA_SRC}/common
    ${LLAMA_SRC}/include
    ${LLAMA_SRC}/ggml/include
    ${LLAMA_SRC}/ggml/src
    ${LLAMA_SRC}/tools/mtmd
    ${LLAMA_SRC}/vendor
)

target_link_libraries(${CMAKE_PROJECT_NAME}
    llama
    llama-common
    mtmd
    android
    log
)
