package com.gouyuanshuo.gymflow;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.SeekBar;
import android.widget.TextView;

public final class NowPlayingActivity extends BaseActivity {
    private TextView title;
    private TextView artist;
    private TextView position;
    private TextView duration;
    private Button toggle;
    private Button shuffle;
    private Button repeat;
    private SeekBar seek;
    private boolean dragging;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final Runnable ticker = new Runnable() {
        @Override public void run() { updateState(); handler.postDelayed(this, 500); }
    };
    private final BroadcastReceiver updates = new BroadcastReceiver() {
        @Override public void onReceive(Context context, Intent intent) {
            String error = intent.getStringExtra("error");
            if (error != null) toast(error);
            updateState();
        }
    };

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        buildUi();
        IntentFilter filter = new IntentFilter(PlaybackService.ACTION_STATE_CHANGED);
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(updates, filter, Context.RECEIVER_NOT_EXPORTED);
        else registerReceiver(updates, filter);
        handler.post(ticker);
    }

    private void buildUi() {
        buildPage("正在播放");
        TextView artwork = ui.text("♫", 88);
        artwork.setTextColor(ui.accent);
        artwork.setGravity(Gravity.CENTER);
        artwork.setBackground(ui.roundRect(ui.elevated, 28, 0));
        content.addView(artwork, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ui.dp(260)));
        content.addView(ui.spacer(24));
        title = ui.text("没有正在播放的音乐", 25);
        title.setTypeface(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD);
        title.setGravity(Gravity.CENTER);
        artist = ui.secondary("本地音频", 15);
        artist.setGravity(Gravity.CENTER);
        content.addView(title);
        content.addView(artist);
        content.addView(ui.spacer(24));
        seek = new SeekBar(this);
        seek.setMax(1000);
        seek.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {}
            @Override public void onStartTrackingTouch(SeekBar seekBar) { dragging = true; }
            @Override public void onStopTrackingTouch(SeekBar seekBar) {
                PlaybackService.State state = PlaybackService.state();
                long target = state.durationMs * seekBar.getProgress() / 1000L;
                Intent intent = new Intent(NowPlayingActivity.this, PlaybackService.class)
                        .setAction(PlaybackService.ACTION_SEEK).putExtra(PlaybackService.EXTRA_POSITION, target);
                startService(intent);
                dragging = false;
            }
        });
        content.addView(seek);
        LinearLayout times = ui.row();
        position = ui.secondary("00:00", 13);
        duration = ui.secondary("00:00", 13);
        duration.setGravity(Gravity.END);
        times.addView(position, UiKit.weight(1));
        times.addView(duration, UiKit.weight(1));
        content.addView(times);
        content.addView(ui.spacer(18));
        LinearLayout transport = ui.row();
        Button previous = ui.button("⏮\n上一首", false);
        previous.setOnClickListener(view -> PlaybackService.send(this, PlaybackService.ACTION_PREVIOUS));
        toggle = ui.button("▶\n播放", true);
        toggle.setOnClickListener(view -> PlaybackService.send(this, PlaybackService.ACTION_TOGGLE));
        Button next = ui.button("⏭\n下一首", false);
        next.setOnClickListener(view -> PlaybackService.send(this, PlaybackService.ACTION_NEXT));
        transport.addView(previous, UiKit.weight(1));
        transport.addView(toggle, UiKit.weight(1));
        transport.addView(next, UiKit.weight(1));
        content.addView(transport);
        content.addView(ui.spacer(18));
        LinearLayout modes = ui.row();
        shuffle = ui.button("随机播放：关", false);
        shuffle.setOnClickListener(view -> PlaybackService.send(this, PlaybackService.ACTION_SHUFFLE));
        repeat = ui.button("循环：关", false);
        repeat.setOnClickListener(view -> PlaybackService.send(this, PlaybackService.ACTION_REPEAT));
        modes.addView(shuffle, UiKit.weight(1));
        modes.addView(repeat, UiKit.weight(1));
        content.addView(modes);
        Button queue = ui.button("查看播放队列", false);
        queue.setOnClickListener(view -> showQueue());
        content.addView(ui.spacer(10));
        content.addView(queue);
        updateState();
    }

    private void updateState() {
        if (title == null) return;
        PlaybackService.State state = PlaybackService.state();
        title.setText(state.trackId == null ? "没有正在播放的音乐" : state.title);
        artist.setText(state.artist.isEmpty() ? "本地音频" : state.artist);
        toggle.setText(state.playing ? "⏸\n暂停" : "▶\n播放");
        shuffle.setText("随机播放：" + (state.shuffle ? "开" : "关"));
        String[] repeats = {"关", "全部", "单曲"};
        repeat.setText("循环：" + repeats[Math.max(0, Math.min(2, state.repeatMode))]);
        long current = state.positionMs;
        if (state.playing) current = Math.min(state.durationMs, current + 450);
        position.setText(WorkoutMath.formatDuration(current / 1000));
        duration.setText(WorkoutMath.formatDuration(state.durationMs / 1000));
        if (!dragging) seek.setProgress(state.durationMs <= 0 ? 0 : (int) (current * 1000 / state.durationMs));
    }

    private void showQueue() {
        java.util.List<Models.Track> tracks = GymFlowDatabase.get(this).getTracks();
        String[] names = new String[tracks.size()];
        PlaybackService.State state = PlaybackService.state();
        for (int index = 0; index < tracks.size(); index++) {
            Models.Track track = tracks.get(index);
            names[index] = (track.id.equals(state.trackId) ? "▶  " : "") + track.title;
        }
        new android.app.AlertDialog.Builder(this).setTitle("播放队列")
                .setItems(names, (dialog, which) -> {
                    java.util.ArrayList<String> ids = new java.util.ArrayList<>();
                    for (Models.Track track : tracks) ids.add(track.id);
                    PlaybackService.play(this, tracks.get(which).id, ids);
                }).setNegativeButton("关闭", null).show();
    }

    @Override protected void onDestroy() {
        handler.removeCallbacks(ticker);
        try { unregisterReceiver(updates); } catch (Exception ignored) {}
        super.onDestroy();
    }
}
