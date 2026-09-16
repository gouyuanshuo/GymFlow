package com.gouyuanshuo.gymflow;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;

import java.io.File;
import java.io.FileNotFoundException;

public final class ShareImageProvider extends ContentProvider {
    @Override public boolean onCreate() { return true; }

    @Override public String getType(Uri uri) { return "image/png"; }

    @Override public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
        if (getContext() == null || !"r".equals(mode)) throw new FileNotFoundException();
        String name = uri.getLastPathSegment();
        if (name == null || !name.matches("[a-zA-Z0-9._-]+")) throw new FileNotFoundException();
        File directory = new File(getContext().getCacheDir(), "share");
        File file = new File(directory, name);
        if (!file.exists() || !file.getParentFile().equals(directory)) throw new FileNotFoundException();
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY);
    }

    @Override public Cursor query(Uri uri, String[] projection, String selection,
                                  String[] selectionArgs, String sortOrder) {
        String name = uri.getLastPathSegment() == null ? "gymflow.png" : uri.getLastPathSegment();
        File file = getContext() == null ? null : new File(new File(getContext().getCacheDir(), "share"), name);
        MatrixCursor cursor = new MatrixCursor(new String[] {OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE});
        cursor.addRow(new Object[] {name, file == null ? 0 : file.length()});
        return cursor;
    }

    @Override public Uri insert(Uri uri, ContentValues values) { throw new UnsupportedOperationException(); }
    @Override public int delete(Uri uri, String selection, String[] selectionArgs) { return 0; }
    @Override public int update(Uri uri, ContentValues values, String selection, String[] selectionArgs) { return 0; }
}
