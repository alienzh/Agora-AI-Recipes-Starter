package io.agora.convoai.example.voiceassistant.ui.common;

import android.animation.ValueAnimator;
import android.content.Context;
import android.content.res.Resources;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.util.AttributeSet;
import android.util.TypedValue;
import android.view.View;
import android.view.animation.LinearInterpolator;
import androidx.core.content.ContextCompat;
import io.agora.convoai.example.voiceassistant.java.R;
import java.util.Random;

/**
 * Agent Speaking Indicator
 * Four bars, wave-like random animation
 */
public class VoiceWaveView extends View {

    private static final int BAR_COUNT = 4;
    private static final float BAR_WIDTH = dpToPx(5);
    private static final float BAR_SPACING = dpToPx(6);
    private static final float BAR_CORNER_RADIUS = dpToPx(3);
    private static final float BAR_HEIGHT_MIN = dpToPx(5);
    private static final float BAR_HEIGHT_MAX = dpToPx(12);
    private static final long ANIMATION_DURATION = 1400L; // ms, one wave cycle, slower for smoothness
    private static final float PHASE_DRIFT_PER_FRAME = 0.018f; // phase drift per frame for flowing effect
    private static final float JITTER_AMPLITUDE = dpToPx(0.5f); // smaller jitter for less abruptness

    private final Paint paint;
    private final float[] barHeights = new float[BAR_COUNT];
    private ValueAnimator animator;
    private float animationProgress = 0f;
    private final float[] phaseOffsets = new float[BAR_COUNT];
    private final Random random = new Random();

    private static float dpToPx(float dp) {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp,
            Resources.getSystem().getDisplayMetrics()
        );
    }

    public VoiceWaveView(Context context) {
        this(context, null);
    }

    public VoiceWaveView(Context context, AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public VoiceWaveView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        
        paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        paint.setColor(ContextCompat.getColor(context, R.color.white));
        paint.setStyle(Paint.Style.FILL);
        
        // Initialize bar heights to minimum
        for (int i = 0; i < BAR_COUNT; i++) {
            barHeights[i] = BAR_HEIGHT_MIN;
            phaseOffsets[i] = random.nextFloat() * 2f * (float) Math.PI;
        }
    }

    /**
     * Start wave animation
     */
    public void startAnimation() {
        if (animator != null && animator.isRunning()) {
            return;
        }
        
        animator = ValueAnimator.ofFloat(0f, 1f);
        animator.setDuration(ANIMATION_DURATION);
        animator.setRepeatCount(ValueAnimator.INFINITE);
        animator.setRepeatMode(ValueAnimator.RESTART);
        animator.setInterpolator(new LinearInterpolator());
        animator.addUpdateListener(animation -> {
            animationProgress = (Float) animation.getAnimatedValue();
            updateBarHeights();
            invalidate();
        });
        animator.start();
    }

    /**
     * Stop animation and reset bars to min height
     */
    public void stopAnimation() {
        if (animator != null) {
            animator.cancel();
            animator = null;
        }
        for (int i = 0; i < BAR_COUNT; i++) {
            barHeights[i] = BAR_HEIGHT_MIN;
        }
        invalidate();
    }

    private void updateBarHeights() {
        for (int i = 0; i < BAR_COUNT; i++) {
            phaseOffsets[i] = (phaseOffsets[i] + PHASE_DRIFT_PER_FRAME) % (2f * (float) Math.PI);
            double wave = Math.sin(2 * Math.PI * (animationProgress + phaseOffsets[i]));
            float base = BAR_HEIGHT_MIN + (BAR_HEIGHT_MAX - BAR_HEIGHT_MIN) * ((float) wave + 1f) / 2f;
            float jitter = random.nextFloat() * 2f - 1f; // [-1, 1]
            barHeights[i] = Math.max(BAR_HEIGHT_MIN, Math.min(BAR_HEIGHT_MAX, base + jitter * JITTER_AMPLITUDE));
        }
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        float centerX = getWidth() / 2f;
        float centerY = getHeight() / 2f;
        float totalWidth = BAR_COUNT * BAR_WIDTH + (BAR_COUNT - 1) * BAR_SPACING;
        float startX = centerX - totalWidth / 2f;
        
        for (int i = 0; i < BAR_COUNT; i++) {
            float barX = startX + i * (BAR_WIDTH + BAR_SPACING);
            float barTop = centerY - barHeights[i] / 2f;
            float barBottom = centerY + barHeights[i] / 2f;
            RectF rect = new RectF(barX, barTop, barX + BAR_WIDTH, barBottom);
            canvas.drawRoundRect(rect, BAR_CORNER_RADIUS, BAR_CORNER_RADIUS, paint);
        }
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        float totalWidth = BAR_COUNT * BAR_WIDTH + (BAR_COUNT - 1) * BAR_SPACING;
        int desiredWidth = (int) totalWidth;
        int desiredHeight = (int) BAR_HEIGHT_MAX;
        int width = resolveSize(desiredWidth, widthMeasureSpec);
        int height = resolveSize(desiredHeight, heightMeasureSpec);
        setMeasuredDimension(width, height);
    }

    @Override
    protected void onDetachedFromWindow() {
        super.onDetachedFromWindow();
        if (animator != null) {
            animator.cancel();
            animator = null;
        }
    }
}

