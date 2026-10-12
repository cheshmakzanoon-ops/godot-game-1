"""Host validation of the cross-UID Android acceptance gate's evidence checks."""
import importlib.util
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("recipient", ROOT / "tools/android_share_receiver.py")
recipient = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recipient)


class RecipientTests(unittest.TestCase):
    def test_fixture_has_no_permissions_or_shared_uid(self):
        manifest = ET.parse(ROOT / "tests/android_receiver/AndroidManifest.xml").getroot()
        self.assertFalse(manifest.findall("uses-permission"))
        self.assertNotIn("{http://schemas.android.com/apk/res/android}sharedUserId", manifest.attrib)
        self.assertNotEqual(manifest.get("package"), "com.needlebeat.drop")

    def test_click_uses_recipient_label_bounds(self):
        xml = '<hierarchy><node text="NB WAV verifier" bounds="[10,40][90,100]"/></hierarchy>'
        self.assertEqual(recipient.target_point(xml), ("50", "70"))
        with self.assertRaises(ValueError):
            recipient.target_point(xml.replace("NB WAV verifier", "Unrelated app"))

    def test_receipt_requires_content_identity_and_denied_permissions(self):
        sha = "e" * 64
        log = "NEEDLEBEAT_QA_EXPORT_SHA256=" + sha + "\nNEEDLEBEAT_QA_PRIVATE_FIXTURE_OK\nNEEDLEBEAT_QA_ORIGIN_CHANGED"
        good = dict(sha256=sha, bytes=705644, duration_ms=8000, read_granted=True,
                    write_denied=True, sibling_denied=True,
                    uri="content://com.needlebeat.drop.fileprovider/filesRoot/exports/test.wav")
        recipient.validate_receipt(good, log)
        for field, invalid in [("sha256", "f" * 64), ("bytes", 44), ("duration_ms", 0),
                               ("write_denied", False), ("sibling_denied", False), ("read_granted", False)]:
            with self.subTest(field=field), self.assertRaises(AssertionError):
                recipient.validate_receipt(dict(good, **{field: invalid}), log)

    def test_ci_builds_separate_recipient_and_runs_real_chooser_path(self):
        ci = (ROOT / ".github/workflows/ci.yml").read_text()
        self.assertIn("build_wav_receiver.sh", ci)
        self.assertIn("python3 tools/android_share_receiver.py", ci)
        source = (ROOT / "tests/android_receiver/src/com/needlebeat/wavverifier/ReceiveActivity.java").read_text()
        for operation in ("openInputStream(uri)", "openOutputStream(uri", "openInputStream(sibling)",
                          "decoder.prepare()", "MessageDigest.getInstance(\"SHA-256\")"):
            self.assertIn(operation, source)
