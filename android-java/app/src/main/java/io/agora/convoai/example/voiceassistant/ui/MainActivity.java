package io.agora.convoai.example.voiceassistant.ui;

import androidx.fragment.app.FragmentManager;
import androidx.navigation.NavController;
import androidx.navigation.fragment.NavHostFragment;
import io.agora.convoai.example.voiceassistant.java.R;
import io.agora.convoai.example.voiceassistant.java.databinding.ActivityMainBinding;
import io.agora.convoai.example.voiceassistant.tools.PermissionHelp;
import io.agora.convoai.example.voiceassistant.ui.common.BaseActivity;

/**
 * MainActivity - Main entry point of the application
 * Acts as a container for fragments with Navigation Component
 */
public class MainActivity extends BaseActivity<ActivityMainBinding> {

    private PermissionHelp mPermissionHelp;

    @Override
    protected ActivityMainBinding getViewBinding() {
        return ActivityMainBinding.inflate(getLayoutInflater());
    }

    @Override
    protected void initView() {
        // MainActivity is now just a container for fragments
        // Navigation is handled by NavHostFragment automatically
        mPermissionHelp = new PermissionHelp(this);
    }

    @Override
    public void onHandleOnBackPressed() {
        // Navigation Component handles back press automatically
        // If Navigation can't handle it (at start destination), finish the activity
        NavHostFragment navHostFragment = (NavHostFragment) getSupportFragmentManager()
            .findFragmentById(R.id.navHostFragment);
        
        if (navHostFragment != null) {
            NavController navController = navHostFragment.getNavController();
            if (navController != null && !navController.navigateUp()) {
                // If Navigation can't navigate up (at start destination), finish the activity
                super.onHandleOnBackPressed();
            }
        } else {
            super.onHandleOnBackPressed();
        }
    }

    /**
     * Check microphone permission and handle the result
     * @param callback Callback to receive the permission result (true if granted, false otherwise)
     */
    public void checkMicrophonePermission(PermissionCallback callback) {
        if (mPermissionHelp.hasMicPerm()) {
            callback.onResult(true);
        } else {
            mPermissionHelp.checkMicPerm(
                () -> callback.onResult(true),
                () -> {
                    showPermissionDialog(
                        "Permission Required",
                        "Microphone permission is required for voice chat. Please grant the permission to continue.",
                        result -> {
                            if (result) {
                                mPermissionHelp.launchAppSettingForMic(
                                    () -> callback.onResult(true),
                                    () -> callback.onResult(false)
                                );
                            } else {
                                callback.onResult(false);
                            }
                        }
                    );
                }
            );
        }
    }

    /**
     * Show permission dialog
     * @param title Dialog title
     * @param content Dialog content
     * @param onResult Callback for dialog result
     */
    private void showPermissionDialog(String title, String content, PermissionCallback onResult) {
        if (isFinishing() || isDestroyed()) {
            return;
        }

        FragmentManager fragmentManager = getSupportFragmentManager();
        if (fragmentManager.isStateSaved()) {
            return;
        }

        new CommonDialog.Builder()
            .setTitle(title)
            .setContent(content)
            .setPositiveButton("Retry", () -> onResult.onResult(true))
            .setNegativeButton("Exit", () -> onResult.onResult(false))
            .setCancelable(false)
            .build()
            .show(fragmentManager, "permission_dialog");
    }

    /**
     * Callback interface for permission check results
     */
    public interface PermissionCallback {
        void onResult(boolean granted);
    }
}

