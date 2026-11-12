# flutter_secure_storage uses Google Tink, which references compile-time-only annotation
# classes (Error Prone, JSR-305) that are not in the APK. They have no runtime effect.
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-keep class com.google.crypto.tink.** { *; }

# Flutter Play Core / deferred components are not used.
-dontwarn com.google.android.play.core.**
