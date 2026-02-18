# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Alarm Manager Plus
-keep class dev.fluttercommunity.plus.alarm_manager.** { *; }
-keep public class dev.fluttercommunity.plus.alarm_manager.AlarmBroadcastReceiver { *; }

# Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Audio Players
-keep class xyz.luan.audioplayers.** { *; }

# Standard Android components
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Fix for R8 warnings regarding missing classes
-dontwarn android.test.**
-dontwarn android.support.test.**
-dontwarn org.junit.**
-dontwarn org.mockito.**
-dontwarn io.flutter.**
-dontwarn dev.fluttercommunity.plus.alarm_manager.**
-dontwarn com.dexterous.flutterlocalnotifications.**
