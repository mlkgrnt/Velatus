# R8 rules for Velatus.
#
# The ML Kit text-recognition plugin compiles against every script it supports
# (Latin, Chinese, Devanagari, Japanese, Korean) but only the Latin model comes
# in transitively. Velatus adds the Chinese model on purpose; the other three
# stay out of the APK, so their dangling references only need to be silenced.

-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit builds its pipeline from a component graph that is resolved at runtime
# through reflection. Shrinking or renaming any part of it makes
# MlKitInitProvider throw "Unsatisfied dependency for component ..." before the
# first frame, which only ever shows up in release builds. Keep the SDK whole.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }

# The Dart bridge talks to these two by name.
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google_mlkit_commons.** { *; }

# Annotation metadata read reflectively when the model is loaded.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
