package com.needlebeat.drop;

import android.app.Activity;
import android.content.ClipData;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;
import androidx.core.content.FileProvider;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;

/** Android 4.7 JavaClassWrapper entry point; no broad storage permission required. */
public final class NeedlebeatShare {
    private static final String TAG = "NeedlebeatShare";
    private static final long MAX_AUDIO_BYTES = 20L * 1024L * 1024L;

    private NeedlebeatShare() {}

    public static boolean shareWav(Activity activity, String sourcePath) {
        if (activity == null || sourcePath == null) return false;
        try {
            File file = new File(sourcePath).getCanonicalFile();
            File privateFiles = activity.getFilesDir().getCanonicalFile();
            // Only accept our own exported music, never a caller-selected private file.
            if (!file.getPath().startsWith(privateFiles.getPath() + File.separator)
                    || !file.getName().matches("needlebeat_[0-9]+_[0-9]+\\.wav")
                    || !file.isFile() || file.length() < 44
                    || file.length() > MAX_AUDIO_BYTES) {
                return false;
            }
            File shareDirectory = new File(activity.getCacheDir(), "shared_audio");
            if (!shareDirectory.isDirectory() && !shareDirectory.mkdirs()) return false;
            File sharedFile = new File(shareDirectory, file.getName());
            try (FileInputStream input = new FileInputStream(file);
                 FileOutputStream output = new FileOutputStream(sharedFile)) {
                byte[] buffer = new byte[16384];
                int n;
                while ((n = input.read(buffer)) != -1) output.write(buffer, 0, n);
            }
            Uri uri = FileProvider.getUriForFile(
                    activity, activity.getPackageName() + ".share", sharedFile);
            Intent send = new Intent(Intent.ACTION_SEND);
            send.setType("audio/wav");
            send.putExtra(Intent.EXTRA_STREAM, uri);
            send.setClipData(ClipData.newRawUri("NEEDLEBEAT audio", uri));
            send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            Intent chooser = Intent.createChooser(send, "Share NEEDLEBEAT WAV");
            chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            activity.runOnUiThread(() -> {
                try {
                    activity.startActivity(chooser);
                } catch (RuntimeException exception) {
                    Log.e(TAG, "Unable to open sharing chooser", exception);
                }
            });
            return true;
        } catch (IOException | IllegalArgumentException | SecurityException exception) {
            Log.e(TAG, "WAV sharing failed", exception);
            return false;
        }
    }
}
