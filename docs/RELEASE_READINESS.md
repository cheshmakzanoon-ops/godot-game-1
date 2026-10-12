# NEEDLEBEAT: DROP — release signoff checklist

**Signoff: NOT GRANTED.** A green automated build is not a promise of perfect
operation on every device. Preserve this distinction in releases and handoffs.

## Automated coverage available in the repository

| Area | Verification |
|---|---|
| Core four-record gameplay | Full-flow Godot suite, geometry tests, score/retry/encore checks |
| Audio | Deterministic PCM, bounded voices, 600-second simulated renderer soak, worker stall/churn test |
| Storage | Checkpoints, corrupted input/JSON, bounded song codes, atomic saves and backup fallback |
| Platform lifecycle | Android focus probe, process-death recovery, native Back test, orderly worker shutdown |
| Player controls | Library rows/gaps, replay without progression inflation, touch, music/effect levels |
| Android packaging | ARM64 and x86_64 debug exports, apksigner, FileProvider and VIBRATE manifest checks |
| Emulator | Actual launch/tap/screenshots, WAV chooser, synthetic focus, recovery, 40-second performance sample |

The PCM worker removes the observed coupling between slow drawing and song-buffer
starvation. The emulator underrun gate was tightened from 100 to 5 events; it was
not loosened to make the new implementation pass. Native effects bypass the
song queue but actual input-to-speaker latency still requires a physical device.

## Required before production release

1. Name physical reference devices and exercise a 15-minute session on each.
   Capture average/P95/P99 frame time, audio underruns, RAM, thermal/battery behavior,
   and touch feel at 30/60/120 Hz. The target remains stable 60 FPS where supported.
2. Test calls, lock/unlock, wired and Bluetooth route changes, and permission/OS
   settings that disable vibration. Synthetic callback tests are not real calls.
3. Send a completed WAV to a separate receiving app; confirm the recipient reads
   and plays the file through the URI grant. Opening a chooser alone is insufficient.
4. Complete blind gameplay/music checks from the original GDD. No validated
   retention, difficulty, or music-quality claim has been made.
5. Create/retain the owner's production upload key outside source control, build
   and verify the release AAB, then perform current Play policy/data-safety and
   accessibility review. Debug-signed APKs must not be sold as production releases.

## Reproducibility and data handling

CI publishes a source archive plus SOURCE_COMMIT.txt for each revision. Engine
logs and Android evidence are separate artifacts. Linux test runs isolate their
user-data directories and fail on runtime errors and leaked-object diagnostics.
Do not commit player saves, signing keys, signing passwords, or personal data.
The shipped app is offline; the Android share chooser transfers only the selected
composition to the app chosen by the player. The built-in Godot FileProvider is
not replaced with a broad custom storage provider.
