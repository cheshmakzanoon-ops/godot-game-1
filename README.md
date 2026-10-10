# NEEDLEBEAT: DROP — playable Godot 4.7.2 Android game

**Tagline:** Every shot risks the run. Every shot writes the song.

This is an actual Godot 4 portrait project implementing the core game described in `design/ORIGINAL_GDD.md`. It includes gameplay source, 50 original synthesized sound effects/instruments, a deterministic four-bar music sequencer, saves, song codes, a daily challenge, tests, Android export preset, and a GitHub Actions workflow.

**Current verification:** Godot **4.7.2** imports and runs this project. The Godot smoke, full-game and process-recovery suites now execute in CI alongside the Python tests. GitHub Actions previously built a signed ARM64 debug APK and passed the Android 15 emulator's launch, tap, WAV export and native sharing gate on October 10, 2026; physical-device audio and touch testing remains outstanding. New musical compositions use **NBD2**: seed-driven, genre-specific chord progressions with chord-tone downbeats. Original **NBD1** codes replay byte-identically with the old music grammar. See `docs/DEVELOPMENT_HANDOFF.md`.

## Open and play

1. Install **Godot 4.7.2 Standard** (not .NET). Godot 4.6+ should use compatible GDScript syntax, but 4.7.2 is the target.
2. Import this folder's `project.godot` in the Godot Project Manager.
3. Press **F6 / F5** or click **Run Project**. The game is portrait, 480×854 logical resolution, Compatibility renderer.
4. Click **MAKE A TRACK**. Tap below/around the record to shoot a pin. Avoid existing pins. Missing a shot restarts only the current record. Clear BEAT, ROOT, HOOK, DROP, then hear the full song.
5. Results: **SAVE TO LIBRARY**, **SHARE / COPY SONG CODE**, **EXPORT AUDIO (.WAV)**, and **NEW TRACK**.

Desktop mouse click and Android single-finger taps have the same semantics. The top-right pause control (or Escape) holds the disc clock and audio transport until resumption; Android app defocus also pauses the game. In the results view, Android song-code sharing uses the system text share chooser when Godot's built-in AndroidRuntime bridge is available; otherwise the code is copied to the clipboard.

## What is implemented

- Four records: BEAT (6 shots), ROOT (7), HOOK (8), DROP (9); deterministic preinstalled obstacles.
- Fixed **110ms** flight with impact-phase angular collision at **12°**, EDGE through **19°**, and PERFECT within **7°** of a sixteenth-note notch.
- Deterministic analytic disc motion: ordinary speed, bar-alternating PULSE, eased REWIND with two-beat visual warning, and alternating concentric TWIN rings.
- Safe shot/edge/perfect/combo/stage/optional two-shot encore scoring, with failed stage points discarded.
- A **four-bar 16-step composition** built from landed pins. NBD2 includes three seed-selected progressions per genre, correct major/minor chord quality, chord-tone melody on downbeats, a shared ahead-of-time audio buffer and WAV renderer. NBD1 remains exact for existing share codes.
- Five playable genre palettes: PULSE, CASSETTE, POCKET, PIXEL, AFTER HOURS. Unlock after 0/3/8/16/30 completed campaign songs.
- UTC daily challenge derived from stable SHA-256 and fixed difficulty independent of campaign progression. Local, non-authoritative daily best scores only.
- Versioned offline saves with backup recovery, up to 20 favorite songs, and **in-progress song checkpoints** (notes, pins, score, retries, completed stages). Relaunch after Android process death offers an explicit **RECOVERED / CONTINUE RECORD** pause screen. Mid-flight pins are refunded rather than silently scored.
- `NBD2` song-code checksum and bounded import with fully supported legacy `NBD1` playback.
- 50 procedurally generated WAV instrument/effect assets, plus original game icon and code to regenerate it.
- Desktop and Android input, haptics toggle, music level, effects toggle, reduced ambient-motion option, no account/network/ads/IAP.

## Current limitations (not production-ready)

- **Godot engine and signed ARM64 debug APK verified in GitHub CI.** Real Android hardware testing, audio latency/speaker performance and true one-thumb touch playtests remain outstanding.
- `EXPORT AUDIO (.WAV)` creates a valid RIFF/PCM file under `user://exports/`; Android's native FileProvider share chooser has passed emulator QA. Real recipient-app/device testing remains outstanding.
- No signed release AAB, global leaderboard, physical-device performance/thermal playtest suite, screen reader support, or final Play Store QA.
- REWIND physically eases at reversal boundaries, but custom pixel-precise rendering and audio/device latency still require Android validation.
- Audio is an original low-CPU-oriented GDScript PCM mixer at 22,050 Hz. Benchmark on an Android device before shipping; the mix-quality goal in the GDD is not yet playtest-validated.
- UI is intentionally drawn in code; menus use editor font fallback rather than the production font art system.

## Source layout

