# NEEDLEBEAT: DROP
## Game Design Document — Android / Godot 4
**Version:** 1.0 (preproduction specification)  
**Engine:** Godot 4, GDScript, 2D Compatibility renderer  
**Display:** Portrait, one-thumb touch input  
**Engineering constraint:** Target **fewer than 5,000 lines of first-party source code**, including GDScript, authored shaders, Kotlin bridge, audio-generation scripts, and automated tests. The Godot engine, binary art/audio assets, and `.tscn`/`.tres` data are excluded. This is a target, not a guarantee.  
**Pitch:** *Every shot risks the run. Every shot writes the song.*

---

## 1. Executive vision

NEEDLEBEAT: DROP combines the instantly legible timing and collision game of a one-tap arcade hit with a miniature music studio. The player launches pins toward a rotating record. Successful pins become notes or percussion events; colliding with a pin ends the current record attempt. Four successive records build drums, bass, melody, and the final harmony/drop. The completed musical phrase can be replayed, saved, and shared.

**Design pillars:**
1. **Readable in three seconds:** One central record, one obvious projectile, one rule: do not hit an existing pin.
2. **Every success changes the sound:** There must be audible progress, not just points.
3. **The music must be convincing:** Fixed musical grammar, quantization, arrangement, and consistent sound palettes protect quality while preserving player-authored rhythm.
4. **Failure is fast and fair:** A collision loses only the current record. Every special move is telegraphed and deterministically simulated.
5. **One-handed, offline, lightweight:** No accounts, cloud backend, leaderboard service, or compulsory advertisements are required for release.
6. **Distinctive art rather than generic neon:** Tactile printmaking, cut metal, restrained color, record wear, and editorial typography.

**Release shape:** A replayable campaign of seeded song challenges, five gradually unlocked genres, three mechanically distinct special records, optional encore shots, a daily seeded challenge, saved tracks, shareable composition codes, and WAV export through Android's share sheet. No video rendering or worldwide ranking server in v1.

## 2. Audience and session structure

Designed for casual arcade players, people who enjoy music toys, and score chasers. No musical training or rhythm-game precision is required to survive; visual timing is primary, and musical timing becomes a secondary source of mastery.

- **First control input:** A tap anywhere outside the HUD fires a pin.
- **Time to understand:** Intended to be under 5 seconds, assessed in blind playtests.
- **Ordinary song:** Four records, approximately 40–90 seconds depending on hesitation and retries.
- **Completed song playback:** Four bars at genre tempo, generally around 7–11 seconds.
- **Fail-to-new-attempt:** Feedback animation about 0.2 seconds; one tap restarts the failed record. Never force a lengthy results screen.
- **Session pattern:** Finish a song, try a new variant, replay one challenge for precision, or run the UTC daily challenge.

## 3. The exact gameplay rules

### 3.1 Arena and pin geometry

One stylized spinning disc sits above a fixed launch point at the bottom of the screen. Preinstalled pins rotate with it. A fired pin travels a fixed visual path in **0.11 seconds** and embeds into the active rim at a fixed world-space launch angle. The stage is deterministic: position, disc phase, speed/reversal schedule, and collision outcome depend on the shot time and seed, not frame rate.

Each pin is stored as a **local polar angle**, not a moving physics body. At impact:

```text
impact_time = touch_time + 0.11 seconds
world_hit_angle = fixed firing angle
local_hit_angle = wrap(world_hit_angle - disc_phase_at(impact_time))
clearance = minimum circular angular distance to pins on active ring
if clearance <= collision_threshold: collide and fail stage
else: embed pin at local_hit_angle, add musical event, award points
```

**Provisional tuning constants** (data-driven, not permanent): disc radius 128 logical units; pin angular collision threshold 12 degrees; near-miss band 12–19 degrees; minimum input-to-screen response one frame; sixteenth-note grid of 16 slots per revolution. Use the same angular model for rendered contact and collision. Make the impact threshold visually honest by drawing the true pin heads and collision rim. Do not silently move a near-hit into a success.

A pin launched while the disc changes speed is judged against the analytically or piecewise-integrated disc position at its impact time. Tests replay the same input timestamps at 30, 60, and 120 FPS and demand identical outcomes.

### 3.2 Fail and retry

