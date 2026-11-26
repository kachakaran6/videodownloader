# Prevent R8 from aggressive optimizations that break reflection
-dontoptimize

# Play Core and deferred components warnings
-dontwarn com.google.android.play.core.**

# Keep WorkManager and Room Database classes from being stripped or obfuscated
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.work.impl.WorkDatabase { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-dontwarn androidx.work.**
-dontwarn androidx.room.**

# Google Mobile Ads & User Messaging Platform (UMP)
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-keep class com.google.android.ump.** { *; }
-keep class io.flutter.plugins.googlemobileads.** { *; }

# App and Flutter Plugin Classes
-keep class app.mediaurl.applicaiton.** { *; }
-keep class io.flutter.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
