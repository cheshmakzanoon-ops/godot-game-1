# NEEDLEBEAT: DROP — playable-source alpha (Godot 4.7.2)

**Tagline:** Every shot risks the run. Every shot writes the song.

This is an actual Godot 4 portrait project implementing the core game described in `design/ORIGINAL_GDD.md`. It includes gameplay source, 50 original synthesized sound effects/instruments, a deterministic four-bar music sequencer, saves, song codes, a daily challenge, tests, Android export preset, and a GitHub Actions workflow.

**Current verification:** The project has been imported and checked with the **real Godot 4.7.2 engine** in Linux headless mode. After correcting GDScript parser and export preset issues, **15/15 engine smoke checks passed** on October 9, 2026. The Python host suite also passes. Android APK export and device touch/audio validation are still outstanding in this network-isolated environment. See `docs/DEVELOPMENT_HANDOFF.md` and `tools/bootstrap_android_linux.sh`.

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
- A **four-bar 16-step composition** built from landed pins, keyed bass/lead/chord grammar, baseline drum anchors, a common ahead-of-time audio buffer and WAV renderer.
- Five playable genre palettes: PULSE, CASSETTE, POCKET, PIXEL, AFTER HOURS. Unlock after 0/3/8/16/30 completed campaign songs.
- UTC daily challenge derived from stable SHA-256 and fixed difficulty independent of campaign progression. Local, non-authoritative daily best scores only.
- Versioned offline save and valid backup, up to 20 favorite songs, `NBD1` share codes with checksum, bounds checks, and re-import.
- 50 procedurally generated WAV instrument/effect assets, plus original game icon and code to regenerate it.
- Desktop and Android input, haptics toggle, music level, effects toggle, reduced ambient-motion option, no account/network/ads/IAP.

## Current limitations (not production-ready)

- **Engine-tested (15/15), but not yet verified on a physical Android device.** Run the existing headless smoke suite after each source change.
- `EXPORT AUDIO (.WAV)` creates a valid RIFF/PCM file under `user://exports/`; desktop users can retrieve it from the Godot user-data folder. The **Android secure WAV share chooser/FileProvider bridge is not yet implemented**. Song codes can be shared with the Android chooser or clipboard.
- No signed release AAB, full native Android Gradle share plugin, global leaderboard, performance/thermal playtest suite, screen reader support, or final Play Store QA.
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
scripts/ProgressStore.gd       Local offline checkpoints, settings, backups
scripts/SongCodec.gd            Versioned checked song-code import/export
scripts/*.gd                    9 GDScript files
assets: audio/0..4/*.wav        50 one-shots at 22.05kHz, original synthesized
art/icon.png                   App launcher icon
art/icon_adaptive.png          Adaptive icon initial asset
tools/generate_sounds.py       Rebuilds all audio assets
tools/make_icon.py             Rebuilds icon assets
tests/test_project.py          Host-only suite
tests/smoke.gd                 Godot headless integration test
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
```

First-party authored `.gd`/`.py` source is counted by `tests/test_project.py`; it is kept under the GDD's 5,000-line guideline, including tests, synthesis, and tooling. Resource files and assets are not included in that count.

## Android APK build

Refer to `BUILD_ANDROID.md`. For local device installs, use the Android **debug** preset. The included GitHub Actions workflow is a starting point for automated Android ARM64 debug builds and uploads APK artifacts; it has **build status must be checked in GitHub Actions**. For Google Play submission, Gradle build template, AAB export, release signing, privacy declarations and on-device validation remain mandatory.

## License and content

All audio samples and the icon in this project were generated from the included scripts. No external copyrighted recordings are bundled. The original GDD is provided by the project owner. Source may be revised or commercially licensed by the project owner after review.
