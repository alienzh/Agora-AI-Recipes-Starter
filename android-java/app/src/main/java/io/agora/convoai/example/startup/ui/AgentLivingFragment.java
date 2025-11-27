package io.agora.convoai.example.startup.ui;

import android.graphics.Color;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;
import androidx.lifecycle.ViewModelProvider;
import androidx.navigation.fragment.NavHostFragment;
import androidx.recyclerview.widget.DiffUtil;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.ListAdapter;
import androidx.recyclerview.widget.RecyclerView;
import io.agora.convoai.convoaiApi.Transcript;
import io.agora.convoai.convoaiApi.TranscriptStatus;
import io.agora.convoai.convoaiApi.TranscriptType;
import io.agora.convoai.example.startup.R;
import io.agora.convoai.example.startup.databinding.FragmentAgentLivingBinding;
import io.agora.convoai.example.startup.databinding.ItemTranscriptAgentBinding;
import io.agora.convoai.example.startup.databinding.ItemTranscriptUserBinding;
import io.agora.convoai.example.startup.ui.common.BaseFragment;
import io.agora.convoai.example.startup.ui.common.SnackbarHelper;

import java.util.ArrayList;

/**
 * AgentLivingFragment - Main interface for voice conversation with AI agent
 * Displays transcripts and agent status.
 */
public class AgentLivingFragment extends BaseFragment<FragmentAgentLivingBinding> {

    private ConversationViewModel viewModel;
    private TranscriptAdapter transcriptAdapter;

    // Track whether to automatically scroll to bottom
    private boolean autoScrollToBottom = true;
    private boolean isScrollBottom = false;

    @Override
    protected FragmentAgentLivingBinding getViewBinding(LayoutInflater inflater, ViewGroup container) {
        return FragmentAgentLivingBinding.inflate(inflater, container, false);
    }

    @Override
    public void initData() {
        super.initData();
        // Get ViewModel from activity scope
        viewModel = new ViewModelProvider(requireActivity()).get(ConversationViewModel.class);
        transcriptAdapter = new TranscriptAdapter();

        // Observe UI state changes
        observeUiState();

        // Observe transcript list changes
        observeTranscriptList();
    }

    @Override
    public void initView() {
        FragmentAgentLivingBinding binding = getBinding();
        if (binding == null) {
            return;
        }

        setOnApplyWindowInsets(binding.getRoot());

        // Get info from ViewModel state
        ConversationViewModel.ConversationUiState currentState = viewModel.uiState.getValue();
        if (currentState != null) {
            String channelName = currentState.channelName;
            int userUid = currentState.userUid;
            int agentUid = currentState.agentUid;

            binding.tvChannel.setText("Channel: " + (channelName != null ? channelName : ""));
            binding.tvUid.setText("UserId: " + userUid);
            binding.tvAgentUid.setText("AgentUid: " + agentUid);
        }

        // Setup RecyclerView for transcript list
        setupRecyclerView();

        binding.btnMute.setOnClickListener(v -> viewModel.toggleMute());

        binding.btnHangup.setOnClickListener(v -> handleHangup());

        // Agent is already started by AgentHomeFragment/ViewModel logic
        // Removed redundant viewModel.startAgent() call
    }

    /**
     * Setup RecyclerView for transcript list
     */
    private void setupRecyclerView() {
        FragmentAgentLivingBinding binding = getBinding();
        if (binding == null || binding.rvTranscript == null) {
            return;
        }

        LinearLayoutManager layoutManager = new LinearLayoutManager(requireContext());
        layoutManager.setReverseLayout(false);
        binding.rvTranscript.setLayoutManager(layoutManager);
        binding.rvTranscript.setAdapter(transcriptAdapter);
        binding.rvTranscript.setItemAnimator(null);

        binding.rvTranscript.addOnScrollListener(new RecyclerView.OnScrollListener() {
            @Override
            public void onScrollStateChanged(@NonNull RecyclerView recyclerView, int newState) {
                super.onScrollStateChanged(recyclerView, newState);
                switch (newState) {
                    case RecyclerView.SCROLL_STATE_IDLE:
                        // Check if at bottom when scrolling stops
                        isScrollBottom = !recyclerView.canScrollVertically(1);
                        if (isScrollBottom) {
                            autoScrollToBottom = true;
                            isScrollBottom = true;
                        }
                        break;

                    case RecyclerView.SCROLL_STATE_DRAGGING:
                        // When user actively drags
                        autoScrollToBottom = false;
                        break;
                }
            }

            @Override
            public void onScrolled(@NonNull RecyclerView recyclerView, int dx, int dy) {
                super.onScrolled(recyclerView, dx, dy);
                // Show button when scrolling up a significant distance
                if (dy < -50) {
                    if (recyclerView.canScrollVertically(1)) {
                        autoScrollToBottom = false;
                    }
                }
            }
        });
    }

