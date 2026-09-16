package com.gouyuanshuo.gymflow;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Shader;
import android.net.Uri;

import java.io.File;
import java.io.FileOutputStream;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public final class WorkoutPosterRenderer {
    public static final int WIDTH = 1179;
    public static final int HEIGHT = 2556;
    public static final String[] BACKGROUND_NAMES = {
            "极光绿", "深海蓝", "日落橙", "霓虹紫", "曜石", "樱花", "电光蓝", "森林", "烈焰", "晨曦"
    };
    private static final int[][] COLORS = {
            {0xFF081B12, 0xFF24B85A}, {0xFF07162F, 0xFF177DDC}, {0xFF36120B, 0xFFFF7043},
            {0xFF17082C, 0xFF8E44EC}, {0xFF050607, 0xFF30343A}, {0xFF33142A, 0xFFE0569B},
            {0xFF051F31, 0xFF00A9D6}, {0xFF071B13, 0xFF287A4A}, {0xFF2D0707, 0xFFE43737},
            {0xFF2B1A0D, 0xFFFFB547}
    };

    private WorkoutPosterRenderer() {}

    public static Bitmap render(Models.Session session, int backgroundIndex,
                                List<Models.Session> history) {
        int index = Math.floorMod(backgroundIndex, COLORS.length);
        Bitmap bitmap = Bitmap.createBitmap(WIDTH, HEIGHT, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        paint.setShader(new LinearGradient(0, 0, WIDTH, HEIGHT, COLORS[index][0], COLORS[index][1], Shader.TileMode.CLAMP));
        canvas.drawRect(0, 0, WIDTH, HEIGHT, paint);
        paint.setShader(null);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3);
        paint.setColor(0x33FFFFFF);
        for (int ring = 0; ring < 7; ring++) canvas.drawCircle(WIDTH + 60, 280, 160 + ring * 95, paint);
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(0x18FFFFFF);
        Path slash = new Path();
        slash.moveTo(-100, HEIGHT * 0.62f);
        slash.lineTo(WIDTH, HEIGHT * 0.43f);
        slash.lineTo(WIDTH, HEIGHT * 0.55f);
        slash.lineTo(-100, HEIGHT * 0.74f);
        slash.close();
        canvas.drawPath(slash, paint);

        Paint text = new Paint(Paint.ANTI_ALIAS_FLAG);
        text.setColor(Color.WHITE);
        text.setTypeface(android.graphics.Typeface.create("sans", android.graphics.Typeface.BOLD));
        text.setTextSize(66);
        canvas.drawText("GYMFLOW", 96, 150, text);
        text.setTypeface(android.graphics.Typeface.create("sans", android.graphics.Typeface.NORMAL));
        text.setTextSize(34);
        text.setColor(0xCCFFFFFF);
        canvas.drawText("每一次完成，都算数。", 96, 208, text);

        text.setTypeface(android.graphics.Typeface.create("sans", android.graphics.Typeface.BOLD));
        text.setColor(Color.WHITE);
        text.setTextSize(96);
        drawWrapped(canvas, session.planName, 96, 430, WIDTH - 192, 112, text, 2);
        text.setTextSize(36);
        text.setColor(0xCCFFFFFF);
        String date = new SimpleDateFormat("yyyy年M月d日  EEEE", Locale.CHINA).format(new Date(session.startedAt));
        canvas.drawText(date, 96, 650, text);

        WorkoutMath.Totals totals = WorkoutMath.totals(session);
        long end = session.completedAt == null ? System.currentTimeMillis() : session.completedAt;
        long seconds = Math.max(0, (end - session.startedAt) / 1000);
        drawMetric(canvas, "训练时长", humanDuration(seconds), 96, 820, text);
        drawMetric(canvas, "完成组数", totals.sets + " 组", 620, 820, text);
        drawMetric(canvas, "总次数", totals.repetitions + " 次", 96, 1080, text);
        drawMetric(canvas, "训练容量", WorkoutMath.formatWeight(totals.volume) + " kg", 620, 1080, text);

        text.setTextSize(38);
        text.setColor(0xBBFFFFFF);
        text.setTypeface(android.graphics.Typeface.create("sans", android.graphics.Typeface.BOLD));
        canvas.drawText("本次亮点", 96, 1370, text);
        List<WorkoutAnalytics.Highlight> highlights = WorkoutAnalytics.highlights(session);
        int y = 1470;
        for (WorkoutAnalytics.Highlight highlight : highlights) {
            paint.setColor(0x22FFFFFF);
            canvas.drawRoundRect(80, y - 70, WIDTH - 80, y + 110, 32, 32, paint);
            text.setColor(Color.WHITE);
            text.setTextSize(43);
            text.setTypeface(android.graphics.Typeface.create("sans", android.graphics.Typeface.BOLD));
            canvas.drawText(ellipsize(highlight.name, 16), 112, y, text);
            text.setTextSize(31);
            text.setColor(0xCCFFFFFF);
            text.setTypeface(android.graphics.Typeface.create("sans", android.graphics.Typeface.NORMAL));
            canvas.drawText(highlight.sets + " 组 · " + highlight.repetitions + " 次 · " +
                    WorkoutMath.formatWeight(highlight.volume) + " kg", 112, y + 60, text);
            y += 220;
        }
        String personalBest = WorkoutAnalytics.newestPersonalBest(session, history);
        if (personalBest != null && y < 2220) {
            paint.setColor(0x33FFD75A);
            canvas.drawRoundRect(80, y - 55, WIDTH - 80, y + 115, 32, 32, paint);
            text.setColor(0xFFFFE78C);
            text.setTypeface(android.graphics.Typeface.create("sans", android.graphics.Typeface.BOLD));
            text.setTextSize(34);
            canvas.drawText("🏆 个人最佳", 112, y, text);
            text.setColor(Color.WHITE);
            text.setTextSize(30);
            canvas.drawText(ellipsize(personalBest, 28), 112, y + 65, text);
        }

        text.setTextSize(30);
        text.setColor(0xAAFFFFFF);
        text.setTypeface(android.graphics.Typeface.create("sans", android.graphics.Typeface.NORMAL));
        canvas.drawText("仅保存在此设备 · 私密离线训练记录", 96, HEIGHT - 105, text);
        return bitmap;
    }

    public static Uri saveForSharing(Context context, Bitmap bitmap, String sessionId) throws Exception {
        File directory = new File(context.getCacheDir(), "share");
        if (!directory.exists() && !directory.mkdirs()) throw new IllegalStateException("无法创建分享缓存");
        String safeId = sessionId == null ? "workout" : sessionId.replaceAll("[^a-zA-Z0-9-]", "");
        File file = new File(directory, "gymflow_" + safeId + ".png");
        try (FileOutputStream output = new FileOutputStream(file)) {
            if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)) {
                throw new IllegalStateException("训练海报生成失败");
            }
        }
        return Uri.parse("content://com.gouyuanshuo.gymflow.share/" + file.getName());
    }

    private static void drawMetric(Canvas canvas, String label, String value, float x, float y, Paint text) {
        Paint block = new Paint(Paint.ANTI_ALIAS_FLAG);
        block.setColor(0x22FFFFFF);
        canvas.drawRoundRect(x - 16, y - 85, x + 455, y + 115, 30, 30, block);
        text.setTypeface(android.graphics.Typeface.create("sans", android.graphics.Typeface.NORMAL));
        text.setTextSize(30);
        text.setColor(0xBBFFFFFF);
        canvas.drawText(label, x + 18, y - 24, text);
        text.setTypeface(android.graphics.Typeface.create("sans", android.graphics.Typeface.BOLD));
        text.setTextSize(50);
        text.setColor(Color.WHITE);
        canvas.drawText(value, x + 18, y + 55, text);
    }

    private static String humanDuration(long seconds) {
        long hours = seconds / 3600;
        long minutes = (seconds % 3600) / 60;
        if (hours > 0) return hours + "小时" + minutes + "分";
        return Math.max(1, minutes) + "分钟";
    }

    private static void drawWrapped(Canvas canvas, String value, float x, float y, float width,
                                    float lineHeight, Paint paint, int maximumLines) {
        String remaining = value == null ? "训练完成" : value;
        for (int line = 0; line < maximumLines && !remaining.isEmpty(); line++) {
            int count = paint.breakText(remaining, true, width, null);
            String segment = remaining.substring(0, count);
            canvas.drawText(segment, x, y + line * lineHeight, paint);
            remaining = remaining.substring(count).trim();
        }
    }

    private static String ellipsize(String value, int limit) {
        if (value == null) return "";
        return value.length() <= limit ? value : value.substring(0, Math.max(1, limit - 1)) + "…";
    }
}