- Touching a lodged pin creates a restrained 0.15–0.25-second stutter/glitch, a distinct dry collision sound, and a high-contrast failure marker.
- **Only the current record resets.** Completed drums/bass/melody remain saved and audible during retries, briefly muted under the failure sound.
- Restart reuses the same seed, preload positions, and hazard timing. It does not reshuffle to rescue the player or surprise them.
- No rewarded-ad revive, no compulsory loss animation, no energy/life currency.
- Stage points are committed **only on clear**; failed partial attempts cannot be used to farm score.

### 3.3 Success grading and score

Every safe shot awards **100**. Bonuses are not needed to progress:

| Event | Condition | Bonus |
|---|---|---:|
| PERFECT | Local landing angle is within 7° of a highlighted 16-step grid center | +60 |
| EDGE | Clearance from the nearest pin is greater than 12° and at most 19° | +35 |
| Combo | Consecutive safe shots within the record | +10 per prior shot, capped at +50 |
| Record clear | All required shots placed | +300 |
| Successful encore | Both optional extra shots completed | +500 |

PERFECT and EDGE may occur together; the display prioritizes `PERFECT + EDGE` when both apply. Difficulty and note quality do not depend on paying, owning a skin, or choosing a genre. Daily challenges exclude optional encore bonuses for strict comparability. Score and hit events are deterministic given identical inputs.

### 3.4 Four-record song format

| Round | Name | New player shots | Starting obstacle pins | Musical contribution |
|---|---|---:|---:|---|
| 1 | **BEAT** | 6 | 1 | Kick, snare, hats, and little percussive fills |
| 2 | **ROOT** | 7 | 2 | Bass pulse, roots, octaves, fifths |
| 3 | **HOOK** | 8 | 2 | Short lead phrase and responsive ornaments |
| 4 | **DROP** | 9 | 3 | Chord stabs, countermelody, rises, and final accent |

Starting pins serve both as physical hazards and optional seed-generated musical events. A stage completes when the required **new** shots are placed without a collision. Lower stages show their previous parts in a compact four-layer progress strip at the top of the screen.

**Target moment:** The final safe shot on DROP stops the record, silences the track for a tightly controlled fraction of a beat, then starts an 8–11-second full arrangement with a dramatic beat-synchronized visual transformation. This is a reward, not an unskippable animation: tapping can move to the results screen, and an explicit Replay button is always available.

## 4. Musical engine and authoring model

### 4.1 Why it is musical, not random noise

Each completed track is a four-bar phrase in 4/4. The record has a visible **16-step** ring: one physical angular revolution maps onto one bar. Each successful pin contributes an event in the current layer. Its angle selects a 16th-note **time step**; the layer, seeded genre grammar, and musical context determine its instrument, pitch, velocity, and length.

```text
step = round(16 * local_angle / 360 degrees) mod 16
bar_length_seconds = 4 * 60 / BPM
step_length_seconds = bar_length_seconds / 16
```

The arrangement repeats each stage's selected step pattern over four bars, but its harmony may change by bar. The player meaningfully chooses **rhythmic placement, density, risk, and accent placement**. Genre data chooses pitch to avoid frequent dissonance.

- **BEAT:** Map slots and successful-shot order to curated drum voices; add a minimal seed-dependent rhythmic skeleton if the player's arrangement lacks an anchor. Accents alter velocity and timbre.
- **ROOT:** On strong steps favor root/octave/fifth; elsewhere use scale-compatible short approaches. A seeded four-chord progression sets the bar-to-bar harmony.
- **HOOK:** Prefer chord tones on downbeats; use a small pentatonic pool and voice-leading constraints on offbeats. Avoid sudden octave jumps except rare prepared accents.
- **DROP:** Place chord stabs, response notes, and a build-up accent. Limit concurrent voices and cap output level to prevent a loud, cluttered finale.
- **Quantization:** Pin *geometry* remains at its exact landed angle, while its audible event snaps to the closest 16th. Show a soft ripple to the musical grid rather than physically shifting the pin.
- **Update rule:** A newly placed pin gets an immediate satisfying **impact sound**. Its new musical event enters the looping score at the next appropriate quantized subdivision or bar boundary; do not interrupt a sounding note.