    @Override
    public void onHandleOnBackPressed() {
        // Handle back press (including swipe back gesture) same as hangup button
        handleHangup();
    }

    private void handleHangup() {
        viewModel.hangup();
        if (isAdded()) {
            NavHostFragment.findNavController(this).popBackStack();
        }
    }

    private void observeUiState() {
        viewModel.uiState.observe(getViewLifecycleOwner(), state -> {
            FragmentAgentLivingBinding binding = getBinding();
            if (binding == null || state == null) {
                return;
            }

            // Update channel, user, agent info from state
            if (state.channelName != null && !state.channelName.isEmpty()) {
                binding.tvChannel.setText("Channel: " + state.channelName);
            }
            if (state.userUid != 0) {
                binding.tvUid.setText("UserId: " + state.userUid);
            }
            if (state.agentUid != 0) {
                binding.tvAgentUid.setText("AgentUid: " + state.agentUid);
            }

            // Update mute button icon
            binding.btnMute.setImageResource(state.isMuted ? R.drawable.ic_mic_off : R.drawable.ic_mic);
            // Update mute button background based on state
            int muteBackground = state.isMuted 
                ? R.drawable.bg_button_mute_muted_selector 
                : R.drawable.bg_button_mute_selector;
            binding.btnMute.setBackgroundResource(muteBackground);
        });

        viewModel.agentState.observe(getViewLifecycleOwner(), agentState -> {
            FragmentAgentLivingBinding binding = getBinding();
            if (binding == null) {
                return;
            }

            if (agentState != null) {
                // Update agent status text using state.value
                binding.tvAgentStatus.setText(agentState.getValue());

            } else {
                // Agent state is null, show default text
                binding.tvAgentStatus.setText("Unknown");
            }
        });

        // Show Snackbar based on connection state (only if fragment is visible)
        viewModel.uiState.observe(getViewLifecycleOwner(), state -> {
            if (isAdded() && isResumed() && state != null) {
                if (state.connectionState == ConversationViewModel.ConnectionState.Error) {
                    // Show error Snackbar for Error state
                    SnackbarHelper.showError(this, state.statusMessage);
                } else if (state.statusMessage != null && !state.statusMessage.isEmpty()) {
                    // Show normal Snackbar for other status messages
                    SnackbarHelper.showNormal(this, state.statusMessage);
                }
            }
        });
    }

    private void observeTranscriptList() {
        viewModel.transcriptList.observe(getViewLifecycleOwner(), transcriptList -> {
            // Update transcript list
            transcriptAdapter.submitList(transcriptList != null ? transcriptList : new ArrayList<>());
            if (autoScrollToBottom) {
                scrollToBottom();
            }
        });
    }

    private void scrollToBottom() {
        FragmentAgentLivingBinding binding = getBinding();
        if (binding == null) {
            return;
        }

        RecyclerView recyclerView = binding.rvTranscript;
        int lastPosition = transcriptAdapter.getItemCount() - 1;
        if (lastPosition < 0) {
            return;
        }

        // Stop any ongoing scrolling
        recyclerView.stopScroll();

        // Get layout manager
        LinearLayoutManager layoutManager = (LinearLayoutManager) recyclerView.getLayoutManager();
        if (layoutManager == null) {
            return;
        }

        // Use single post call to handle all scrolling logic
        recyclerView.post(() -> {
            // First jump to target position
            layoutManager.scrollToPosition(lastPosition);

            // Handle extra-long messages within the same post
            View lastView = layoutManager.findViewByPosition(lastPosition);
            if (lastView != null) {
                // For extra-long messages, ensure scrolling to bottom
                if (lastView.getHeight() > recyclerView.getHeight()) {
                    int offset = recyclerView.getHeight() - lastView.getHeight();
                    layoutManager.scrollToPositionWithOffset(lastPosition, offset);
                }
            }

            // Update UI state
            isScrollBottom = true;
        });
    }

    /**
     * TranscriptAdapter - RecyclerView adapter for displaying transcripts
     */
    private static class TranscriptAdapter extends ListAdapter<Transcript, RecyclerView.ViewHolder> {

        private static final int VIEW_TYPE_USER = 0;
        private static final int VIEW_TYPE_AGENT = 1;

        public TranscriptAdapter() {
            super(new TranscriptDiffCallback());
        }

        @Override
        public int getItemViewType(int position) {
            Transcript transcript = getItem(position);
            if (transcript == null) {
                return VIEW_TYPE_USER;
            }
            return transcript.getType() == TranscriptType.USER ? VIEW_TYPE_USER : VIEW_TYPE_AGENT;
        }

