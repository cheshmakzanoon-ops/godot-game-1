# Implementation and QA ledger

Updated: 2026-10-09.

| GDD target | Implementation | Verification |
|---|---|---|
| 110ms pin flight, 12° collision, 12–19° EDGE, 7° PERFECT | `Geometry.gd`, `Game.gd` | Godot 4.7.2 smoke verified; device test pending |
| Preloaded pins, four sequential stages, same-record retry | `StageDirector.gd`, `Game.gd` | Source complete; engine smoke test pending |
| Seeded independent physical disc with PULSE/REWIND/TWIN | `DiscMotion.gd`, `StageDirector.gd` | Analytic host motion regression passes; device test pending |
| Four-bar 16-step drum/bass/lead/chord loop | `MusicEngine.gd` | 50 sound assets validated; live device audio pending |
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
| Android debug APK | Export preset and Actions workflow | Not yet built here |
| Signed release AAB / Play tests | Build guide only | **Incomplete** |

**Release blockers:** Start the project in Godot, maintain `tests/smoke.gd`, export/install Android debug APK, playtest input/audio/visuals on at least one real phone, complete WAV chooser, verify audio focus and latency, then set up release AAB signing. Do not market this source as a fully tested commercial release until these gates have passed.


### Godot engine verification (2026-10-09)
Godot 4.7.2 headless import succeeded; 15/15 smoke assertions passed. A nonfatal engine cleanup warning remains. Android export is unverified because SDK downloads are blocked in this container.
