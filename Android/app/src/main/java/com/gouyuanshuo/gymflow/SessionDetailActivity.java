package com.gouyuanshuo.gymflow;

import android.os.Bundle;
import android.view.Gravity;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public final class SessionDetailActivity extends BaseActivity {
    private GymFlowDatabase database;
    private Models.Session session;

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        database = GymFlowDatabase.get(this);
        session = database.getSession(getIntent().getStringExtra("session_id"));
        if (session == null) { finish(); return; }
        renderDetails();
    }

    private void renderDetails() {
        buildPage(session.planName);
        LinearLayout overview = ui.card();
        overview.addView(ui.secondary(new SimpleDateFormat("yyyy年M月d日 EEEE HH:mm", Locale.CHINA)
                .format(new Date(session.startedAt)), 14));
        long end = session.completedAt == null ? session.startedAt : session.completedAt;
        WorkoutMath.Totals totals = WorkoutMath.totals(session);
        LinearLayout metrics = ui.row();
        metrics.addView(metric(humanDuration((end - session.startedAt) / 1000), "时长"), UiKit.weight(1));
        metrics.addView(metric(totals.exercises + "", "动作"), UiKit.weight(1));
        metrics.addView(metric(totals.sets + "", "组数"), UiKit.weight(1));
        overview.addView(ui.spacer(12));
        overview.addView(metrics);
        LinearLayout metrics2 = ui.row();
        metrics2.addView(metric(totals.repetitions + "", "总次数"), UiKit.weight(1));
        metrics2.addView(metric(WorkoutMath.formatWeight(totals.volume) + " kg", "训练容量"), UiKit.weight(2));
        overview.addView(ui.spacer(10));
        overview.addView(metrics2);
        if (!session.notes.isEmpty()) {
            overview.addView(ui.spacer(10));
            overview.addView(ui.secondary("备注：" + session.notes, 14));
        }
        content.addView(overview);

        content.addView(ui.section("训练内容"));
        for (Models.ExerciseRecord record : session.records) {
            LinearLayout card = ui.card();
            TextView name = ui.text(record.name, 18);
            name.setTypeface(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD);
            card.addView(name);
            boolean has = false;
            for (Models.WorkoutSet set : record.sets) {
                if (!set.completed) continue;
                has = true;
                card.addView(ui.text("第 " + set.setNumber + " 组  ·  " + WorkoutMath.formatWeight(set.weight) +
                        " kg × " + set.repetitions + (set.warmup ? "  ·  热身" : ""), 15));
            }
            if (!has) card.addView(ui.secondary("没有完成的组", 14));
            if (!record.notes.isEmpty()) card.addView(ui.secondary("备注：" + record.notes, 13));
            content.addView(card);
        }
        String best = WorkoutAnalytics.newestPersonalBest(session, database.getCompletedSessions(null));
        if (best != null) {
            LinearLayout pb = ui.card();
            TextView title = ui.text("🏆 本次个人最佳", 18);
            title.setTypeface(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD);
            title.setTextColor(ui.accent);
            pb.addView(title);
            pb.addView(ui.text(best, 15));
            content.addView(pb);
        }
        Button share = ui.button("分享训练海报", true);
        share.setOnClickListener(view -> WorkoutShare.show(this, session));
        Button delete = ui.button("删除这条训练记录", false);
        delete.setTextColor(ui.destructive);
        delete.setOnClickListener(view -> confirm("删除训练记录？", "此操作无法撤销。", "删除", () -> {
            database.deleteSession(session.id);
            finish();
        }));
        content.addView(ui.spacer(10));
        content.addView(share);
        content.addView(ui.spacer(8));
        content.addView(delete);
    }

    private LinearLayout metric(String value, String label) {
        LinearLayout column = ui.column();
        TextView main = ui.text(value, 18);
        main.setTypeface(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD);
        main.setGravity(Gravity.CENTER);
        TextView caption = ui.secondary(label, 12);
        caption.setGravity(Gravity.CENTER);
        column.addView(main);
        column.addView(caption);
        return column;
    }

    private String humanDuration(long seconds) {
        long minutes = Math.max(0, seconds) / 60;
        if (minutes >= 60) return minutes / 60 + "小时" + minutes % 60 + "分";
        return Math.max(1, minutes) + "分钟";
    }
}
