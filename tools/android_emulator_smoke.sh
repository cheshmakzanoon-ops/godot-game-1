#!/usr/bin/env bash
# Android 15 emulator runtime / touch / WAV share integration test.
set -euo pipefail
apk="${1:-build/NEEDLEBEAT_DROP-x86_64-debug.apk}"
package='com.needlebeat.drop'
evidence='build/emulator-evidence'
mkdir -p "$evidence"

fail() { echo "ANDROID_EMULATOR_FAILURE: $*" >&2; adb logcat -d -t 40000 > "$evidence/logcat.txt" || true; exit 1; }
# Google API emulator can show a Pixel Launcher ANR dialog above our healthy app.
# Only dismiss a focused launcher ANR; do not tap unrelated Android dialogs.
dismiss_launcher_anr() {
  for attempt in 1 2 3; do
    if adb shell dumpsys window | grep -Eq 'mCurrentFocus=.*Application Not Responding.*nexuslauncher'; then
      echo "Pixel Launcher ANR dismissed (attempt $attempt)" | tee -a "$evidence/system_dialogs.txt"
      adb shell input tap 300 418  # "Close app" in the emulator's ANR dialog
      sleep 3
    else
      break
    fi
  done
}
adb wait-for-device
adb shell getprop sys.boot_completed | tr -d '\r' | grep -qx '1' || fail 'emulator did not boot'
adb install -r "$apk" || fail 'failed to install x86_64 debug APK'
adb shell wm size 480x854
adb shell wm density 240
# Android shows a first-run immersive-mode confirmation, which masks screenshots.
adb shell settings put secure immersive_mode_confirmations confirmed || true
# Startup produces thousands of Google Play Services messages per second.
# Retain the first 15 seconds of app logs instead of losing the actual crash
# behind `logcat -t 5000`'s newest-lines-only truncation.
adb logcat -G 12M || true
adb logcat -c

# The first start must render the menu and accept the large one-thumb PLAY target.
adb shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p "$package"
sleep 3
adb logcat -d -t 40000 > "$evidence/early_startup_logcat.txt" || true
sleep 9
# Fallback for system images that ignore immersive_mode_confirmations settings.
adb shell input tap 390 353
sleep 2
dismiss_launcher_anr
if ! adb shell pidof "$package" >/dev/null; then
  adb logcat -d -t 40000 > "$evidence/first_launch_logcat.txt" || true
  adb shell dumpsys activity processes > "$evidence/first_launch_processes.txt" || true
  # Emulator cold boots can briefly drop an Activity; retry once and still
  # fail if the second launch also exits instead of masking a real regression.
  adb shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p "$package" || true
  sleep 6
  adb shell pidof "$package" >/dev/null || fail 'the game crashed during launch (twice)'
fi
adb shell screencap -p /sdcard/needlebeat_menu.png
adb pull /sdcard/needlebeat_menu.png "$evidence/menu.png" >/dev/null
adb shell input tap 240 720
sleep 5
adb shell pidof "$package" >/dev/null || fail 'the game crashed after a touch event'
adb logcat -d -t 5000 > "$evidence/after_tap_logcat.txt"
if ! grep -q 'NEEDLEBEAT_QA_PLAY_STARTED' "$evidence/after_tap_logcat.txt"; then
  dismiss_launcher_anr
  adb shell input tap 240 720
  sleep 5
  adb logcat -d -t 5000 > "$evidence/after_tap_logcat.txt"
fi
touch_failure=0
if ! grep -q 'NEEDLEBEAT_QA_PLAY_STARTED' "$evidence/after_tap_logcat.txt"; then
  touch_failure=1
  echo 'TOUCH_INCONCLUSIVE: PLAY event absent or blocked by Android system dialog' | tee "$evidence/touch_warning.txt"
fi
adb shell screencap -p /sdcard/needlebeat_play.png
adb pull /sdcard/needlebeat_play.png "$evidence/play.png" >/dev/null
visual_failure=0
if ! python3 tools/check_android_screenshots.py "$evidence/menu.png" "$evidence/play.png"; then
  visual_failure=1
  echo 'VISUAL_CAPTURE_INCONCLUSIVE: compositor output is unchanged' | tee "$evidence/visual_warning.txt"
  adb shell dumpsys window > "$evidence/window_state.txt" || true
  adb shell dumpsys SurfaceFlinger --list > "$evidence/surface_list.txt" || true
fi

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
dismiss_launcher_anr
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
# Fail visibly if the old software GPU uniform shader-link error reappears.
if grep -Fq 'Fragment shader active uniforms exceed GL_MAX_FRAGMENT_UNIFORM_VECTORS' "$evidence/after_tap_logcat.txt" "$evidence/logcat.txt"; then
  fail 'Android GLES3 canvas shader exceeded emulator GPU uniform limit'
