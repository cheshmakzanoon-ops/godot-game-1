# Android development builds

Target: **Godot 4.7.2 Standard**, OpenJDK 17, a portrait Compatibility-renderer
project. Current Android package: `com.needlebeat.drop`, version 0.2.0/code 2.

## Local Android APK

Install the matching Godot export templates and Android command-line tools.
The verified debug APK workflow installs `platform-tools`, `build-tools;35.0.1`,
`platforms;android-35`, `cmdline-tools;latest`, `cmake;3.10.2.4988404`, and
`ndk;28.1.13356709`. Set the Java and Android SDK paths in Godot's Editor Settings.
The NDK/CMake are not used to recompile the engine in the standard APK export.

```bash
mkdir -p build
godot --headless --editor --path . --import --quit
godot --headless --path . --export-debug Android build/NEEDLEBEAT_DROP-debug.apk
adb install -r build/NEEDLEBEAT_DROP-debug.apk
```

Do not mistake this debug-signed APK for a production-signed Play release. Use
owner-controlled keys outside source control for production. No key/password
should be committed. Godot's prebuilt template contains the engine; the app's
GDScript, resources, and original PCM samples are included by the exporter.

## CI and evidence

`.github/workflows/ci.yml` publishes an exact source snapshot plus its commit ID,
runs Python and isolated Godot suites, exports ARM64 and x86_64 debug APKs,
verifies Android signatures/package declarations, and starts an Android 15
x86_64 emulator. Engine logs and Android screenshots/logcat are separate artifacts.

The software emulator uses `-gpu swangle`: the older `swiftshader_indirect`
backend failed to link Godot's GLES3 shaders in prior runs. The product remains
on Godot's Compatibility renderer. The emulator check is not a phone benchmark.

`tools/android_emulator_smoke.sh` tests actual launch/tap/rendering and native WAV
chooser behavior, synthetic audio focus, process-death recovery, and a 40-second
performance sample. `tools/android_native_back.sh` additionally sends an actual
ADB Back key and requires the application to stay alive on a paused record.
The debug probes are inactive without their explicit launch extras and are
blocked in release builds. Native navigation is production behavior, not a probe.

## Sharing and haptics

The game uses Godot's existing AndroidX FileProvider via JavaClassWrapper, a
`content://` URI, ClipData, and a temporary read grant for the selected WAV.
No custom manifest/plugin, broad storage access, microphone, Internet permission,
or network account is required. `permissions/vibrate=true` is enabled so the
haptics toggle can work; actual hardware vibration is still a physical-device test.

Native Back is routed through the root Window signal with automatic mobile quit
disabled. It pauses a moving record, remains paused on another Back, closes Import
to Library, and leaves other menus for Studio. The Continue control resumes;
Back at Studio exits. Desktop window close checkpoints before stopping audio.

## Production requirements

Read `docs/RELEASE_READINESS.md`. A production AAB, secure upload key, current
store-policy/data-safety review, physical-device performance/audio/route/call
checks, receiving-app WAV validation, and blind gameplay/music tests are still
required. No production or physical-device signoff has been claimed.
