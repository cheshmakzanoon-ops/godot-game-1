# Phase E — Immutable WAV sharing and a real receiving app

The previous Android gate proved that the sharesheet opened. It did not prove
that a separate app could read the chosen file. The new gate installs the
permission-free `com.needlebeat.wavverifier` test APK as a different Android UID,
selects **NB WAV verifier** in the real system chooser, and requires it to:

- Open the content URI with its own ContentResolver, validate all PCM header
  fields, and hash the complete file (not an adb-pulled copy).
- Match the sender's SHA-256 and 705,644-byte, eight-second stereo fixture.
- Prepare that URI using Android MediaPlayer and verify its decoded duration.
- Reject opening the file for writing and reject reading an existing unshared
  sibling. The receiver requests no storage or network permissions.

Two deliveries are required, preceded by a cancelled chooser. Receipts, logcat,
chooser XML and a screenshot are retained with emulator evidence. The host tests
also reject altered hashes, missing denials and incorrect duration/length.

## Production changes

Shared files are now copied to private content-addressed snapshots named
`needlebeat_shared_<sha256>.wav`. Re-exporting a different arrangement using the
same original filename cannot change an already-shared attachment. Identical
exports reuse a verified snapshot. The debug-only receiver probe replaces its
original fixture *after* sharing; the receiver must still read the original PCM.
The probe never modifies player files. Existing `wav_share` probes are unchanged.

WAV rendering writes to a temporary file and verifies write status and length
before replacement. Failed writes preserve the existing export. A Godot test
exercises this by making the temporary destination unwritable.

## Scope and remaining validation

The recipient APK is test-only: not installed for players, not a plugin, and not
part of the game APK's native classes. It is built directly with Java/SDK tools;
no Gradle or external application dependencies were added to the game.

This gate is not proof of compatibility with every messaging app. It does not
measure audible playback, Bluetooth latency, real-phone frame pacing or thermal
performance. Private immutable snapshots are retained; a future explicit user
cleanup flow must not remove attachments still in use by receiving apps.

References: Android's official secure-file-sharing guides:
https://developer.android.com/training/secure-file-sharing/request-file
https://developer.android.com/training/secure-file-sharing/retrieve-info
