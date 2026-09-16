package com.gouyuanshuo.gymflow;

import android.content.Context;
import android.database.Cursor;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.provider.OpenableColumns;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;

public final class AudioImportManager {
    private static final Set<String> SUPPORTED = new HashSet<>(Arrays.asList(
            "mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "flac", "ogg", "opus"));

    private AudioImportManager() {}

    public static Models.Track importUri(Context context, Uri uri) throws Exception {
        String originalName = displayName(context, uri);
        String extension = extension(originalName);
        if (!SUPPORTED.contains(extension)) {
            throw new IllegalArgumentException("暂不支持 ." + extension + " 音频，请选择 MP3、M4A、AAC、WAV、AIFF、FLAC、OGG 或 OPUS");
        }
        File directory = musicDirectory(context);
        String base = stripExtension(originalName).replaceAll("[^a-zA-Z0-9._\\-一-龥]", "_");
        if (base.isEmpty()) base = "audio";
        File destination = uniqueFile(directory, base, extension);
        try (InputStream input = context.getContentResolver().openInputStream(uri);
             FileOutputStream output = new FileOutputStream(destination)) {
            if (input == null) throw new IllegalArgumentException("无法读取所选音频文件");
            byte[] buffer = new byte[64 * 1024];
            int read;
            while ((read = input.read(buffer)) != -1) output.write(buffer, 0, read);
        } catch (Exception error) {
            destination.delete();
            throw error;
        }

        Models.Track track = new Models.Track();
        track.title = stripExtension(originalName);
        track.originalFileName = originalName;
        track.storedFileName = destination.getName();
        track.extension = extension;
        track.createdAt = System.currentTimeMillis();
        track.sortOrder = -1;
        MediaMetadataRetriever retriever = new MediaMetadataRetriever();
        try {
            retriever.setDataSource(destination.getAbsolutePath());
            String title = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE);
            String artist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST);
            String duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
            if (title != null && !title.trim().isEmpty()) track.title = title.trim();
            if (artist != null) track.artist = artist.trim();
            if (duration != null) track.durationMs = Long.parseLong(duration);
        } catch (Exception ignored) {
            // The system player provides the final compatibility check; metadata is optional.
        } finally {
            retriever.release();
        }
        try {
            return GymFlowDatabase.get(context).saveTrack(track);
        } catch (Exception error) {
            destination.delete();
            throw error;
        }
    }

    public static File trackFile(Context context, Models.Track track) {
        return new File(musicDirectory(context), track.storedFileName);
    }

    public static boolean deleteTrackFile(Context context, Models.Track track) {
        File file = trackFile(context, track);
        return !file.exists() || file.delete();
    }

    public static void deleteAllFiles(Context context) {
        File[] files = musicDirectory(context).listFiles();
        if (files == null) return;
        for (File file : files) if (file.isFile()) file.delete();
    }

    private static File musicDirectory(Context context) {
        File directory = new File(context.getFilesDir(), "music");
        if (!directory.exists() && !directory.mkdirs()) {
            throw new IllegalStateException("无法创建本地音乐文件夹");
        }
        return directory;
    }

    private static File uniqueFile(File directory, String base, String extension) {
        File candidate = new File(directory, base + "." + extension);
        int suffix = 2;
        while (candidate.exists()) candidate = new File(directory, base + "_" + suffix++ + "." + extension);
        return candidate;
    }

    private static String displayName(Context context, Uri uri) {
        try (Cursor cursor = context.getContentResolver().query(uri,
                new String[] {OpenableColumns.DISPLAY_NAME}, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                String value = cursor.getString(0);
                if (value != null && !value.trim().isEmpty()) return value;
            }
        }
        String fallback = uri.getLastPathSegment();
        return fallback == null ? "audio.mp3" : fallback;
    }

    private static String extension(String name) {
        int dot = name.lastIndexOf('.');
        return dot < 0 ? "" : name.substring(dot + 1).toLowerCase(Locale.ROOT);
    }

    private static String stripExtension(String name) {
        int dot = name.lastIndexOf('.');
        return dot <= 0 ? name : name.substring(0, dot);
    }
}
