"""Prevent accidental removal of the bounded audio soak and Android QA gate."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PerformanceContract(unittest.TestCase):
    def test_ten_minute_bounded_synthesis_is_part_of_ci(self):
        source = (ROOT / 'tests/audio_soak.gd').read_text()
        ci = (ROOT / '.github/workflows/ci.yml').read_text()
        self.assertIn('DURATION_SECONDS := 600', source)
        self.assertIn('max_voices <= MAX_VOICES', source)
        self.assertIn('memory_delta=', source)
        self.assertIn('ratio < 0.35', source)
        self.assertIn('audio_soak.gd', ci)

    def test_android_probe_needs_debug_intent(self):
        control = (ROOT / 'tests/android_runtime.gd').read_text()
        script = (ROOT / 'tests/android_soak.gd').read_text()
        self.assertIn('OS.has_feature("debug")', control)
        self.assertIn('performance_soak', control)
        self.assertIn('get_parent().add_child(probe)', control)
        self.assertIn('NEEDLEBEAT_QA_PERF_PASS', script)
        self.assertIn('get_skips()', script)
        self.assertIn('MAX_MEMORY_GROWTH', script)

    def test_emulator_uploads_genuine_perf_evidence(self):
        script = (ROOT / 'tools/android_emulator_smoke.sh').read_text()
        self.assertIn('needlebeat.qa performance_soak', script)
        self.assertIn('NEEDLEBEAT_QA_PERF_PASS', script)
        self.assertIn('perf_soak_logcat.txt', script)
        self.assertIn('soak_meminfo.txt', script)


if __name__ == '__main__':
    unittest.main()
