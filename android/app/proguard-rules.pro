# Prevent R8 from aggressive optimizations that break reflection
-dontoptimize

# Play Core and deferred components warnings
-dontwarn com.google.android.play.core.**

# Keep WorkManager and Room Database classes from being stripped or obfuscated
-keep class androidx.work.** { *; }
-keep interface androidx.work.** { *; }
-keep class androidx.room.** { *; }
-keep class androidx.sqlite.** { *; }
-keep class androidx.sqlite.db.** { *; }
-keep class androidx.sqlite.db.framework.** { *; }
-keep class * extends androidx.room.RoomDatabase {
    public <init>();
    *;
}
-keep class * extends androidx.work.impl.WorkDatabase {
    public <init>();
    *;
}
-keep class androidx.work.impl.WorkDatabase {
    public <init>();
    *;
}
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
    *;
}
-keep class **_Impl {
    public <init>(...);
    *;
}
-keepclassmembers class * extends androidx.room.RoomDatabase {
    public <init>();
    *;
}
-dontwarn androidx.work.**
-dontwarn androidx.room.**
-dontwarn androidx.room.paging.**

# Google Mobile Ads & User Messaging Platform (UMP)
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-keep class com.google.android.ump.** { *; }
-keep class io.flutter.plugins.googlemobileads.** { *; }

# App and Flutter Plugin Classes
-keep class app.mediaurl.applicaiton.** { *; }
-keep class io.flutter.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
