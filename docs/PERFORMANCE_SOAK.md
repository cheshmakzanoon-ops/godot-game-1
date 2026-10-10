# NEEDLEBEAT: DROP — sustained audio and Android performance gate

**Scope:** the game's low-cost Godot 4.7.2 PCM renderer under continuous playback and a reproducible Android 15 emulator test. This is an engineering preflight, not a physical-phone thermal, speaker, Bluetooth latency, or battery result.

## Headless deterministic music endurance

Run `godot --headless --path . --script res://tests/audio_soak.gd` after importing the project. This renders 600 seconds (13,230,000 frames) of a dense 30-event four-layer track at 22,050 Hz, without waiting in real time. It checks:

- Exact audio-frame accounting after ten virtual minutes, and output remaining finite and below the 16-bit clipping ceiling.
- Active voices bounded to 16; no sustained growth over 8 MiB in Godot's statically accounted engine allocation since the first minute.
- Runtime on the host CI runner using less than 35% of the simulated audio duration. This is a generous **host-CI** threshold, not evidence of mobile CPU or thermal headroom.
- A five-hour playback-position seek and bit-identical samples across an ordinary transport and a checkpoint-restored transport at a deliberately unaligned frame.

The test prints `AUDIO SOAK: ... real-time ratio=... max_voices=... memory_delta=...`, then returns a nonzero process exit code on failure. CI runs it in its `game-test` job with a 3-minute timeout. Its measured elapsed wall time and memory usage are runner-specific and should not be compared directly with phones.

## Android 15 emulator runtime endurance

With an emulator, `bash tools/android_emulator_smoke.sh` exercises normal PLAY, sharing, audio-focus interruption, and checkpoint recovery. It then launches the separate debug-only `needlebeat.qa=performance_soak` intent.

The probe exercises a spinning record while the real Android audio generator runs all four populated song layers for **40 seconds after 3 seconds of warm-up**. Its diagnostics include:

- 95th-percentile main-loop frame interval (maximum 250 ms on CI's software emulator; **not** the product's 60 FPS goal).
- Audio mixer frame progression within 85–115% of real elapsed time.
- Up to 100 generator-buffer underrun **events**, as returned by `AudioStreamGeneratorPlayback.get_skips()`. This counter counts underrun occurrences, not samples; the threshold is deliberately conservative for emulation.
- Godot engine allocator growth below 24 MiB during the sampling window, with at least 150 observed render frames.

The emulator script requires both `NEEDLEBEAT_QA_PERF_METRICS` and `NEEDLEBEAT_QA_PERF_PASS` in Android logcat; any `NEEDLEBEAT_QA_PERF_FAIL` or missing completion is a CI failure. The `NEEDLEBEAT_DROP_Emulator_Evidence` artifact includes `perf_soak_logcat.txt`, `soak_meminfo.txt`, `soak_gfxinfo.txt`, and `soak.png` for review. No real user data should be modified by the debug probe.

## Physical Android release gates still open

For a midrange Android phone, test at 30/60/120 Hz and collect average, P95 and P99 frame times, driver underrun counts, peak RAM, CPU time, thermals, and battery usage over at least 15 minutes of active gameplay and uninterrupted composition. Repeat on speaker, wired headphones, and Bluetooth; include a real incoming call, device lock/unlock, app backgrounding, and process kill. Target stable 60 FPS with no audible generator skips and acceptable latency. The emulator cannot validate acoustical sync, actual phone GPU stability, heat, or radio/device interruptions.
