# ── Flutter engine ────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.app.** { *; }

# ── Flutter eklentileri ───────────────────────────────────────────────────────

# flutter_local_notifications — receiver/service sınıfları AndroidManifest'te kayıtlı
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# camera
-keep class androidx.camera.** { *; }

# geolocator
-keep class com.baseflow.geolocator.** { *; }

# sensors_plus
-keep class dev.fluttercommunity.plus.sensors.** { *; }

# connectivity_plus
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# share_plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# audioplayers
-keep class xyz.luan.audioplayers.** { *; }

# ── Kotlin coroutines ─────────────────────────────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

# ── Annotation & reflection ───────────────────────────────────────────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable

# Crash raporları için satır numarasını koru
-renamesourcefileattribute SourceFile
