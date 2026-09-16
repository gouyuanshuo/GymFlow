package com.gouyuanshuo.gymflow;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.media.MediaMetadata;
import android.media.MediaPlayer;
import android.media.session.MediaSession;
import android.media.session.PlaybackState;
import android.os.IBinder;
import android.os.Handler;
import android.os.Looper;

import java.io.File;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;

public final class PlaybackService extends Service implements MediaPlayer.OnCompletionListener,
        MediaPlayer.OnErrorListener, AudioManager.OnAudioFocusChangeListener {
    public static final String ACTION_STATE_CHANGED = "com.gouyuanshuo.gymflow.PLAYBACK_STATE";
    public static final String ACTION_PLAY_TRACK = "com.gouyuanshuo.gymflow.PLAY_TRACK";
    public static final String ACTION_TOGGLE = "com.gouyuanshuo.gymflow.TOGGLE";
    public static final String ACTION_PREVIOUS = "com.gouyuanshuo.gymflow.PREVIOUS";
    public static final String ACTION_NEXT = "com.gouyuanshuo.gymflow.NEXT";
    public static final String ACTION_SEEK = "com.gouyuanshuo.gymflow.SEEK";
    public static final String ACTION_SHUFFLE = "com.gouyuanshuo.gymflow.SHUFFLE";
    public static final String ACTION_REPEAT = "com.gouyuanshuo.gymflow.REPEAT";
    public static final String ACTION_STOP = "com.gouyuanshuo.gymflow.STOP";
    public static final String ACTION_DUCK = "com.gouyuanshuo.gymflow.DUCK";
    public static final String EXTRA_TRACK_ID = "track_id";
    public static final String EXTRA_QUEUE = "queue";
    public static final String EXTRA_POSITION = "position";
    private static final String CHANNEL_ID = "gymflow_music";
    private static final int NOTIFICATION_ID = 4201;

    public static final class State {
        public String trackId;
        public String title = "";
        public String artist = "";
        public boolean playing;
        public long positionMs;
        public long durationMs;
        public boolean shuffle;
        public int repeatMode;
    }

    private static final Object STATE_LOCK = new Object();
    private static final State STATE = new State();
    private final ArrayList<String> queue = new ArrayList<>();
    private MediaPlayer player;
    private MediaSession mediaSession;
    private AudioManager audioManager;
    private AudioFocusRequest focusRequest;
    private GymFlowDatabase database;
    private final Random random = new Random();
    private int queueIndex = -1;
    private final Handler handler = new Handler(Looper.getMainLooper());

    public static State state() {
        synchronized (STATE_LOCK) {
            State value = new State();
            value.trackId = STATE.trackId;
            value.title = STATE.title;
            value.artist = STATE.artist;
            value.playing = STATE.playing;
            value.positionMs = STATE.positionMs;
            value.durationMs = STATE.durationMs;
            value.shuffle = STATE.shuffle;
            value.repeatMode = STATE.repeatMode;
            return value;
        }
    }

    public static void send(Context context, String action) {
        Intent intent = new Intent(context, PlaybackService.class).setAction(action);
        if (ACTION_PLAY_TRACK.equals(action) || ACTION_TOGGLE.equals(action)) context.startForegroundService(intent);
        else context.startService(intent);
    }

    public static void play(Context context, String trackId, List<String> queue) {
        Intent intent = new Intent(context, PlaybackService.class).setAction(ACTION_PLAY_TRACK);
        intent.putExtra(EXTRA_TRACK_ID, trackId);
        intent.putStringArrayListExtra(EXTRA_QUEUE, new ArrayList<>(queue));
        context.startForegroundService(intent);
    }

    @Override public void onCreate() {
        super.onCreate();
        database = GymFlowDatabase.get(this);
        audioManager = (AudioManager) getSystemService(AUDIO_SERVICE);
        createChannel();
        mediaSession = new MediaSession(this, "GymFlowMusic");
        mediaSession.setCallback(new MediaSession.Callback() {
            @Override public void onPlay() { handleToggle(true); }
            @Override public void onPause() { pause(); }
            @Override public void onSkipToNext() { next(false); }
            @Override public void onSkipToPrevious() { previous(); }
            @Override public void onSeekTo(long position) { seek(position); }
            @Override public void onStop() { stopPlayback(); }
        });
        mediaSession.setActive(true);
    }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        String action = intent == null ? ACTION_TOGGLE : intent.getAction();
        if (ACTION_PLAY_TRACK.equals(action) || ACTION_TOGGLE.equals(action)) {
            startForeground(NOTIFICATION_ID, notification());
        }
        try {
            if (ACTION_PLAY_TRACK.equals(action)) {
                ArrayList<String> incoming = intent.getStringArrayListExtra(EXTRA_QUEUE);
                if (incoming != null) {
                    queue.clear();
                    queue.addAll(incoming);
                }
                playTrack(intent.getStringExtra(EXTRA_TRACK_ID));
            } else if (ACTION_TOGGLE.equals(action)) {
                handleToggle(false);
            } else if (ACTION_PREVIOUS.equals(action)) {
                previous();
            } else if (ACTION_NEXT.equals(action)) {
                next(false);
            } else if (ACTION_SEEK.equals(action)) {
                seek(intent.getLongExtra(EXTRA_POSITION, 0));
            } else if (ACTION_SHUFFLE.equals(action)) {
                synchronized (STATE_LOCK) { STATE.shuffle = !STATE.shuffle; }
                publish();
            } else if (ACTION_REPEAT.equals(action)) {
                synchronized (STATE_LOCK) { STATE.repeatMode = (STATE.repeatMode + 1) % 3; }
                publish();
            } else if (ACTION_STOP.equals(action)) {
                stopPlayback();
            } else if (ACTION_DUCK.equals(action)) {
                if (player != null && player.isPlaying()) {
                    player.setVolume(0.22f, 0.22f);
                    handler.removeCallbacksAndMessages("duck");
                    handler.postAtTime(() -> {
                        if (player != null) player.setVolume(1f, 1f);
                    }, "duck", android.os.SystemClock.uptimeMillis() + 1200);
                }
            }
        } catch (Exception error) {
            broadcastError("音频播放失败：" + safeMessage(error));
            stopPlayback();
        }
        return START_NOT_STICKY;
    }

    private void handleToggle(boolean systemRequestedPlay) {
        if (player != null && player.isPlaying()) {
            if (!systemRequestedPlay) pause();
            return;
        }
        if (player != null) {
            requestAudioFocus();
            player.start();
            synchronized (STATE_LOCK) { STATE.playing = true; }
            publish();
            return;
        }
        List<Models.Track> tracks = database.getTracks();
        if (tracks.isEmpty()) {
            broadcastError("音乐库中还没有音频");
            stopForeground(STOP_FOREGROUND_REMOVE);
            stopSelf();
            return;
        }
        queue.clear();
        for (Models.Track track : tracks) queue.add(track.id);
        playTrack(queue.get(0));
    }

    private void playTrack(String trackId) {
        Models.Track track = database.getTrack(trackId);
        if (track == null) throw new IllegalArgumentException("找不到这首音频");
        if (queue.isEmpty()) {
            for (Models.Track value : database.getTracks()) queue.add(value.id);
        }
        queueIndex = queue.indexOf(track.id);
        if (queueIndex < 0) {
            queue.add(track.id);
            queueIndex = queue.size() - 1;
        }
        File file = AudioImportManager.trackFile(this, track);
        if (!file.isFile()) throw new IllegalArgumentException("本地音频文件已丢失");
        releasePlayer();
        requestAudioFocus();
        player = new MediaPlayer();
        player.setAudioAttributes(new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build());
        player.setOnCompletionListener(this);
        player.setOnErrorListener(this);
        try {
            player.setDataSource(file.getAbsolutePath());
            player.prepare();
            player.start();
        } catch (Exception error) {
            releasePlayer();
            throw new IllegalArgumentException("系统无法播放该音频格式", error);
        }
        synchronized (STATE_LOCK) {
            STATE.trackId = track.id;
            STATE.title = track.title;
            STATE.artist = track.artist;
            STATE.durationMs = player.getDuration();
            STATE.positionMs = 0;
            STATE.playing = true;
        }
        updateMediaSession(track);
        startForeground(NOTIFICATION_ID, notification());
        publish();
    }

    private void pause() {
        if (player != null && player.isPlaying()) player.pause();
        synchronized (STATE_LOCK) {
            STATE.playing = false;
            if (player != null) STATE.positionMs = player.getCurrentPosition();
        }
        abandonAudioFocus();
        publish();
    }

    private void previous() {
        if (player != null && player.getCurrentPosition() > 4000) {
            seek(0);
            return;
        }
        if (queue.isEmpty()) return;
        int index = queueIndex <= 0 ? queue.size() - 1 : queueIndex - 1;
        playTrack(queue.get(index));
    }

    private void next(boolean automatic) {
        if (queue.isEmpty()) return;
        State snapshot = state();
        if (automatic && snapshot.repeatMode == 2) {
            seek(0);
            if (player != null) player.start();
            synchronized (STATE_LOCK) { STATE.playing = true; }
            publish();
            return;
        }
        int index;
        if (snapshot.shuffle && queue.size() > 1) {
            do { index = random.nextInt(queue.size()); } while (index == queueIndex);
        } else {
            index = queueIndex + 1;
            if (index >= queue.size()) {
                if (snapshot.repeatMode == 1 || !automatic) index = 0;
                else {
                    synchronized (STATE_LOCK) { STATE.playing = false; STATE.positionMs = STATE.durationMs; }
                    publish();
                    return;
                }
            }
        }
        playTrack(queue.get(index));
    }

    private void seek(long position) {
        if (player == null) return;
        int target = (int) Math.max(0, Math.min(position, player.getDuration()));
        player.seekTo(target);
        synchronized (STATE_LOCK) { STATE.positionMs = target; }
        publish();
    }

    private void stopPlayback() {
        releasePlayer();
        abandonAudioFocus();
        synchronized (STATE_LOCK) {
            STATE.trackId = null;
            STATE.title = "";
            STATE.artist = "";
            STATE.playing = false;
            STATE.positionMs = 0;
            STATE.durationMs = 0;
        }
        mediaSession.setPlaybackState(new PlaybackState.Builder()
                .setState(PlaybackState.STATE_STOPPED, 0, 0).build());
        stopForeground(STOP_FOREGROUND_REMOVE);
        publish();
        stopSelf();
    }

    private void publish() {
        if (player != null) {
            synchronized (STATE_LOCK) {
                STATE.playing = player.isPlaying();
                STATE.positionMs = player.getCurrentPosition();
                STATE.durationMs = player.getDuration();
            }
        }
        State snapshot = state();
        long actions = PlaybackState.ACTION_PLAY | PlaybackState.ACTION_PAUSE |
                PlaybackState.ACTION_PLAY_PAUSE | PlaybackState.ACTION_SKIP_TO_NEXT |
                PlaybackState.ACTION_SKIP_TO_PREVIOUS | PlaybackState.ACTION_SEEK_TO | PlaybackState.ACTION_STOP;
        mediaSession.setPlaybackState(new PlaybackState.Builder().setActions(actions)
                .setState(snapshot.playing ? PlaybackState.STATE_PLAYING : PlaybackState.STATE_PAUSED,
                        snapshot.positionMs, snapshot.playing ? 1 : 0).build());
        if (snapshot.trackId != null) {
            ((NotificationManager) getSystemService(NOTIFICATION_SERVICE)).notify(NOTIFICATION_ID, notification());
        }
        sendBroadcast(new Intent(ACTION_STATE_CHANGED).setPackage(getPackageName()));
    }

    private void updateMediaSession(Models.Track track) {
        mediaSession.setMetadata(new MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, track.title)
                .putString(MediaMetadata.METADATA_KEY_ARTIST, track.artist.isEmpty() ? "本地音频" : track.artist)
                .putLong(MediaMetadata.METADATA_KEY_DURATION, state().durationMs)
                .build());
    }

    private Notification notification() {
        State snapshot = state();
        Intent open = new Intent(this, MainActivity.class).putExtra("open_music", true)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent content = PendingIntent.getActivity(this, 1, open,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        Notification.Action previous = new Notification.Action.Builder(
                android.R.drawable.ic_media_previous, "上一首", servicePending(ACTION_PREVIOUS, 2)).build();
        Notification.Action toggle = new Notification.Action.Builder(
                snapshot.playing ? android.R.drawable.ic_media_pause : android.R.drawable.ic_media_play,
                snapshot.playing ? "暂停" : "播放", servicePending(ACTION_TOGGLE, 3)).build();
        Notification.Action next = new Notification.Action.Builder(
                android.R.drawable.ic_media_next, "下一首", servicePending(ACTION_NEXT, 4)).build();
        return new Notification.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_gymflow)
                .setContentTitle(snapshot.title.isEmpty() ? "GymFlow 音乐" : snapshot.title)
                .setContentText(snapshot.artist.isEmpty() ? "本地音频" : snapshot.artist)
                .setContentIntent(content)
                .setDeleteIntent(servicePending(ACTION_STOP, 5))
                .setOngoing(snapshot.playing)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .addAction(previous).addAction(toggle).addAction(next)
                .setStyle(new Notification.MediaStyle().setMediaSession(mediaSession.getSessionToken())
                        .setShowActionsInCompactView(0, 1, 2))
                .build();
    }

    private PendingIntent servicePending(String action, int request) {
        Intent intent = new Intent(this, PlaybackService.class).setAction(action);
        return PendingIntent.getService(this, request, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private void createChannel() {
        NotificationChannel channel = new NotificationChannel(CHANNEL_ID,
                getString(R.string.music_channel_name), NotificationManager.IMPORTANCE_LOW);
        channel.setDescription("显示正在播放的本地音乐和播放控制");
        ((NotificationManager) getSystemService(NOTIFICATION_SERVICE)).createNotificationChannel(channel);
    }

    private void requestAudioFocus() {
        if (focusRequest == null) {
            focusRequest = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                    .setOnAudioFocusChangeListener(this).build();
        }
        audioManager.requestAudioFocus(focusRequest);
    }

    private void abandonAudioFocus() {
        if (focusRequest != null) audioManager.abandonAudioFocusRequest(focusRequest);
    }

    private void releasePlayer() {
        if (player == null) return;
        try { player.stop(); } catch (Exception ignored) {}
        player.release();
        player = null;
    }

    private void broadcastError(String message) {
        Intent intent = new Intent(ACTION_STATE_CHANGED).setPackage(getPackageName());
        intent.putExtra("error", message);
        sendBroadcast(intent);
    }

    private static String safeMessage(Exception error) {
        return error.getMessage() == null ? "未知错误" : error.getMessage();
    }

    @Override public void onCompletion(MediaPlayer mediaPlayer) { next(true); }

    @Override public boolean onError(MediaPlayer mediaPlayer, int what, int extra) {
        broadcastError("播放过程中发生错误（" + what + "/" + extra + "）");
        next(true);
        return true;
    }

    @Override public void onAudioFocusChange(int focusChange) {
        if (focusChange == AudioManager.AUDIOFOCUS_LOSS || focusChange == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) pause();
        else if (focusChange == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK && player != null) player.setVolume(0.22f, 0.22f);
        else if (focusChange == AudioManager.AUDIOFOCUS_GAIN && player != null) player.setVolume(1f, 1f);
    }

    @Override public IBinder onBind(Intent intent) { return null; }

    @Override public void onDestroy() {
        handler.removeCallbacksAndMessages(null);
        releasePlayer();
        abandonAudioFocus();
        if (mediaSession != null) mediaSession.release();
        super.onDestroy();
    }
}
