# NEEDLEBEAT: DROP — durable development context

Project repository: https://github.com/cheshmakzanoon-ops/godot-game-1

Engine: Godot 4.7.2 **standard**, Linux x86-64 executable. Godot script files, not Kotlin, implement the main game. The renderer is GL Compatibility, portrait 480×854, 2D/GDScript. The original GDD is `design/ORIGINAL_GDD.md`. Keep application code under the 5,000-line target where practical.

Engine source ZIP is saved in the user's ChatGPT Library at `/GameDev/NEEDLEBEAT_DROP/toolchains/Godot_v4.7.2-stable_linux.x86_64.zip`. Engine binary extraction: `unzip 'Godot_v4.7.2-stable_linux.x86_64.zip' -d /opt/godot/4.7.2 && chmod +x /opt/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64`. Then link it as `godot` or invoke by full path. Environments are not guaranteed to persist across chats: re-download the Library artifact and re-install if necessary. Do not commit the 140 MB engine binary into the game repository.

Run engine tests after importing project resources:

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/smoke.gd
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

October 9, 2026: Godot 4.7.2 headless import and **15/15 engine smoke checks passed** after fixing prior GDScript errors in geometry (`NBGeometry.wrap()`), type inference (`StageDirector.gd`, `MusicEngine.gd`), song-code validation indentation, `preload` reserved keyword in drawing, and a malformed secondary export preset. The checks do not prove Android performance or a full manual gameplay session. The same run noted a nonfatal ObjectDB cleanup warning.

**Android environment constraints at that check:** OpenJDK 21, Kotlin compiler, CMake installed; no local Android SDK/ADB, standalone Gradle, or emulator. Internet DNS for `dl.google.com` and `github.com` unavailable from the container; `/dev/kvm` absent. These are environment limitations, not proof the app cannot build. The existing GitHub Actions workflow installs SDK packages and can export a debug Android APK after engine tests. `tools/bootstrap_android_linux.sh` bootstraps SDK, ADB, Gradle, emulator packages/AVD on a networked Linux host. Emulation needs KVM; Android hardware can be tested with ADB on a local device.

Priority remaining work: complete and verify GitHub Actions Android APK export; test touch/audio on a real Android phone; implement secure WAV sharing with Android FileProvider; accessibility and device latency/thermal tests; release signing and AAB export. Do not claim Play-ready status without these checks.