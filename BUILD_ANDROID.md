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

## Native WAV sharing (new)

This Android export now requires a **Gradle build** so it can compile a tiny Java
`FileProvider` bridge. After installing the Android SDK and Godot export templates:

```bash
mkdir -p android/build
unzip -q "$HOME/.local/share/godot/export_templates/4.7.2.stable/android_source.zip" -d android/build
echo '4.7.2.stable' > android/.build_version
touch android/build/.gdignore
chmod +x android/build/gradlew
python tools/prepare_android_share.py
godot --headless --path . --export-debug Android build/NEEDLEBEAT_DROP-debug.apk
```

`tools/prepare_android_share.py` is idempotent. It injects the bridge source,
AndroidX core dependency and provider declaration into the generated (gitignored)
`android/build/` folder. It must be rerun whenever the template is regenerated.
The provider can grant read access **only** to audio copied into
`cache/shared_audio/`; exported WAVs remain in `user://exports/`.
There is no microphone, external-storage or broad file permission.

**Device acceptance:** Complete a song, select **EXPORT / SHARE WAV**, choose
a mail/chat/file app, verify the recipient can play the stereo four-bar WAV,
and retry with no matching share app. Test background/resume and Android 10+.
Those on-device checks have not yet been performed.

Note: `--install-android-build-template --quit` does not install the template by itself; CI explicitly extracts the matched Godot 4.7.2 source template.
