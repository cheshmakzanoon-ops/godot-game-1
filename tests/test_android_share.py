"""Android cache-only FileProvider wiring and template-overlay regressions."""
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


class AndroidWavShareTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.project = Path(self.tmp.name)
        shutil.copytree(ROOT / "android_native", self.project / "android_native")
        spec = importlib.util.spec_from_file_location("prepare_android_share", ROOT / "tools/prepare_android_share.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.install = module.install

    def _template(self):
        app = self.project / "android" / "build"
        (app / "src/main").mkdir(parents=True)
        (app / "src/main/AndroidManifest.xml").write_text(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
            '<application></application></manifest>', encoding="utf-8")
        (app / "build.gradle").write_text('plugins {}\ndependencies {\n    implementation "x:y:1"\n}\n', encoding="utf-8")
        return app

    def test_android_gradle_configured(self):
        preset = (ROOT / "export_presets.cfg").read_text()
        self.assertIn('gradle_build/use_gradle_build=true', preset)
        self.assertIn('com.needlebeat.drop', preset)

    def test_missing_template_fails_closed(self):
        with self.assertRaisesRegex(RuntimeError, "template missing"):
            self.install(self.project)

    def test_fileprovider_overlay_idempotent(self):
        app = self._template()
        self.install(self.project)
        manifest = app / "src/main/AndroidManifest.xml"
        gradle = app / "build.gradle"
        first_manifest, first_gradle = manifest.read_text(), gradle.read_text()
        self.install(self.project)
        self.assertEqual(manifest.read_text(), first_manifest)
        self.assertEqual(gradle.read_text(), first_gradle)
        root = ET.fromstring(first_manifest)
        ns = '{http://schemas.android.com/apk/res/android}'
        provider = root.find('application/provider')
        self.assertIsNotNone(provider)
        self.assertEqual(provider.attrib[ns+'authorities'], '${applicationId}.share')
        self.assertEqual(provider.attrib[ns+'exported'], 'false')
        self.assertEqual(provider.attrib[ns+'grantUriPermissions'], 'true')
        self.assertEqual(first_manifest.count('androidx.core.content.FileProvider'), 1)
        self.assertEqual(first_gradle.count('androidx.core:core:1.13.1'), 1)
        paths = ET.parse(app / 'src/main/res/xml/needlebeat_share_paths.xml').getroot()
        self.assertEqual(len(paths), 1)
        self.assertEqual(paths[0].tag, 'cache-path')
        self.assertEqual(paths[0].attrib['path'], 'shared_audio/')
        self.assertTrue((app / 'src/main/java/com/needlebeat/drop/NeedlebeatShare.java').is_file())

    def test_java_bridge_security_guards(self):
        java = (ROOT / 'android_native/src/main/java/com/needlebeat/drop/NeedlebeatShare.java').read_text()
        for marker in ('getCanonicalFile()', 'getFilesDir()', 'getCacheDir()',
                       'getUriForFile(', 'FLAG_GRANT_READ_URI_PERMISSION',
                       'ACTION_SEND', 'setClipData(', 'audio/wav', 'MAX_AUDIO_BYTES',
                       '.matches(', 'runOnUiThread('):
            self.assertIn(marker, java)
        self.assertNotIn('Uri.fromFile', java)
        self.assertNotIn('MANAGE_EXTERNAL_STORAGE', java)


if __name__ == '__main__':
    unittest.main()
