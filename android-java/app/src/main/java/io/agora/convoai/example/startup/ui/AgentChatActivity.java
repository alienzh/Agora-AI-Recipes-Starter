package io.agora.convoai.example.startup.ui;

import android.graphics.Color;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;
import androidx.lifecycle.Observer;
import androidx.lifecycle.ViewModelProvider;
import androidx.recyclerview.widget.DiffUtil;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.ListAdapter;
import androidx.recyclerview.widget.RecyclerView;

import io.agora.convoai.convoaiApi.AgentState;
import io.agora.convoai.convoaiApi.Transcript;
import io.agora.convoai.convoaiApi.TranscriptStatus;
import io.agora.convoai.convoaiApi.TranscriptType;
import io.agora.convoai.example.startup.R;
import io.agora.convoai.example.startup.databinding.ActivityAgentChatBinding;
import io.agora.convoai.example.startup.databinding.ItemTranscriptAgentBinding;
import io.agora.convoai.example.startup.databinding.ItemTranscriptUserBinding;
import io.agora.convoai.example.startup.ui.common.BaseActivity;
import io.agora.convoai.example.startup.ui.CommonDialog;
import io.agora.convoai.example.startup.tools.PermissionHelp;

import java.util.ArrayList;
import java.util.List;

/**
 * Activity for agent chat interface
 * Layout: log, agent status, transcript, start/control buttons
 */
public class AgentChatActivity extends BaseActivity<ActivityAgentChatBinding> {

    private AgentChatViewModel viewModel;
    private PermissionHelp mPermissionHelp;
    private TranscriptAdapter transcriptAdapter;

    // Track whether to automatically scroll to bottom
    private boolean autoScrollToBottom = true;
    private boolean isScrollBottom = false;

    @Override
    protected ActivityAgentChatBinding getViewBinding() {
        return ActivityAgentChatBinding.inflate(getLayoutInflater());
    }

    @Override
    public void initData() {
        super.initData();
        viewModel = new ViewModelProvider(this).get(AgentChatViewModel.class);
        mPermissionHelp = new PermissionHelp(this);
        transcriptAdapter = new TranscriptAdapter();

        // Observe UI state changes
        observeUiState();

        // Observe transcript list changes
        observeTranscriptList();

        // Observe debug log changes
        observeDebugLogs();
    }

    @Override
    protected void initView() {
        ActivityAgentChatBinding binding = getBinding();
        if (binding == null) {
            return;
        }

        setOnApplyWindowInsetsListener(binding.getRoot());

        // Setup RecyclerView for transcript list
        setupRecyclerView();

        // Start button click listener
        binding.btnStart.setOnClickListener(v -> {
            // Generate random channel name each time joining channel
            String channelName = AgentChatViewModel.generateRandomChannelName();

            // Check microphone permission before joining channel
            checkMicrophonePermission(granted -> {
                if (granted) {
                    viewModel.joinChannelAndLogin(channelName);
                } else {
                    Toast.makeText(
                            AgentChatActivity.this,
                            "Microphone permission is required to join channel",
                            Toast.LENGTH_LONG
                    ).show();
                }
            });
        });

        // Mute button click listener
        binding.btnMute.setOnClickListener(v -> viewModel.toggleMute());

        // Stop button click listener
        binding.btnStop.setOnClickListener(v -> viewModel.hangup());
    }

    @Override
    public boolean supportOnBackPressed() {
        return false;
    }

