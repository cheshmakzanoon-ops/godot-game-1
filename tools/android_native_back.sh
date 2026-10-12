#!/usr/bin/env bash
# Runs against the same installed x86_64 debug APK after the existing runtime suite.
set -euo pipefail
package='com.needlebeat.drop'
evidence='build/emulator-evidence'
mkdir -p "$evidence"
adb shell am force-stop "$package"
adb logcat -c
adb shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p "$package"
sleep 5
adb shell input tap 240 720
sleep 2
adb logcat -d -t 40000 > "$evidence/native_back_logcat.txt"
grep -q 'NEEDLEBEAT_QA_PLAY_STARTED' "$evidence/native_back_logcat.txt"
adb shell input keyevent 4
sleep 2
adb shell pidof "$package" >/dev/null
adb logcat -d -t 40000 > "$evidence/native_back_logcat.txt"
grep -q 'NEEDLEBEAT_QA_NATIVE_BACK screen=PAUSED' "$evidence/native_back_logcat.txt"
adb shell screencap -p /sdcard/needlebeat_native_back.png
adb pull /sdcard/needlebeat_native_back.png "$evidence/native_back.png" >/dev/null
echo 'ANDROID_NATIVE_BACK_PASS: actual Back key paused without terminating the record'