        @NonNull
        @Override
        public RecyclerView.ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
            LayoutInflater inflater = LayoutInflater.from(parent.getContext());
            if (viewType == VIEW_TYPE_USER) {
                return new UserViewHolder(ItemTranscriptUserBinding.inflate(inflater, parent, false));
            } else if (viewType == VIEW_TYPE_AGENT) {
                return new AgentViewHolder(ItemTranscriptAgentBinding.inflate(inflater, parent, false));
            } else {
                throw new IllegalArgumentException("Unknown view type: " + viewType);
            }
        }

        @Override
        public void onBindViewHolder(@NonNull RecyclerView.ViewHolder holder, int position) {
            Transcript transcript = getItem(position);
            if (transcript == null) {
                return;
            }

            if (holder instanceof UserViewHolder) {
                ((UserViewHolder) holder).bind(transcript);
            } else if (holder instanceof AgentViewHolder) {
                ((AgentViewHolder) holder).bind(transcript);
            }
        }

        static class UserViewHolder extends RecyclerView.ViewHolder {
            private final TextView tvType;
            private final TextView tvText;
            private final TextView tvStatus;

            UserViewHolder(ItemTranscriptUserBinding binding) {
                super(binding.getRoot());
                tvType = binding.tvTranscriptType;
                tvText = binding.tvTranscriptText;
                tvStatus = binding.tvTranscriptStatus;
            }

            void bind(Transcript transcript) {
                // Set transcript type with color for USER
                tvType.setText("USER");
                android.graphics.drawable.Drawable drawable = ContextCompat.getDrawable(
                    itemView.getContext(), 
                    R.drawable.bg_type_badge
                );
                if (drawable != null) {
                    drawable.setTint(Color.parseColor("#10B981"));
                    tvType.setBackground(drawable);
                }

                // Set transcript text
                String text = transcript.getText();
                tvText.setText(!text.isEmpty() ? text : "(empty)");

                // Set transcript status with color
                String statusText;
                int statusColor;
                TranscriptStatus status = transcript.getStatus();
                if (status == TranscriptStatus.IN_PROGRESS) {
                    statusText = "IN PROGRESS";
                    statusColor = Color.parseColor("#FF9800");
                } else if (status == TranscriptStatus.END) {
                    statusText = "END";
                    statusColor = Color.parseColor("#4CAF50");
                } else if (status == TranscriptStatus.INTERRUPTED) {
                    statusText = "INTERRUPTED";
                    statusColor = Color.parseColor("#F44336");
                } else {
                    statusText = "UNKNOWN";
                    statusColor = Color.parseColor("#9E9E9E");
                }
                tvStatus.setText(statusText);
                tvStatus.setTextColor(statusColor);
            }
        }

        static class AgentViewHolder extends RecyclerView.ViewHolder {
            private final TextView tvType;
            private final TextView tvText;
            private final TextView tvStatus;

            AgentViewHolder(ItemTranscriptAgentBinding binding) {
                super(binding.getRoot());
                tvType = binding.tvTranscriptType;
                tvText = binding.tvTranscriptText;
                tvStatus = binding.tvTranscriptStatus;
            }

            void bind(Transcript transcript) {
                // Set transcript type with color for AGENT
                tvType.setText("AGENT");
                android.graphics.drawable.Drawable drawable = ContextCompat.getDrawable(
                    itemView.getContext(), 
                    R.drawable.bg_type_badge
                );
                if (drawable != null) {
                    drawable.setTint(Color.parseColor("#6366F1"));
                    tvType.setBackground(drawable);
                }

                // Set transcript text
                String text = transcript.getText();
                tvText.setText(!text.isEmpty() ? text : "(empty)");

                // Set transcript status with color
                String statusText;
                int statusColor;
                TranscriptStatus status = transcript.getStatus();
                if (status == TranscriptStatus.IN_PROGRESS) {
                    statusText = "IN PROGRESS";
                    statusColor = Color.parseColor("#FF9800");
                } else if (status == TranscriptStatus.END) {
                    statusText = "END";
                    statusColor = Color.parseColor("#4CAF50");
                } else if (status == TranscriptStatus.INTERRUPTED) {
                    statusText = "INTERRUPTED";
                    statusColor = Color.parseColor("#F44336");
                } else {
                    statusText = "UNKNOWN";
                    statusColor = Color.parseColor("#9E9E9E");
                }
                tvStatus.setText(statusText);
                tvStatus.setTextColor(statusColor);
            }
        }

        private static class TranscriptDiffCallback extends DiffUtil.ItemCallback<Transcript> {
            @Override
            public boolean areItemsTheSame(@NonNull Transcript oldItem, @NonNull Transcript newItem) {
                return oldItem.getTurnId() == newItem.getTurnId() && 
                       oldItem.getType() == newItem.getType();
            }

            @Override
            public boolean areContentsTheSame(@NonNull Transcript oldItem, @NonNull Transcript newItem) {
                return oldItem.equals(newItem);
            }
        }
    }
}