fi
# Inject a debug-only transient audio-focus loss in the actual Android
# runtime. This uses the same callback path as the AudioManager listener.
adb shell am force-stop "$package"
adb logcat -c
adb shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER \
    -p "$package" --es needlebeat.qa audio_focus
for attempt in $(seq 1 25); do
  adb logcat -d -t 10000 > "$evidence/audio_focus_logcat.txt" || true
  if grep -q 'NEEDLEBEAT_QA_FOCUS_RESUMED' "$evidence/audio_focus_logcat.txt"; then break; fi
  if grep -Eq 'NEEDLEBEAT_QA_FOCUS_.*FAILED|FATAL EXCEPTION|SCRIPT ERROR' "$evidence/audio_focus_logcat.txt"; then
    fail 'Audio-focus probe crashed or refused a pause/resume transition'
  fi
  sleep 2
done
for marker in REQUEST_OK PAUSED NO_AUTOPLAY RESUMED; do
  grep -q "NEEDLEBEAT_QA_FOCUS_$marker" "$evidence/audio_focus_logcat.txt" || fail "Audio focus gate missing $marker"
done

# Save one real scored pin on Android, then terminate the process.
adb shell am force-stop "$package"
adb logcat -c
adb shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER \
    -p "$package" --es needlebeat.qa checkpoint_seed
for attempt in $(seq 1 30); do
  adb logcat -d -t 10000 > "$evidence/checkpoint_seed_logcat.txt" || true
  if grep -q 'NEEDLEBEAT_QA_CHECKPOINT_SAVED' "$evidence/checkpoint_seed_logcat.txt"; then break; fi
  if grep -Eq 'NEEDLEBEAT_QA_CHECKPOINT_.*(INCOMPLETE|NOT_DURABLE|NO_WINDOW)|FATAL EXCEPTION' "$evidence/checkpoint_seed_logcat.txt"; then
    fail 'Cannot persist an active record before Android process death'
  fi
  sleep 2
done
grep -q 'NEEDLEBEAT_QA_CHECKPOINT_SAVED' "$evidence/checkpoint_seed_logcat.txt" || fail 'Session checkpoint did not persist'
adb shell am force-stop "$package"
adb logcat -c
adb shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p "$package"
for attempt in $(seq 1 30); do
  adb logcat -d -t 10000 > "$evidence/checkpoint_restore_logcat.txt" || true
  if grep -q 'NEEDLEBEAT_QA_SESSION_RESTORED stage=0 placed=1' "$evidence/checkpoint_restore_logcat.txt"; then break; fi
  if grep -Eq 'FATAL EXCEPTION|SCRIPT ERROR' "$evidence/checkpoint_restore_logcat.txt"; then
    fail 'Restoration crashed after Android process death'
  fi
  sleep 2
done
grep -q 'NEEDLEBEAT_QA_SESSION_RESTORED stage=0 placed=1' "$evidence/checkpoint_restore_logcat.txt" || fail 'Android relaunch did not recover an unfinished record'
adb shell screencap -p /sdcard/needlebeat_recovered.png
adb pull /sdcard/needlebeat_recovered.png "$evidence/recovered.png" >/dev/null

# Exercise sustained Android rendering and native audio streaming independently
# of test-mode WAV export. The app reports measured frame pacing, audio clock
# progression, generator skips and engine-allocator growth; fail on a regression.
adb shell am force-stop "$package"
adb logcat -c
adb shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER \
    -p "$package" --es needlebeat.qa performance_soak
for attempt in $(seq 1 75); do
  adb logcat -d -t 20000 > "$evidence/perf_soak_logcat.txt" || true
  if grep -q 'NEEDLEBEAT_QA_PERF_PASS' "$evidence/perf_soak_logcat.txt"; then break; fi
  if grep -Eq 'NEEDLEBEAT_QA_PERF_FAIL|FATAL EXCEPTION|SCRIPT ERROR' "$evidence/perf_soak_logcat.txt"; then
    fail 'Android sustained performance probe reported a failure'
  fi
  sleep 1
done
grep -q 'NEEDLEBEAT_QA_PERF_PASS' "$evidence/perf_soak_logcat.txt" || fail 'Performance probe timed out'
grep -q 'NEEDLEBEAT_QA_PERF_METRICS' "$evidence/perf_soak_logcat.txt" || fail 'Performance metrics were not reported'
adb shell dumpsys meminfo "$package" > "$evidence/soak_meminfo.txt" || true
adb shell dumpsys gfxinfo "$package" framestats > "$evidence/soak_gfxinfo.txt" || true
adb shell screencap -p /sdcard/needlebeat_soak.png
adb pull /sdcard/needlebeat_soak.png "$evidence/soak.png" >/dev/null

if [ "$touch_failure" -ne 0 ] || [ "$visual_failure" -ne 0 ]; then
  fail 'Android screen or touch regression; see emulator evidence'
fi
echo 'ANDROID_EMULATOR_PASS: launch, touch, WAV share, focus, recovery, sustained performance'