```text
project.godot                    Godot 4 project configuration
scenes/Main.tscn                Main playable Control scene
scripts/Game.gd                 Screens, gameplay state, drawing, input and feedback
scripts/Geometry.gd             Angles, angular collision, grading and impact
scripts/DiscMotion.gd           Pure analytic phase vs. time, motion specials
scripts/StageDirector.gd        Deterministic preloads/difficulties/daily/genres
scripts/MusicEngine.gd          Sample-accurate per-step synth arrangement mixer
scripts/AudioSystem.gd          Generator playback and identical offline WAV mixer
scripts/AndroidShare.gd         AndroidRuntime JavaClassWrapper text chooser
scripts/ProgressStore.gd       Local offline saves, active-song checkpoints, settings, backups
scripts/SongCodec.gd            Versioned checked song-code import/export
scripts/*.gd                    9 GDScript files
assets: audio/0..4/*.wav        50 one-shots at 22.05kHz, original synthesized
art/icon.png                   App launcher icon
art/icon_adaptive.png          Adaptive icon initial asset
tools/generate_sounds.py       Rebuilds all audio assets
tools/make_icon.py             Rebuilds icon assets
tests/test_project.py          Host-only suite
tests/smoke.gd                 Godot engine smoke / WAV / schema test
tests/full_flow.gd             Four-record, score rollback, encore, v1/v2 music regression
tests/checkpoint_flow.gd       Process-death recovery, backup fallback, transport restoration
.github/workflows/ci.yml       Engine test + ARM64 Android debug build jobs
export_presets.cfg             Android and Windows export presets
design/ORIGINAL_GDD.md         Unmodified game design document
```

## Run tests

On any computer with Python 3 installed:

```bash
python -m unittest discover -s tests -p 'test_*.py' -v
```

With Godot 4.7.2 installed:

```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . --script res://tests/full_flow.gd
```

First-party authored `.gd`/`.py` source is counted by `tests/test_project.py`; it is kept under the GDD's 5,000-line guideline, including tests, synthesis, and tooling. Resource files and assets are not included in that count.

## Android APK build

Refer to `BUILD_ANDROID.md`. For local device installs, use the Android **debug** preset. The included GitHub Actions workflow runs the host tests, two engine test suites, exports and verifies a signed ARM64 debug APK, and uploads that APK as an artifact. See the latest build's status under the repository's **Actions** tab. For Google Play submission, Gradle build template, AAB export, release signing, privacy declarations and on-device validation remain mandatory.

## License and content

All audio samples and the icon in this project were generated from the included scripts. No external copyrighted recordings are bundled. The original GDD is provided by the project owner. Source may be revised or commercially licensed by the project owner after review.

### Sharing the actual WAV on Android

The results screen's **EXPORT / SHARE WAV** control renders the stereo
four-bar RIFF WAV and opens Android's native audio share sheet. It uses
Godot 4.7.2's preinstalled `FileProvider` through `JavaClassWrapper` and
temporarily grants `content://` read access to the selected WAV only.
No Gradle custom build, plugin, external storage permission or network is
needed. Desktop exports remain saved under the Godot user-data directory.
See `BUILD_ANDROID.md` for details and outstanding real-device tests.

## Android runtime regression test

The CI workflow now includes an Android 15 x86_64 emulator gate for app startup, actual touch navigation, screenshot transitions, PCM WAV rendering and an Android share-sheet integration test using Godot's existing FileProvider. Runtime artifacts include screenshots and logcat. The test entry point is disabled in release builds and inaccessible without an explicit debug-only adb launch extra. Real devices still need audio latency and accessibility playtesting.

## Interrupted sessions / Android process-death safety

An unfinished song is saved after every successful shot, stage transition and
application pause. Android is free to terminate a backgrounded process, so
the next launch restores the same deterministic disc, planted pins, song notes,
score and retry counts into an **explicit paused recovery screen**. A shot
interrupted in flight is not counted; the player can fire it again. Completed
songs and intentionally abandoned runs clear this checkpoint.

`tests/checkpoint_flow.gd` covers simulated restart, JSON disk persistence,
corrupt-primary backup recovery, accurate restored audio PCM, and no score
duplication. The Android emulator script additionally force-stops the running
app after a debug-only one-shot checkpoint and checks that an ordinary relaunch
restores it. See `docs/SESSION_RECOVERY.md`.

## Android audio interruption and manual resume

Android calls, other music apps and system audio-focus interruptions now have
an explicit `AudioManager` bridge (`scripts/AndroidAudioFocus.gd`) using the
API-compatible listener/stream focus request. All audio
focus losses suspend the song and persist unfinished records; focus gain never
starts playing behind an interruption screen. Tap **RESUME** after the phone
returns to normal. Pausing or leaving a record releases audio focus for other
apps. This is tested with a synthetic Android callback and headless Godot
checks; see `docs/AUDIO_FOCUS.md`. A real phone-call and Bluetooth test is still
required on physical hardware.
