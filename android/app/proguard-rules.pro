# Google Mobile Ads SDK ProGuard rules
-keep public class com.google.android.gms.ads.** {
   public *;
}
-keep public class com.google.ads.** {
   public *;
}

# User Messaging Platform (UMP) SDK
-keep public class com.google.android.ump.** {
   public *;
}

# Native Ad Factory & Application Classes
-keep public class app.mediaurl.applicaiton.** {
   public *;
}

# Preserve Javascript interface if used
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
