# Flutter ProGuard Rules
# This file is used to configure ProGuard/R8 for release builds

# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }
-dontwarn io.flutter.embedding.**

# PicoClaw
-keep class com.homeai.homeocto.** { *; }

# Umeng Analytics
-keep class com.umeng.** { *; }
-keepclassmembers class * {
    public <init> (org.json.JSONObject);
}
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
-keep public class com.homeai.homeocto.R$* {
    public static final int *;
}

# Prevent R8 from stripping necessary method signatures
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Fix R8 missing class errors for javax.xml.stream (not available on Android)
# Referenced by Apache Tika (transitive dependency from Umeng SDK)
-dontwarn javax.xml.stream.**
-dontwarn javax.xml.XMLConstants
-keep class javax.xml.stream.** { *; }
-keep class org.apache.tika.** { *; }
-dontwarn org.apache.tika.**

# Ktor and Netty ProGuard Rules
# Netty optional dependencies (TC Native, BouncyCastle, Conscrypt, etc.)
-dontwarn io.netty.internal.tcnative.**
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.apache.log4j.**
-dontwarn org.apache.logging.log4j.**
-dontwarn org.eclipse.jetty.npn.**
-dontwarn reactor.blockhound.**
-dontwarn java.lang.management.**

# Keep Ktor serialization classes
-keep class kotlinx.serialization.** { *; }
-keepclassmembers class kotlinx.serialization.** { *; }

# Keep Ktor server classes
-keep class io.ktor.** { *; }
-keepclassmembers class io.ktor.** { *; }
