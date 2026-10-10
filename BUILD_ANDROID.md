# Android build guide for NEEDLEBEAT: DROP

Target: Godot 4.7.2 Standard, OpenJDK 17, Android SDK platform 35, Build-Tools 35.0.1, NDK 28.1.13356709 (only if you use native modules). The Godot 4.7 Android exporter is documented at https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html .

## On your development computer

1. Install Godot 4.7.2 and download the matching Godot export templates via **Editor → Manage Export Templates**.
2. Install Android Studio or the Android SDK command-line tools. Use `sdkmanager` to install: `platform-tools`, `build-tools;35.0.1`, `platforms;android-35`, `cmdline-tools;latest`, `cmake;3.10.2.4988404`, `ndk;28.1.13356709`.
3. Install **OpenJDK 17**. In Godot's Editor Settings → Export → Android, set `Android SDK Path` and `Java SDK Path`.
4. Import `project.godot`, open `Project → Export`, and select the existing **Android** preset (or create a new one with package `com.needlebeat.drop` and ARM64 enabled).
5. Export **Debug** to `build/NEEDLEBEAT_DROP-debug.apk` or use a terminal:

```bash
mkdir -p build
godot --headless --editor --path . --import --quit
godot --headless --path . --export-debug 'Android' build/NEEDLEBEAT_DROP-debug.apk
```

6. Install to a USB-connected phone with ADB:

```bash
adb install -r build/NEEDLEBEAT_DROP-debug.apk
```

**Note:** A source zip is **not** an APK. Debug APK export was verified on GitHub Actions with the matching Godot template and Android `apksigner` (v2 and v3). Re-run CI after making changes; hardware testing is still required.

## GitHub Actions path

Place the project folder at the root of a GitHub repository. On push or via `workflow_dispatch`, `.github/workflows/ci.yml` requests the Godot 4.7.2 engine with export templates, runs the host and engine smoke tests, configures Android SDK/JDK, and attempts an ARM64 debug export. A successful job publishes the downloadable APK as a workflow artifact. The October 9, 2026 build passed Godot tests and Android signature verification. Subsequent changes must re-pass CI; download the APK from the latest successful workflow's artifacts.

## Google Play release

The Play Store requires a signed release **AAB**, not an unsigned or debug APK. Enable **Gradle Build** in the Android export preset, install the Android build template, configure a securely stored release signing key, update version code and package identity, and use `--export-release` to generate an `.aab`. Do not place keystore passwords in the repo. Complete Android audio-focus, haptic, permission, thermal, accessibility, crash, privacy, and Play policy tests before production rollout.

The game itself is designed for offline play, does not need microphone permission, and does not make network calls. Android share chooser for **text** is implemented via the built-in `AndroidRuntime` bridge; third-party WAV sharing via secure `content://` URI is pending.
