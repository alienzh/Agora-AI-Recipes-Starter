package io.agora.convoai.example.voiceassistant.ui;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import androidx.annotation.NonNull;
import androidx.lifecycle.ViewModelProvider;
import androidx.navigation.fragment.NavHostFragment;
import io.agora.convoai.example.voiceassistant.KeyCenter;
import io.agora.convoai.example.voiceassistant.java.R;
import io.agora.convoai.example.voiceassistant.java.databinding.FragmentAgentConfigBinding;
import io.agora.convoai.example.voiceassistant.ui.common.BaseFragment;
import io.agora.convoai.example.voiceassistant.ui.common.SnackbarHelper;

import java.util.ArrayList;
import java.util.List;

/**
 * AgentConfigFragment - Configuration screen for starting a conversation
 */
public class AgentConfigFragment extends BaseFragment<FragmentAgentConfigBinding> {

    private ConversationViewModel viewModel;
    private boolean hasNavigated = false;
    private final List<String> statusHistory = new ArrayList<>();
    private String lastStatusMessage = "";

    @Override
    protected FragmentAgentConfigBinding getViewBinding(LayoutInflater inflater, ViewGroup container) {
        return FragmentAgentConfigBinding.inflate(inflater, container, false);
    }

    @Override
    public void initData() {
        super.initData();
        // Get ViewModel from activity scope
        viewModel = new ViewModelProvider(requireActivity()).get(ConversationViewModel.class);
    }

    @Override
    public void initView() {
        FragmentAgentConfigBinding binding = getBinding();
        if (binding == null) {
            return;
        }

        setOnApplyWindowInsets(binding.getRoot());

        // Display App ID first 5 characters
        String appId = KeyCenter.AGORA_APP_ID;
        String appIdPrefix = (appId != null && appId.length() >= 5) 
            ? appId.substring(0, 5) + "***" 
            : "*****";
        binding.tvAppId.setText(appIdPrefix);

        // Display Pipeline ID first 5 characters
        String pipelineId = KeyCenter.PIPELINE_ID;
        String pipelineIdPrefix = (pipelineId != null && pipelineId.length() >= 5) 
            ? pipelineId.substring(0, 5) + "***" 
            : "*****";
        binding.tvPipelineId.setText(pipelineIdPrefix);

        binding.btnStarter.setOnClickListener(v -> {
            // Generate random channel name each time joining channel
            String channelName = ConversationViewModel.generateRandomChannelName();

            // Clear status history when starting new connection
            statusHistory.clear();
            lastStatusMessage = "";
            updateStatusDisplay();

            // Check microphone permission before joining channel
            if (getActivity() instanceof MainActivity) {
                MainActivity mainActivity = (MainActivity) getActivity();
                mainActivity.checkMicrophonePermission(granted -> {
                    if (granted) {
                        viewModel.joinChannelAndLogin(channelName);
                    } else {
                        SnackbarHelper.showError(
                            AgentConfigFragment.this,
                            "Microphone permission is required to join channel"
                        );
                    }
                });
            }
        });

        // Observe UI state changes
        observeUiState();
    }

    private void observeUiState() {
        viewModel.uiState.observe(getViewLifecycleOwner(), state -> {
            FragmentAgentConfigBinding binding = getBinding();
            if (binding == null || state == null) {
                return;
            }

            // Reset hasNavigated flag when disconnected (after hangup)
            if (state.connectionState != ConversationViewModel.ConnectionState.Connected && hasNavigated) {
                hasNavigated = false;
            }

            // Update status - accumulate status messages for history
            updateStatusMessage(state);

            // Update loading state
            binding.btnStarter.setEnabled(state.connectionState != ConversationViewModel.ConnectionState.Connecting);
            binding.progressBar.setVisibility(
                state.connectionState == ConversationViewModel.ConnectionState.Connecting 
                    ? View.VISIBLE 
                    : View.GONE
            );

            // Show error via Snackbar if connection state is Error
            if (state.connectionState == ConversationViewModel.ConnectionState.Error &&
                state.statusMessage != null &&
                !state.statusMessage.isEmpty() &&
                isAdded() && isResumed()
            ) {
                SnackbarHelper.showError(this, state.statusMessage);
            }

            // Navigate to voice assistant when RTC and RTM are connected successfully (only once)
            if (state.connectionState == ConversationViewModel.ConnectionState.Connected && !hasNavigated) {
                hasNavigated = true;
                NavHostFragment.findNavController(this).navigate(R.id.action_agentConfig_to_voiceAssistant);
            }
        });
    }

    /**
     * Update status message - accumulate status messages for history
     * Only show when connecting, hide when idle/connected/disconnected
     */
    private void updateStatusMessage(ConversationViewModel.ConversationUiState state) {
        // Add new status message to history if it's different from the last one
        if (state.connectionState == ConversationViewModel.ConnectionState.Connecting &&
            state.statusMessage != null &&
            !state.statusMessage.isEmpty() &&
            !state.statusMessage.equals(lastStatusMessage)
        ) {
            statusHistory.add(state.statusMessage);
            lastStatusMessage = state.statusMessage;
        }

        // Clear history when disconnected or idle
        if (state.connectionState == ConversationViewModel.ConnectionState.Idle) {
            statusHistory.clear();
            lastStatusMessage = "";
        }

        updateStatusDisplay();
    }

    /**
     * Update status display with accumulated history
     */
    private void updateStatusDisplay() {
        FragmentAgentConfigBinding binding = getBinding();
        if (binding == null) {
            return;
        }

        StringBuilder displayMessage = new StringBuilder();
        for (int i = 0; i < statusHistory.size(); i++) {
            if (i > 0) {
                displayMessage.append("\n");
            }
            displayMessage.append(statusHistory.get(i));
        }
        binding.tvStatus.setText(displayMessage.toString());
    }
}

