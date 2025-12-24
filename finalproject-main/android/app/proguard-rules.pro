# Flutter Core & Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# Critical: Keep the generated plugin registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Android Lifecycle often needed by plugins
-keep class androidx.lifecycle.** { *; }


# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.auth.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }


# Sqflite
-keep class com.tekartik.sqflite.** { *; }

# Tflite
-keep class com.tflite_flutter.** { *; }
-keep class org.tensorflow.lite.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# SquareUp (often used by networking libs)
-keep class com.squareup.** { *; }
-keepnames class com.squareup.** { *; }

# FFmpeg Kit
-keep class com.arthenica.ffmpegkit.** { *; }

# Google Play Core (Deferred Components)
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Video Thumbnail
-keep class xyz.justsoft.video_thumbnail.** { *; }

# Flutter Blue Plus
-keep class com.boskokg.flutter_blue_plus.** { *; }

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }

# Share Plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# Generic Flutter Plugin interfaces
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.embedding.engine.plugins.** { *; }

