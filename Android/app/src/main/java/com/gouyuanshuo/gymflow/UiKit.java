package com.gouyuanshuo.gymflow;

import android.content.Context;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowInsets;
import android.os.Build;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.Space;
import android.widget.TextView;

public final class UiKit {
    public final Context context;
    public final boolean dark;
    public final int background;
    public final int surface;
    public final int elevated;
    public final int text;
    public final int secondary;
    public final int accent;
    public final int destructive = Color.rgb(210, 52, 57);

    public UiKit(Context context) {
        this.context = context;
        dark = (context.getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK)
                == Configuration.UI_MODE_NIGHT_YES;
        background = dark ? Color.rgb(11, 13, 16) : Color.rgb(245, 247, 246);
        surface = dark ? Color.rgb(25, 28, 32) : Color.WHITE;
        elevated = dark ? Color.rgb(35, 39, 44) : Color.rgb(232, 236, 233);
        text = dark ? Color.rgb(245, 247, 246) : Color.rgb(23, 27, 25);
        secondary = dark ? Color.rgb(173, 180, 176) : Color.rgb(92, 101, 96);
        accent = dark ? Color.rgb(93, 236, 124) : Color.rgb(25, 148, 66);
    }

    public int dp(float value) { return Math.round(value * context.getResources().getDisplayMetrics().density); }

    public TextView text(String value, float size) {
        TextView view = new TextView(context);
        view.setText(value);
        view.setTextSize(size);
        view.setTextColor(text);
        view.setLineSpacing(0, 1.12f);
        return view;
    }

    public TextView secondary(String value, float size) {
        TextView view = text(value, size);
        view.setTextColor(secondary);
        return view;
    }

    public TextView title(String value) {
        TextView view = text(value, 28);
        view.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        view.setPadding(0, dp(6), 0, dp(8));
        return view;
    }

    public TextView section(String value) {
        TextView view = text(value, 18);
        view.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        view.setPadding(dp(2), dp(18), dp(2), dp(9));
        return view;
    }

    public LinearLayout column() {
        LinearLayout layout = new LinearLayout(context);
        layout.setOrientation(LinearLayout.VERTICAL);
        return layout;
    }

    public LinearLayout row() {
        LinearLayout layout = new LinearLayout(context);
        layout.setOrientation(LinearLayout.HORIZONTAL);
        layout.setGravity(Gravity.CENTER_VERTICAL);
        return layout;
    }

    public LinearLayout card() {
        LinearLayout card = column();
        card.setPadding(dp(16), dp(15), dp(16), dp(15));
        card.setBackground(roundRect(surface, 18, 0));
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.setMargins(0, dp(6), 0, dp(6));
        card.setLayoutParams(params);
        card.setElevation(dp(1));
        return card;
    }

    public Button button(String label, boolean primary) {
        Button button = new Button(context);
        button.setText(label);
        button.setTextSize(15);
        button.setTextColor(primary ? Color.WHITE : accent);
        button.setAllCaps(false);
        button.setMinHeight(dp(46));
        button.setGravity(Gravity.CENTER);
        button.setPadding(dp(14), 0, dp(14), 0);
        button.setBackground(roundRect(primary ? accent : elevated, 13, 0));
        return button;
    }

    public Button destructiveButton(String label) {
        Button button = button(label, false);
        button.setTextColor(Color.WHITE);
        button.setBackground(roundRect(destructive, 13, 0));
        return button;
    }

    public EditText edit(String hint, String value, boolean multiline) {
        EditText edit = new EditText(context);
        edit.setHint(hint);
        edit.setText(value == null ? "" : value);
        edit.setTextSize(16);
        edit.setTextColor(text);
        edit.setHintTextColor(secondary);
        edit.setPadding(dp(12), dp(10), dp(12), dp(10));
        edit.setBackground(roundRect(elevated, 12, 0));
        edit.setSingleLine(!multiline);
        if (multiline) {
            edit.setMinLines(3);
            edit.setGravity(Gravity.TOP);
            edit.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE);
        }
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.setMargins(0, dp(5), 0, dp(7));
        edit.setLayoutParams(params);
        return edit;
    }

    public EditText numberEdit(String hint, String value, boolean decimal) {
        EditText edit = edit(hint, value, false);
        edit.setInputType(InputType.TYPE_CLASS_NUMBER |
                (decimal ? InputType.TYPE_NUMBER_FLAG_DECIMAL : 0));
        return edit;
    }

    public Space spacer(int dp) {
        Space value = new Space(context);
        value.setLayoutParams(new LinearLayout.LayoutParams(1, this.dp(dp)));
        return value;
    }

    public Space horizontalSpacer(int dp) {
        Space value = new Space(context);
        value.setLayoutParams(new LinearLayout.LayoutParams(this.dp(dp), 1));
        return value;
    }

    public static void applySystemBarInsets(View view) {
        view.setOnApplyWindowInsetsListener((target, insets) -> {
            int left;
            int top;
            int right;
            int bottom;
            if (Build.VERSION.SDK_INT >= 30) {
                android.graphics.Insets bars = insets.getInsets(WindowInsets.Type.systemBars());
                left = bars.left;
                top = bars.top;
                right = bars.right;
                bottom = bars.bottom;
            } else {
                left = insets.getSystemWindowInsetLeft();
                top = insets.getSystemWindowInsetTop();
                right = insets.getSystemWindowInsetRight();
                bottom = insets.getSystemWindowInsetBottom();
            }
            target.setPadding(left, top, right, bottom);
            return insets;
        });
        view.requestApplyInsets();
    }

    public GradientDrawable roundRect(int color, int radiusDp, int strokeColor) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color);
        drawable.setCornerRadius(dp(radiusDp));
        if (strokeColor != 0) drawable.setStroke(dp(1), strokeColor);
        return drawable;
    }

    public static LinearLayout.LayoutParams weight(float value) {
        return new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, value);
    }
}
