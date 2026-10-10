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

## Android audio sharing (Godot 4.7.2 built-in FileProvider)

Godot 4.7.2 includes an AndroidX `FileProvider` with the authority
`<applicationId>.fileprovider`, mapping the app's private `filesDir`.
The game's `NBAndroidShare.share_wav` uses `JavaClassWrapper` and the
`AndroidRuntime` singleton to construct a `content://` URI for the finished
WAV in `user://exports/`, grant temporary read access, and open the native
Android share chooser. **No custom Android plugin or Gradle template is needed.**

The established non-Gradle debug APK export remains:

```bash
godot --headless --path . --export-debug Android build/NEEDLEBEAT_DROP-debug.apk
```

The recipient gets a read grant only to the chosen URI, not all user data.
No file:// link, microphone permission, broad storage access, or network
account is required. The provider is defined by Godot's Android library.

**Real-phone acceptance:** Complete a song, tap `EXPORT / SHARE WAV`, select
an audio-capable target, and check that the recipient can open the 4-bar WAV;
repeat after background/resume, a cancelled chooser, and with no target app.
Android device testing remains outstanding until an actual device is used.

## Android emulator runtime gate

The `android-emulator` GitHub Actions job runs on an API 35 x86_64 emulator. The
shipping ARM64 debug artifact is unchanged. CI exports a separate x86_64-only
APK, installs and launches it, taps PLAY, verifies screenshots are distinct,
then launches a **debug-only** test intent with `needlebeat.qa=wav_share`. The
Godot test script generates a RIFF PCM WAV and invokes the actual Android
`FileProvider` share chooser. The test fails unless Android logcat confirms
the WAV and share intent and the Android sharesheet becomes visible.

Emulator screenshots, logs and window state are uploaded as a separate
`NEEDLEBEAT_DROP_Emulator_Evidence` artifact. The instrumentation is disabled
in release builds and inactive for ordinary user launches. This is **not** a
substitute for physical-device speaker/Bluetooth latency and tap tests.
