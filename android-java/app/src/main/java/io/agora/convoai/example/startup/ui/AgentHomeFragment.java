package io.agora.convoai.example.startup.ui;

import android.view.LayoutInflater;
import android.view.ViewGroup;

import androidx.lifecycle.ViewModelProvider;
import androidx.navigation.fragment.NavHostFragment;
import io.agora.convoai.example.startup.KeyCenter;
import io.agora.convoai.example.startup.R;
import io.agora.convoai.example.startup.databinding.FragmentAgentHomeBinding;
import io.agora.convoai.example.startup.ui.common.BaseFragment;
import io.agora.convoai.example.startup.ui.common.SnackbarHelper;

/**
 * AgentHomeFragment - Configuration screen for starting a conversation
 */
public class AgentHomeFragment extends BaseFragment<FragmentAgentHomeBinding> {

    private ConversationViewModel viewModel;
    private boolean hasNavigated = false;

    @Override
    protected FragmentAgentHomeBinding getViewBinding(LayoutInflater inflater, ViewGroup container) {
        return FragmentAgentHomeBinding.inflate(inflater, container, false);
    }

    @Override
    public void initData() {
        super.initData();
        // Get ViewModel from activity scope
        viewModel = new ViewModelProvider(requireActivity()).get(ConversationViewModel.class);
    }

    @Override
    public void initView() {
        FragmentAgentHomeBinding binding = getBinding();
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

            // Check microphone permission before joining channel
            if (getActivity() instanceof MainActivity) {
                MainActivity mainActivity = (MainActivity) getActivity();
                mainActivity.checkMicrophonePermission(granted -> {
                    if (granted) {
                        viewModel.joinChannelAndLogin(channelName);
                    } else {
                        SnackbarHelper.showError(
                            AgentHomeFragment.this,
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
            FragmentAgentHomeBinding binding = getBinding();
            if (binding == null || state == null) {
                return;
            }

            // Reset hasNavigated flag when disconnected (after hangup)
            if (state.connectionState != ConversationViewModel.ConnectionState.Connected && hasNavigated) {
                hasNavigated = false;
            }

            // Update loading state
            boolean isConnecting = state.connectionState == ConversationViewModel.ConnectionState.Connecting;
            boolean isError = state.connectionState == ConversationViewModel.ConnectionState.Error;
            binding.btnStarter.setEnabled(!isConnecting);
            
            if (isConnecting) {
                binding.btnStarter.setText("Starting...");
            } else {
                binding.btnStarter.setText("Start Agent");
            }
            
            // Show error via Snackbar if connection state is Error
            if (isError && state.statusMessage != null && !state.statusMessage.isEmpty() &&
                isAdded() && isResumed()
            ) {
                SnackbarHelper.showError(this, state.statusMessage);
            }

            // Navigate to agent living fragment when RTC and RTM are connected successfully AND agent is started
            if (state.connectionState == ConversationViewModel.ConnectionState.Connected && 
                state.agentStarted && // This field needs to be added to ConversationUiState in ViewModel
                !hasNavigated) {
                hasNavigated = true;
                // Note: ID needs to be updated in nav_graph.xml
                NavHostFragment.findNavController(this).navigate(R.id.action_agentHome_to_agentLiving);
            }
        });
    }
}