The phrase is *guided composition*, not an unrestricted DAW. This is an intentional trade-off: fewer controls, immediate musical gratification, and predictable shareable results.

### 4.2 Motion/audio synchronization

**The audio transport is the master clock.** On a standard record, its nominal rotation is one revolution per bar so pins visually pass a playhead in musical time. Reversals and speed-pulse obstacles change the **physical scoring disc**, but they **do not slow, pitch-bend, or reverse the completed song**. A thin inner pulse ring, driven by the audio clock, shows the actual music step during specials. This prevents impossible audio timing and avoids making a player's track sound broken during a difficult stage.

The beat scheduler uses an audio-oriented clock and buffers or queues notes ahead rather than blindly firing `AudioStreamPlayer.play()` once per graphical frame. Verify latency and drift on real Android handsets. Start with existing sample playback for the proof of concept; switch to a small ahead-of-time PCM mixer if frame-timed triggering audibly swings the sixteenth notes. The same deterministic event renderer should support offline WAV export.

### 4.3 Sound implementation

Generate a limited library of short **original PCM one-shots** offline from a small first-party synthesis script, then mix those samples for playback. Useful algorithms include swept sine for kick, filtered noise for snare/hats, FM for mallets/keys, softened pulse/saw for bass, Karplus–Strong-like plucks, and noise sweeps for rises. Asset generation is source-controlled and its code counts toward the LOC budget; exported audio files do not.

**Mix budget:** A modest number of simultaneous voices (e.g., 8 musical voices plus transient effects), deterministic velocity, light limiter, no heavy per-frame FFT effects, and a small common reverb where supported. Work at a mobile-suitable PCM rate and benchmark on a low-end device. A CPU-intensive pure-GDScript 44.1 kHz synthesizer is explicitly *not* the plan.

### 4.4 Five unlockable genres

| Pack | Unlock | BPM target | Audio identity | Visual identity |
|---|---|---:|---|---|
| **PULSE** | Start | 120 | Rounded synth bass, crisp drums, glassy arpeggio | Ink, cobalt, copper |
| **CASSETTE** | 3 completed songs | 96 | Soft dusty percussion, detuned keys, warm plucks | Parchment, rust, faded plum |
| **POCKET** | 8 completed songs | 112 | Syncopated electric-style bass, tight drums, muted stabs | Petrol blue, tangerine, cream |
| **PIXEL** | 16 completed songs | 132 | Pulse leads, bit-like accents, punchy electronic percussion | Deep violet, lime, powder blue |
| **AFTER HOURS** | 30 completed songs | 104 | Brush-like noise, electric-piano FM, plucked-bass tone | Midnight navy, brass, soft jade |

Genre unlocks are permanent and based on completed songs, not calendar days. They change *sound, art, and harmony grammar*, not hitbox difficulty. A daily challenge temporarily gives access to its featured genre even if the player has not unlocked it. Genres are data-driven configurations and soundbanks, not separate game implementations.

## 5. Fair difficulty progression

A seeded `StageDirector` selects the number of preload pins, disc behavior, music seed, and warnings. Difficulty comes primarily from crowding, angular speed, and scripted direction changes—not invisible hitbox reductions.

| Campaign segment | Primary teaching | Speed | Specials |
|---|---|---|---|
| Songs 1–3 | Learn firing, collision, four layers, and drop | 0.85–1.0× baseline | None |
| Songs 4–10 | Timing windows, near misses, combos | 0.95–1.1× | Pulse preview |
| Songs 11–20 | Disc reversals with clear warning | 1.0–1.15× | REWIND |
| Songs 21–35 | Lane choice and active-rim awareness | 1.0–1.2× | TWIN |
| Songs 36+ | Carefully composed combinations and score mastery | Up to 1.25× | Combined scripted sets |

These are tuning bands, not claims of validated difficulty. Compute nominal baseline from the genre's BPM. A challenge generator must reject obstacle configurations that exceed the geometric capacity of a record, and automated seeds should simulate legal shot availability. No arbitrary mid-flight reversals: changes are announced at least **two beats** ahead through a distinct outer-ring cue. Campaign may expose a no-penalty *Practice* mode; daily challenges keep the same deterministic configuration for everyone.

### 5.1 Three special records

