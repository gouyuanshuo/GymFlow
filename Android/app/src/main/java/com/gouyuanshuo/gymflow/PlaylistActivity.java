package com.gouyuanshuo.gymflow;

import android.app.AlertDialog;
import android.os.Bundle;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.List;

public final class PlaylistActivity extends BaseActivity {
    private GymFlowDatabase database;
    private Models.Playlist playlist;

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        database = GymFlowDatabase.get(this);
        playlist = database.getPlaylist(getIntent().getStringExtra("playlist_id"));
        if (playlist == null) { finish(); return; }
        renderPlaylist();
    }

    private void renderPlaylist() {
        playlist = database.getPlaylist(playlist.id);
        buildPage(playlist.name);
        LinearLayout header = ui.card();
        header.addView(ui.text(playlist.name, 22));
        header.addView(ui.secondary(playlist.trackIds.size() + " 首音频", 14));
        LinearLayout actions = ui.row();
        Button play = ui.button("播放列表", true);
        play.setEnabled(!playlist.trackIds.isEmpty());
        play.setOnClickListener(view -> PlaybackService.play(this, playlist.trackIds.get(0), playlist.trackIds));
        Button rename = ui.button("重命名", false);
        rename.setOnClickListener(view -> renamePlaylist());
        Button add = ui.button("添加音频", false);
        add.setOnClickListener(view -> addTracks());
        actions.addView(play, UiKit.weight(1));
        actions.addView(rename, UiKit.weight(1));
        actions.addView(add, UiKit.weight(1));
        header.addView(ui.spacer(8));
        header.addView(actions);
        content.addView(header);
        content.addView(ui.section("歌曲"));
        if (playlist.trackIds.isEmpty()) content.addView(ui.secondary("这个播放列表还是空的。", 15));
        for (int index = 0; index < playlist.trackIds.size(); index++) {
            Models.Track track = database.getTrack(playlist.trackIds.get(index));
            if (track == null) continue;
            addTrackCard(track, index);
        }
        Button delete = ui.button("删除播放列表", false);
        delete.setTextColor(ui.destructive);
        delete.setOnClickListener(view -> confirm("删除播放列表？", "本地音频不会被删除。", "删除", () -> {
            database.deletePlaylist(playlist.id);
            finish();
        }));
        content.addView(ui.spacer(14));
        content.addView(delete);
    }

    private void addTrackCard(Models.Track track, int index) {
        LinearLayout card = ui.card();
        TextView title = ui.text((index + 1) + ".  " + track.title, 17);
        title.setTypeface(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD);
        title.setOnClickListener(view -> PlaybackService.play(this, track.id, playlist.trackIds));
        card.addView(title);
        card.addView(ui.secondary(track.artist.isEmpty() ? track.originalFileName : track.artist, 13));
        LinearLayout controls = ui.row();
        Button up = ui.button("↑", false);
        up.setEnabled(index > 0);
        up.setOnClickListener(view -> move(index, index - 1));
        Button down = ui.button("↓", false);
        down.setEnabled(index + 1 < playlist.trackIds.size());
        down.setOnClickListener(view -> move(index, index + 1));
        Button remove = ui.button("从列表移除", false);
        remove.setTextColor(ui.destructive);
        remove.setOnClickListener(view -> { playlist.trackIds.remove(track.id); database.savePlaylist(playlist); renderPlaylist(); });
        controls.addView(up, UiKit.weight(1));
        controls.addView(down, UiKit.weight(1));
        controls.addView(remove, UiKit.weight(3));
        card.addView(ui.spacer(6));
        card.addView(controls);
        content.addView(card);
    }

    private void move(int source, int destination) {
        String value = playlist.trackIds.remove(source);
        playlist.trackIds.add(destination, value);
        database.savePlaylist(playlist);
        renderPlaylist();
    }

    private void renamePlaylist() {
        EditText name = ui.edit("播放列表名称", playlist.name, false);
        new AlertDialog.Builder(this).setTitle("重命名播放列表").setView(name)
                .setNegativeButton("取消", null).setPositiveButton("保存", (dialog, which) -> {
                    try {
                        playlist.name = name.getText().toString();
                        database.savePlaylist(playlist);
                        renderPlaylist();
                    } catch (Exception error) { showError("无法重命名", error); }
                }).show();
    }

    private void addTracks() {
        List<Models.Track> tracks = database.getTracks();
        if (tracks.isEmpty()) { toast("音乐库中还没有音频"); return; }
        String[] names = new String[tracks.size()];
        boolean[] checked = new boolean[tracks.size()];
        for (int index = 0; index < tracks.size(); index++) {
            names[index] = tracks.get(index).title;
            checked[index] = playlist.trackIds.contains(tracks.get(index).id);
        }
        new AlertDialog.Builder(this).setTitle("选择音频")
                .setMultiChoiceItems(names, checked, (dialog, which, selected) -> checked[which] = selected)
                .setNegativeButton("取消", null)
                .setPositiveButton("完成", (dialog, which) -> {
                    ArrayList<String> ordered = new ArrayList<>();
                    for (String existing : playlist.trackIds) {
                        int index = indexOf(tracks, existing);
                        if (index >= 0 && checked[index]) ordered.add(existing);
                    }
                    for (int index = 0; index < tracks.size(); index++) {
                        if (checked[index] && !ordered.contains(tracks.get(index).id)) ordered.add(tracks.get(index).id);
                    }
                    playlist.trackIds.clear();
                    playlist.trackIds.addAll(ordered);
                    database.savePlaylist(playlist);
                    renderPlaylist();
                }).show();
    }

    private int indexOf(List<Models.Track> tracks, String id) {
        for (int index = 0; index < tracks.size(); index++) if (tracks.get(index).id.equals(id)) return index;
        return -1;
    }
}
