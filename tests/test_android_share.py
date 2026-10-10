"""Verify that sharing uses Godot 4.7's existing Android FileProvider."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class AndroidWavShareTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.code = (ROOT / "scripts/AndroidShare.gd").read_text(encoding="utf8")

    def test_no_unnecessary_gradle_dependency(self):
        preset = (ROOT / "export_presets.cfg").read_text()
        self.assertIn("gradle_build/use_gradle_build=false", preset)
        self.assertFalse((ROOT / "android_native").exists())

    def test_engine_native_content_provider_and_grants(self):
        for required in ('androidx.core.content.FileProvider',
                         '.fileprovider', 'getUriForFile(', 'java.io.File',
                         'FLAG_GRANT_READ_URI_PERMISSION', 'setClipData(',
                         'ACTION_SEND', 'audio/wav', 'createChooser(',
                         'createRunnableFromGodotCallable(',
                         'runOnUiThread(', 'user://exports/'):
            self.assertIn(required, self.code)
        self.assertNotIn('Uri.fromFile', self.code)
        self.assertNotIn('file://', self.code)
        self.assertNotIn('android.permission.READ_EXTERNAL_STORAGE', self.code)

    def test_sharing_is_guarded(self):
        self.assertIn('path.begins_with("user://exports/")', self.code)
        self.assertIn('path.get_extension().to_lower() != "wav"', self.code)
        self.assertIn('path.get_file().begins_with("needlebeat_")', self.code)
        self.assertIn('FileAccess.file_exists(path)', self.code)
        self.assertIn('OS.get_name() != "Android"', self.code)
        self.assertIn('JavaClassWrapper.get_exception()', self.code)

    def test_ci_checks_fileprovider_in_apk(self):
        workflow = (ROOT / '.github/workflows/ci.yml').read_text()
        self.assertIn('aapt" dump xmltree', workflow)
        self.assertIn('FileProvider', workflow)
        self.assertNotIn('Install Godot Android Gradle', workflow)


if __name__ == '__main__':
    unittest.main()
