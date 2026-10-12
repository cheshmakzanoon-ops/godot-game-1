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
    # Android may return exit 0 with "null root" while the chooser is opening.
    # Retry missing/partial snapshots; never accept stale XML or guess an app tap.
    remote = "/data/local/tmp/nb_receiver.xml"
    for attempt in range(12):
        time.sleep(2)
        try:
            adb("shell", "rm", "-f", remote)
            output = adb("shell", "uiautomator", "dump", "--compressed", remote)
            (EVIDENCE / f"receiver-dump-{attempt}.txt").write_text(output)
            xml = adb("shell", "cat", remote)
            ET.fromstring(xml)  # A partial hierarchy is not evidence of a missing app.
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, ET.ParseError) as error:
            (EVIDENCE / f"receiver-dump-{attempt}.txt").write_text(str(error))
            continue
        (EVIDENCE / "receiver-chooser.xml").write_text(xml)
        try:
            x, y = target_point(xml)
            adb("shell", "input", "tap", x, y)
            return
        except ValueError:
            # Expand only after reading a valid hierarchy without our label.
            adb("shell", "input", "swipe", "240", "750", "240", "300", "300")
    raise AssertionError("No visible QA recipient after bounded chooser retries")


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
        for name, args, binary in [
            ("receiver-failure.log", ("logcat", "-d", "-t", "20000"), False),
            ("receiver-failure-window.txt", ("shell", "dumpsys", "window"), False),
            ("receiver-failure.png", ("exec-out", "screencap", "-p"), True),
        ]:
            try:
                result = adb(*args, binary=binary)
                path = EVIDENCE / name
                path.write_bytes(result) if binary else path.write_text(result)
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
                pass  # Keep the original diagnostic exception.
        raise
