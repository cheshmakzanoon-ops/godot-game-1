# Android interrupted-session recovery

NEEDLEBEAT: DROP / Godot 4.7.2 — 2026-10-10.

## Behavior

- An unfinished campaign or daily song is checkpointed when a shot lands, a
  record is cleared or failed, an encore is started, or the app pauses.
- The `active_song` object lives inside the existing `user://save_v1.json`;
  it is included in the existing last-known-good backup without a save-version
  bump, so old users' progression and favorites remain readable.
- The checkpoint records the fixed campaign/daily seed, current stage index,
  actual pins (including lane), placed notes, stage score, accepted PERFECTs,
  total score, miss/retry counters, encore state, and stage clock.
- On restart, `StageDirector` reconstructs the deterministic stage; the pins
  and notes are restored precisely, with a deliberate PAUSED recovery screen.
  The player must press CONTINUE RECORD before the disc resumes.
- Unjudged in-flight shots are **refunded**: no invisible impact occurs while
  Android is terminating the app. A cleared stage remains cleared. A failed
  stage still requires retry. An encore may be resumed safely.
- The audio transport returns to the saved timeline through
  `NBMusicEngine.seek_frame`, re-rendering only the trailing one second to
  reconstruct active samples without performing the entire prior session.
- Completed songs clear `active_song` in the same progress save as the score;
  selecting Exit to Studio intentionally discards the unfinished run.

## Schema and migrations

Checkpoint `v=1` is independent of the existing progress `version=1`. Old
player saves have no active checkpoint and continue to load normally. A
malformed/unsupported checkpoint is discarded without resetting campaign
progress, favorites, daily bests or user settings. The checkpoint is small
(nonbinary) and bounded (at most 42 note events / 50 pins).

## Verification

```bash
python -m unittest discover -s tests -p 'test_*.py' -v
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/checkpoint_flow.gd
godot --headless --path . --script res://tests/full_flow.gd
```

`tools/android_emulator_smoke.sh` additionally performs a real Android
process-death scenario: seed one safe pin in a debug-only QA launch, confirm
a durable on-disk checkpoint, `adb shell am force-stop`, reopen normally,
require a `NEEDLEBEAT_QA_SESSION_RESTORED` marker and collect a screenshot.
The emulator gate also retains screenshot/PLAY and native WAV-share tests.

A passing emulator gate cannot guarantee all manufacturers' lifecycle or
audio-focus behavior. Before Play Store release, reproduce the process kill,
phone call interruption, Bluetooth disconnect and playback recovery on at
least two physical handsets.
