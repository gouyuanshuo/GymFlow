package com.gouyuanshuo.gymflow;

import android.Manifest;
import android.app.AlertDialog;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.graphics.Typeface;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.FrameLayout;
import android.widget.GridLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.Spinner;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.Toast;

import java.text.SimpleDateFormat;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

public final class MainActivity extends android.app.Activity {
    private static final int IMPORT_AUDIO_REQUEST = 9001;
    private static final int NOTIFICATION_REQUEST = 9002;
    private enum Tab { TODAY, PLANS, HISTORY, MUSIC, SETTINGS }

    private UiKit ui;
    private GymFlowDatabase database;
    private SharedPreferences preferences;
    private LinearLayout root;
    private LinearLayout body;
    private Tab selectedTab = Tab.TODAY;
    private boolean historyCalendar;
    private String historySearch = "";
    private YearMonth calendarMonth = YearMonth.now();
    private boolean musicPlaylists;
    private int musicSort;

    private final BroadcastReceiver updates = new BroadcastReceiver() {
        @Override public void onReceive(Context context, Intent intent) {
            String error = intent.getStringExtra("error");
            if (error != null) Toast.makeText(MainActivity.this, error, Toast.LENGTH_LONG).show();
            render();
        }
    };

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        ui = new UiKit(this);
        database = GymFlowDatabase.get(this);
        database.ensureSeeded();
        preferences = getSharedPreferences("gymflow_settings", MODE_PRIVATE);
        if (!preferences.contains("default_rest")) {
            preferences.edit().putInt("default_rest", 90)
                    .putBoolean("timer_sound", true)
                    .putBoolean("timer_haptic", true)
                    .putBoolean("autoplay_playlist", false).apply();
        }
        musicSort = preferences.getInt("music_sort", 0);
        registerUpdates();
        handleIntent(getIntent());
        render();
    }

    @Override protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleIntent(intent);
    }

    private void handleIntent(Intent intent) {
        if (intent == null) return;
        if (intent.getBooleanExtra("resume_workout", false) && database != null && database.getActiveSession() != null) {
            startActivity(new Intent(this, WorkoutActivity.class));
        } else if (intent.getBooleanExtra("open_music", false)) {
            selectedTab = Tab.MUSIC;
            startActivity(new Intent(this, NowPlayingActivity.class));
        }
        intent.removeExtra("resume_workout");
        intent.removeExtra("open_music");
    }

    private void registerUpdates() {
        IntentFilter filter = new IntentFilter();
        filter.addAction(PlaybackService.ACTION_STATE_CHANGED);
        filter.addAction(WorkoutNotificationManager.ACTION_CHANGED);
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(updates, filter, Context.RECEIVER_NOT_EXPORTED);
        else registerReceiver(updates, filter);
    }

    @Override protected void onResume() {
        super.onResume();
        if (database != null) render();
    }

    @Override protected void onDestroy() {
        try { unregisterReceiver(updates); } catch (Exception ignored) {}
        super.onDestroy();
    }

    private void render() {
        if (ui == null) return;
        root = ui.column();
        root.setBackgroundColor(ui.background);
        UiKit.applySystemBarInsets(root);
        addTopBar();
        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        body = ui.column();
        body.setPadding(ui.dp(16), ui.dp(4), ui.dp(16), ui.dp(28));
        renderSelectedTab();
        scroll.addView(body, new ScrollView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        root.addView(scroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        addMiniPlayer();
        addBottomNavigation();
        setContentView(root);
    }

    private void addTopBar() {
        LinearLayout bar = ui.row();
        bar.setPadding(ui.dp(18), ui.dp(12), ui.dp(14), ui.dp(6));
        TextView title = ui.text(tabTitle(), 24);
        title.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        bar.addView(title, UiKit.weight(1));
        if (selectedTab == Tab.PLANS) {
            Button library = ui.button("动作库", false);
            library.setOnClickListener(view -> startActivity(new Intent(this, ExerciseLibraryActivity.class)));
            bar.addView(library);
        } else if (selectedTab == Tab.MUSIC) {
            Button importButton = ui.button("＋ 导入", false);
            importButton.setOnClickListener(view -> openAudioPicker());
            bar.addView(importButton);
        }
        root.addView(bar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ui.dp(62)));
    }

    private String tabTitle() {
        switch (selectedTab) {
            case PLANS: return "训练计划";
            case HISTORY: return "训练历史";
            case MUSIC: return "音乐";
            case SETTINGS: return "设置";
            default: return "今天";
        }
    }

    private void renderSelectedTab() {
        switch (selectedTab) {
            case PLANS: renderPlans(); break;
            case HISTORY: renderHistory(); break;
            case MUSIC: renderMusic(); break;
            case SETTINGS: renderSettings(); break;
            default: renderToday();
        }
    }

    private void renderToday() {
        TextView date = ui.secondary(new SimpleDateFormat("M月d日 EEEE", Locale.CHINA).format(new Date()), 16);
        body.addView(date);
        body.addView(ui.spacer(8));
        Models.Session active = database.getActiveSession();
        if (active != null) {
            LinearLayout card = ui.card();
            TextView activeLabel = ui.secondary("正在进行", 13);
            activeLabel.setTextColor(ui.accent);
            card.addView(activeLabel);
            TextView activeName = ui.text(active.planName, 21);
            activeName.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
            card.addView(activeName);
            card.addView(ui.secondary("已训练 " + WorkoutMath.formatDuration(
                    Math.max(0, (System.currentTimeMillis() - active.startedAt) / 1000)), 14));
            Button resume = ui.button("继续训练", true);
            resume.setOnClickListener(view -> startActivity(new Intent(this, WorkoutActivity.class)));
            card.addView(ui.spacer(10));
            card.addView(resume);
            body.addView(card);
        }

        List<Models.Plan> plans = database.getPlans();
        if (plans.isEmpty()) {
            LinearLayout empty = ui.card();
            empty.addView(ui.section("还没有训练计划"));
            empty.addView(ui.secondary("先创建一个计划，再开始记录每一组训练。", 15));
            Button create = ui.button("创建训练计划", true);
            create.setOnClickListener(view -> startActivity(new Intent(this, PlanEditorActivity.class)));
            empty.addView(ui.spacer(12));
            empty.addView(create);
            body.addView(empty);
            return;
        }
        body.addView(ui.section("选择今天的计划"));
        Spinner spinner = new Spinner(this);
        ArrayAdapter<Models.Plan> adapter = new ArrayAdapter<>(this, android.R.layout.simple_spinner_item, plans);
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        spinner.setAdapter(adapter);
        String selectedId = preferences.getString("selected_plan", plans.get(0).id);
        int selectedIndex = 0;
        for (int index = 0; index < plans.size(); index++) if (plans.get(index).id.equals(selectedId)) selectedIndex = index;
        spinner.setSelection(selectedIndex, false);
        spinner.setOnItemSelectedListener(new android.widget.AdapterView.OnItemSelectedListener() {
            @Override public void onItemSelected(android.widget.AdapterView<?> parent, View view, int position, long id) {
                Models.Plan selected = plans.get(position);
                if (!selected.id.equals(preferences.getString("selected_plan", ""))) {
                    preferences.edit().putString("selected_plan", selected.id).apply();
                    render();
                }
            }
            @Override public void onNothingSelected(android.widget.AdapterView<?> parent) {}
        });
        LinearLayout selectorCard = ui.card();
        selectorCard.addView(spinner);
        body.addView(selectorCard);

        Models.Plan plan = plans.get(selectedIndex);
        LinearLayout summary = ui.card();
        TextView name = ui.text(plan.name, 24);
        name.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        summary.addView(name);
        if (!plan.notes.isEmpty()) summary.addView(ui.secondary(plan.notes, 14));
        summary.addView(ui.spacer(10));
        LinearLayout metrics = ui.row();
        metrics.addView(metric(plan.exercises.size() + "", "个动作"), UiKit.weight(1));
        metrics.addView(metric("约 " + WorkoutMath.expectedDurationMinutes(plan), "分钟"), UiKit.weight(1));
        Models.Session latest = database.getLastCompletedForPlan(plan.id);
        metrics.addView(metric(latest == null ? "—" : shortDate(latest.completedAt), "上次完成"), UiKit.weight(1));
        summary.addView(metrics);
        Models.Playlist playlist = database.getPlaylist(plan.assignedPlaylistId);
        if (playlist != null) {
            summary.addView(ui.spacer(8));
            summary.addView(ui.secondary("♪ 已关联播放列表：" + playlist.name, 14));
        }
        Button start = ui.button(active == null ? "开始训练" : "已有训练正在进行", true);
        start.setEnabled(active == null);
        start.setAlpha(active == null ? 1f : 0.5f);
        start.setOnClickListener(view -> startWorkout(plan));
        summary.addView(ui.spacer(14));
        summary.addView(start);
        body.addView(summary);

        LinearLayout shortcuts = ui.row();
        Button library = ui.button("浏览动作库", false);
        library.setOnClickListener(view -> startActivity(new Intent(this, ExerciseLibraryActivity.class)));
        Button plansButton = ui.button("管理计划", false);
        plansButton.setOnClickListener(view -> { selectedTab = Tab.PLANS; render(); });
        shortcuts.addView(library, UiKit.weight(1));
        shortcuts.addView(ui.horizontalSpacer(8));
        shortcuts.addView(plansButton, UiKit.weight(1));
        body.addView(shortcuts);
    }

    private LinearLayout metric(String value, String label) {
        LinearLayout metric = ui.column();
        TextView main = ui.text(value, 18);
        main.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        main.setGravity(Gravity.CENTER_HORIZONTAL);
        TextView secondary = ui.secondary(label, 12);
        secondary.setGravity(Gravity.CENTER_HORIZONTAL);
        metric.addView(main);
        metric.addView(secondary);
        return metric;
    }

    private void startWorkout(Models.Plan plan) {
        try {
            Models.Session session = database.createSession(plan);
            preferences.edit().putString("active_session", session.id).apply();
            requestNotificationPermission();
            WorkoutNotificationManager.show(this);
            if (preferences.getBoolean("autoplay_playlist", false)) {
                Models.Playlist playlist = database.getPlaylist(plan.assignedPlaylistId);
                if (playlist != null && !playlist.trackIds.isEmpty()) {
                    PlaybackService.play(this, playlist.trackIds.get(0), playlist.trackIds);
                }
            }
            startActivity(new Intent(this, WorkoutActivity.class));
        } catch (Exception error) {
            showError("无法开始训练", error);
        }
    }

    private void renderPlans() {
        LinearLayout actions = ui.row();
        Button newPlan = ui.button("＋ 新建计划", true);
        newPlan.setOnClickListener(view -> startActivity(new Intent(this, PlanEditorActivity.class)));
        actions.addView(newPlan, UiKit.weight(1));
        body.addView(actions);
        List<Models.Plan> plans = database.getPlans();
        if (plans.isEmpty()) {
            body.addView(ui.secondary("这里还没有训练计划。", 16));
            return;
        }
        for (int index = 0; index < plans.size(); index++) {
            Models.Plan plan = plans.get(index);
            LinearLayout card = ui.card();
            TextView name = ui.text(plan.name, 20);
            name.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
            card.addView(name);
            card.addView(ui.secondary(plan.exercises.size() + " 个动作 · 约 " +
                    WorkoutMath.expectedDurationMinutes(plan) + " 分钟", 14));
            if (!plan.notes.isEmpty()) card.addView(ui.secondary(plan.notes, 13));
            LinearLayout row = ui.row();
            Button edit = ui.button("编辑", false);
            edit.setOnClickListener(view -> startActivity(new Intent(this, PlanEditorActivity.class).putExtra("plan_id", plan.id)));
            Button duplicate = ui.button("复制", false);
            duplicate.setOnClickListener(view -> { database.duplicatePlan(plan.id); render(); });
            Button reorder = ui.button(index == 0 ? "下移" : "上移", false);
            final int position = index;
            reorder.setOnClickListener(view -> movePlan(plans, position, position == 0 ? 1 : position - 1));
            Button delete = ui.button("删除", false);
            delete.setTextColor(ui.destructive);
            delete.setOnClickListener(view -> confirm("删除训练计划？", "历史训练不会受到影响。", "删除",
                    () -> { database.deletePlan(plan.id); render(); }));
            row.addView(edit, UiKit.weight(1));
            row.addView(duplicate, UiKit.weight(1));
            row.addView(reorder, UiKit.weight(1));
            row.addView(delete, UiKit.weight(1));
            card.addView(ui.spacer(8));
            card.addView(row);
            body.addView(card);
        }
    }

    private void movePlan(List<Models.Plan> plans, int source, int destination) {
        if (destination < 0 || destination >= plans.size() || source == destination) return;
        Models.Plan left = plans.get(source);
        Models.Plan right = plans.get(destination);
        int order = left.sortOrder;
        left.sortOrder = right.sortOrder;
        right.sortOrder = order;
        database.savePlan(left);
        database.savePlan(right);
        render();
    }

    private void renderHistory() {
        LinearLayout toggle = ui.row();
        Button list = ui.button("列表", !historyCalendar);
        Button calendar = ui.button("日历", historyCalendar);
        list.setOnClickListener(view -> { historyCalendar = false; render(); });
        calendar.setOnClickListener(view -> { historyCalendar = true; render(); });
        toggle.addView(list, UiKit.weight(1));
        toggle.addView(ui.horizontalSpacer(8));
        toggle.addView(calendar, UiKit.weight(1));
        body.addView(toggle);
        if (historyCalendar) renderCalendar(); else renderHistoryList();
    }

    private void renderHistoryList() {
        LinearLayout searchRow = ui.row();
        android.widget.EditText search = ui.edit("搜索计划或动作", historySearch, false);
        searchRow.addView(search, UiKit.weight(1));
        Button searchButton = ui.button("搜索", false);
        searchButton.setOnClickListener(view -> { historySearch = search.getText().toString(); render(); });
        searchRow.addView(searchButton);
        body.addView(searchRow);
        List<Models.Session> sessions = database.getCompletedSessions(historySearch);
        if (sessions.isEmpty()) {
            body.addView(ui.secondary(historySearch.isEmpty() ? "完成一次训练后，记录会出现在这里。" : "没有符合条件的训练。", 16));
            return;
        }
        for (Models.Session session : sessions) addHistoryCard(session);
    }

    private void addHistoryCard(Models.Session session) {
        LinearLayout card = ui.card();
        TextView name = ui.text(session.planName, 19);
        name.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        card.addView(name);
        long end = session.completedAt == null ? session.startedAt : session.completedAt;
        WorkoutMath.Totals totals = WorkoutMath.totals(session);
        card.addView(ui.secondary(shortDate(session.startedAt) + " · " +
                humanDuration((end - session.startedAt) / 1000) + " · " + totals.sets + " 组", 14));
        LinearLayout actions = ui.row();
        Button detail = ui.button("查看详情", false);
        detail.setOnClickListener(view -> startActivity(new Intent(this, SessionDetailActivity.class)
                .putExtra("session_id", session.id)));
        Button share = ui.button("分享", false);
        share.setOnClickListener(view -> WorkoutShare.show(this, session));
        Button delete = ui.button("删除", false);
        delete.setTextColor(ui.destructive);
        delete.setOnClickListener(view -> confirm("删除训练记录？", "这条历史记录将永久删除。", "删除",
                () -> { database.deleteSession(session.id); render(); }));
        actions.addView(detail, UiKit.weight(1));
        actions.addView(share, UiKit.weight(1));
        actions.addView(delete, UiKit.weight(1));
        card.addView(ui.spacer(7));
        card.addView(actions);
        body.addView(card);
    }

    private void renderCalendar() {
        LinearLayout navigation = ui.row();
        Button previous = ui.button("‹", false);
        previous.setOnClickListener(view -> { calendarMonth = calendarMonth.minusMonths(1); render(); });
        TextView month = ui.text(calendarMonth.format(DateTimeFormatter.ofPattern("yyyy年M月", Locale.CHINA)), 19);
        month.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        month.setGravity(Gravity.CENTER);
        Button today = ui.button("本月", false);
        today.setOnClickListener(view -> { calendarMonth = YearMonth.now(); render(); });
        Button next = ui.button("›", false);
        next.setOnClickListener(view -> { calendarMonth = calendarMonth.plusMonths(1); render(); });
        navigation.addView(previous, new LinearLayout.LayoutParams(ui.dp(48), ui.dp(46)));
        navigation.addView(month, UiKit.weight(1));
        navigation.addView(today);
        navigation.addView(next, new LinearLayout.LayoutParams(ui.dp(48), ui.dp(46)));
        body.addView(navigation);

        List<Models.Session> all = database.getCompletedSessions(null);
        Map<LocalDate, List<Models.Session>> grouped = new HashMap<>();
        ZoneId zone = ZoneId.systemDefault();
        for (Models.Session session : all) {
            LocalDate date = Instant.ofEpochMilli(session.startedAt).atZone(zone).toLocalDate();
            grouped.computeIfAbsent(date, key -> new ArrayList<>()).add(session);
        }
        LinearLayout calendarCard = ui.card();
        GridLayout grid = new GridLayout(this);
        grid.setColumnCount(7);
        String[] weekdays = {"一", "二", "三", "四", "五", "六", "日"};
        for (String weekday : weekdays) {
            TextView label = ui.secondary(weekday, 13);
            label.setGravity(Gravity.CENTER);
            grid.addView(label, cellParams());
        }
        LocalDate first = calendarMonth.atDay(1);
        int offset = first.getDayOfWeek().getValue() - DayOfWeek.MONDAY.getValue();
        for (int blank = 0; blank < offset; blank++) grid.addView(new TextView(this), cellParams());
        for (int day = 1; day <= calendarMonth.lengthOfMonth(); day++) {
            LocalDate date = calendarMonth.atDay(day);
            List<Models.Session> sessions = grouped.get(date);
            Button cell = ui.button(day + (sessions == null ? "" : "\n●"), false);
            cell.setTextColor(sessions == null ? ui.text : ui.accent);
            cell.setContentDescription(date + (sessions == null ? "，无训练" : "，" + sessions.size() + " 次训练"));
            if (sessions != null) cell.setOnClickListener(view -> showDaySessions(date, sessions));
            grid.addView(cell, cellParams());
        }
        calendarCard.addView(grid);
        body.addView(calendarCard);

        int workouts = 0;
        long seconds = 0;
        Set<LocalDate> days = new HashSet<>();
        for (Map.Entry<LocalDate, List<Models.Session>> entry : grouped.entrySet()) {
            if (!YearMonth.from(entry.getKey()).equals(calendarMonth)) continue;
            days.add(entry.getKey());
            workouts += entry.getValue().size();
            for (Models.Session session : entry.getValue()) {
                long end = session.completedAt == null ? session.startedAt : session.completedAt;
                seconds += Math.max(0, (end - session.startedAt) / 1000);
            }
        }
        LinearLayout summary = ui.card();
        summary.addView(ui.section("本月概览"));
        LinearLayout metrics = ui.row();
        metrics.addView(metric(String.valueOf(workouts), "次训练"), UiKit.weight(1));
        metrics.addView(metric(String.valueOf(days.size()), "个训练日"), UiKit.weight(1));
        metrics.addView(metric(humanDuration(seconds), "总时长"), UiKit.weight(1));
        summary.addView(metrics);
        body.addView(summary);
    }

    private GridLayout.LayoutParams cellParams() {
        GridLayout.LayoutParams params = new GridLayout.LayoutParams();
        params.width = 0;
        params.height = ui.dp(58);
        params.columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f);
        params.setMargins(ui.dp(1), ui.dp(1), ui.dp(1), ui.dp(1));
        return params;
    }

    private void showDaySessions(LocalDate date, List<Models.Session> sessions) {
        String[] names = new String[sessions.size()];
        for (int index = 0; index < sessions.size(); index++) names[index] = sessions.get(index).planName;
        new AlertDialog.Builder(this)
                .setTitle(date.format(DateTimeFormatter.ofPattern("M月d日", Locale.CHINA)))
                .setItems(names, (dialog, which) -> startActivity(new Intent(this, SessionDetailActivity.class)
                        .putExtra("session_id", sessions.get(which).id)))
                .setNegativeButton("关闭", null).show();
    }

    private void renderMusic() {
        LinearLayout toggle = ui.row();
        Button library = ui.button("音乐库", !musicPlaylists);
        Button playlists = ui.button("播放列表", musicPlaylists);
        library.setOnClickListener(view -> { musicPlaylists = false; render(); });
        playlists.setOnClickListener(view -> { musicPlaylists = true; render(); });
        toggle.addView(library, UiKit.weight(1));
        toggle.addView(ui.horizontalSpacer(8));
        toggle.addView(playlists, UiKit.weight(1));
        body.addView(toggle);
        if (musicPlaylists) renderPlaylists(); else renderMusicLibrary();
    }

    private void renderMusicLibrary() {
        List<Models.Track> tracks = database.getTracks();
        if (tracks.isEmpty()) {
            LinearLayout empty = ui.card();
            empty.addView(ui.section("还没有本地音乐"));
            empty.addView(ui.secondary("可导入 MP3、M4A、AAC、WAV、AIFF、FLAC、OGG 或 OPUS。音频会复制到 GymFlow 的私有目录。", 14));
            Button importButton = ui.button("导入本地音频", true);
            importButton.setOnClickListener(view -> openAudioPicker());
            empty.addView(ui.spacer(12));
            empty.addView(importButton);
            body.addView(empty);
            return;
        }
        Spinner sort = new Spinner(this);
        String[] choices = {"播放顺序", "标题", "艺术家", "最近导入"};
        sort.setAdapter(new ArrayAdapter<>(this, android.R.layout.simple_spinner_dropdown_item, choices));
        sort.setSelection(musicSort, false);
        sort.setOnItemSelectedListener(new android.widget.AdapterView.OnItemSelectedListener() {
            @Override public void onItemSelected(android.widget.AdapterView<?> parent, View view, int position, long id) {
                if (position != musicSort) {
                    musicSort = position;
                    preferences.edit().putInt("music_sort", position).apply();
                    render();
                }
            }
            @Override public void onNothingSelected(android.widget.AdapterView<?> parent) {}
        });
        LinearLayout sortCard = ui.card();
        sortCard.addView(ui.secondary("排序方式", 13));
        sortCard.addView(sort);
        body.addView(sortCard);
        if (musicSort == 1) tracks.sort(Comparator.comparing(value -> value.title));
        else if (musicSort == 2) tracks.sort(Comparator.comparing(value -> value.artist));
        else if (musicSort == 3) tracks.sort((a, b) -> Long.compare(b.createdAt, a.createdAt));
        List<String> queue = new ArrayList<>();
        for (Models.Track track : tracks) queue.add(track.id);
        PlaybackService.State state = PlaybackService.state();
        for (int trackIndex = 0; trackIndex < tracks.size(); trackIndex++) {
            Models.Track track = tracks.get(trackIndex);
            LinearLayout card = ui.card();
            LinearLayout heading = ui.row();
            TextView icon = ui.text(track.id.equals(state.trackId) ? "♪" : "♫", 23);
            icon.setTextColor(track.id.equals(state.trackId) ? ui.accent : ui.secondary);
            heading.addView(icon, new LinearLayout.LayoutParams(ui.dp(38), ViewGroup.LayoutParams.WRAP_CONTENT));
            LinearLayout labels = ui.column();
            TextView title = ui.text(track.title, 17);
            title.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
            labels.addView(title);
            labels.addView(ui.secondary(track.artist.isEmpty() ? track.originalFileName : track.artist, 13));
            heading.addView(labels, UiKit.weight(1));
            heading.setOnClickListener(view -> PlaybackService.play(this, track.id, queue));
            card.addView(heading);
            LinearLayout actions = ui.row();
            Button play = ui.button(track.id.equals(state.trackId) && state.playing ? "暂停" : "播放", false);
            play.setOnClickListener(view -> {
                if (track.id.equals(PlaybackService.state().trackId)) PlaybackService.send(this, PlaybackService.ACTION_TOGGLE);
                else PlaybackService.play(this, track.id, queue);
            });
            Button add = ui.button("加入列表", false);
            add.setOnClickListener(view -> addTrackToPlaylist(track));
            Button delete = ui.button("删除", false);
            delete.setTextColor(ui.destructive);
            delete.setOnClickListener(view -> deleteTrack(track));
            actions.addView(play, UiKit.weight(1));
            actions.addView(add, UiKit.weight(1));
            if (musicSort == 0 && tracks.size() > 1) {
                Button move = ui.button(trackIndex == 0 ? "下移" : "上移", false);
                final int sourceIndex = trackIndex;
                move.setOnClickListener(view -> moveTrack(tracks, sourceIndex, sourceIndex == 0 ? 1 : sourceIndex - 1));
                actions.addView(move, UiKit.weight(1));
            }
            actions.addView(delete, UiKit.weight(1));
            card.addView(ui.spacer(6));
            card.addView(actions);
            body.addView(card);
        }
    }

    private void moveTrack(List<Models.Track> tracks, int source, int destination) {
        if (destination < 0 || destination >= tracks.size()) return;
        Models.Track value = tracks.remove(source);
        tracks.add(destination, value);
        ArrayList<String> ids = new ArrayList<>();
        for (Models.Track track : tracks) ids.add(track.id);
        database.updateTrackSortOrders(ids);
        render();
    }

    private void renderPlaylists() {
        Button create = ui.button("＋ 新建播放列表", true);
        create.setOnClickListener(view -> createPlaylist());
        body.addView(create);
        for (Models.Playlist playlist : database.getPlaylists()) {
            LinearLayout card = ui.card();
            TextView title = ui.text(playlist.name, 19);
            title.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
            card.addView(title);
            card.addView(ui.secondary(playlist.trackIds.size() + " 首音频", 14));
            LinearLayout actions = ui.row();
            Button open = ui.button("打开", false);
            open.setOnClickListener(view -> startActivity(new Intent(this, PlaylistActivity.class)
                    .putExtra("playlist_id", playlist.id)));
            Button play = ui.button("播放", false);
            play.setEnabled(!playlist.trackIds.isEmpty());
            play.setOnClickListener(view -> PlaybackService.play(this, playlist.trackIds.get(0), playlist.trackIds));
            Button delete = ui.button("删除", false);
            delete.setTextColor(ui.destructive);
            delete.setOnClickListener(view -> confirm("删除播放列表？", "音频文件不会被删除。", "删除",
                    () -> { database.deletePlaylist(playlist.id); render(); }));
            actions.addView(open, UiKit.weight(1));
            actions.addView(play, UiKit.weight(1));
            actions.addView(delete, UiKit.weight(1));
            card.addView(ui.spacer(7));
            card.addView(actions);
            body.addView(card);
        }
    }

    private void createPlaylist() {
        android.widget.EditText name = ui.edit("例如：腿部训练歌单", "", false);
        new AlertDialog.Builder(this).setTitle("新建播放列表").setView(name)
                .setNegativeButton("取消", null)
                .setPositiveButton("创建", (dialog, which) -> {
                    try {
                        Models.Playlist playlist = new Models.Playlist();
                        playlist.name = name.getText().toString();
                        database.savePlaylist(playlist);
                        render();
                    } catch (Exception error) { showError("创建失败", error); }
                }).show();
    }

    private void addTrackToPlaylist(Models.Track track) {
        List<Models.Playlist> playlists = database.getPlaylists();
        if (playlists.isEmpty()) {
            Toast.makeText(this, "请先创建一个播放列表", Toast.LENGTH_LONG).show();
            musicPlaylists = true;
            render();
            return;
        }
        String[] names = new String[playlists.size()];
        for (int index = 0; index < playlists.size(); index++) names[index] = playlists.get(index).name;
        new AlertDialog.Builder(this).setTitle("加入播放列表").setItems(names, (dialog, which) -> {
            Models.Playlist playlist = playlists.get(which);
            if (!playlist.trackIds.contains(track.id)) playlist.trackIds.add(track.id);
            database.savePlaylist(playlist);
            Toast.makeText(this, "已加入“" + playlist.name + "”", Toast.LENGTH_SHORT).show();
        }).setNegativeButton("取消", null).show();
    }

    private void deleteTrack(Models.Track track) {
        confirm("删除本地音频？", "复制到 GymFlow 的音频文件也会被删除。", "删除", () -> {
            if (track.id.equals(PlaybackService.state().trackId)) PlaybackService.send(this, PlaybackService.ACTION_STOP);
            if (!AudioImportManager.deleteTrackFile(this, track)) {
                Toast.makeText(this, "音频文件未能删除", Toast.LENGTH_LONG).show();
                return;
            }
            database.deleteTrack(track.id);
            render();
        });
    }

    private void renderSettings() {
        body.addView(ui.section("训练默认值"));
        LinearLayout restCard = ui.card();
        final int rest = preferences.getInt("default_rest", 90);
        TextView restLabel = ui.text("默认休息：" + rest + " 秒", 17);
        LinearLayout restRow = ui.row();
        Button minus = ui.button("−15 秒", false);
        minus.setOnClickListener(view -> { preferences.edit().putInt("default_rest", Math.max(0, rest - 15)).apply(); render(); });
        Button plus = ui.button("＋15 秒", false);
        plus.setOnClickListener(view -> { preferences.edit().putInt("default_rest", Math.min(900, rest + 15)).apply(); render(); });
        restRow.addView(minus, UiKit.weight(1));
        restRow.addView(ui.horizontalSpacer(8));
        restRow.addView(plus, UiKit.weight(1));
        restCard.addView(restLabel);
        restCard.addView(ui.secondary("重量单位：千克（kg）", 14));
        restCard.addView(ui.spacer(8));
        restCard.addView(restRow);
        body.addView(restCard);

        body.addView(ui.section("反馈与播放"));
        body.addView(settingSwitch("休息结束提示音", "timer_sound", true));
        body.addView(settingSwitch("休息结束振动", "timer_haptic", true));
        body.addView(settingSwitch("开始训练时自动播放关联歌单", "autoplay_playlist", false));
        LinearLayout appearance = ui.card();
        appearance.addView(ui.text("外观", 17));
        appearance.addView(ui.secondary("跟随 Android 系统的浅色 / 深色模式", 14));
        body.addView(appearance);

        body.addView(ui.section("通知"));
        LinearLayout notification = ui.card();
        boolean granted = checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED;
        notification.addView(ui.text(granted ? "通知已允许" : "通知未开启", 17));
        notification.addView(ui.secondary("用于持续训练控制、休息完成提醒和音乐播放控制。", 14));
        Button notificationButton = ui.button(granted ? "打开系统通知设置" : "允许通知", false);
        notificationButton.setOnClickListener(view -> {
            if (granted) {
                Intent intent = new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, getPackageName());
                startActivity(intent);
            } else requestNotificationPermission();
        });
        notification.addView(ui.spacer(8));
        notification.addView(notificationButton);
        body.addView(notification);

        body.addView(ui.section("数据"));
        LinearLayout data = ui.card();
        Button reset = ui.button("恢复中文示例计划", false);
        reset.setOnClickListener(view -> confirm("恢复示例计划？", "当前计划和动作库会被替换；训练历史与音乐保留。", "恢复",
                () -> { database.resetSamplePlansAndExercises(); render(); }));
        Button deleteWorkout = ui.destructiveButton("删除所有训练数据");
        deleteWorkout.setOnClickListener(view -> confirm("永久删除训练数据？", "计划、动作、进行中的训练和历史记录都会删除，且无法撤销。", "永久删除",
                () -> { database.deleteAllWorkoutData(); RestTimerManager.get(this).cancel(); WorkoutNotificationManager.cancel(this); render(); }));
        Button deleteAudio = ui.destructiveButton("删除所有导入音频");
        deleteAudio.setOnClickListener(view -> confirm("永久删除所有音频？", "GymFlow 复制的音频文件和播放列表都会删除。", "永久删除",
                () -> { PlaybackService.send(this, PlaybackService.ACTION_STOP); AudioImportManager.deleteAllFiles(this); database.deleteAllAudioRecords(); render(); }));
        data.addView(reset);
        data.addView(ui.spacer(8));
        data.addView(deleteWorkout);
        data.addView(ui.spacer(8));
        data.addView(deleteAudio);
        body.addView(data);

        body.addView(ui.section("关于"));
        LinearLayout about = ui.card();
        about.addView(ui.text("GymFlow Android " + BuildConfig.VERSION_NAME, 17));
        about.addView(ui.secondary("所有训练数据与导入音乐仅保存在这台设备上。无账号、无广告、无分析、无云端。", 14));
        body.addView(about);
    }

    private LinearLayout settingSwitch(String label, String key, boolean defaultValue) {
        LinearLayout card = ui.card();
        LinearLayout row = ui.row();
        TextView title = ui.text(label, 16);
        Switch toggle = new Switch(this);
        toggle.setChecked(preferences.getBoolean(key, defaultValue));
        toggle.setOnCheckedChangeListener((button, checked) -> preferences.edit().putBoolean(key, checked).apply());
        row.addView(title, UiKit.weight(1));
        row.addView(toggle);
        card.addView(row);
        return card;
    }

    private void addMiniPlayer() {
        PlaybackService.State state = PlaybackService.state();
        if (state.trackId == null) return;
        LinearLayout mini = ui.row();
        mini.setPadding(ui.dp(14), ui.dp(8), ui.dp(8), ui.dp(8));
        mini.setBackgroundColor(ui.surface);
        TextView title = ui.text("♫  " + state.title, 14);
        title.setSingleLine(true);
        title.setOnClickListener(view -> startActivity(new Intent(this, NowPlayingActivity.class)));
        mini.addView(title, UiKit.weight(1));
        Button toggle = ui.button(state.playing ? "暂停" : "播放", false);
        toggle.setOnClickListener(view -> PlaybackService.send(this, PlaybackService.ACTION_TOGGLE));
        Button next = ui.button("下一首", false);
        next.setOnClickListener(view -> PlaybackService.send(this, PlaybackService.ACTION_NEXT));
        mini.addView(toggle);
        mini.addView(next);
        root.addView(mini, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ui.dp(60)));
    }

    private void addBottomNavigation() {
        LinearLayout navigation = ui.row();
        navigation.setPadding(ui.dp(4), ui.dp(4), ui.dp(4), ui.dp(5));
        navigation.setBackgroundColor(ui.surface);
        addTab(navigation, Tab.TODAY, "今天", "●");
        addTab(navigation, Tab.PLANS, "计划", "≡");
        addTab(navigation, Tab.HISTORY, "历史", "◷");
        addTab(navigation, Tab.MUSIC, "音乐", "♫");
        addTab(navigation, Tab.SETTINGS, "设置", "⚙");
        root.addView(navigation, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ui.dp(66)));
    }

    private void addTab(LinearLayout navigation, Tab tab, String label, String icon) {
        Button button = ui.button(icon + "\n" + label, false);
        button.setTextSize(12);
        button.setTextColor(tab == selectedTab ? ui.accent : ui.secondary);
        button.setBackgroundColor(android.graphics.Color.TRANSPARENT);
        button.setOnClickListener(view -> { selectedTab = tab; render(); });
        navigation.addView(button, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1));
    }

    private void openAudioPicker() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.setType("audio/*");
        intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        startActivityForResult(intent, IMPORT_AUDIO_REQUEST);
    }

    @Override protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != IMPORT_AUDIO_REQUEST || resultCode != RESULT_OK || data == null) return;
        ArrayList<Uri> uris = new ArrayList<>();
        if (data.getClipData() != null) {
            for (int index = 0; index < data.getClipData().getItemCount(); index++) {
                uris.add(data.getClipData().getItemAt(index).getUri());
            }
        } else if (data.getData() != null) uris.add(data.getData());
        int imported = 0;
        ArrayList<String> errors = new ArrayList<>();
        for (Uri uri : uris) {
            try { AudioImportManager.importUri(this, uri); imported++; }
            catch (Exception error) { errors.add(error.getMessage() == null ? "未知导入错误" : error.getMessage()); }
        }
        String message = "已导入 " + imported + " 首音频";
        if (!errors.isEmpty()) message += "；" + errors.size() + " 首失败：" + errors.get(0);
        Toast.makeText(this, message, Toast.LENGTH_LONG).show();
        selectedTab = Tab.MUSIC;
        musicPlaylists = false;
        render();
    }

    private void requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[] {Manifest.permission.POST_NOTIFICATIONS}, NOTIFICATION_REQUEST);
        }
    }

    @Override public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == NOTIFICATION_REQUEST && grantResults.length > 0
                && grantResults[0] == PackageManager.PERMISSION_GRANTED) WorkoutNotificationManager.show(this);
    }

    private String shortDate(Long time) {
        if (time == null) return "—";
        return new SimpleDateFormat("M月d日", Locale.CHINA).format(new Date(time));
    }

    private String humanDuration(long seconds) {
        long minutes = Math.max(0, seconds) / 60;
        if (minutes >= 60) return minutes / 60 + "小时" + minutes % 60 + "分";
        return Math.max(1, minutes) + "分钟";
    }

    private void confirm(String title, String message, String action, Runnable operation) {
        new AlertDialog.Builder(this).setTitle(title).setMessage(message).setNegativeButton("取消", null)
                .setPositiveButton(action, (dialog, which) -> operation.run()).show();
    }

    private void showError(String title, Throwable error) {
        new AlertDialog.Builder(this).setTitle(title)
                .setMessage(error.getMessage() == null ? "发生未知错误" : error.getMessage())
                .setPositiveButton("好", null).show();
    }
}