    private void checkMicrophonePermission(PermissionCallback callback) {
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

    private void showPermissionDialog(String title, String content, PermissionCallback onResult) {
        if (isFinishing() || isDestroyed() || getSupportFragmentManager().isStateSaved()) {
            return;
        }

        new CommonDialog.Builder()
                .setTitle(title)
                .setContent(content)
                .setPositiveButton("Retry", () -> onResult.onResult(true))
                .setNegativeButton("Exit", () -> onResult.onResult(false))
                .setCancelable(false)
                .build()
                .show(getSupportFragmentManager(), "permission_dialog");
    }

    /**
     * Callback interface for permission check results
     */
    private interface PermissionCallback {
        void onResult(boolean granted);
    }

    /**
     * Setup RecyclerView for transcript list
     */
    private void setupRecyclerView() {
        ActivityAgentChatBinding binding = getBinding();
        if (binding == null) {
            return;
        }

        RecyclerView recyclerView = binding.rvTranscript;
        LinearLayoutManager linearLayoutManager = new LinearLayoutManager(this);
        linearLayoutManager.setReverseLayout(false);
        recyclerView.setLayoutManager(linearLayoutManager);
        recyclerView.setAdapter(transcriptAdapter);
        recyclerView.setItemAnimator(null);
        recyclerView.addOnScrollListener(new RecyclerView.OnScrollListener() {
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

    private void observeUiState() {
        viewModel.uiState.observe(this, state -> {
            ActivityAgentChatBinding binding = getBinding();
            if (binding == null || state == null) {
                return;
            }

            // Update button visibility based on connection state
            boolean isConnected = state.connectionState == AgentChatViewModel.ConnectionState.Connected;
            boolean isConnecting = state.connectionState == AgentChatViewModel.ConnectionState.Connecting;

            // Show/hide buttons
            binding.llStart.setVisibility(isConnected ? View.GONE : View.VISIBLE);
            binding.llControls.setVisibility(isConnected ? View.VISIBLE : View.GONE);

            // Update button loading state
            if (isConnecting) {
                binding.btnStart.setText("Starting...");
                binding.btnStart.setEnabled(false);
            } else {
                binding.btnStart.setText("Start Agent");
                binding.btnStart.setEnabled(true);
            }

            // Update mute button UI
            binding.btnMute.setImageResource(
                    state.isMuted ? R.drawable.ic_mic_off : R.drawable.ic_mic
            );
        });

        // Observe agent state
        viewModel.agentState.observe(this, agentState -> {
            ActivityAgentChatBinding binding = getBinding();
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
    }

    private void observeTranscriptList() {
        viewModel.transcriptList.observe(this, transcriptList -> {
            // Update transcript list
            transcriptAdapter.submitList(transcriptList != null ? transcriptList : new ArrayList<>());
            if (autoScrollToBottom) {
                scrollToBottom();
            }
        });
    }

    private void observeDebugLogs() {
        viewModel.debugLogList.observe(this, logList -> {
            ActivityAgentChatBinding binding = getBinding();
            if (binding == null) {
                return;
            }

            // Update log text with all logs, separated by newlines
            if (logList != null && !logList.isEmpty()) {
                StringBuilder sb = new StringBuilder();
                for (int i = 0; i < logList.size(); i++) {
                    if (i > 0) {
                        sb.append("\n");
                    }
                    sb.append(logList.get(i));
                }
                binding.tvLog.setText(sb.toString());
            } else {
                binding.tvLog.setText("log");
            }

            // Auto scroll to bottom
            binding.tvLog.post(() -> {
                View parent = (View) binding.tvLog.getParent();
                if (parent instanceof android.widget.ScrollView) {
                    ((android.widget.ScrollView) parent).fullScroll(View.FOCUS_DOWN);
                }
            });
        });
    }

    /**
     * Scroll RecyclerView to the bottom to show latest transcript
     */
    private void scrollToBottom() {
        ActivityAgentChatBinding binding = getBinding();
        if (binding == null) {
            return;
        }

        RecyclerView recyclerView = binding.rvTranscript;
        int lastPosition = transcriptAdapter.getItemCount() - 1;
        if (lastPosition < 0) {
            return;
        }

        recyclerView.stopScroll();
        LinearLayoutManager layoutManager = (LinearLayoutManager) recyclerView.getLayoutManager();
        if (layoutManager == null) {
            return;
        }

        // Use single post call to handle all scrolling logic
        recyclerView.post(() -> {
            layoutManager.scrollToPosition(lastPosition);

            // Handle extra-long messages that exceed viewport height
            View lastView = layoutManager.findViewByPosition(lastPosition);
            if (lastView != null && lastView.getHeight() > recyclerView.getHeight()) {
                int offset = recyclerView.getHeight() - lastView.getHeight();
                layoutManager.scrollToPositionWithOffset(lastPosition, offset);
            }

            isScrollBottom = true;
        });
    }
}

/**
 * Adapter for displaying transcript list with different view types for USER and AGENT
 */
class TranscriptAdapter extends ListAdapter<Transcript, RecyclerView.ViewHolder> {

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
        switch (viewType) {
            case VIEW_TYPE_USER:
                return new UserViewHolder(ItemTranscriptUserBinding.inflate(inflater, parent, false));

            case VIEW_TYPE_AGENT:
                return new AgentViewHolder(ItemTranscriptAgentBinding.inflate(inflater, parent, false));

            default:
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

    /**
     * ViewHolder for USER transcript items
     */
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
            // Set transcript type badge with green color for USER
            tvType.setText("USER");
            android.graphics.drawable.Drawable drawable = ContextCompat.getDrawable(
                    itemView.getContext(), R.drawable.bg_type_badge);
            if (drawable != null) {
                drawable.setTint(Color.parseColor("#10B981"));
                tvType.setBackground(drawable);
            }

            // Set transcript text
            String text = transcript.getText();
            tvText.setText(text != null && !text.isEmpty() ? text : "(empty)");

            // Set transcript status with appropriate color
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

    /**
     * ViewHolder for AGENT transcript items
     */
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
            // Set transcript type badge with indigo color for AGENT
            tvType.setText("AGENT");
            android.graphics.drawable.Drawable drawable = ContextCompat.getDrawable(
                    itemView.getContext(), R.drawable.bg_type_badge);
            if (drawable != null) {
                drawable.setTint(Color.parseColor("#6366F1"));
                tvType.setBackground(drawable);
            }

            // Set transcript text
            String text = transcript.getText();
            tvText.setText(text != null && !text.isEmpty() ? text : "(empty)");

            // Set transcript status with appropriate color
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
            return oldItem.getTurnId() == newItem.getTurnId() && oldItem.getType() == newItem.getType();
        }

        @Override
        public boolean areContentsTheSame(@NonNull Transcript oldItem, @NonNull Transcript newItem) {
            return oldItem.equals(newItem);
        }
    }
}

