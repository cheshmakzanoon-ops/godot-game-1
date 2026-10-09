#!/usr/bin/env bash
# Reproducible Android toolchain for NEEDLEBEAT: DROP / Godot 4.7.2.
# Downloads binaries from Google and Gradle; requires internet and sufficient disk space.
set -euo pipefail
if [[ "$(uname -sm)" != "Linux x86_64" ]]; then
  echo "This installer targets Linux x86_64. Use Android Studio for another OS." >&2
  exit 2
fi
for cmd in curl unzip sha256sum java; do command -v "$cmd" >/dev/null || { echo "Missing prerequisite: $cmd" >&2; exit 2; }; done
if ! command -v javac >/dev/null; then echo "Install OpenJDK 17 or 21 first." >&2; exit 2; fi
JAVA_MAJOR=$(java -version 2>&1 | sed -nE 's/.*version "([0-9]+).*/\1/p' | head -n1)
if [[ -z "$JAVA_MAJOR" || "$JAVA_MAJOR" -lt 17 ]]; then echo "Java 17+ required." >&2; exit 2; fi
SDK_DIR="${ANDROID_HOME:-$HOME/Android/Sdk}"
GRADLE_VERSION="9.6.1"
GRADLE_DIR="$HOME/.local/share/needlebeat/gradle-$GRADLE_VERSION"
CMDLINE_VERSION="15859902"
CMDLINE_SHA256="4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/needlebeat-downloads"
mkdir -p "$SDK_DIR/cmdline-tools" "$CACHE" "$(dirname "$GRADLE_DIR")"
if [[ ! -x "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" ]]; then
  ARCHIVE="$CACHE/commandlinetools-linux-${CMDLINE_VERSION}_latest.zip"
  curl -fL --retry 3 -o "$ARCHIVE" "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_VERSION}_latest.zip"
  echo "$CMDLINE_SHA256  $ARCHIVE" | sha256sum -c -
  TEMP=$(mktemp -d)
  trap 'rm -rf "$TEMP"' EXIT
  unzip -q "$ARCHIVE" -d "$TEMP"
  test -x "$TEMP/cmdline-tools/bin/sdkmanager" || chmod +x "$TEMP/cmdline-tools/bin/sdkmanager"
  rm -rf "$SDK_DIR/cmdline-tools/latest"
  mv "$TEMP/cmdline-tools" "$SDK_DIR/cmdline-tools/latest"
fi
export ANDROID_HOME="$SDK_DIR" ANDROID_SDK_ROOT="$SDK_DIR"
export PATH="$SDK_DIR/cmdline-tools/latest/bin:$SDK_DIR/platform-tools:$SDK_DIR/emulator:$PATH"
echo "Android SDK licenses must be reviewed and accepted interactively:"
sdkmanager --licenses
sdkmanager --sdk_root="$SDK_DIR" \
  'platform-tools' 'build-tools;35.0.1' 'platforms;android-35' 'cmdline-tools;latest' \
  'cmake;3.10.2.4988404' 'ndk;28.1.13356709' \
  'emulator' 'system-images;android-35;google_apis;x86_64'
if [[ ! -x "$GRADLE_DIR/bin/gradle" ]]; then
  ARCHIVE="$CACHE/gradle-${GRADLE_VERSION}-bin.zip"
  SHA="$CACHE/gradle-${GRADLE_VERSION}-bin.zip.sha256"
  curl -fL --retry 3 -o "$ARCHIVE" "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip"
  curl -fL --retry 3 -o "$SHA" "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip.sha256"
  printf '%s  %s\n' "$(head -c 64 "$SHA")" "$ARCHIVE" | sha256sum -c -
  unzip -q "$ARCHIVE" -d "$(dirname "$GRADLE_DIR")"
fi
AVD_NAME="Needlebeat_API_35"
if [[ -e /dev/kvm ]]; then
  if ! avdmanager list avd | grep -Fq "Name: $AVD_NAME"; then
    echo no | avdmanager create avd -n "$AVD_NAME" -k 'system-images;android-35;google_apis;x86_64' --force
  fi
else
  echo "Emulator binaries installed but this host has no /dev/kvm; hardware-accelerated AVD launch unavailable." >&2
fi
cat > "$HOME/.needlebeat_android_env" <<ENV
export ANDROID_HOME="$SDK_DIR"
export ANDROID_SDK_ROOT="$SDK_DIR"
export PATH="$SDK_DIR/cmdline-tools/latest/bin:$SDK_DIR/platform-tools:$SDK_DIR/emulator:$GRADLE_DIR/bin:\$PATH"
ENV
printf '\nTo activate SDK and Gradle in a new shell: source %s/.needlebeat_android_env\n' "$HOME"
printf 'Android tools: '; "$SDK_DIR/platform-tools/adb" version | head -n1
printf 'Gradle version: '; "$GRADLE_DIR/bin/gradle" --version | grep -m1 '^Gradle '
printf 'Godot config: Editor > Editor Settings > Export > Android; SDK path: %s ; Java path: %s\n' "$SDK_DIR" "$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"