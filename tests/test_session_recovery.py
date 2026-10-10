"""Host-level wiring guards for Android lifecycle recovery (no engine needed)."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SessionRecoveryContract(unittest.TestCase):
    def test_old_save_schema_and_active_song_extension(self):
        store = (ROOT / "scripts/ProgressStore.gd").read_text()
        self.assertIn('const VERSION := 1', store)
        self.assertIn('"active_song": {}', store)
        self.assertIn('data = _read_valid(backup_path)', store)

    def test_audio_timeline_uses_bounded_seek(self):
        engine = (ROOT / "scripts/MusicEngine.gd").read_text()
        self.assertIn('func seek_frame(target: int)', engine)
        self.assertIn('destination - RATE', engine)
        self.assertIn('func seek_seconds(seconds: float)', (ROOT / "scripts/AudioSystem.gd").read_text())

    def test_android_process_death_is_enforced_by_ci(self):
        workflow = (ROOT / ".github/workflows/ci.yml").read_text()
        probe = (ROOT / "tools/android_emulator_smoke.sh").read_text()
        self.assertIn('tests/checkpoint_flow.gd', workflow)
        self.assertIn('checkpoint_seed', probe)
        self.assertIn('NEEDLEBEAT_QA_SESSION_RESTORED stage=0 placed=1', probe)
        self.assertIn('adb shell am force-stop', probe)
        self.assertIn('-gpu swangle', workflow)


if __name__ == '__main__':
    unittest.main()