1. **PULSE — Breathing velocity.** Every four beats, speed changes between 0.85× and 1.15×. A radial tick mark forecasts the next shift; exact change times are part of the seed. Music tempo stays fixed.
2. **REWIND — Warning and reversal.** A two-beat warning sweeps the rim; the direction reverses at the next bar boundary. Speed changes use a short easing interval included in the collision prediction.
3. **TWIN — Alternating rims.** Two concentric target rims share the disc center. After each successful shot, the highlighted active rim alternates. Each rim maintains its own set of pins and its own collision threshold. The player still uses exactly one tap. The target trajectory and active rim are clearly visible before firing.

Never ship invisible pins, random teleports, deceptive animation, or hazards whose effects are impossible to predict. Special visuals must be readable in grayscale and at reduced animation intensity.

### 5.2 Optional encore

After any non-daily record clears, a short `ENCORE?` option permits **two extra shots** onto that record. Succeed: add two scored musical ornament events, earn the bonus, and make the track's next playback slightly richer. Miss: keep the original record complete, discard the unsuccessful encore attempt, and simply advance. The main flow always has `NEXT` available and auto-focuses it; encore must never block progression. Disable encore in daily mode so comparable daily scores share the same shot count.

## 6. First-time user experience

**0–4 sec:** Title dissolves into an already-spinning disc. No account screen. Minimal hint: `TAP TO DROP A NOTE`.  
**4–10 sec:** First safe shot; the pin sticks, an audible tick enters the rhythm, and a restrained concentric ripple confirms musical creation.  
**10–20 sec:** Other pins appear; collision danger becomes obvious. A perfect opportunity is shown with a subtly illuminated step notch.  
**20–50 sec:** Four stage names appear one at a time. Earlier layers keep playing while the player adds the next layer.  
**50–70 sec:** Final DROP demonstration with 4-bar song preview and a clear `PLAY AGAIN` / `NEXT TRACK` choice.  
**After first complete track:** A single contextual explanation introduces saved compositions. No forced pop-ups, daily prompts, account sign-in, or notification permission.

Teach near-miss and specials with two-second visual prompts only when first relevant; a `?` button provides explanations later.

## 7. Visual, UX, and feedback specification

**Art direction:** Editorial, tactile, and restrained. Think printed record labels, scratched anodized-metal pins, hairline grooves, subtle chromatic ink misregistration, paper grain, warm spotlights, and geometry drawn with absolute precision. Avoid glossy casino effects and visual noise. Each genre swaps 3–5 colors and an audio-reactive motif while preserving a single recognizable UI identity.

**Portrait layout:**
- Top 15%: song title, score, tiny mute/pause buttons, four mini-layer status indicators.
- Middle 62%: giant record, visible pin silhouettes, 16 subtle step ticks, current active rim, anticipation cue, and minimal `PERFECT / EDGE` typography.
- Lower 23%: firing origin, `N SHOTS LEFT` indicator, one contextual `TAP` hint during onboarding. Entire free lower region is an input target.

**Feedback hierarchy:**
- **Valid shot:** crisp transient, 1-frame white/copper spark, short elastic impact, immediate note preview.
- **Perfect:** visible gold ring sweep, distinct harmonic overtone, compact `PERFECT` text; no full-screen flash.
- **Near miss:** tiny contact sparks, stereo tick, optional mild haptic pulse.
- **Collision:** short pitch-dropping scratch and controlled 0.2-second interruption, then instant retry.
- **Stage clear:** colored layer fills on the HUD and seamlessly joins the song.
- **DROP:** tightly synchronized, 4-bar visualizer with beat-based shapes, momentary pre-drop silence, stronger bass entry, and a clean ending card. A tap can skip playback.

Accessibility: haptics toggle, reduced motion, reduced flashes, independent music/effects sliders, color-blind-safe warning shapes, large touch targets, and audio focus handling for phone calls and background/resume. Haptic cues should supplement, not replace, visible feedback.

## 8. Campaign, save system, and replay economy

**Campaign:** An effectively endless reproducible sequence of songs defined by `(generator_version, campaign_index, genre_id, seed)`. One song = four records. The first 40 songs introduce all core behaviors and genres; later seeds combine behaviors within reasonable boundaries. Store the last played campaign index, finished-song count, unlocked genres, best score per song, and up to 20 favorite saved compositions locally in `user://save_v1.json`.

