# flutter_secure_storage uses Google Tink, which references classes that are not in the
# APK and are never used at runtime: compile-time annotations (Error Prone, JSR-305) and
# the optional Google HTTP client / Joda time behind Tink's KeysDownloader.
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn com.google.api.client.http.**
-dontwarn com.google.api.client.http.javanet.**
-dontwarn org.joda.time.**

# Flutter Play Core / deferred components are not used.
-dontwarn com.google.android.play.core.**
