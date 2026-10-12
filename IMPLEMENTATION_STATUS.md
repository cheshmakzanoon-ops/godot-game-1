# NEEDLEBEAT: DROP — implementation and acceptance status

## Completed source phases

**A — Audio independence:** One serialized PCM producer works off the render
thread. Mixer event/volume/clock access is synchronized. Start, pause, seek,
reconfiguration, and teardown stop/join the worker before replacing its state.
Immediate effects bypass the music queue using a bounded native player pool.
The worker regression deliberately blocks the main thread for 450 ms.

**B — Save/import safety:** Typed metadata and bounded event payloads, verified
primary/backup writes through temporary files, invalid-save fallback, newer-save
read-only protection, and duplicate campaign-completion protection. The parser
retains supported NBD1/NBD2 formats; the original music grammar remains intact.

**C — Rendering/player controls:** Static ink and grooves are cached by palette.
Library card gaps no longer select an incorrect song. Replays keep score metadata
and do not increment progression. Multi-touch duplicate shots are rejected.
Settings expose independent sound levels, reduced motion/glow, and haptics.

**D — Native navigation/test integrity:** Android Back is intercepted through the
root Window signal. It pauses active play, dismisses Import to Library, returns
non-playing menus to Studio, and exits only from Studio. It does not resume a
paused record. Desktop close checkpoints and stops audio. The Android export
explicitly declares VIBRATE and version 0.2.0/code 2. Linux engine tests use isolated
user-data, timeouts, and fail on runtime errors or leaked-object diagnostics.

**E — Export and receiving-app integrity:** Shared WAVs use verified immutable
content snapshots; rendering failures preserve the prior export. A separate,
permission-free Android test app must read exact bytes, prepare the WAV with
MediaPlayer, and be denied writes and reads of an unshared sibling. The chooser
is exercised after cancellation and across repeated exports. See
`docs/WAV_RECEIVER_QA.md`; actual passing receipts are CI evidence, not inferred
from source inspection.

## Locally exercised checks

26 Python tests; 20 smoke assertions; 196 full-game, 29 checkpoint, 19 audio-focus,
20 audio-worker, 56 storage/parser, 49 player-flow, 12 native-navigation, and
10 WAV-integrity and 10 deterministic audio-soak assertions. Re-run CI for the current revision;
counts are implementation coverage, not claims of exhaustive correctness.
The ten-minute audio soak renders simulated audio, not ten minutes of wall time.

The recovered A–C implementation passed all three jobs in CI run 38197163164,
including a 40-second Android performance sample with zero generator underruns.
Phase D adds actual Android Back-key coverage to the existing emulator suite.
Latest revision status and exact artifacts are available in the Actions run for
that commit. See `docs/PERFORMANCE_SOAK.md` for the measured pre-D comparison.

## Open acceptance work

Physical-device frame pacing/thermals/battery, speaker/headphone/Bluetooth latency,
real incoming calls and route changes, actual vibration, receiving-app WAV read
access, and novice/music blind playtests remain unverified. Release signing and
a production AAB/store submission have not been completed. Custom-drawn controls
are not claimed to support TalkBack. These are release gates, not optional polish.
