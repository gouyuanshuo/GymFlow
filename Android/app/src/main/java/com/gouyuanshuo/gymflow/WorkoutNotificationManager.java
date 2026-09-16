package com.gouyuanshuo.gymflow;

import android.Manifest;
import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;

public final class WorkoutNotificationManager {
    public static final String ACTION_CHANGED = "com.gouyuanshuo.gymflow.WORKOUT_CHANGED";
    static final String ACTION_COMPLETE = "com.gouyuanshuo.gymflow.COMPLETE_SET";
    static final String ACTION_ADD_THIRTY = "com.gouyuanshuo.gymflow.ADD_THIRTY";
    static final String ACTION_SKIP_REST = "com.gouyuanshuo.gymflow.SKIP_REST";
    static final String ACTION_TIMER_DONE = "com.gouyuanshuo.gymflow.TIMER_DONE";
    private static final String CHANNEL = "gymflow_workout";
    private static final int NOTIFICATION_ID = 4102;
    private static final int ALARM_REQUEST = 4103;

    private WorkoutNotificationManager() {}

    public static void show(Context context) {
        createChannel(context);
        if (context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return;
        Models.Session session = GymFlowDatabase.get(context).getActiveSession();
        if (session == null || session.records.isEmpty()) {
            cancel(context);
            return;
        }
        int index = Math.max(0, Math.min(session.currentExerciseIndex, session.records.size() - 1));
        Models.ExerciseRecord record = session.records.get(index);
        int remaining = RestTimerManager.get(context).remainingSeconds();
        String detail = "第 " + Math.max(1, session.currentSetNumber) + " 组 · " + record.name;
        if (remaining > 0) detail = "休息 " + WorkoutMath.formatDuration(remaining) + " · " + record.name;
        Intent open = new Intent(context, MainActivity.class).putExtra("resume_workout", true)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent content = PendingIntent.getActivity(context, 4100, open,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        Notification notification = new Notification.Builder(context, CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_gymflow)
                .setContentTitle(session.planName)
                .setContentText(detail)
                .setContentIntent(content)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setCategory(Notification.CATEGORY_WORKOUT)
                .addAction(new Notification.Action.Builder(android.R.drawable.checkbox_on_background,
                        "完成当前组", receiverPending(context, ACTION_COMPLETE, 4110)).build())
                .addAction(new Notification.Action.Builder(android.R.drawable.ic_input_add,
                        "休息 +30 秒", receiverPending(context, ACTION_ADD_THIRTY, 4111)).build())
                .addAction(new Notification.Action.Builder(android.R.drawable.ic_media_next,
                        "跳过休息", receiverPending(context, ACTION_SKIP_REST, 4112)).build())
                .build();
        ((NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE)).notify(NOTIFICATION_ID, notification);
    }

    public static void cancel(Context context) {
        ((NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE)).cancel(NOTIFICATION_ID);
        cancelRestAlarm(context);
    }

    public static void scheduleRestAlarm(Context context) {
        cancelRestAlarm(context);
        int remaining = RestTimerManager.get(context).remainingSeconds();
        if (remaining <= 0) return;
        AlarmManager alarms = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + remaining * 1000L,
                receiverPending(context, ACTION_TIMER_DONE, ALARM_REQUEST));
    }

    public static void cancelRestAlarm(Context context) {
        AlarmManager alarms = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        alarms.cancel(receiverPending(context, ACTION_TIMER_DONE, ALARM_REQUEST));
    }

    private static PendingIntent receiverPending(Context context, String action, int request) {
        Intent intent = new Intent(context, WorkoutActionReceiver.class).setAction(action);
        return PendingIntent.getBroadcast(context, request, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private static void createChannel(Context context) {
        NotificationChannel channel = new NotificationChannel(CHANNEL,
                context.getString(R.string.workout_channel_name), NotificationManager.IMPORTANCE_LOW);
        channel.setDescription("显示当前动作、休息时间和快捷训练操作");
        ((NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE)).createNotificationChannel(channel);
    }
}
