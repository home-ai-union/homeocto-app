# MiniCPM-V consumer ProGuard rules
# These rules are applied when the library is consumed by the app module.

# Preserve all MiniCPM-V classes (JNI + Activities + Services)
-keep class com.example.minicpm_v_demo.** { *; }

# Preserve JNI native method signatures
-keepclasseswithmembernames class com.example.minicpm_v_demo.LlamaEngine {
    native <methods>;
}
