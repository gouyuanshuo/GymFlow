package com.gouyuanshuo.gymflow;

import android.app.AlertDialog;
import android.os.Bundle;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.Spinner;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

public final class ExerciseLibraryActivity extends BaseActivity {
    private GymFlowDatabase database;
    private String searchText = "";
    private String muscle = "全部";
    private boolean includeArchived;
    private int sortMode;

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        database = GymFlowDatabase.get(this);
        renderLibrary();
        if (getIntent().getBooleanExtra("open_create", false)) {
            ExerciseEditDialog.show(this, null, value -> renderLibrary());
        }
    }

    private void renderLibrary() {
        buildPage("动作库");
        LinearLayout intro = ui.card();
        intro.addView(ui.text("搜索、筛选并维护训练动作", 18));
        intro.addView(ui.secondary("内置动作可以编辑或归档；未被计划和历史使用的自定义动作可以永久删除。", 13));
        content.addView(intro);

        LinearLayout filters = ui.card();
        EditText search = ui.edit("搜索名称、肌群或器械", searchText, false);
        filters.addView(search);
        Spinner muscleSpinner = new Spinner(this);
        ArrayList<String> muscles = new ArrayList<>();
        muscles.add("全部");
        for (String value : ExerciseEditDialog.MUSCLES) muscles.add(value);
        muscleSpinner.setAdapter(new ArrayAdapter<>(this, android.R.layout.simple_spinner_dropdown_item, muscles));
        muscleSpinner.setSelection(Math.max(0, muscles.indexOf(muscle)));
        Spinner sort = new Spinner(this);
        sort.setAdapter(new ArrayAdapter<>(this, android.R.layout.simple_spinner_dropdown_item,
                new String[] {"按名称", "按肌群", "最近更新"}));
        sort.setSelection(sortMode);
        LinearLayout selectors = ui.row();
        selectors.addView(muscleSpinner, UiKit.weight(1));
        selectors.addView(sort, UiKit.weight(1));
        filters.addView(selectors);
        CheckBox archived = new CheckBox(this);
        archived.setText("显示已归档动作");
        archived.setTextColor(ui.secondary);
        archived.setChecked(includeArchived);
        filters.addView(archived);
        LinearLayout buttons = ui.row();
        Button apply = ui.button("应用筛选", false);
        apply.setOnClickListener(view -> {
            searchText = search.getText().toString();
            muscle = (String) muscleSpinner.getSelectedItem();
            includeArchived = archived.isChecked();
            sortMode = sort.getSelectedItemPosition();
            renderLibrary();
        });
        Button create = ui.button("＋ 自定义动作", true);
        create.setOnClickListener(view -> ExerciseEditDialog.show(this, null, value -> renderLibrary()));
        buttons.addView(apply, UiKit.weight(1));
        buttons.addView(create, UiKit.weight(1));
        filters.addView(buttons);
        content.addView(filters);

        List<Models.ExerciseDefinition> exercises = database.getExercises(includeArchived, searchText, muscle);
        if (sortMode == 0) exercises.sort(Comparator.comparing(value -> value.name));
        else if (sortMode == 1) exercises.sort(Comparator.comparing((Models.ExerciseDefinition value) -> value.muscleGroup)
                .thenComparing(value -> value.name));
        else exercises.sort((left, right) -> Long.compare(right.updatedAt, left.updatedAt));
        content.addView(ui.section("动作（" + exercises.size() + "）"));
        if (exercises.isEmpty()) {
            content.addView(ui.secondary("没有符合当前条件的动作。", 15));
            return;
        }
        for (Models.ExerciseDefinition exercise : exercises) addExerciseCard(exercise);
    }

    private void addExerciseCard(Models.ExerciseDefinition exercise) {
        LinearLayout card = ui.card();
        TextView title = ui.text(exercise.name + (exercise.archived ? "  ·  已归档" : ""), 18);
        title.setTypeface(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD);
        if (exercise.archived) title.setTextColor(ui.secondary);
        card.addView(title);
        card.addView(ui.secondary(exercise.muscleGroup + " · " + exercise.equipment +
                (exercise.custom ? " · 自定义" : " · 内置"), 14));
        String defaults = defaultText(exercise);
        if (!defaults.isEmpty()) card.addView(ui.secondary("计划默认值：" + defaults, 13));
        card.setOnClickListener(view -> showDetails(exercise));
        LinearLayout actions = ui.row();
        Button detail = ui.button("详情 / 个人最佳", false);
        detail.setOnClickListener(view -> showDetails(exercise));
        Button edit = ui.button("编辑", false);
        edit.setOnClickListener(view -> ExerciseEditDialog.show(this, exercise, value -> renderLibrary()));
        Button archive = ui.button(exercise.archived ? "恢复" : "归档", false);
        archive.setOnClickListener(view -> { database.setExerciseArchived(exercise.id, !exercise.archived); renderLibrary(); });
        actions.addView(detail, UiKit.weight(2));
        actions.addView(edit, UiKit.weight(1));
        actions.addView(archive, UiKit.weight(1));
        if (exercise.custom) {
            Button delete = ui.button("删除", false);
            delete.setTextColor(ui.destructive);
            delete.setOnClickListener(view -> confirm("删除自定义动作？", "只有未被计划和历史记录使用的动作可以删除。", "删除", () -> {
                if (!database.deleteCustomExerciseIfUnused(exercise.id)) toast("该动作仍被计划或训练历史使用，不能删除；可以先归档");
                renderLibrary();
            }));
            actions.addView(delete, UiKit.weight(1));
        }
        card.addView(ui.spacer(7));
        card.addView(actions);
        content.addView(card);
    }

    private void showDetails(Models.ExerciseDefinition exercise) {
        LinearLayout details = ui.column();
        details.setPadding(ui.dp(18), 0, ui.dp(18), ui.dp(18));
        details.addView(ui.text(exercise.muscleGroup + " · " + exercise.equipment, 16));
        if (!exercise.secondaryMuscleGroups.isEmpty()) details.addView(ui.secondary("次要肌群：" + exercise.secondaryMuscleGroups, 14));
        if (!defaultText(exercise).isEmpty()) details.addView(ui.secondary("默认值：" + defaultText(exercise), 14));
        if (!exercise.notes.isEmpty()) details.addView(ui.secondary(exercise.notes, 14));
        WorkoutAnalytics.PersonalBests bests = WorkoutAnalytics.personalBests(exercise.id, exercise.name,
                database.getCompletedSessions(null));
        details.addView(ui.section("个人最佳"));
        if (!bests.hasAny()) {
            details.addView(ui.secondary("完成这个动作后，这里会显示历史最佳。", 14));
        } else {
            if (bests.heaviestWeight > 0) details.addView(ui.text("最重重量  " + WorkoutMath.formatWeight(bests.heaviestWeight) + " kg", 16));
            if (bests.estimatedOneRepMax > 0) details.addView(ui.text("预估 1RM  " + WorkoutMath.formatWeight(bests.estimatedOneRepMax) + " kg", 16));
            if (bests.setVolume > 0) details.addView(ui.text("单组最大容量  " + WorkoutMath.formatWeight(bests.setVolume) + " kg", 16));
            if (bests.repetitions > 0) details.addView(ui.text("最多次数  " + bests.repetitions + " 次" +
                    (bests.repetitionWeight > 0 ? " @ " + WorkoutMath.formatWeight(bests.repetitionWeight) + " kg" : "（自重）"), 16));
            details.addView(ui.section("纪录时间线"));
            int start = Math.max(0, bests.events.size() - 8);
            for (int index = bests.events.size() - 1; index >= start; index--) details.addView(ui.secondary("• " + bests.events.get(index), 13));
        }
        ScrollView scroll = new ScrollView(this);
        scroll.addView(details, new ScrollView.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));
        new AlertDialog.Builder(this).setTitle(exercise.name).setView(scroll)
                .setNegativeButton("关闭", null)
                .setPositiveButton("编辑", (dialog, which) -> ExerciseEditDialog.show(this, exercise, value -> renderLibrary()))
                .show();
    }

    private String defaultText(Models.ExerciseDefinition exercise) {
        ArrayList<String> parts = new ArrayList<>();
        if (exercise.defaultSets != null) parts.add(exercise.defaultSets + " 组");
        if (exercise.defaultRepetitions != null) parts.add(exercise.defaultRepetitions + " 次");
        if (exercise.defaultRestSeconds != null) parts.add("休息 " + exercise.defaultRestSeconds + " 秒");
        return String.join(" · ", parts);
    }
}
