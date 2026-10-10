"""Check that the Android runtime acceptance gate remains wired up."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class AndroidEmulatorCITests(unittest.TestCase):
    def test_emulator_build_does_not_change_arm64_artifact(self):
        ci = (ROOT / '.github/workflows/ci.yml').read_text()
        self.assertIn('name: NEEDLEBEAT_DROP_Android_ARM64_Debug', ci)
        self.assertIn('name: NEEDLEBEAT_DROP_Android_x86_64_Debug', ci)
        self.assertIn('needs: android-debug', ci)
        self.assertIn('reactivecircus/android-emulator-runner@v2', ci)
        self.assertIn('api-level: 34', ci)
        self.assertIn('bash tools/android_emulator_smoke.sh', ci)

    def test_qa_cannot_trigger_for_release_or_ordinary_launch(self):
        source = (ROOT / 'scripts/Game.gd').read_text()
        probe = (ROOT / 'tests/android_runtime.gd').read_text()
        self.assertIn('OS.has_feature("debug")', source)
        self.assertIn('OS.has_feature("debug")', probe)
        self.assertIn('intent.getStringExtra(EXTRA)', probe)
        self.assertIn('NBAndroidShare.share_wav(PROBE_WAV)', probe)
        self.assertIn('NEEDLEBEAT_QA_SHARE_REQUESTED', probe)

    def test_emulator_requires_real_chooser_and_export(self):
        script = (ROOT / 'tools/android_emulator_smoke.sh').read_text()
        for phrase in ('adb install -r', 'adb shell input tap', 'NEEDLEBEAT_QA_EXPORT_OK',
                       'NEEDLEBEAT_QA_SHARE_REQUESTED', 'intentresolver', 'FATAL EXCEPTION'):
            self.assertIn(phrase, script)

if __name__ == '__main__':
    unittest.main()
