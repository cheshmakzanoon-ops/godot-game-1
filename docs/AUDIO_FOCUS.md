# Android audio-focus and lifecycle handling (2026-10-10)

This phase adds audio-only interruption handling to the existing app-background and
process-death recovery features. The release remains an offline Godot 4.7.2 game.

## Runtime behavior

- The music generator requests transiently owned Android **music/game audio focus**
  when it starts or a player explicitly resumes. Android API 26+ uses
  `AudioFocusRequest.Builder` and `AudioAttributes` (`USAGE_GAME`,
  `CONTENT_TYPE_MUSIC`); Android 24–25 uses the legacy compatible overload.
- `AudioManager.OnAudioFocusChangeListener` is implemented in GDScript using
  Godot 4.7.2's `JavaClassWrapper.create_sam_callback`. Its callback forwards
  to the game thread using `call_deferred`.
- Permanent, transient and ducking audio-focus loss all pause the generator,
  checkpoint unfinished records, and release the audio-focus request. Ducking
  intentionally pauses this timing game rather than letting its music become
  inaudible or distorted under competing audio.
- **Focus gain never automatically restarts the game.** The player must tap
  RESUME. The record clock stays frozen; pins, notes, score and combo remain
  unchanged. If a competing app still owns audio focus, RESUME is denied and
  the game stays paused rather than advancing silently.
- Explicit pause, returning to menu, and closing the game release audio focus
  so other apps can play. WAV export works offline independent of music focus.
- AndroidRuntime-less deployments fall back to the existing Godot activity
  focus notifications; they must not lose offline gameplay access.

## Automated checks

- `tests/audio_focus_flow.gd` invokes the same focus-loss event handler used by
  Java callbacks; confirms all three losses, stale gains, pause/checkpoint,
  frozen PCM and explicit resume; confirms idempotence with Android's normal
  pause/focus-out notifications.
- `tests/android_runtime.gd` has a debug-only `needlebeat.qa=audio_focus` path
  that insists the Android bridge is installed; injects transient focus loss
  and verifies the real game state, frozen mixer, no auto-resume and recovery.
- `tools/android_emulator_smoke.sh` runs this probe on the same Android 15
  emulator as touch, WAV FileProvider sharing, and process-death tests.

The emulator audio-focus test uses **synthetic focus callbacks in the real
Android runtime**. It does not simulate a real cellular phone call, Bluetooth
headphones switching, audio-route changes, or phone speaker latency. Those
remain *physical device acceptance criteria* before Play Store release.

No new permissions, Gradle plugins, recordings, microphone access or services
are required. References: Android Developers' Manage Audio Focus guide and
Godot 4.7's JavaClassWrapper / AndroidRuntime API documentation.
