package com.needlebeat.wavverifier;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.media.MediaPlayer;
import android.net.Uri;
import android.os.Bundle;
import android.os.Process;
import android.provider.OpenableColumns;
import android.util.Log;
import android.widget.TextView;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import org.json.JSONObject;

/** CI-only receiving app. Reads through its own ContentResolver, never adb/run-as. */
public final class ReceiveActivity extends Activity {
    private TextView status;
    private static final int LIMIT = 4 * 1024 * 1024;

    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        status = new TextView(this);
        status.setTextSize(22);
        status.setPadding(24, 80, 24, 24);
        status.setText("Checking shared WAV...");
        setContentView(status);
        new Thread(() -> verify(getIntent()), "wav-verifier").start();
    }

    private static void require(boolean condition, String reason) {
        if (!condition) throw new IllegalStateException(reason);
    }

    @SuppressWarnings("deprecation")
    private void verify(Intent intent) {
        try {
            require(Intent.ACTION_SEND.equals(intent.getAction()), "wrong action");
            Uri uri = intent.getParcelableExtra(Intent.EXTRA_STREAM);
            require(uri != null && "content".equals(uri.getScheme()), "not a content URI");
            require("com.needlebeat.drop.fileprovider".equals(uri.getAuthority()), "wrong provider");
            require("audio/wav".equals(intent.getType()), "wrong MIME");
            require(intent.getClipData() != null && intent.getClipData().getItemCount() == 1
                && uri.equals(intent.getClipData().getItemAt(0).getUri()), "ClipData mismatch");
            require(checkUriPermission(uri, Process.myPid(), Process.myUid(),
                Intent.FLAG_GRANT_READ_URI_PERMISSION) == PackageManager.PERMISSION_GRANTED, "no read grant");
            require(checkUriPermission(uri, Process.myPid(), Process.myUid(),
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION) == PackageManager.PERMISSION_DENIED, "write grant leaked");
            String name;
            long declaredSize;
            try (Cursor c = getContentResolver().query(uri, null, null, null, null)) {
                require(c != null && c.moveToFirst(), "missing metadata");
                name = c.getString(c.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME));
                declaredSize = c.getLong(c.getColumnIndexOrThrow(OpenableColumns.SIZE));
            }
            require(name.matches("needlebeat_shared_[0-9a-f]{64}\\.wav"), "not an immutable WAV snapshot");
            require(declaredSize > 44 && declaredSize <= LIMIT, "invalid size");
            byte[] wav;
            try (InputStream input = getContentResolver().openInputStream(uri);
                 ByteArrayOutputStream bytes = new ByteArrayOutputStream()) {
                require(input != null, "null input stream");
                byte[] buffer = new byte[8192];
                for (int n; (n = input.read(buffer)) != -1;) {
                    require(bytes.size() + n <= LIMIT, "unbounded data");
                    bytes.write(buffer, 0, n);
                }
                wav = bytes.toByteArray();
            }
            require(wav.length == declaredSize, "truncated recipient read");
            ByteBuffer header = ByteBuffer.wrap(wav).order(ByteOrder.LITTLE_ENDIAN);
            require(new String(wav, 0, 4, StandardCharsets.US_ASCII).equals("RIFF")
                && new String(wav, 8, 8, StandardCharsets.US_ASCII).equals("WAVEfmt ")
                && new String(wav, 36, 4, StandardCharsets.US_ASCII).equals("data"), "invalid RIFF chunks");
            require(header.getInt(4) == wav.length - 8 && header.getInt(16) == 16
                && header.getShort(20) == 1 && header.getShort(22) == 2
                && header.getInt(24) == 22050 && header.getInt(28) == 88200
                && header.getShort(32) == 4 && header.getShort(34) == 16
                && header.getInt(40) == wav.length - 44, "wrong PCM format");
            boolean writeDenied = false;
            try (OutputStream ignored = getContentResolver().openOutputStream(uri, "wa")) {
                // Opening alone must fail; never modify the source even on regression.
            } catch (SecurityException expected) { writeDenied = true; }
            require(writeDenied, "provider allowed writing");
            String parent = uri.getPath().substring(0, uri.getPath().lastIndexOf('/') + 1);
            Uri sibling = uri.buildUpon().path(parent + "needlebeat_qa_private.txt").build();
            boolean siblingDenied = false;
            try (InputStream ignored = getContentResolver().openInputStream(sibling)) {
                // Sender creates this harmless fixture: denial cannot be a missing-file pass.
            } catch (SecurityException expected) { siblingDenied = true; }
            require(siblingDenied, "read grant leaked to an unshared sibling");
            MediaPlayer decoder = new MediaPlayer();
            int duration;
            try {
                decoder.setDataSource(this, uri);
                decoder.prepare();
                duration = decoder.getDuration();
                require(Math.abs(duration - 8000) <= 50, "Android decoder rejected four-bar duration");
            } finally { decoder.release(); }
            StringBuilder sha = new StringBuilder();
            for (byte b : MessageDigest.getInstance("SHA-256").digest(wav)) sha.append(String.format("%02x", b & 255));
            JSONObject receipt = new JSONObject();
            receipt.put("sha256", sha.toString()).put("bytes", wav.length).put("duration_ms", duration)
                .put("read_granted", true).put("write_denied", true).put("sibling_denied", true)
                .put("uid", Process.myUid()).put("uri", uri.toString());
            try (OutputStream out = openFileOutput("receipt.json", MODE_PRIVATE)) {
                out.write(receipt.toString().getBytes(StandardCharsets.UTF_8));
            }
            Log.i("NBWavVerifier", "NEEDLEBEAT_RECEIVER_PASS " + receipt);
            runOnUiThread(() -> status.setText("WAV VERIFIED\n\n8 seconds / stereo PCM\nRead granted\nWrite blocked\nOther files blocked"));
        } catch (Exception failure) {
            Log.e("NBWavVerifier", "NEEDLEBEAT_RECEIVER_FAIL " + failure, failure);
            runOnUiThread(() -> status.setText("WAV VERIFICATION FAILED\n" + failure));
        }
    }
}
