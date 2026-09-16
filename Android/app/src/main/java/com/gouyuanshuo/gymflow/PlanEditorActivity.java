package com.gouyuanshuo.gymflow;

import android.app.AlertDialog;
import android.os.Bundle;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.List;

public final class PlanEditorActivity extends BaseActivity {
    private GymFlowDatabase database;
    private Models.Plan draft;
    private EditText nameField;
    private EditText notesField;
    private Spinner playlistSpinner;
    private List<Models.Playlist> playlists;

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        database = GymFlowDatabase.get(this);
        String id = getIntent().getStringExtra("plan_id");
        Models.Plan existing = database.getPlan(id);
        draft = existing == null ? new Models.Plan() : existing.copy();
        if (existing == null) draft.name = "";
        renderEditor();
    }

    private void syncFields() {
        if (nameField != null) draft.name = nameField.getText().toString();
        if (notesField != null) draft.notes = notesField.getText().toString();
        if (playlistSpinner != null && playlists != null) {
            int position = playlistSpinner.getSelectedItemPosition();
            draft.assignedPlaylistId = position <= 0 ? null : playlists.get(position - 1).id;
        }
    }

    private void renderEditor() {
        syncFields();
        buildPage(draft.id == null ? "新建训练计划" : "编辑训练计划");
        content.addView(ui.section("计划"));
        LinearLayout planCard = ui.card();
        nameField = ui.edit("计划名称（必填）", draft.name, false);
        notesField = ui.edit("计划备注", draft.notes, true);
        planCard.addView(nameField);
        planCard.addView(notesField);
        playlists = database.getPlaylists();
        ArrayList<String> playlistNames = new ArrayList<>();
        playlistNames.add("不关联播放列表");
        int selected = 0;
        for (int index = 0; index < playlists.size(); index++) {
            Models.Playlist playlist = playlists.get(index);
            playlistNames.add(playlist.name);
            if (playlist.id.equals(draft.assignedPlaylistId)) selected = index + 1;
        }
        planCard.addView(ui.secondary("训练播放列表", 13));
        playlistSpinner = new Spinner(this);
        playlistSpinner.setAdapter(new ArrayAdapter<>(this, android.R.layout.simple_spinner_dropdown_item, playlistNames));
        playlistSpinner.setSelection(selected);
        planCard.addView(playlistSpinner);
        content.addView(planCard);

        content.addView(ui.section("动作顺序"));
        if (draft.exercises.isEmpty()) content.addView(ui.secondary("还没有动作。添加后可单独设置重量、次数和休息时间。", 15));
        for (int index = 0; index < draft.exercises.size(); index++) addExerciseRow(index);
        Button add = ui.button("＋ 添加动作", false);
        add.setOnClickListener(view -> { syncFields(); showExercisePicker(); });
        content.addView(add);
        content.addView(ui.spacer(18));
        Button save = ui.button("保存计划", true);
        save.setOnClickListener(view -> savePlan());
        content.addView(save);
        content.addView(ui.spacer(8));
        Button cancel = ui.button("取消", false);
        cancel.setOnClickListener(view -> finish());
        content.addView(cancel);
    }

    private void addExerciseRow(int index) {
        Models.PlannedExercise exercise = draft.exercises.get(index);
        LinearLayout card = ui.card();
        TextView title = ui.text((index + 1) + ".  " + exercise.name, 18);
        title.setTypeface(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD);
        card.addView(title);
        card.addView(ui.secondary(exercise.targetSets + " 组 × " + exercise.targetRepetitions + " 次 · " +
                WorkoutMath.formatWeight(exercise.targetWeight) + " kg · 休息 " + exercise.restSeconds + " 秒", 14));
        LinearLayout actions = ui.row();
        Button edit = ui.button("设置", false);
        edit.setOnClickListener(view -> { syncFields(); showPlannedExerciseEditor(exercise); });
        Button up = ui.button("↑", false);
        up.setEnabled(index > 0);
        up.setOnClickListener(view -> move(index, index - 1));
        Button down = ui.button("↓", false);
        down.setEnabled(index + 1 < draft.exercises.size());
        down.setOnClickListener(view -> move(index, index + 1));
        Button remove = ui.button("移除", false);
        remove.setTextColor(ui.destructive);
        remove.setOnClickListener(view -> { syncFields(); draft.exercises.remove(exercise); renderEditor(); });
        actions.addView(edit, UiKit.weight(2));
        actions.addView(up, UiKit.weight(1));
        actions.addView(down, UiKit.weight(1));
        actions.addView(remove, UiKit.weight(2));
        card.addView(ui.spacer(6));
        card.addView(actions);
        content.addView(card);
    }

    private void move(int source, int destination) {
        syncFields();
        if (destination < 0 || destination >= draft.exercises.size()) return;
        Models.PlannedExercise value = draft.exercises.remove(source);
        draft.exercises.add(destination, value);
        renderEditor();
    }

    private void showExercisePicker() {
        List<Models.ExerciseDefinition> exercises = database.getExercises(false, null, null);
        String[] names = new String[exercises.size() + 1];
        names[0] = "＋ 新建自定义动作";
        for (int index = 0; index < exercises.size(); index++) {
            Models.ExerciseDefinition exercise = exercises.get(index);
            names[index + 1] = exercise.name + "  ·  " + exercise.muscleGroup;
        }
        new AlertDialog.Builder(this).setTitle("添加动作")
                .setItems(names, (dialog, which) -> {
                    if (which == 0) {
                        ExerciseEditDialog.show(this, null, exercise -> { addDefinition(exercise); renderEditor(); });
                    } else {
                        addDefinition(exercises.get(which - 1));
                        renderEditor();
                    }
                }).setNegativeButton("取消", null).show();
    }

    private void addDefinition(Models.ExerciseDefinition definition) {
        Models.PlannedExercise exercise = new Models.PlannedExercise();
        exercise.exerciseId = definition.id;
        exercise.name = definition.name;
        exercise.targetSets = definition.defaultSets == null ? 3 : definition.defaultSets;
        exercise.targetRepetitions = definition.defaultRepetitions == null ? 10 : definition.defaultRepetitions;
        exercise.restSeconds = definition.defaultRestSeconds == null
                ? getSharedPreferences("gymflow_settings", MODE_PRIVATE).getInt("default_rest", 90)
                : definition.defaultRestSeconds;
        exercise.sortOrder = draft.exercises.size();
        draft.exercises.add(exercise);
    }

    private void showPlannedExerciseEditor(Models.PlannedExercise exercise) {
        LinearLayout form = ui.column();
        form.setPadding(ui.dp(18), 0, ui.dp(18), ui.dp(12));
        EditText sets = ui.numberEdit("目标组数", String.valueOf(exercise.targetSets), false);
        EditText reps = ui.numberEdit("目标次数", String.valueOf(exercise.targetRepetitions), false);
        EditText weight = ui.numberEdit("目标重量（kg）", WorkoutMath.formatWeight(exercise.targetWeight), true);
        EditText rest = ui.numberEdit("休息秒数", String.valueOf(exercise.restSeconds), false);
        EditText notes = ui.edit("动作备注", exercise.notes, true);
        form.addView(sets); form.addView(reps); form.addView(weight); form.addView(rest); form.addView(notes);
        AlertDialog dialog = new AlertDialog.Builder(this).setTitle(exercise.name).setView(form)
                .setNegativeButton("取消", null).setPositiveButton("完成", null).create();
        dialog.setOnShowListener(value -> dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(view -> {
            try {
                exercise.targetSets = parse(sets, 1, 30, "组数");
                exercise.targetRepetitions = parse(reps, 0, 100, "次数");
                exercise.targetWeight = parseDouble(weight, 0, 500, "重量");
                exercise.restSeconds = parse(rest, 0, 900, "休息时间");
                exercise.notes = notes.getText().toString();
                dialog.dismiss();
                renderEditor();
            } catch (Exception error) { Toast.makeText(this, error.getMessage(), Toast.LENGTH_LONG).show(); }
        }));
        dialog.show();
    }

    private void savePlan() {
        syncFields();
        try {
            if (draft.exercises.isEmpty()) throw new IllegalArgumentException("请至少添加一个动作");
            database.savePlan(draft);
            toast("训练计划已保存");
            finish();
        } catch (Exception error) { showError("无法保存计划", error); }
    }

    private int parse(EditText field, int minimum, int maximum, String name) {
        int value = Integer.parseInt(field.getText().toString().trim());
        if (value < minimum || value > maximum) throw new IllegalArgumentException(name + "需在 " + minimum + "–" + maximum + " 之间");
        return value;
    }

    private double parseDouble(EditText field, double minimum, double maximum, String name) {
        double value = Double.parseDouble(field.getText().toString().trim());
        if (value < minimum || value > maximum) throw new IllegalArgumentException(name + "需在 " + minimum + "–" + maximum + " 之间");
        return Math.round(value * 2) / 2.0;
    }
}
