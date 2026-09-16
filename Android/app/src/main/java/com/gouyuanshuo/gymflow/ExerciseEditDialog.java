package com.gouyuanshuo.gymflow;

import android.app.Activity;
import android.app.AlertDialog;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.Spinner;
import android.widget.Toast;

public final class ExerciseEditDialog {
    public interface Callback { void saved(Models.ExerciseDefinition exercise); }
    public static final String[] MUSCLES = {"胸部", "背部", "肩部", "肱二头肌", "肱三头肌", "股四头肌", "腘绳肌", "臀部", "小腿", "核心", "有氧", "其他"};
    public static final String[] EQUIPMENT = {"杠铃", "哑铃", "壶铃", "绳索器械", "固定器械", "自重", "弹力带", "有氧器械", "其他"};

    private ExerciseEditDialog() {}

    public static void show(Activity activity, Models.ExerciseDefinition source, Callback callback) {
        UiKit ui = new UiKit(activity);
        Models.ExerciseDefinition draft = source == null ? new Models.ExerciseDefinition() : copy(source);
        if (source == null) {
            draft.custom = true;
            draft.muscleGroup = "其他";
            draft.equipment = "其他";
            draft.defaultRestSeconds = activity.getSharedPreferences("gymflow_settings", Activity.MODE_PRIVATE)
                    .getInt("default_rest", 90);
            draft.defaultSets = 3;
            draft.defaultRepetitions = 10;
        }
        LinearLayout form = ui.column();
        form.setPadding(ui.dp(18), ui.dp(4), ui.dp(18), ui.dp(18));
        EditText name = ui.edit("动作名称", draft.name, false);
        Spinner muscle = spinner(activity, MUSCLES, indexOf(MUSCLES, draft.muscleGroup));
        Spinner equipment = spinner(activity, EQUIPMENT, indexOf(EQUIPMENT, draft.equipment));
        EditText secondary = ui.edit("次要肌群（用顿号或逗号分隔）", draft.secondaryMuscleGroups, false);
        EditText sets = ui.numberEdit("默认组数", nullable(draft.defaultSets), false);
        EditText reps = ui.numberEdit("默认次数", nullable(draft.defaultRepetitions), false);
        EditText rest = ui.numberEdit("默认休息秒数", nullable(draft.defaultRestSeconds), false);
        EditText notes = ui.edit("动作备注", draft.notes, true);
        form.addView(ui.section("动作"));
        form.addView(name);
        form.addView(ui.secondary("主要肌群", 13));
        form.addView(muscle);
        form.addView(ui.secondary("器械", 13));
        form.addView(equipment);
        form.addView(secondary);
        form.addView(ui.section("加入计划时的默认值"));
        form.addView(sets);
        form.addView(reps);
        form.addView(rest);
        form.addView(notes);
        ScrollView scroll = new ScrollView(activity);
        scroll.addView(form, new ScrollView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        AlertDialog dialog = new AlertDialog.Builder(activity)
                .setTitle(source == null ? "新建自定义动作" : "编辑动作")
                .setView(scroll).setNegativeButton("取消", null)
                .setPositiveButton("保存", null).create();
        dialog.setOnShowListener(value -> dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(view -> {
            try {
                draft.name = name.getText().toString();
                draft.muscleGroup = (String) muscle.getSelectedItem();
                draft.equipment = (String) equipment.getSelectedItem();
                draft.secondaryMuscleGroups = secondary.getText().toString().trim();
                draft.defaultSets = parseNullable(sets.getText().toString(), 1, 30, "默认组数");
                draft.defaultRepetitions = parseNullable(reps.getText().toString(), 0, 100, "默认次数");
                draft.defaultRestSeconds = parseNullable(rest.getText().toString(), 0, 900, "默认休息");
                draft.notes = notes.getText().toString();
                Models.ExerciseDefinition saved = GymFlowDatabase.get(activity).saveExercise(draft);
                dialog.dismiss();
                callback.saved(saved);
            } catch (Exception error) {
                Toast.makeText(activity, error.getMessage(), Toast.LENGTH_LONG).show();
            }
        }));
        dialog.show();
    }

    private static Spinner spinner(Activity activity, String[] values, int selection) {
        Spinner spinner = new Spinner(activity);
        spinner.setAdapter(new ArrayAdapter<>(activity, android.R.layout.simple_spinner_dropdown_item, values));
        spinner.setSelection(Math.max(0, selection));
        return spinner;
    }

    private static int indexOf(String[] values, String target) {
        for (int index = 0; index < values.length; index++) if (values[index].equals(target)) return index;
        return values.length - 1;
    }

    private static Integer parseNullable(String value, int minimum, int maximum, String field) {
        String trimmed = value.trim();
        if (trimmed.isEmpty()) return null;
        int parsed = Integer.parseInt(trimmed);
        if (parsed < minimum || parsed > maximum) throw new IllegalArgumentException(field + "需在 " + minimum + "–" + maximum + " 之间");
        return parsed;
    }

    private static String nullable(Integer value) { return value == null ? "" : String.valueOf(value); }

    private static Models.ExerciseDefinition copy(Models.ExerciseDefinition source) {
        Models.ExerciseDefinition value = new Models.ExerciseDefinition();
        value.id = source.id;
        value.name = source.name;
        value.muscleGroup = source.muscleGroup;
        value.secondaryMuscleGroups = source.secondaryMuscleGroups;
        value.equipment = source.equipment;
        value.defaultRestSeconds = source.defaultRestSeconds;
        value.defaultSets = source.defaultSets;
        value.defaultRepetitions = source.defaultRepetitions;
        value.notes = source.notes;
        value.custom = source.custom;
        value.archived = source.archived;
        value.createdAt = source.createdAt;
        value.updatedAt = source.updatedAt;
        return value;
    }
}
