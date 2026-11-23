# R8 rules for Velatus.
#
# The ML Kit text-recognition plugin compiles against every script it supports
# (Latin, Chinese, Devanagari, Japanese, Korean) but only the Latin model comes
# in transitively. Velatus adds the Chinese model on purpose; the other three
# stay out of the APK, so their references only need to be silenced.

-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit is driven from generated code and reflection-adjacent entry points;
# shrinking its internals breaks model loading at runtime.
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google_mlkit_commons.** { *; }

# Keep the annotation metadata ML Kit reads at runtime.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