A favorite track record stores generator version, seed, genre, BPM, and a compact list of musical events. Reloading a saved song reconstructs the same arrangement. Store a small version field from day one; migrate safely on app updates. A corrupt save triggers restoration from a last-known-good local backup, never a crash.

Daily play and saved song playback work **offline**. A network connection is not required for ordinary gameplay or unlocks.

## 9. Daily challenge

At **00:00 UTC**, calculate the date-specific seed with a stable hash of `daily:<UTC YYYYMMDD>:<challenge_version>` and a locally stored or published generator version. Every device on the same version receives identical genre, preload angles, hazard timing, and shot requirements. The daily genre can be played without owning its campaign unlock.

- One shared challenge per UTC day; unlimited local practice attempts.
- Record best completed score, perfect count, miss count, and whether the song was completed without stage retries.
- Disable encore and campaign assists; use a fixed set of song rules.
- Share a result card containing date, score, precision, and a reproducible challenge ID.
- **No server = no trustworthy world leaderboard.** Scores are local/unverified and device clocks can be changed. Do not claim global rankings, authoritative streaks, or tamper-proof records.
- Make reset time explicit in the UI (`New challenge in ... UTC`) without push-notification pressure.

## 10. Song saving, codes, and Android sharing

Song sharing must deliver something another person can actually hear—not only a screenshot.

**A. Replayable song code (release requirement).** After DROP, encode version, genre, seed, and compact event positions/voices into a URL-safe string with an integrity check. The recipient may paste it into `Import Song` to reconstruct and play the identical arrangement locally. Include parser bounds checks (maximum events, supported version, valid genre, and checksum). Do not include personal data or player identifiers.

**B. WAV audio (release goal, retained if line budget permits).** Reuse the deterministic offline audio renderer to produce one complete four-bar audio file in `user://exports/`, then use a small Godot Android v2 Kotlin plugin to open the Android share chooser. For third-party file access, use a `FileProvider` content URI and temporary read permissions—not a `file://` URI. The app can also show `Copy Code` so an unsupported share target never blocks sharing. A WAV that works in other music players is a minimum acceptance condition.

**C. Artwork card (lower priority).** A static PNG with genre palette, record visual, and seed/track code; export using a viewport texture. May be added if the native share bridge and performance are already stable. **Do not add MP4/video capture in v1.** Video encoding, permissions, synchronization, and platform edge cases threaten the five-thousand-line constraint.

For desktop testing, copy codes to the clipboard and save WAV files locally. On Android, request only permissions the app actually needs. The game's own recording/export feature does **not** require microphone access.

## 11. Godot architecture

Use **Godot 4 GDScript and the 2D Compatibility renderer**. The game is CanvasItem-driven; no 3D meshes, rigid-body simulation, or online infrastructure. Keep mechanical simulation separate from visuals and audio.

```text
res://
  scenes/
    Main.tscn                    # Root, DiscCanvas, HUD, overlay transitions
    DiscVisual.tscn              # Record, two optional rings, pin presentation
    TrackResult.tscn             # Playback, score, save, share, next
  scripts/
    GameFlow.gd                  # Session state machine and transitions
    DiscMotion.gd                # Phase / velocity / reversal timeline
    ShotSystem.gd                # Input, flight, collision, grading
    StageDirector.gd             # Seeded layouts, specials, balancing
    MusicSequencer.gd            # Four-bar event clock and scheduling
    PCMRenderer.gd               # Event mixing and WAV rendering
    FeedbackFX.gd                # Sparks, text, ripples, optional haptics
    UIController.gd              # HUD, menus, result card
    ProgressStore.gd             # Genres, scores, local versioned saves
    DailyChallenge.gd            # UTC seed, daily records
    ShareManager.gd              # Song code, export, Android wrapper
  data/
    genres/*.tres                # BPM, key, instruments, palettes
    patterns/*.tres              # Chord grammars and song templates
  tools/
    generate_sounds.py           # Original synthesized one-shot bank
  addons/android_share/         # Small Kotlin bridge and export metadata
  tests/                        # Seed, collision, song-code, WAV smoke tests
```

