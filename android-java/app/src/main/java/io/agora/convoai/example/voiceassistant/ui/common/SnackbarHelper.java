package io.agora.convoai.example.voiceassistant.ui.common;

import android.view.View;
import android.view.ViewGroup;
import androidx.core.content.ContextCompat;
import androidx.fragment.app.Fragment;
import com.google.android.material.snackbar.Snackbar;
import io.agora.convoai.example.voiceassistant.java.R;

/**
 * SnackbarHelper utility class for showing Snackbars with custom styling
 */
public class SnackbarHelper {
    /**
     * Show a Snackbar with normal background color
     * @param fragment The fragment to show the Snackbar in
     * @param message The message to display
     * @param duration The duration of the Snackbar (default: Snackbar.LENGTH_SHORT)
     */
    public static void showNormal(Fragment fragment, String message, int duration) {
        View rootView = fragment.getActivity() != null 
            ? fragment.getActivity().findViewById(android.R.id.content)
            : fragment.getView();
        
        if (rootView != null) {
            Snackbar snackbar = Snackbar.make(rootView, message, duration);
            snackbar.getView().setBackgroundTintList(
                android.content.res.ColorStateList.valueOf(
                    ContextCompat.getColor(fragment.requireContext(), R.color.snackbar_background)
                )
            );
            snackbar.setTextColor(ContextCompat.getColor(fragment.requireContext(), R.color.snackbar_text));
            // Remove margins to make it stick to screen edges
            snackbar.getView().post(() -> {
                ViewGroup.LayoutParams layoutParams = snackbar.getView().getLayoutParams();
                if (layoutParams instanceof ViewGroup.MarginLayoutParams) {
                    ViewGroup.MarginLayoutParams marginParams = (ViewGroup.MarginLayoutParams) layoutParams;
                    marginParams.leftMargin = 0;
                    marginParams.rightMargin = 0;
                    marginParams.bottomMargin = 0;
                    snackbar.getView().setLayoutParams(marginParams);
                }
            });
            snackbar.show();
        }
    }

    /**
     * Show a Snackbar with normal background color (default duration: LENGTH_SHORT)
     * @param fragment The fragment to show the Snackbar in
     * @param message The message to display
     */
    public static void showNormal(Fragment fragment, String message) {
        showNormal(fragment, message, Snackbar.LENGTH_SHORT);
    }

    /**
     * Show a Snackbar with error background color
     * @param fragment The fragment to show the Snackbar in
     * @param message The message to display
     * @param duration The duration of the Snackbar (default: Snackbar.LENGTH_LONG)
     */
    public static void showError(Fragment fragment, String message, int duration) {
        View rootView = fragment.getActivity() != null 
            ? fragment.getActivity().findViewById(android.R.id.content)
            : fragment.getView();
        
        if (rootView != null) {
            Snackbar snackbar = Snackbar.make(rootView, message, duration);
            snackbar.getView().setBackgroundTintList(
                android.content.res.ColorStateList.valueOf(
                    ContextCompat.getColor(fragment.requireContext(), R.color.snackbar_background_error)
                )
            );
            snackbar.setTextColor(ContextCompat.getColor(fragment.requireContext(), R.color.snackbar_text));
            // Remove margins to make it stick to screen edges
            snackbar.getView().post(() -> {
                ViewGroup.LayoutParams layoutParams = snackbar.getView().getLayoutParams();
                if (layoutParams instanceof ViewGroup.MarginLayoutParams) {
                    ViewGroup.MarginLayoutParams marginParams = (ViewGroup.MarginLayoutParams) layoutParams;
                    marginParams.leftMargin = 0;
                    marginParams.rightMargin = 0;
                    marginParams.bottomMargin = 0;
                    snackbar.getView().setLayoutParams(marginParams);
                }
            });
            snackbar.show();
        }
    }

    /**
     * Show a Snackbar with error background color (default duration: LENGTH_LONG)
     * @param fragment The fragment to show the Snackbar in
     * @param message The message to display
     */
    public static void showError(Fragment fragment, String message) {
        showError(fragment, message, Snackbar.LENGTH_LONG);
    }
}

