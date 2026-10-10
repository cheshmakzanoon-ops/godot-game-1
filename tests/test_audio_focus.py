"""Contract guards for the Android audio-focus integration and CI entrypoint."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class AudioFocusContract(unittest.TestCase):
    def test_android_focus_request_uses_platform_interface(self):
        source = (ROOT / 'scripts/AndroidAudioFocus.gd').read_text()
        self.assertIn('create_sam_callback(', source)
        self.assertIn('AudioManager$OnAudioFocusChangeListener', source)
        self.assertIn('requestAudioFocus(listener, 3, FOCUS_GAIN)', source)
        self.assertIn('abandonAudioFocus(listener)', source)
        self.assertNotIn('AudioAttributes$Builder").Builder()', source)
        self.assertIn('call_deferred("_apply_focus_change", change)', source)

    def test_focus_loss_does_not_autoresume_or_lose_checkpoint(self):
        game = (ROOT / 'scripts/Game.gd').read_text()
        audio = (ROOT / 'scripts/AudioSystem.gd').read_text()
        self.assertIn('audio.focus_interrupted.connect(_on_android_audio_interrupted)', game)
        self.assertIn('if not audio.resume_playback():', game)
        self.assertIn('focus.abandon_focus()', audio)
        self.assertIn('player.stream_paused = true', audio)
        self.assertIn('_checkpoint_session()', game)

    def test_qa_requires_real_android_bridge_and_focus_transitions(self):
        qa = (ROOT / 'tests/android_runtime.gd').read_text()
        ci = (ROOT / '.github/workflows/ci.yml').read_text()
        emulator = (ROOT / 'tools/android_emulator_smoke.sh').read_text()
        self.assertIn('if not game.audio.focus.supported:', qa)
        self.assertIn('tests/audio_focus_flow.gd', ci)
        self.assertIn('needlebeat.qa audio_focus', emulator)
        for marker in ('REQUEST_OK', 'PAUSED', 'NO_AUTOPLAY', 'RESUMED'):
            self.assertIn(marker, emulator)
        self.assertNotIn('NOTIFICATION_APPLICATION_RESUMED', (ROOT / 'scripts/AudioSystem.gd').read_text())


if __name__ == '__main__':
    unittest.main()
