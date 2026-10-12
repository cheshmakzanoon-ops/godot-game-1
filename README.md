# NEEDLEBEAT: DROP

**Every shot risks the run. Every shot writes the song.**

A portrait, offline Android music game built with **Godot 4.7.2 Standard** and the
2D Compatibility renderer. Current development version: **0.2.0**, version code 2.
The original design is preserved in `design/ORIGINAL_GDD.md`.

## Play

Import `project.godot` in Godot 4.7.2 and press F5. Choose **MAKE A TRACK**.
Tap to launch pins without hitting an embedded pin. Complete **BEAT**, **ROOT**,
**HOOK**, and **DROP** to build drums, bass, melody, and harmony. A failed record
resets only that record. Optional encores add two extra notes without risking
previously completed records. The daily challenge has no encore bonus.

The results screen offers replay, favorite saving, NBD1/NBD2 code sharing, and
four-bar WAV export. On Android the WAV is offered through the native share sheet
using Godot's built-in FileProvider and a temporary read grant. No microphone,
Internet, account, or broad storage permission is required. Haptics use the
VIBRATE permission declared in the Android preset.

## What is implemented

- Fixed 110 ms flight and analytical angular collision; normal, PULSE, REWIND,
  and TWIN records; PERFECT, EDGE, combos, and stage-checkpoint scoring.
- Five genres with earned unlocks, seeded chord progressions, original synthesized
  samples, a deterministic four-bar renderer, and backward-compatible song codes.
- An independent PCM worker, synchronized mixer updates, bounded voice counts,
  immediate native effects, and sample-accurate recovery of musical transport.
- Cached static record/paper artwork, one-finger input, library pagination with
  corrected hit regions, reusable replay controls, independent music/effect
  levels, reduced-motion/reduced-glow controls, and a UTC daily reset countdown.
- Validated local saves with atomic primary/backup writes, malformed composition
  rejection, future-save downgrade protection, and unfinished-record recovery.
- Audio-focus loss handling, explicit player resumption, and native Android Back
  navigation that pauses a record rather than quitting it mid-shot. Window close
  checkpoints before stopping the audio worker. Back while paused stays paused;
  the Continue button resumes. Back at the studio exits.

## Build and test

See `BUILD_ANDROID.md`. The CI workflow archives the exact committed source,
runs host and Godot tests, builds signed **debug** ARM64 and x86_64 APKs, verifies
the package/signature/permissions, and exercises an Android 15 software emulator.
Artifacts include source, APKs, engine logs, screenshots, and Android logcat.

```bash
python -m unittest discover -s tests -p 'test_*.py' -v
godot --headless --editor --path . --import --quit
# Linux: isolated user-data, bounded execution, runtime error/leak rejection.
bash tools/run_godot_test.sh res://tests/audio_worker.gd
bash tools/run_godot_test.sh res://tests/storage_safety.gd
bash tools/run_godot_test.sh res://tests/player_flow.gd
bash tools/run_godot_test.sh res://tests/native_navigation.gd
```

Other operating systems may invoke the test scripts with Godot directly; use a
separate test user-data profile rather than an irreplaceable player save. The
source-line gate counts GDScript, Python, shell, shaders, Kotlin, and Java under
first-party code directories, excluding the engine and generated resources.

## Release status

**This is a development build, not a signed-off production release.** Read
`docs/RELEASE_READINESS.md` and `IMPLEMENTATION_STATUS.md`. Automated correctness
and emulator checks do not verify real phone speakers/Bluetooth latency, actual
incoming calls, physical haptics, thermal behavior, or stable 60 FPS on hardware.
The emulator still falls short of the physical-device frame-rate goal. A real
recipient app reading the granted WAV, blind music/gameplay tests, production
signing, and Play release review remain open gates.

All sounds and launcher artwork originate from the included synthesis/art tools.
No third-party commercial recordings are bundled. Source licensing and production
release decisions remain with the project owner.
