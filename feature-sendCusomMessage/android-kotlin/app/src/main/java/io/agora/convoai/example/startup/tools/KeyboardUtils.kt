package io.agora.convoai.example.startup.tools

import android.animation.ValueAnimator
import android.content.res.Resources
import android.util.TypedValue
import android.view.ViewTreeObserver

val Number.dp
    get() = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        this.toFloat(),
        Resources.getSystem().displayMetrics
    )

/**
 * Keyboard visibility listener with smooth animation support
 */
class KeyboardVisibilityHelper {
    private var keyboardListener: ViewTreeObserver.OnGlobalLayoutListener? = null
    private var keyboardAnimator: ValueAnimator? = null
    private var lastKeyboardVisible = false
}