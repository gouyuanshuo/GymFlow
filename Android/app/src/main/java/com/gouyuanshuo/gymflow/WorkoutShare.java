package com.gouyuanshuo.gymflow;

import android.app.Activity;
import android.app.Dialog;
import android.content.ClipData;
import android.content.Intent;
import android.graphics.Bitmap;
import android.net.Uri;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.Spinner;
import android.widget.Toast;

import java.util.List;
import java.util.Random;

public final class WorkoutShare {
    private WorkoutShare() {}

    public static void show(Activity activity, Models.Session session) {
        UiKit ui = new UiKit(activity);
        GymFlowDatabase database = GymFlowDatabase.get(activity);
        List<Models.Session> history = database.getCompletedSessions(null);
        Dialog dialog = new Dialog(activity);
        dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        LinearLayout root = ui.column();
        UiKit.applySystemBarInsets(root);
        root.setPadding(ui.dp(16), ui.dp(16), ui.dp(16), ui.dp(16));
        root.setBackgroundColor(ui.background);
        root.addView(ui.title("分享训练"));
        root.addView(ui.secondary("海报只包含训练摘要，不包含备注、音乐、文件路径或设备信息。", 13));
        Spinner backgrounds = new Spinner(activity);
        backgrounds.setAdapter(new ArrayAdapter<>(activity, android.R.layout.simple_spinner_dropdown_item,
                WorkoutPosterRenderer.BACKGROUND_NAMES));
        int initial = new Random().nextInt(WorkoutPosterRenderer.BACKGROUND_NAMES.length);
        backgrounds.setSelection(initial);
        root.addView(backgrounds);
        ImageView preview = new ImageView(activity);
        preview.setAdjustViewBounds(true);
        preview.setScaleType(ImageView.ScaleType.FIT_CENTER);
        LinearLayout.LayoutParams previewParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1);
        previewParams.setMargins(0, ui.dp(8), 0, ui.dp(8));
        root.addView(preview, previewParams);
        Bitmap[] bitmap = new Bitmap[] {WorkoutPosterRenderer.render(session, initial, history)};
        preview.setImageBitmap(bitmap[0]);
        backgrounds.setOnItemSelectedListener(new android.widget.AdapterView.OnItemSelectedListener() {
            private int current = initial;
            @Override public void onItemSelected(android.widget.AdapterView<?> parent, android.view.View view,
                                                  int position, long id) {
                if (position == current) return;
                Bitmap next = WorkoutPosterRenderer.render(session, position, history);
                preview.setImageBitmap(next);
                if (bitmap[0] != null && !bitmap[0].isRecycled()) bitmap[0].recycle();
                bitmap[0] = next;
                current = position;
            }
            @Override public void onNothingSelected(android.widget.AdapterView<?> parent) {}
        });
        LinearLayout buttons = ui.row();
        Button close = ui.button("关闭", false);
        close.setOnClickListener(view -> dialog.dismiss());
        Button random = ui.button("换一个", false);
        random.setOnClickListener(view -> {
            int next = (backgrounds.getSelectedItemPosition() + 1 + new Random().nextInt(
                    WorkoutPosterRenderer.BACKGROUND_NAMES.length - 1)) % WorkoutPosterRenderer.BACKGROUND_NAMES.length;
            backgrounds.setSelection(next);
        });
        Button share = ui.button("分享海报", true);
        share.setOnClickListener(view -> {
            try {
                Uri uri = WorkoutPosterRenderer.saveForSharing(activity, bitmap[0], session.id);
                Intent send = new Intent(Intent.ACTION_SEND);
                send.setType("image/png");
                send.putExtra(Intent.EXTRA_STREAM, uri);
                send.setClipData(ClipData.newRawUri("GymFlow 训练海报", uri));
                send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                activity.startActivity(Intent.createChooser(send, "分享训练海报"));
            } catch (Exception error) {
                Toast.makeText(activity, "海报生成失败：" + error.getMessage(), Toast.LENGTH_LONG).show();
            }
        });
        buttons.addView(close, UiKit.weight(1));
        buttons.addView(random, UiKit.weight(1));
        buttons.addView(share, UiKit.weight(1));
        root.addView(buttons);
        dialog.setContentView(root);
        Window window = dialog.getWindow();
        if (window != null) window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
        dialog.setOnDismissListener(value -> {
            if (bitmap[0] != null && !bitmap[0].isRecycled()) bitmap[0].recycle();
        });
        dialog.show();
        if (window != null) window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT);
    }
}
