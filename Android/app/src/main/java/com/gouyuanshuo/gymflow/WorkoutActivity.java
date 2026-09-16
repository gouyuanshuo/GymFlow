package com.gouyuanshuo.gymflow;

import android.Manifest;
import android.app.AlertDialog;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.Typeface;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.content.pm.PackageManager;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.NumberPicker;
import android.widget.Switch;
import android.widget.TextView;

import java.util.List;

public final class WorkoutActivity extends BaseActivity {
    private GymFlowDatabase database;
    private RestTimerManager timer;
    private Models.Session session;
    private int currentExerciseIndex;
    private TextView elapsedText;
    private TextView timerText;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private boolean completedView;

    private final BroadcastReceiver workoutUpdates = new BroadcastReceiver() {
        @Override public void onReceive(Context context, Intent intent) {
            if (!completedView) renderWorkout();
        }
    };

    private final Runnable tick = new Runnable() {
        @Override public void run() {
            if (session != null && elapsedText != null) {
                elapsedText.setText(WorkoutMath.formatDuration(
                        Math.max(0, (System.currentTimeMillis() - session.startedAt) / 1000)));
            }
            int remaining = timer == null ? 0 : timer.remainingSeconds();
            if (timerText != null) timerText.setText(WorkoutMath.formatDuration(remaining));
            if (timer != null && timer.consumeCompletion()) {
                TimerFeedback.play(WorkoutActivity.this);
                WorkoutNotificationManager.show(WorkoutActivity.this);
                if (!completedView) renderWorkout();
            }
            handler.postDelayed(this, 1000);
        }
    };

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        database = GymFlowDatabase.get(this);
        timer = RestTimerManager.get(this);
        registerWorkoutUpdates();
        renderWorkout();
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[] {Manifest.permission.POST_NOTIFICATIONS}, 7101);
        }
        handler.post(tick);
    }

    private void registerWorkoutUpdates() {
        IntentFilter filter = new IntentFilter(WorkoutNotificationManager.ACTION_CHANGED);
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(workoutUpdates, filter, Context.RECEIVER_NOT_EXPORTED);
        else registerReceiver(workoutUpdates, filter);
    }

    @Override protected void onResume() {
        super.onResume();
        if (database != null && !completedView) renderWorkout();
    }

    @Override protected void onDestroy() {
        handler.removeCallbacks(tick);
        try { unregisterReceiver(workoutUpdates); } catch (Exception ignored) {}
        super.onDestroy();
    }

    @Override public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == 7101 && grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            WorkoutNotificationManager.show(this);
        }
    }

    private void renderWorkout() {
        session = database.getActiveSession();
        if (session == null) {
            finish();
            return;
        }
        currentExerciseIndex = Math.max(0, Math.min(session.currentExerciseIndex, session.records.size() - 1));
        buildPage(session.planName);
        addWorkoutHeader();
        if (session.records.isEmpty()) {
            content.addView(ui.secondary("这个训练中没有动作。", 16));
            return;
        }
        Models.ExerciseRecord record = session.records.get(currentExerciseIndex);
        addExerciseHeader(record);
        addPreviousPerformance(record);
        addSets(record);
        addRestTimer();
        addExerciseNotes(record);
        addNavigation();
        addCompactMusic();
        WorkoutNotificationManager.show(this);
    }

    private void addWorkoutHeader() {
        LinearLayout status = ui.card();
        LinearLayout row = ui.row();
        LinearLayout elapsed = ui.column();
        elapsedText = ui.text(WorkoutMath.formatDuration(
                Math.max(0, (System.currentTimeMillis() - session.startedAt) / 1000)), 22);
        elapsedText.setTypeface(Typeface.MONOSPACE, Typeface.BOLD);
        elapsed.addView(ui.secondary("训练时长", 12));
        elapsed.addView(elapsedText);
        row.addView(elapsed, UiKit.weight(1));
        TextView progress = ui.text((currentExerciseIndex + 1) + " / " + session.records.size() + " 个动作", 16);
        progress.setGravity(Gravity.END);
        row.addView(progress, UiKit.weight(1));
        status.addView(row);
        LinearLayout actions = ui.row();
        Button cancel = ui.button("取消训练", false);
        cancel.setTextColor(ui.destructive);
        cancel.setOnClickListener(view -> confirm("取消这次训练？", "已经填写的内容会保留为已取消记录，但不会出现在历史中。", "取消训练", this::cancelWorkout));
        Button finish = ui.button("完成训练", true);
        finish.setOnClickListener(view -> confirm("完成训练？", "已勾选完成的组将写入训练历史。", "完成", this::finishWorkout));
        actions.addView(cancel, UiKit.weight(1));
        actions.addView(ui.horizontalSpacer(8));
        actions.addView(finish, UiKit.weight(1));
        status.addView(ui.spacer(9));
        status.addView(actions);
        content.addView(status);
    }

    private void addExerciseHeader(Models.ExerciseRecord record) {
        LinearLayout header = ui.card();
        TextView eyebrow = ui.secondary("当前动作 · " + (currentExerciseIndex + 1) + " / " + session.records.size(), 13);
        eyebrow.setTextColor(ui.accent);
        header.addView(eyebrow);
        TextView title = ui.text(record.name, 27);
        title.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        header.addView(title);
        int completed = 0;
        for (Models.WorkoutSet set : record.sets) if (set.completed) completed++;
        header.addView(ui.secondary("已完成 " + completed + " / " + record.sets.size() + " 组 · 组间休息 " +
                record.restSeconds + " 秒", 14));
        content.addView(header);
    }

    private void addPreviousPerformance(Models.ExerciseRecord record) {
        Models.ExerciseRecord previous = null;
        for (Models.Session historical : database.getCompletedSessions(null)) {
            for (Models.ExerciseRecord candidate : historical.records) {
                boolean same = record.exerciseId != null && candidate.exerciseId != null
                        ? record.exerciseId.equals(candidate.exerciseId)
                        : GymFlowDatabase.normalize(record.name).equals(GymFlowDatabase.normalize(candidate.name));
                if (same) { previous = candidate; break; }
            }
            if (previous != null) break;
        }
        LinearLayout card = ui.card();
        card.addView(ui.secondary("上次表现", 13));
        if (previous == null) {
            card.addView(ui.text("还没有完成记录", 15));
        } else {
            StringBuilder values = new StringBuilder();
            for (Models.WorkoutSet set : previous.sets) {
                if (!set.completed) continue;
                if (values.length() > 0) values.append("  ·  ");
                values.append(WorkoutMath.formatWeight(set.weight)).append(" kg × ").append(set.repetitions);
            }
            card.addView(ui.text(values.length() == 0 ? "还没有完成组" : values.toString(), 14));
        }
        content.addView(card);
    }

    private void addSets(Models.ExerciseRecord record) {
        content.addView(ui.section("训练组"));
        LinearLayout card = ui.card();
        for (Models.WorkoutSet set : record.sets) {
            LinearLayout row = ui.row();
            row.setPadding(0, ui.dp(5), 0, ui.dp(5));
            TextView number = ui.text("#" + set.setNumber, 16);
            number.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
            row.addView(number, new LinearLayout.LayoutParams(ui.dp(38), ViewGroup.LayoutParams.WRAP_CONTENT));
            Button weight = ui.button(WorkoutMath.formatWeight(set.weight) + " kg", false);
            weight.setContentDescription("第 " + set.setNumber + " 组重量");
            weight.setOnClickListener(view -> showWeightPicker(set));
            row.addView(weight, UiKit.weight(1));
            Button reps = ui.button(set.repetitions + " 次", false);
            reps.setContentDescription("第 " + set.setNumber + " 组次数");
            reps.setOnClickListener(view -> showRepetitionPicker(set));
            row.addView(reps, UiKit.weight(1));
            Button complete = ui.button(set.completed ? "✓" : "○", set.completed);
            complete.setTextSize(20);
            complete.setContentDescription(set.completed ? "标记第 " + set.setNumber + " 组未完成" : "完成第 " + set.setNumber + " 组");
            complete.setOnClickListener(view -> toggleSet(record, set));
            row.addView(complete, new LinearLayout.LayoutParams(ui.dp(56), ui.dp(48)));
            card.addView(row);
            CheckBox warmup = new CheckBox(this);
            warmup.setText("热身组（不计入个人最佳）");
            warmup.setTextColor(ui.secondary);
            warmup.setChecked(set.warmup);
            warmup.setOnCheckedChangeListener((button, checked) -> {
                set.warmup = checked;
                database.updateSet(set);
            });
            card.addView(warmup);
        }
        LinearLayout controls = ui.row();
        Button add = ui.button("＋ 加一组", false);
        add.setOnClickListener(view -> { database.addSet(record.id); renderWorkout(); });
        Button remove = ui.button("− 删除最后一组", false);
        remove.setEnabled(record.sets.size() > 1);
        remove.setOnClickListener(view -> { database.removeLastSet(record.id); renderWorkout(); });
        controls.addView(add, UiKit.weight(1));
        controls.addView(remove, UiKit.weight(1));
        card.addView(ui.spacer(8));
        card.addView(controls);
        content.addView(card);
    }

    private void showWeightPicker(Models.WorkoutSet set) {
        NumberPicker picker = new NumberPicker(this);
        picker.setMinValue(0);
        picker.setMaxValue(1000);
        picker.setValue((int) Math.round(set.weight * 2));
        picker.setFormatter(value -> WorkoutMath.formatWeight(value / 2.0) + " kg");
        picker.setWrapSelectorWheel(false);
        new AlertDialog.Builder(this).setTitle("第 " + set.setNumber + " 组重量")
                .setView(picker).setNegativeButton("取消", null)
                .setPositiveButton("完成", (dialog, which) -> {
                    set.weight = picker.getValue() / 2.0;
                    database.updateSet(set);
                    renderWorkout();
                }).show();
    }

    private void showRepetitionPicker(Models.WorkoutSet set) {
        NumberPicker picker = new NumberPicker(this);
        picker.setMinValue(0);
        picker.setMaxValue(100);
        picker.setValue(Math.max(0, Math.min(100, set.repetitions)));
        picker.setFormatter(value -> value + " 次");
        picker.setWrapSelectorWheel(false);
        new AlertDialog.Builder(this).setTitle("第 " + set.setNumber + " 组次数")
                .setView(picker).setNegativeButton("取消", null)
                .setPositiveButton("完成", (dialog, which) -> {
                    set.repetitions = picker.getValue();
                    database.updateSet(set);
                    renderWorkout();
                }).show();
    }

    private void toggleSet(Models.ExerciseRecord record, Models.WorkoutSet set) {
        set.completed = !set.completed;
        set.completedAt = set.completed ? System.currentTimeMillis() : null;
        database.updateSet(set);
        if (set.completed) {
            vibrateTick();
            if (record.restSeconds > 0) {
                timer.start(record.restSeconds);
                WorkoutNotificationManager.scheduleRestAlarm(this);
            }
            moveCursorToNextIncomplete(session, currentExerciseIndex, set.setNumber);
        }
        WorkoutNotificationManager.show(this);
        renderWorkout();
    }

    private void moveCursorToNextIncomplete(Models.Session value, int fromExercise, int fromSet) {
        int exercise = fromExercise;
        int number = fromSet;
        boolean found = false;
        for (int index = fromExercise; index < value.records.size() && !found; index++) {
            for (Models.WorkoutSet candidate : value.records.get(index).sets) {
                if (!candidate.completed) {
                    exercise = index;
                    number = candidate.setNumber;
                    found = true;
                    break;
                }
            }
        }
        database.updateSessionCursor(value.id, exercise, number);
    }

    private void addRestTimer() {
        if (!timer.isActive() && timer.originalDuration() <= 0) return;
        content.addView(ui.section("休息计时"));
        LinearLayout card = ui.card();
        timerText = ui.text(WorkoutMath.formatDuration(timer.remainingSeconds()), 44);
        timerText.setTypeface(Typeface.MONOSPACE, Typeface.BOLD);
        timerText.setGravity(Gravity.CENTER);
        card.addView(timerText);
        card.addView(ui.secondary(timer.isPaused() ? "已暂停" : timer.isRunning() ? "休息中" : "计时结束", 14));
        LinearLayout controls = ui.row();
        Button pause = ui.button(timer.isPaused() ? "继续" : "暂停", false);
        pause.setOnClickListener(view -> {
            if (timer.isPaused()) {
                timer.resume();
                WorkoutNotificationManager.scheduleRestAlarm(this);
            } else {
                timer.pause();
                WorkoutNotificationManager.cancelRestAlarm(this);
            }
            renderWorkout();
        });
        Button add = ui.button("＋30 秒", false);
        add.setOnClickListener(view -> { timer.addThirtySeconds(); WorkoutNotificationManager.scheduleRestAlarm(this); renderWorkout(); });
        Button restart = ui.button("重来", false);
        restart.setOnClickListener(view -> { timer.restart(); WorkoutNotificationManager.scheduleRestAlarm(this); renderWorkout(); });
        Button skip = ui.button("跳过", false);
        skip.setOnClickListener(view -> { timer.cancel(); WorkoutNotificationManager.cancelRestAlarm(this); renderWorkout(); });
        controls.addView(pause, UiKit.weight(1));
        controls.addView(add, UiKit.weight(1));
        controls.addView(restart, UiKit.weight(1));
        controls.addView(skip, UiKit.weight(1));
        card.addView(ui.spacer(8));
        card.addView(controls);
        content.addView(card);
    }

    private void addExerciseNotes(Models.ExerciseRecord record) {
        content.addView(ui.section("动作备注"));
        LinearLayout card = ui.card();
        EditText notes = ui.edit("记录动作提示、器械设置等", record.notes, true);
        Button save = ui.button("保存备注", false);
        save.setOnClickListener(view -> {
            database.updateRecordNotes(record.id, notes.getText().toString());
            toast("备注已保存");
        });
        card.addView(notes);
        card.addView(save);
        content.addView(card);
    }

    private void addNavigation() {
        LinearLayout navigation = ui.row();
        Button previous = ui.button("‹ 上一个动作", false);
        previous.setEnabled(currentExerciseIndex > 0);
        previous.setOnClickListener(view -> navigateTo(currentExerciseIndex - 1));
        Button next = ui.button("下一个动作 ›", false);
        next.setEnabled(currentExerciseIndex + 1 < session.records.size());
        next.setOnClickListener(view -> navigateTo(currentExerciseIndex + 1));
        navigation.addView(previous, UiKit.weight(1));
        navigation.addView(ui.horizontalSpacer(8));
        navigation.addView(next, UiKit.weight(1));
        content.addView(ui.spacer(8));
        content.addView(navigation);
    }

    private void navigateTo(int index) {
        if (index < 0 || index >= session.records.size()) return;
        int setNumber = 1;
        for (Models.WorkoutSet set : session.records.get(index).sets) if (!set.completed) { setNumber = set.setNumber; break; }
        database.updateSessionCursor(session.id, index, setNumber);
        renderWorkout();
    }

    private void addCompactMusic() {
        PlaybackService.State state = PlaybackService.state();
        LinearLayout card = ui.card();
        card.addView(ui.secondary("训练音乐", 13));
        card.addView(ui.text(state.trackId == null ? "没有正在播放的音乐" : state.title, 16));
        LinearLayout controls = ui.row();
        Button previous = ui.button("上一首", false);
        previous.setOnClickListener(view -> PlaybackService.send(this, PlaybackService.ACTION_PREVIOUS));
        Button toggle = ui.button(state.playing ? "暂停" : "播放", false);
        toggle.setOnClickListener(view -> PlaybackService.send(this, PlaybackService.ACTION_TOGGLE));
        Button next = ui.button("下一首", false);
        next.setOnClickListener(view -> PlaybackService.send(this, PlaybackService.ACTION_NEXT));
        Button open = ui.button("全屏", false);
        open.setOnClickListener(view -> startActivity(new Intent(this, NowPlayingActivity.class)));
        controls.addView(previous, UiKit.weight(1));
        controls.addView(toggle, UiKit.weight(1));
        controls.addView(next, UiKit.weight(1));
        controls.addView(open, UiKit.weight(1));
        card.addView(ui.spacer(8));
        card.addView(controls);
        content.addView(ui.spacer(8));
        content.addView(card);
    }

    private void finishWorkout() {
        database.finishSession(session.id, session.notes);
        timer.cancel();
        WorkoutNotificationManager.cancel(this);
        session = database.getSession(session.id);
        completedView = true;
        renderCompletion();
    }

    private void renderCompletion() {
        buildPage("训练完成");
        LinearLayout hero = ui.card();
        TextView check = ui.text("✓", 58);
        check.setTextColor(ui.accent);
        check.setGravity(Gravity.CENTER);
        hero.addView(check);
        TextView title = ui.text(session.planName, 27);
        title.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        title.setGravity(Gravity.CENTER);
        hero.addView(title);
        hero.addView(ui.secondary("做得漂亮，这次训练已经保存在本机。", 15));
        content.addView(hero);
        WorkoutMath.Totals totals = WorkoutMath.totals(session);
        long end = session.completedAt == null ? System.currentTimeMillis() : session.completedAt;
        LinearLayout summary = ui.card();
        LinearLayout first = ui.row();
        first.addView(completionMetric("时长", humanDuration((end - session.startedAt) / 1000)), UiKit.weight(1));
        first.addView(completionMetric("动作", totals.exercises + " 个"), UiKit.weight(1));
        first.addView(completionMetric("完成组", totals.sets + " 组"), UiKit.weight(1));
        summary.addView(first);
        LinearLayout second = ui.row();
        second.addView(completionMetric("次数", totals.repetitions + " 次"), UiKit.weight(1));
        second.addView(completionMetric("容量", WorkoutMath.formatWeight(totals.volume) + " kg"), UiKit.weight(2));
        summary.addView(ui.spacer(12));
        summary.addView(second);
        content.addView(summary);

        String best = WorkoutAnalytics.newestPersonalBest(session, database.getCompletedSessions(null));
        if (best != null) {
            LinearLayout pb = ui.card();
            TextView label = ui.text("🏆 新的个人最佳", 18);
            label.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
            label.setTextColor(ui.accent);
            pb.addView(label);
            pb.addView(ui.text(best, 16));
            content.addView(pb);
        }
        LinearLayout notesCard = ui.card();
        notesCard.addView(ui.section("训练备注"));
        EditText notes = ui.edit("今天感觉怎么样？", session.notes, true);
        notesCard.addView(notes);
        content.addView(notesCard);
        Button share = ui.button("分享训练海报", false);
        share.setOnClickListener(view -> {
            database.updateSessionNotes(session.id, notes.getText().toString());
            session.notes = notes.getText().toString();
            WorkoutShare.show(this, session);
        });
        Button done = ui.button("保存并返回今天", true);
        done.setOnClickListener(view -> {
            database.updateSessionNotes(session.id, notes.getText().toString());
            getSharedPreferences("gymflow_settings", MODE_PRIVATE).edit().remove("active_session").apply();
            finish();
        });
        content.addView(share);
        content.addView(ui.spacer(8));
        content.addView(done);
    }

    private LinearLayout completionMetric(String label, String value) {
        LinearLayout column = ui.column();
        TextView number = ui.text(value, 19);
        number.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        number.setGravity(Gravity.CENTER);
        TextView caption = ui.secondary(label, 12);
        caption.setGravity(Gravity.CENTER);
        column.addView(number);
        column.addView(caption);
        return column;
    }

    private void cancelWorkout() {
        database.cancelSession(session.id);
        timer.cancel();
        WorkoutNotificationManager.cancel(this);
        getSharedPreferences("gymflow_settings", MODE_PRIVATE).edit().remove("active_session").apply();
        finish();
    }

    private void vibrateTick() {
        if (!getSharedPreferences("gymflow_settings", MODE_PRIVATE).getBoolean("timer_haptic", true)) return;
        Vibrator vibrator = (Vibrator) getSystemService(VIBRATOR_SERVICE);
        if (vibrator != null && vibrator.hasVibrator()) vibrator.vibrate(VibrationEffect.createOneShot(45, 90));
    }

    private String humanDuration(long seconds) {
        long minutes = Math.max(0, seconds) / 60;
        if (minutes >= 60) return minutes / 60 + "小时" + minutes % 60 + "分";
        return Math.max(1, minutes) + "分钟";
    }
}
