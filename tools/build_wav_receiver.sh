#!/usr/bin/env bash
# Build a permission-free QA recipient using SDK tools; no Gradle/dependencies.
set -euo pipefail
sdk="${ANDROID_HOME:?Android SDK required}"
bt="$sdk/build-tools/35.0.1"
platform="$sdk/platforms/android-35/android.jar"
out="$PWD/build/wav-receiver"
mkdir -p "$out/classes" "$out/dex"
javac -source 8 -target 8 -classpath "$platform" -d "$out/classes" \
  tests/android_receiver/src/com/needlebeat/wavverifier/ReceiveActivity.java
mapfile -t classes < <(find "$out/classes" -name '*.class' -type f | sort)
"$bt/d8" --lib "$platform" --min-api 24 --output "$out/dex" "${classes[@]}"
"$bt/aapt" package -f -M tests/android_receiver/AndroidManifest.xml \
  -I "$platform" -F "$out/raw.apk"
(cd "$out/dex" && "$bt/aapt" add "$out/raw.apk" classes.dex)
"$bt/zipalign" -f 4 "$out/raw.apk" "$out/aligned.apk"
if [[ ! -f "$out/qa.keystore" ]]; then
  keytool -genkeypair -noprompt -keystore "$out/qa.keystore" -alias qa \
    -storepass android -keypass android -keyalg RSA -keysize 2048 -validity 30 \
    -dname 'CN=NEEDLEBEAT Test Recipient'
fi
"$bt/apksigner" sign --ks "$out/qa.keystore" --ks-key-alias qa --ks-pass pass:android \
  --out build/NEEDLEBEAT_WAV_Verifier.apk "$out/aligned.apk"
"$bt/apksigner" verify build/NEEDLEBEAT_WAV_Verifier.apk
