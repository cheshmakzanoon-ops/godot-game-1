# Implementation and QA ledger

Updated: 2026-10-10.

| GDD target | Implementation | Verification |
|---|---|---|
| 110ms pin flight, 12° collision, 12–19° EDGE, 7° PERFECT | `Geometry.gd`, `Game.gd` | Godot 4.7.2 smoke verified; device test pending |
| Preloaded pins, four sequential stages, same-record retry | `StageDirector.gd`, `Game.gd` | Godot engine test passes; end-to-end integration added |
| Seeded independent physical disc with PULSE/REWIND/TWIN | `DiscMotion.gd`, `StageDirector.gd` | Analytic host motion regression passes; device test pending |
| Four-bar 16-step drum/bass/lead/chord loop | `MusicEngine.gd` | NBD2 has curated progressions, correct chord qualities, seeded variation; legacy NBD1 PCM golden hash passes |
| Ahead-of-time PCM audio buffer / offline WAV | `AudioSystem.gd` | Source written; Godot 4.7.2 smoke verified |
| Five unlocked genres | `StageDirector.gd`, `ProgressStore.gd` | Source written |
| Optional two-shot encore | `Game.gd` | Source written |
| Local versioned saves / backup / 20 favorites | `ProgressStore.gd` | Source written |
| UTC seed / daily comparability | `StageDirector.gd` | Date-derived seed; local tests pass, cross-device test pending |
| Song code export/import / checksum | `SongCodec.gd` | Godot 4.7.2 smoke verified |
| Android song-code text share | `AndroidShare.gd` | Godot 4.7 AndroidRuntime API integration; device test pending |
| Standard PCM WAV written to `user://exports` | `AudioSystem.gd` | Godot 4.7.2 smoke verified |
| WAV Android secure share chooser/FileProvider | Not yet wired | **Incomplete** |
| Portrait vector editorial UI | `Game.gd` | Needs screenshot QA and live device visual verification |
| First-party source under 5,000 lines | Test-enforced | Pass |
| Android debug APK | Export preset and Actions workflow | Signed ARM64 debug APK passed 2026-10-09 GitHub Actions, including v2/v3 APK signature validation |
| Signed release AAB / Play tests | Build guide only | **Incomplete** |

**Release blockers:** Start the project in Godot, maintain `tests/smoke.gd`, export/install Android debug APK, playtest input/audio/visuals on at least one real phone, complete WAV chooser, verify audio focus and latency, then set up release AAB signing. Do not market this source as a fully tested commercial release until these gates have passed.


### Godot engine verification (2026-10-09)
Godot 4.7.2 headless import succeeded; 15/15 smoke assertions passed. A nonfatal engine cleanup warning remains. Android export is unverified because SDK downloads are blocked in this container.

### Next milestone complete (2026-10-10)
- End-to-end Godot `tests/full_flow.gd` plays all four records with collision-timestamp shots and verifies checkpoints, retries, encores, high-level specials, saved song playback, daily isolation and 30-event song reconstruction.
- Fixed PERFECT count accounting: failed attempts cannot inflate completion accuracy; encores preserve or commit accuracy alongside their notes.
- New music grammar uses seed-selected genre progressions, consistent triad qualities and chord-tone downbeats. All previously shared NBD1 codes preserve their original timbre and arrangement (8192-frame golden PCM SHA-256 regression).
- Song codes now normalize numeric event types when imported; supports NBD1 and NBD2. A code checksum never replaces input validation.
- Live Android rendering/touch/audio focus and WAV share chooser/FileProvider remain release blockers.
