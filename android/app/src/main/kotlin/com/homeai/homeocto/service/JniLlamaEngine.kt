package com.homeai.homeocto.service

import android.content.Context
import android.util.Log
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import java.io.File

/**
 * JNI wrapper for llama.cpp inference engine.
 * Provides OpenAI-compatible text and image generation.
 */
class JniLlamaEngine private constructor() {

    companion object {
        private const val TAG = "JniLlamaEngine"

        @Volatile
        private var isNativeLibraryLoaded = false
        @Volatile
        private var nativeLibraryLoadFailed = false

        val instance = JniLlamaEngine()

        /**
         * 尝试加载 native 库，失败时仅记录警告
         */
        fun tryLoadNativeLibrary() {
            if (isNativeLibraryLoaded || nativeLibraryLoadFailed) {
                return
            }
            synchronized(this) {
                if (isNativeLibraryLoaded || nativeLibraryLoadFailed) {
                    return
                }
                try {
                    System.loadLibrary("homeocto_llama")
                    isNativeLibraryLoaded = true
                    Log.i(TAG, "Native library libhomeocto_llama.so loaded successfully")
                } catch (e: UnsatisfiedLinkError) {
                    nativeLibraryLoadFailed = true
                    Log.w(TAG, "Failed to load libhomeocto_llama.so: ${e.message}. Inference service will be unavailable.")
                } catch (e: Exception) {
                    nativeLibraryLoadFailed = true
                    Log.w(TAG, "Failed to load libhomeocto_llama.so: ${e.message}. Inference service will be unavailable.")
                }
            }
        }
    }

    // Native methods - JNI interface
    private external fun init(nativeLibDir: String)
    private external fun load(modelPath: String): Int
    private external fun loadMmproj(mmprojPath: String, imageMaxSliceNums: Int): Int
    private external fun prepare(): Int
    private external fun processSystemPrompt(systemPrompt: String): Int
    private external fun processUserPrompt(userPrompt: String, predictLength: Int): Int
    private external fun generateNextToken(): String?
    private external fun prefillImage(imageData: ByteArray, imageSize: Int): Int
    private external fun nativeCancelGeneration()
    private external fun fullReset()
    private external fun unload()
    private external fun shutdown()
    private external fun systemInfo(): String
    private external fun setMinicpmvVersionNative(version: Int)
    private external fun getMinicpmvVersionNative(): Int
    private external fun setImageMaxSliceNumsNative(n: Int)

    // State
    private var isInitialized = false
    private var isModelLoaded = false
    private var isGenerating = false

    /**
     * Initialize the engine with native backend.
     * Must be called once before any other operations.
     */
    fun initialize(context: Context) {
        if (!isNativeLibraryLoaded) {
            Log.w(TAG, "Native library not loaded, skipping engine initialization")
            return
        }

        if (isInitialized) {
            Log.w(TAG, "Engine already initialized")
            return
        }

        val nativeLibDir = context.applicationInfo.nativeLibraryDir
        init(nativeLibDir)
        isInitialized = true
        Log.i(TAG, "Engine initialized successfully")
    }

    /**
     * Load GGUF model and optionally mmproj for vision.
     *
     * @param modelPath Path to main GGUF model file
     * @param mmprojPath Path to vision projector file (null for text-only)
     * @param imageMaxSliceNums Max image slices for vision (1-9, default 9)
     * @return true if loading succeeded
     */
    fun loadModel(
        modelPath: String,
        mmprojPath: String? = null,
        imageMaxSliceNums: Int = 9,
        modelVersion: Int = 0
    ): Boolean {
        if (!isInitialized) {
            Log.e(TAG, "Engine not initialized")
            return false
        }

        // Load main model
        val modelFile = File(modelPath)
        if (!modelFile.exists()) {
            Log.e(TAG, "Model file not found: $modelPath")
            return false
        }

        val loadResult = load(modelPath)
        if (loadResult != 0) {
            Log.e(TAG, "Failed to load model, error code: $loadResult")
            return false
        }

        // Load vision projector if provided
        if (mmprojPath != null) {
            val mmprojFile = File(mmprojPath)
            if (!mmprojFile.exists()) {
                Log.w(TAG, "MMProj file not found, continuing without vision: $mmprojPath")
            } else {
                val mmprojResult = loadMmproj(mmprojPath, imageMaxSliceNums)
                if (mmprojResult != 0) {
                    Log.e(TAG, "Failed to load mmproj, error code: $mmprojResult")
                    return false
                }

                // Set model version for context size selection
                setMinicpmvVersionNative(modelVersion)
            }
        }

        // Prepare context
        val prepareResult = prepare()
        if (prepareResult != 0) {
            Log.e(TAG, "Failed to prepare context, error code: $prepareResult")
            return false
        }

        isModelLoaded = true
        Log.i(TAG, "Model loaded successfully")
        return true
    }

    /**
     * Set system prompt for the conversation.
     */
    fun setSystemPrompt(prompt: String): Boolean {
        if (!isModelLoaded) {
            Log.e(TAG, "Model not loaded")
            return false
        }

        val result = processSystemPrompt(prompt)
        return result == 0
    }

    /**
     * Process user prompt and generate response as a Flow of tokens.
     *
     * @param prompt User input text
     * @param maxTokens Maximum tokens to generate
     * @return Flow of generated text tokens
     */
    fun generateStream(prompt: String, maxTokens: Int = 512): Flow<String> = flow {
        if (!isModelLoaded) {
            Log.e(TAG, "Model not loaded")
            return@flow
        }

        if (isGenerating) {
            Log.w(TAG, "Generation already in progress")
            return@flow
        }

        isGenerating = true
        try {
            val result = processUserPrompt(prompt, maxTokens)
            if (result != 0) {
                Log.e(TAG, "Failed to process user prompt, error code: $result")
                return@flow
            }

            // Generate tokens one by one
            while (true) {
                val token = generateNextToken() ?: break
                if (token.isNotEmpty()) {
                    emit(token)
                }
            }
        } finally {
            isGenerating = false
        }
    }

    /**
     * Prefill image data into the context for vision understanding.
     *
     * @param imageData JPEG or PNG image bytes
     * @return true if image was prefilled successfully
     */
    fun prefillImage(imageData: ByteArray): Boolean {
        if (!isModelLoaded) {
            Log.e(TAG, "Model not loaded")
            return false
        }

        val result = prefillImage(imageData, imageData.size)
        return result == 0
    }

    /**
     * Cancel ongoing generation.
     */
    fun cancelGeneration() {
        nativeCancelGeneration()
        isGenerating = false
    }

    /**
     * Reset conversation state while keeping model loaded.
     */
    fun reset() {
        fullReset()
        isGenerating = false
    }

    /**
     * Unload model and free resources.
     */
    fun unloadModel() {
        if (isModelLoaded) {
            unload()
            isModelLoaded = false
            isGenerating = false
        }
    }

    /**
     * Shutdown engine and free native resources.
     */
    fun destroy() {
        unloadModel()
        if (isInitialized) {
            shutdown()
            isInitialized = false
        }
    }

    /**
     * Get system info from llama.cpp.
     */
    fun getSystemInfo(): String {
        return systemInfo()
    }

    /**
     * Get loaded model version.
     */
    fun getModelVersion(): Int {
        return getMinicpmvVersionNative()
    }
}
