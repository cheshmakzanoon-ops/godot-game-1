#!/usr/bin/env bash
# Android 15 emulator runtime / touch / WAV share integration test.
set -euo pipefail
apk="${1:-build/NEEDLEBEAT_DROP-x86_64-debug.apk}"
package='com.needlebeat.drop'
evidence='build/emulator-evidence'
mkdir -p "$evidence"

fail() { echo "ANDROID_EMULATOR_FAILURE: $*" >&2; adb logcat -d -t 5000 > "$evidence/logcat.txt" || true; exit 1; }
adb wait-for-device
adb shell getprop sys.boot_completed | tr -d '\r' | grep -qx '1' || fail 'emulator did not boot'
adb install -r "$apk" || fail 'failed to install x86_64 debug APK'
adb shell wm size 480x854
adb shell wm density 240
adb logcat -c

# The first start must render the menu and accept the large one-thumb PLAY target.
adb shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p "$package"
sleep 12
adb shell pidof "$package" >/dev/null || fail 'the game crashed during launch'
adb shell screencap -p /sdcard/needlebeat_menu.png
adb pull /sdcard/needlebeat_menu.png "$evidence/menu.png" >/dev/null
adb shell input tap 240 720
sleep 5
adb shell pidof "$package" >/dev/null || fail 'the game crashed after a touch event'
adb logcat -d -t 5000 > "$evidence/after_tap_logcat.txt"
grep -q 'NEEDLEBEAT_QA_PLAY_STARTED' "$evidence/after_tap_logcat.txt" || fail 'the PLAY tap did not start a record'
adb shell screencap -p /sdcard/needlebeat_play.png
adb pull /sdcard/needlebeat_play.png "$evidence/play.png" >/dev/null
python3 tools/check_android_screenshots.py "$evidence/menu.png" "$evidence/play.png" || fail 'screenshots invalid or menu did not transition'

# A separate launch exercises real Android FileProvider + chooser from GDScript.
adb shell am force-stop "$package"
adb logcat -c
adb shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER \
    -p "$package" --es needlebeat.qa wav_share
for attempt in $(seq 1 45); do
  adb logcat -d -t 10000 > "$evidence/logcat.txt" || true
  if grep -q 'NEEDLEBEAT_QA_SHARE_REQUESTED' "$evidence/logcat.txt"; then break; fi
  if grep -q 'NEEDLEBEAT_QA_.*FAILED\|NEEDLEBEAT_QA_.*UNAVAILABLE\|FATAL EXCEPTION' "$evidence/logcat.txt"; then
    fail 'Android WAV integration probe failed'
  fi
  sleep 2
done
grep -q 'NEEDLEBEAT_QA_EXPORT_OK' "$evidence/logcat.txt" || fail 'WAV export was not confirmed'
grep -q 'NEEDLEBEAT_QA_SHARE_REQUESTED' "$evidence/logcat.txt" || fail 'FileProvider sharing intent was not issued'

# Android can display either the native sharesheet or a resolver depending on image/apps.
adb shell dumpsys activity activities > "$evidence/activities.txt"
adb shell uiautomator dump /sdcard/needlebeat_window.xml >/dev/null 2>&1 || true
adb shell cat /sdcard/needlebeat_window.xml > "$evidence/window.xml" 2>/dev/null || true
adb shell screencap -p /sdcard/needlebeat_share.png
adb pull /sdcard/needlebeat_share.png "$evidence/share.png" >/dev/null
if ! grep -Eiq 'chooser|resolver|sharesheet|intentresolver' "$evidence/activities.txt" "$evidence/window.xml"; then
  fail 'The Android share sheet did not become visible'
fi
if grep -Eiq 'FATAL EXCEPTION|AndroidRuntime.*FATAL|NEEDLEBEAT_QA_SHARE_FAILED' "$evidence/logcat.txt"; then
  fail 'Uncaught Android error detected'
fi
echo 'ANDROID_EMULATOR_PASS: launch, touch, PCM WAV, native sharesheet'
