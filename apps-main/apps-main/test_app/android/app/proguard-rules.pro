# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Sqflite
-keep class com.tekartik.sqflite.** { *; }

# Firebase
-keep class io.flutter.plugins.firebase.** { *; }
-keep class com.google.firebase.** { *; }

# General
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Play Core
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