**Core session states:** `MENU → RECORD_PLAY → STAGE_CLEAR → RECORD_PLAY (next layer)`; `RECORD_PLAY → STAGE_FAIL → RECORD_PLAY (same layer)`; `DROP_COMPLETE → DROP_SHOW → RESULTS → MENU/NEXT/REPLAY`. `ENCORE` is an optional state between `STAGE_CLEAR` and the next layer. Pause/background transitions must preserve stage seed and event history.

**Data model:**
```text
SongSession {
  version, genre_id, seed, bpm, song_index,
  stages[4] { variant, ring_state, preload_pins, placed_pins,
              event_list, required_shots, retries, stage_score },
  musical_events[] { layer, step, voice, pitch_class, velocity, duration },
  score, completed, track_code
}
```

Avoid separately coding each level. New visual palettes and chord templates are resources loaded by the same four-stage simulation.

## 12. Strict application-code budget

All **first-party** GDScript, Kotlin, authored shader, Python sample-generation, and test source count toward the limit. Files generated by the engine and binary media do not. This is an engineering budget, not a prediction of actual final code length.

| Component | Budgeted lines |
|---|---:|
| Game state, session transitions | 230 |
| Disc motion, angular collision, prediction | 430 |
| Shot input, grading, score rules | 340 |
| Stages, difficulty, three special records | 450 |
| Sequencer, PCM renderer, WAV generation | 750 |
| Original one-shot synthesis script | 300 |
| UI, effects, shaders, accessible settings | 620 |
| Save, progression, five genre definitions | 300 |
| UTC daily generation and result validation | 220 |
| Share codes, Kotlin Android intent bridge | 420 |
| Automated tests and diagnostic helpers | 360 |
| **Planned source total** | **4,420** |
| **Contingency before 5,000** | **580** |

**Non-negotiable scope rules:** no account system, backend, live multiplayer, global leaderboard, in-app purchases, rewarded ads, 3D physics, MP4 capture, custom editor tooling suite, or large inventory interface in v1. Five genres are **data** on the same musical grammar. If tests reveal that native WAV sharing exceeds budget, protect correct audio and pin physics first; simplify the artwork-sharing surface before touching gameplay.

## 13. Production phases and acceptance gates

### Phase 0 — Technical proof (first real-device APK)
Implement one static disc, tap-to-shoot with fixed flight time, angular collision, and instant same-stage retry. Integrate a metronome, four-note loop, and an Android debug APK. **Gate:** reproducible hits across frame rates, intuitive first tap, no device-specific touch or audio blocker.

### Phase 1 — The playable one-minute loop
Build all four record stages, stage checkpoints, 16-step note placement, simple drum/bass/lead/chord voices, stage-clear feedback, and the final DROP presentation. **Gate:** a novice can finish an interesting song in one short session; failures restart only one record.

### Phase 2 — Music quality
Build the seed-driven chord/scale grammar, three candidate sound identities, tight step scheduling, output limiter, and save/replay. Test repeatedly with headphones and phone speakers. **Gate:** at least 8 of 10 blind prototype tracks judged rhythmically coherent by the test group; no clipping/crackling on target devices.

### Phase 3 — Art and depth
Finish the editorial art system, five genre packs, perfect/near-miss feedback, PULSE/REWIND/TWIN, campaign generator, encore, save migration, and accessibility. **Gate:** state changes visually readable without sound, telegraphing clear during specials, stable 60 FPS on selected reference hardware.

### Phase 4 — Daily and sharing
Add UTC deterministic daily seed, local best attempts, code export/import, WAV renderer, native Android chooser bridge, and optional static share card. **Gate:** challenge parameters match across devices on a common version; a shared code reconstructs a song exactly; WAV plays in an independent Android audio app.

### Phase 5 — Ship readiness
Android release signing, Google Play AAB export, privacy/data-safety documentation, accessibility/thermal tests, 30/60/120Hz frame-rate verification, Play policy review, crash/regression fixes, and final code count. **Gate:** complete offline campaign, no stop-ship bugs, all release features verified on Android, and a reproducible build from source.

## 14. QA matrix and success criteria

