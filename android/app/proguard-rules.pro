# Proguard rules for Fuel Expense Tracker
# This file specifies classes and methods to keep while still allowing minification

# Keep Flutter and Dart classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-keep class com.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep our app classes
-keep class com.fueltracker.fuel_expense_tracker.** { *; }

# Keep SQLite
-keep class android.database.sqlite.** { *; }

# Keep permission handler
-keep class com.baseflow.permissionhandler.** { *; }

# Keep local notification classes
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Keep geocoding/geolocation
-keep class io.flutter.plugins.geolocator.** { *; }
-keep class io.flutter.plugins.geocoding.** { *; }

# Keep connectivity_plus
-keep class io.flutter.plugins.connectivity.** { *; }

# Keep fl_chart
-keep class com.github.philjay.mpandroidchart.** { *; }

# Keep image picker
-keep class com.example.imagepicker.** { *; }

# Keep camera
-keep class io.flutter.plugins.camera.** { *; }

# Keep shared preferences
-keep class com.codetroopers.libraries.** { *; }

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Optimization options
-optimizationpasses 5
-dontusemixedcaseclassnames
-verbose

# Remove unused code
-dontshrink
-dontoptimize

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom view constructors
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}

# Keep enum values
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep generated classes
-keep class **.R$* {
    <fields>;
}

# Preserve line numbers for debugging
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
