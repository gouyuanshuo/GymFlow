package com.gouyuanshuo.gymflow;

import android.content.Context;
import android.content.SharedPreferences;
import android.media.AudioManager;
import android.media.ToneGenerator;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.Handler;
import android.os.Looper;

public final class TimerFeedback {
    private TimerFeedback() {}

    public static void play(Context context) {
        if (PlaybackService.state().playing) {
            try { PlaybackService.send(context, PlaybackService.ACTION_DUCK); } catch (Exception ignored) {}
        }
        SharedPreferences preferences = context.getSharedPreferences("gymflow_settings", Context.MODE_PRIVATE);
        if (preferences.getBoolean("timer_sound", true)) {
            ToneGenerator tone = new ToneGenerator(AudioManager.STREAM_NOTIFICATION, 90);
            tone.startTone(ToneGenerator.TONE_PROP_BEEP2, 700);
            new Handler(Looper.getMainLooper()).postDelayed(tone::release, 900);
        }
        if (preferences.getBoolean("timer_haptic", true)) {
            Vibrator vibrator = (Vibrator) context.getSystemService(Context.VIBRATOR_SERVICE);
            if (vibrator != null && vibrator.hasVibrator()) {
                vibrator.vibrate(VibrationEffect.createWaveform(new long[] {0, 180, 100, 180}, -1));
            }
        }
    }
}
