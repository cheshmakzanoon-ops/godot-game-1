#!/usr/bin/env python3
"""Deterministic original one-shot synthesis. No external samples/dependencies."""
from pathlib import Path
from math import sin, pi, exp, tanh
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / 'audio'
RATE = 22050
VOICES = {'kick': .35, 'snare': .25, 'hat': .12, 'perc': .20,
          'bass': .85, 'lead': .70, 'chord': .95, 'click': .07,
          'crash': .55, 'fail': .24}


def make(voice, genre):
    rng = random.Random(18122026 + genre * 37 + list(VOICES).index(voice))
    dur = VOICES[voice]
    n = round(dur * RATE)
    arr = []
    previous = 0.0
    prev2 = 0.0
    phase = 0.0
    for i in range(n):
        t = i / RATE
        k = t / dur
        raw_noise = rng.random() * 2 - 1
        # Dynamic, deterministic high-passed noise prevents digital hiss fatigue.
        high = raw_noise - previous * .80
        previous = raw_noise
        bass_freq = 110.0 * (1.0 if genre != 4 else .995)
        if voice == 'kick':
            freq = 47 + 110 * exp(-t * 34)
            phase += 2 * pi * freq / RATE
            v = sin(phase) * exp(-t * (11 if genre != 1 else 9)) + high * .06 * exp(-t * 90)
        elif voice == 'snare':
            v = (high * (.56 if genre != 4 else .32) + sin(2 * pi * 180 * t) * .24) * exp(-t * (17 if genre != 1 else 13))
        elif voice == 'hat':
            v = high * exp(-t * (36 if genre != 4 else 24)) * .50
        elif voice == 'perc':
            v = (sin(2 * pi * (385 + 110 * exp(-t * 35)) * t) + .22 * high) * exp(-t * 20) * .49
        elif voice == 'bass':
            f = bass_freq
            phase += 2 * pi * f / RATE
            if genre == 2:
                v = (.65 * sin(phase) + .23 * sin(phase * 2) + .09 * sin(phase * 3)) * exp(-t * 4.5)
            elif genre == 3:
                v = (.44 * sin(phase) + .16 * (1 if sin(phase) > 0 else -1)) * exp(-t * 4)
            else:
                v = (sin(phase) * .69 + sin(2 * phase) * .24 + sin(3 * phase) * .07) * exp(-t * (5 if genre == 0 else 4))
            v *= min(1, t * 200)
        elif voice == 'lead':
            f = 440.0
            phase += 2 * pi * f / RATE
            wobble = sin(2 * pi * 5.0 * t)
            if genre == 3:
                v = (.46 * (1 if sin(phase) > 0 else -1) + .12 * sin(phase * 2)) * exp(-t * 4.2)
            elif genre == 4:
                v = (sin(phase + .7 * sin(phase * 2.03)) + .23 * sin(2 * phase)) * exp(-t * 4.5) * .65
            else:
                v = (sin(phase + .28 * wobble) * .55 + sin(2 * phase) * .23 + sin(3 * phase) * .10) * exp(-t * (4.2 if genre != 1 else 3.3))
            v *= min(1, t * 140)
        elif voice == 'chord':
            phase += 2 * pi * 261.6256 / RATE
            if genre == 4:
                v = sin(phase + 1.2 * sin(2.002 * phase)) * exp(-t * 4.2) * .57
            else:
                v = (sin(phase) * .62 + sin(2.005 * phase) * .22 + sin(3 * phase) * .11) * exp(-t * 3.2)
            v *= min(1, t * (100 if genre != 1 else 50))
        elif voice == 'click':
            v = high * exp(-t * 85) * .43 + sin(2 * pi * 990 * t) * exp(-t * 68) * .25
        elif voice == 'crash':
            v = high * exp(-t * 7.7) * .62 + sin(2 * pi * 112 * t) * exp(-t * 18) * .17
        else:  # fail: brief pitched scratch, deliberately less loud than success.
            freq = 220 * (1.0 - .73 * k)
            phase += 2 * pi * freq / RATE
            v = (sin(phase) * .43 + high * .3) * exp(-t * 14)
        if genre == 1 and voice not in ('click', 'fail'):
            v = .72 * v + .28 * prev2  # warmer/dustier cassette response
        if genre == 3 and voice in ('bass', 'lead'):
            v = round(v * 16) / 16.0  # gentle 8-bit imprint
        prev2 = v
        # Fade the last ~5 ms to prevent sample clicks.
        v *= min(1.0, max(0.0, (dur - t) * 195))
        arr.append(v)
    peak = max(abs(x) for x in arr) or 1
    gain = (.77 if voice in ('kick', 'bass', 'lead') else .59) / peak
    return [tanh(s * gain) for s in arr]


def write_wav(path, samples):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(struct.pack('<' + 'h' * len(samples), *(int(max(-1, min(1, s)) * 32767) for s in samples)))


def main():
    for genre in range(5):
        for voice in VOICES:
            write_wav(ROOT / str(genre) / f'{voice}.wav', make(voice, genre))
    print('Generated 50 original PCM instruments/effects for 5 genre palettes')


if __name__ == '__main__':
    main()
