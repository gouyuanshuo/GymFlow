package com.gouyuanshuo.gymflow;

import android.app.Activity;
import android.app.AlertDialog;
import android.os.Bundle;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.Toast;

public abstract class BaseActivity extends Activity {
    protected UiKit ui;
    protected LinearLayout root;
    protected LinearLayout content;

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        ui = new UiKit(this);
    }

    protected void buildPage(String title) {
        root = ui.column();
        root.setBackgroundColor(ui.background);
        UiKit.applySystemBarInsets(root);
        LinearLayout toolbar = ui.row();
        toolbar.setPadding(ui.dp(12), ui.dp(8), ui.dp(16), ui.dp(7));
        Button back = ui.button("‹", false);
        back.setTextSize(27);
        back.setContentDescription("返回");
        back.setOnClickListener(view -> finish());
        toolbar.addView(back, new LinearLayout.LayoutParams(ui.dp(52), ui.dp(48)));
        android.widget.TextView heading = ui.text(title, 21);
        heading.setTypeface(android.graphics.Typeface.DEFAULT, android.graphics.Typeface.BOLD);
        heading.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams titleParams = UiKit.weight(1);
        titleParams.setMargins(ui.dp(8), 0, 0, 0);
        toolbar.addView(heading, titleParams);
        root.addView(toolbar);

        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        content = ui.column();
        content.setPadding(ui.dp(16), ui.dp(8), ui.dp(16), ui.dp(32));
        scroll.addView(content, new ScrollView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        root.addView(scroll, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));
        setContentView(root);
    }

    protected void toast(String message) {
        Toast.makeText(this, message, Toast.LENGTH_LONG).show();
    }

    protected void showError(String title, Throwable error) {
        String message = error == null || error.getMessage() == null ? "发生未知错误" : error.getMessage();
        new AlertDialog.Builder(this).setTitle(title).setMessage(message).setPositiveButton("好", null).show();
    }

    protected void confirm(String title, String message, String action, Runnable operation) {
        new AlertDialog.Builder(this).setTitle(title).setMessage(message)
                .setNegativeButton("取消", null)
                .setPositiveButton(action, (dialog, which) -> operation.run()).show();
    }
}
