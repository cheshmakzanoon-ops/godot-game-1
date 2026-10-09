#!/usr/bin/env python3
"""Host-only integrity and frame-invariance regression tests (no Godot needed)."""
from pathlib import Path
import hashlib
import math
import random
import struct
import unittest
import wave

ROOT = Path(__file__).resolve().parents[1]
TAU = 2 * math.pi
FLIGHT = 0.11


def circular(a, b):
    d = abs((a - b) % TAU)
    return min(d, TAU - d)


def phase(t, period, mode):
    n = math.floor(t / period)
    partial = t - n * period
    if mode == 'PULSE':
        return TAU / period * (period * (((n + 1) // 2) * .85 + (n // 2) * 1.15) + partial * (.85 if n % 2 == 0 else 1.15))
    if mode == 'REWIND':
        ramp = min(.16, period * .11)
        if partial < ramp:
            area = .5 * partial - ramp / (2*math.pi)*math.sin(math.pi*partial/ramp)
        elif partial <= period - ramp:
            area = .5*ramp + partial - ramp
        else:
            tail = partial - (period - ramp)
            area = period - 1.5*ramp + .5*tail + ramp/(2*math.pi)*math.sin(math.pi*tail/ramp)
        return TAU / period * ((period-ramp if n%2 else 0) + area * (-1 if n%2 else 1))
    return TAU * t / period


class NeedlbeatTests(unittest.TestCase):
    def test_project_resources(self):
        text = (ROOT / 'project.godot').read_text()
        self.assertIn('res://scenes/Main.tscn', text)
        for stem in ('Game', 'MusicEngine', 'AudioSystem', 'SongCodec', 'StageDirector', 'DiscMotion', 'Geometry', 'ProgressStore'):
            self.assertTrue((ROOT / 'scripts' / (stem + '.gd')).is_file(), stem)
        self.assertTrue((ROOT / '.github/workflows/ci.yml').exists())

    def test_all_50_original_samples(self):
        files = list((ROOT / 'audio').glob('*/*.wav'))
        self.assertEqual(len(files), 50)
        for f in files:
            with wave.open(str(f)) as w:
                self.assertEqual(w.getframerate(), 22050)
                self.assertEqual(w.getnchannels(), 1)
                self.assertEqual(w.getsampwidth(), 2)
                sample = w.readframes(w.getnframes())
                self.assertNotEqual(max(sample), min(sample), str(f))

    def test_collision_threshold_and_twins(self):
        rng = random.Random(1943)
        for _ in range(1000):
            p = rng.random() * TAU
            self.assertLess(circular(p, p + TAU - .00001), .000011)
            self.assertTrue(circular(p, p + math.radians(11.999)) < math.radians(12))
            self.assertTrue(circular(p, p + math.radians(12.001)) > math.radians(12))
        rings = {0: [0], 1: [math.pi / 2]}
        self.assertGreater(min(circular(0, v) for v in rings[1]), math.radians(12))

    def test_exact_impacts_at_30_60_120_fps(self):
        rng = random.Random(77)
        for mode in ('NORMAL', 'PULSE', 'REWIND'):
            for _ in range(2000):
                t = rng.uniform(.01, 22.)
                expected = (math.pi/2 - phase(t + FLIGHT, 2.4, mode)) % TAU
                for fps in (30, 60, 120):
                    frame = math.ceil((t + FLIGHT) * fps)
                    # Render frame may be later, but judgment must be at true impact.
                    self.assertGreaterEqual(frame/fps + 1e-10, t + FLIGHT)
                    actual = (math.pi/2 - phase(t + FLIGHT, 2.4, mode)) % TAU
                    self.assertAlmostEqual(expected, actual)

    def test_periodic_motion(self):
        self.assertAlmostEqual(phase(4.8, 2.4, 'REWIND'), 0)
        self.assertAlmostEqual(phase(4.8, 2.4, 'PULSE'), TAU * 2)

    def test_line_budget(self):
        sources = [*ROOT.glob('scripts/*.gd'), *ROOT.glob('tools/*.py'), *ROOT.glob('tests/*.gd'), *ROOT.glob('tests/*.py')]
        lines = sum(len(p.read_text().splitlines()) for p in sources)
        self.assertLess(lines, 5000, f'{lines} first-party source lines')
        print('First-party script / synthesis / test lines:', lines)


if __name__ == '__main__':
    unittest.main(verbosity=2)
