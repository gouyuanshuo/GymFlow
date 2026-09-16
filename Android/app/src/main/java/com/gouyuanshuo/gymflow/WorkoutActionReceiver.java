package com.gouyuanshuo.gymflow;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public final class WorkoutActionReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        String action = intent == null ? null : intent.getAction();
        GymFlowDatabase database = GymFlowDatabase.get(context);
        Models.Session session = database.getActiveSession();
        RestTimerManager timer = RestTimerManager.get(context);
        if (WorkoutNotificationManager.ACTION_TIMER_DONE.equals(action)) {
            timer.remainingSeconds();
            if (timer.consumeCompletion()) TimerFeedback.play(context);
        } else if (WorkoutNotificationManager.ACTION_ADD_THIRTY.equals(action)) {
            timer.addThirtySeconds();
            WorkoutNotificationManager.scheduleRestAlarm(context);
        } else if (WorkoutNotificationManager.ACTION_SKIP_REST.equals(action)) {
            timer.cancel();
            WorkoutNotificationManager.cancelRestAlarm(context);
        } else if (WorkoutNotificationManager.ACTION_COMPLETE.equals(action) && session != null) {
            completeCurrent(database, session, timer);
            WorkoutNotificationManager.scheduleRestAlarm(context);
        }
        WorkoutNotificationManager.show(context);
        context.sendBroadcast(new Intent(WorkoutNotificationManager.ACTION_CHANGED).setPackage(context.getPackageName()));
    }

    private static void completeCurrent(GymFlowDatabase database, Models.Session session, RestTimerManager timer) {
        if (session.records.isEmpty()) return;
        int exerciseIndex = Math.max(0, Math.min(session.currentExerciseIndex, session.records.size() - 1));
        Models.ExerciseRecord record = session.records.get(exerciseIndex);
        Models.WorkoutSet target = null;
        for (Models.WorkoutSet set : record.sets) {
            if (set.setNumber == session.currentSetNumber && !set.completed) { target = set; break; }
        }
        if (target == null) for (Models.WorkoutSet set : record.sets) if (!set.completed) { target = set; break; }
        if (target == null) return;
        target.completed = true;
        target.completedAt = System.currentTimeMillis();
        database.updateSet(target);
        if (record.restSeconds > 0) timer.start(record.restSeconds);

        int nextExercise = exerciseIndex;
        int nextSet = target.setNumber + 1;
        boolean found = false;
        for (int r = exerciseIndex; r < session.records.size() && !found; r++) {
            Models.ExerciseRecord candidate = session.records.get(r);
            for (Models.WorkoutSet set : candidate.sets) {
                if (!set.completed) {
                    nextExercise = r;
                    nextSet = set.setNumber;
                    found = true;
                    break;
                }
            }
        }
        database.updateSessionCursor(session.id, nextExercise, nextSet);
    }
}
