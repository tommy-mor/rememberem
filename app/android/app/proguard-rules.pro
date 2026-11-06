# Release builds shrink code. flutter_local_notifications stores scheduled
# reminders with Gson, which needs these generic types and the plugin's
# model classes intact, or scheduling fails silently in release only.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.** { *; }

# Google ML Kit face detection (capture): its plugin and SDK use reflection;
# without these, face finding throws in release builds only.
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_face_detection.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_face** { *; }
-dontwarn com.google.mlkit.**

# Place notices: the geofence plugin's worker, receivers and callback
# lookup run with the app closed; shrinking could silently stop them.
-keep class com.chunkytofustudios.native_geofence.** { *; }

# WorkManager (pulled in by plugins): the app crashes at startup in release
# when R8 strips the generated WorkDatabase_Impl constructor, which Room and
# WorkManager look up by reflection.
-keep class androidx.work.impl.WorkDatabase_Impl { <init>(); }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.** { *; }
