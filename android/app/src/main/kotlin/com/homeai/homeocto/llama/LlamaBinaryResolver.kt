package com.homeai.homeocto.llama

import android.content.Context
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipFile

object LlamaBinaryResolver {
    private const val TAG = "LlamaBinaryResolver"
    private const val BINARY_NAME = "libllama-server.so"

    /**
     * Resolve the llama-server binary path using the same dual-strategy as PicoClawService:
     * 1. Check nativeLibraryDir first
     * 2. If missing, extract from APK zip to context.filesDir
     */
    fun resolveBinary(context: Context): File {
        val nativeLibDir = context.applicationInfo.nativeLibraryDir
        val binaryFile = File(nativeLibDir, BINARY_NAME)

        if (binaryFile.exists() && binaryFile.canExecute()) {
            Log.i(TAG, "Using llama-server from nativeLibraryDir: ${binaryFile.absolutePath}")
            return binaryFile
        }

        Log.w(TAG, "$BINARY_NAME not found in nativeLibraryDir, trying to extract from APK")
        val extractedFile = extractBinaryFromApk(context)
        if (extractedFile != null) {
            Log.i(TAG, "Using extracted llama-server: ${extractedFile.absolutePath}")
            return extractedFile
        }

        throw RuntimeException(
            "llama-server binary not found. " +
            "Tried: ${binaryFile.absolutePath} and APK extraction. " +
            "Ensure $BINARY_NAME is placed in jniLibs/arm64-v8a/"
        )
    }

    /**
     * Extract the binary from APK to filesDir
     */
    private fun extractBinaryFromApk(context: Context): File? {
        try {
            val abi = android.os.Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a"
            val zipEntryPath = "lib/$abi/$BINARY_NAME"
            val outputFile = File(context.filesDir, BINARY_NAME)

            if (outputFile.exists() && outputFile.canExecute()) {
                Log.i(TAG, "Using cached llama-server: ${outputFile.absolutePath}")
                return outputFile
            }

            val apkPath = context.applicationInfo.sourceDir
            Log.i(TAG, "Extracting $BINARY_NAME from APK: $apkPath (entry: $zipEntryPath)")

            ZipFile(apkPath).use { zipFile ->
                val entry = zipFile.getEntry(zipEntryPath)
                    ?: zipFile.getEntry("lib/arm64-v8a/$BINARY_NAME")
                    ?: zipFile.getEntry("lib/armeabi-v7a/$BINARY_NAME")
                    ?: return null

                zipFile.getInputStream(entry).use { input ->
                    FileOutputStream(outputFile).use { output ->
                        input.copyTo(output)
                    }
                }
            }

            outputFile.setExecutable(true)
            Log.i(TAG, "Successfully extracted llama-server to ${outputFile.absolutePath}")
            return outputFile
        } catch (e: Exception) {
            Log.e(TAG, "Failed to extract llama-server from APK", e)
            return null
        }
    }
}