**Physics:** Sweep 1,000+ timestamped shots through fixed and reversing discs; verify frame-rate-independent collision and score, threshold edges, two-ring separation, and no impossible initial layouts.  
**Audio:** Generate and compare deterministic PCM hashes from song codes; test sync for 10-minute sessions, clipping, Bluetooth/headphone latency, silent mode, audio focus loss/resume, and no pop at bar boundaries. Do not score taps against device speaker output latency; score against predicted visible disc geometry.  
**Persistence:** Save during a stage, reboot, restore, handle corrupt JSON, future format versions, and songs with maximum event counts.  
**UTC daily:** Test midnight UTC crossing, simulated time zone changes, mismatched generator version, offline play, and deterministic seeded results.  
**Android sharing:** Test missing target apps, invalid paths, older OS, file read permissions, `.wav` decoding, clipboard fallback, and rapid repeat exports.  
**Performance:** Target stable 60 FPS on a selected midrange Android phone and graceful functionality at 30 FPS; no GC spikes on successful hits, bounded particle count, battery/thermal sanity, no background audio unless opted into by OS expectations.  
**Accessibility:** Reduced flash, reduced motion, readable warning shape, left/right-thumb play, usable pause/menu gestures, consistent font contrast.

**Internal playtest targets (hypotheses, not market claims):**
- 80% of new testers understand the central rule without a verbal explanation.
- At least 70% finish the first track within three failed-stage retries.
- Median 4+ minutes of voluntary play in a short blind test; prioritize qualitative enjoyment over engineered compulsion.
- At least half of players who finish a track voluntarily replay it once or try a new track.
- At least 8 of 10 generated songs in a curated blind review sound musically coherent.

## 15. Monetization and ethics

The launch version can be entirely free, with a small permanent cosmetic `Studio Pack` considered only after retention and sharing quality are established. Keep gameplay and all five music genres earnable through play. No forced interstitial ads after death, no artificial energy system, no random purchase crates, no paid power that distorts daily results. These choices reduce both code footprint and reasons for players to quit. Nothing in the design guarantees revenue or chart success; release quality and discovery must be validated with real users.

## 16. Biggest risks and mitigation

| Risk | Mitigation |
|---|---|
| Generated loops sound chaotic | Curated voice grammar, chord-aware note generation, audio playtests, fallback groove skeleton |
| Rhythm drifts during reversal | Separate deterministic physical motion from master music clock; inner audio pulse ring |
| Pure-GDScript audio renderer is too slow | Short original pre-rendered samples, low-cost event mixing, buffer-ahead scheduling, real-device profiling |
| Four rounds take too long | Cut shot quotas or acceleration; never add explanatory interstitials |
| Daily challenge is unfair | Versioned deterministic generator, fixed mode rules, no unverified world leaderboard claim |
| Native share integration grows too large | Text codes first, one thin Kotlin share module, WAV FileProvider; cut static images and video |
| Visual effects obscure collision | Render true hit radius, bounded particles, clarity priority over spectacle |
| Below-5,000 LOC prevents quality | Preserve core feel/music, move variety into data/resources, postpone nonessential platform extras |

## 17. Immediate implementation order

1. Create the Godot 4 portrait project using the Compatibility renderer and a 2D record CanvasItem.
2. Implement and unit-test `phase_at(time)`, `angular_clearance`, fixed-flight impact prediction, and collision rules.
3. Place 6 shots against 1 preload pin and run a three-person blind test before adding music.
4. Implement a 16-step four-bar metronome and make landed pins audibly contribute events.
5. Build the four-layer flow and same-record retry; validate a full one-minute session.
6. Add the deterministic genre grammar and at least one polished synth bank.
7. Only then add perfect/edge, three specials, encore, save, daily, and sharing in that order.

**The single metric to protect:** When a player makes a risky but successful tap, they should immediately see the danger they escaped **and** hear the song become more satisfying. If that dual reward does not feel excellent, adding more modes will not solve the game.

---

## Technical references

- Godot official docs — Android export: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html
- Godot official docs — Compatibility renderer: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
- Godot official docs — Sync gameplay and audio: https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html
- Godot official docs — Android v2 plugins: https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html
- Godot official docs — AudioStreamWAV: https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html
- Android Developers — Secure content-URI file sharing: https://developer.android.com/training/secure-file-sharing/setup-sharing

