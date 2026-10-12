"""Select a separate recipient in Android's real chooser; require exact WAV bytes."""
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

EVIDENCE = Path("build/emulator-evidence")
GAME = "com.needlebeat.drop"
RECEIVER = "com.needlebeat.wavverifier"
LABEL = "NB WAV verifier"


def adb(*args, binary=False):
    return subprocess.run(["adb", *args], check=True, capture_output=True,
                          text=not binary, timeout=30).stdout


def target_point(xml):
    for node in ET.fromstring(xml).iter("node"):
        if LABEL in (node.get("text", ""), node.get("content-desc", "")):
            bounds = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", ""))
            if bounds:
                x1, y1, x2, y2 = map(int, bounds.groups())
                if x2 > x1 and y2 > y1:
                    return str((x1 + x2) // 2), str((y1 + y2) // 2)
    raise ValueError("QA recipient not visible in the Android share sheet")


def validate_receipt(receipt, log):
    match = re.search(r"NEEDLEBEAT_QA_EXPORT_SHA256=([0-9a-f]{64})", log)
    assert match and receipt.get("sha256") == match[1], "received WAV differs from sender"
    assert receipt.get("bytes") == 705644, "wrong four-bar PCM byte length"
    assert abs(receipt.get("duration_ms", -1) - 8000) <= 50, "native decoder duration"
    assert all(receipt.get(k) is True for k in ("read_granted", "write_denied", "sibling_denied"))
    assert "NEEDLEBEAT_QA_PRIVATE_FIXTURE_OK" in log, "unshared sibling must exist"
    assert "NEEDLEBEAT_QA_ORIGIN_CHANGED" in log, "origin replacement must exercise snapshot isolation"
    assert receipt.get("uri", "").startswith("content://com.needlebeat.drop.fileprovider/"), "not engine content URI"


def wait_for(marker, logfile):
    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        log = adb("logcat", "-d", "-t", "20000")
        logfile.write_text(log)
        assert not re.search(r"NEEDLEBEAT_RECEIVER_FAIL|NEEDLEBEAT_QA_\w*FAILED|FATAL EXCEPTION", log), "Android runtime failure"
        if marker in log:
            return log
        time.sleep(1)
    raise TimeoutError(marker)


def launch():
    adb("shell", "am", "force-stop", GAME)
    adb("shell", "am", "start", "-W", "-a", "android.intent.action.MAIN", "-c",
        "android.intent.category.LAUNCHER", "-p", GAME, "--es", "needlebeat.qa", "receiver_share")


def choose():
    for attempt in range(5):
        adb("shell", "uiautomator", "dump", "/sdcard/nb_receiver.xml")
        xml = adb("shell", "cat", "/sdcard/nb_receiver.xml")
        (EVIDENCE / "receiver-chooser.xml").write_text(xml)
        try:
            x, y = target_point(xml)
            adb("shell", "input", "tap", x, y)
            return
        except ValueError:
            # Expand a collapsed sharesheet, not blind coordinates for an app.
            adb("shell", "input", "swipe", "240", "750", "240", "300", "300")
            time.sleep(1)
    raise AssertionError("No visible QA recipient after expanding chooser")


def run():
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    adb("install", "-r", "build/NEEDLEBEAT_WAV_Verifier.apk")
    # Cancel first; do not treat a chooser's mere appearance as successful delivery.
    adb("logcat", "-c")
    launch()
    wait_for("NEEDLEBEAT_QA_SHARE_REQUESTED", EVIDENCE / "receiver-cancel.log")
    time.sleep(2)
    adb("shell", "input", "keyevent", "4")
    time.sleep(1)
    assert "NEEDLEBEAT_RECEIVER_PASS" not in adb("logcat", "-d"), "cancel delivered a file"
    for attempt in range(2):
        adb("shell", "am", "force-stop", RECEIVER)
        adb("logcat", "-c")
        launch()
        logfile = EVIDENCE / f"receiver-{attempt}.log"
        wait_for("NEEDLEBEAT_QA_SHARE_REQUESTED", logfile)
        choose()
        log = wait_for("NEEDLEBEAT_RECEIVER_PASS", logfile)
        receipt = json.loads(adb("shell", "run-as", RECEIVER, "cat", "files/receipt.json"))
        validate_receipt(receipt, log)
        (EVIDENCE / f"receiver-{attempt}.json").write_text(json.dumps(receipt, indent=2))
    (EVIDENCE / "receiver.png").write_bytes(adb("exec-out", "screencap", "-p", binary=True))
    print("ANDROID_RECEIVER_PASS: exact PCM, native decoder, read-only URI, sibling denied, cancel and repeat")


if __name__ == "__main__":
    try:
        run()
    except Exception:
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        (EVIDENCE / "receiver-failure.log").write_text(adb("logcat", "-d", "-t", "20000"))
        raise
