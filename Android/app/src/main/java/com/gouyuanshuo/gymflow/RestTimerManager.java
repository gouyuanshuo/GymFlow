package com.gouyuanshuo.gymflow;

import android.content.Context;
import android.content.SharedPreferences;

public final class RestTimerManager {
    private static final String PREFS = "gymflow_rest_timer";
    private static RestTimerManager instance;
    private final SharedPreferences preferences;

    public static synchronized RestTimerManager get(Context context) {
        if (instance == null) instance = new RestTimerManager(context.getApplicationContext());
        return instance;
    }

    private RestTimerManager(Context context) {
        preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    public synchronized void start(int durationSeconds) {
        if (durationSeconds <= 0) {
            cancel();
            return;
        }
        preferences.edit()
                .putLong("end_at", System.currentTimeMillis() + durationSeconds * 1000L)
                .putInt("original", durationSeconds)
                .putInt("paused_remaining", 0)
                .putBoolean("paused", false)
                .putBoolean("completion_pending", false)
                .apply();
    }

    public synchronized void pause() {
        int remaining = remainingSeconds();
        if (remaining <= 0) return;
        preferences.edit()
                .remove("end_at")
                .putInt("paused_remaining", remaining)
                .putBoolean("paused", true)
                .apply();
    }

    public synchronized void resume() {
        int remaining = preferences.getInt("paused_remaining", 0);
        if (!preferences.getBoolean("paused", false) || remaining <= 0) return;
        preferences.edit()
                .putLong("end_at", System.currentTimeMillis() + remaining * 1000L)
                .putBoolean("paused", false)
                .putInt("paused_remaining", 0)
                .apply();
    }

    public synchronized void addThirtySeconds() {
        if (isPaused()) {
            preferences.edit().putInt("paused_remaining", remainingSeconds() + 30).apply();
        } else if (isRunning()) {
            preferences.edit().putLong("end_at", preferences.getLong("end_at", 0) + 30_000L).apply();
        } else {
            int original = Math.max(30, preferences.getInt("original", 0) + 30);
            start(original);
        }
    }

    public synchronized void restart() {
        int original = preferences.getInt("original", 0);
        if (original > 0) start(original);
    }

    public synchronized void cancel() {
        preferences.edit()
                .remove("end_at")
                .remove("paused_remaining")
                .remove("paused")
                .remove("completion_pending")
                .apply();
    }

    public synchronized int remainingSeconds() {
        if (preferences.getBoolean("paused", false)) {
            return Math.max(0, preferences.getInt("paused_remaining", 0));
        }
        long endAt = preferences.getLong("end_at", 0);
        if (endAt <= 0) return 0;
        int remaining = Math.max(0, (int) Math.ceil((endAt - System.currentTimeMillis()) / 1000.0));
        if (remaining == 0) {
            preferences.edit()
                    .remove("end_at")
                    .remove("paused_remaining")
                    .putBoolean("paused", false)
                    .putBoolean("completion_pending", true)
                    .apply();
        }
        return remaining;
    }

    public synchronized boolean consumeCompletion() {
        if (!preferences.getBoolean("completion_pending", false)) return false;
        preferences.edit().putBoolean("completion_pending", false).apply();
        return true;
    }

    public synchronized boolean isPaused() {
        return preferences.getBoolean("paused", false) && preferences.getInt("paused_remaining", 0) > 0;
    }

    public synchronized boolean isRunning() {
        return preferences.getLong("end_at", 0) > System.currentTimeMillis();
    }

    public synchronized boolean isActive() { return isPaused() || isRunning(); }

    public synchronized int originalDuration() { return preferences.getInt("original", 0); }
}
