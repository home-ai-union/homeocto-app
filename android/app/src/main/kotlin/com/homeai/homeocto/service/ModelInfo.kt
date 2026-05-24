package com.homeai.homeocto.service

/**
 * Metadata for a GGUF model variant supported by the JNI inference engine.
 *
 * Models can be downloaded from HuggingFace or ModelScope with racing downloads
 * (both sources in parallel, first to respond wins).
 */
data class ModelInfo(
    val id: String,
    val displayName: String,
    val description: String,
    val ggufFileName: String,
    val mmprojFileName: String,
    val hfRepo: String? = null,
    val msRepo: String? = null,
    val hfBranch: String = "main",
    val msBranch: String = "master",
    val ggufRemoteName: String? = null,
    val mmprojRemoteName: String? = null,
    val directGgufUrl: String? = null,
    val directMmprojUrl: String? = null,
    val ggufMd5: String? = null,
    val mmprojMd5: String? = null,
    val version: Int = 0  // MiniCPM-V family version: 46 for V-4.6, 5 for V-4, etc.
) {
    val ggufRemotePath: String
        get() = ggufRemoteName ?: ggufFileName

    val mmprojRemotePath: String
        get() = mmprojRemoteName ?: mmprojFileName

    val hasHfMsSources: Boolean
        get() = !hfRepo.isNullOrBlank() && !msRepo.isNullOrBlank()

    companion object {
        val AVAILABLE_MODELS = listOf(
             ModelInfo(
                id = "minicpm-v-4_6-instruct",
                displayName = "MiniCPM-V-4.6 (Q4_K_M)",
                description = "Next-gen multimodal model, image/text understanding (1.2B)",
                ggufFileName = "MiniCPM-V-4_6-Q4_K_M.gguf",
                mmprojFileName = "mmproj-model-f16.gguf",
                hfRepo = "openbmb/MiniCPM-V-4.6-gguf",
                msRepo = "OpenBMB/MiniCPM-V-4.6-gguf",
                ggufMd5 = "fd778481dd56b6036dd8f9cf7c1519cf",
                mmprojMd5 = "54aea6e04d752f47309a48f12795a1a3",
                version = 46
            ),
            ModelInfo(
                id = "minicpm-v-4",
                displayName = "MiniCPM-V-4 (Q4_K_M)",
                description = "Lightweight multimodal model, image/text understanding (4.1B)",
                ggufFileName = "ggml-model-Q4_K_M.gguf",
                mmprojFileName = "mmproj-model-f16.gguf",
                hfRepo = "openbmb/MiniCPM-V-4-gguf",
                msRepo = "OpenBMB/MiniCPM-V-4-gguf",
                version = 5
            )
        )

        val DEFAULT_MODEL = AVAILABLE_MODELS.first()

        fun findById(id: String): ModelInfo? = AVAILABLE_MODELS.find { it.id == id }
    }
}
