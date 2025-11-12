package io.agora.convoai.example.voiceassistant.ui

import android.view.LayoutInflater
import android.view.ViewGroup
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.fragment.app.activityViewModels
import io.agora.convoai.example.voiceassistant.ui.common.SnackbarHelper
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import io.agora.convoai.example.voiceassistant.R
import io.agora.convoai.example.voiceassistant.databinding.FragmentVoiceAssistantBinding
import io.agora.convoai.example.voiceassistant.databinding.ItemTranscriptAgentBinding
import io.agora.convoai.example.voiceassistant.databinding.ItemTranscriptUserBinding
import io.agora.convoai.example.voiceassistant.ui.common.BaseFragment
import io.agora.convoai.convoaiApi.Transcript
import io.agora.convoai.convoaiApi.TranscriptStatus
import io.agora.convoai.convoaiApi.TranscriptType
import kotlinx.coroutines.launch
import kotlin.text.ifEmpty
import androidx.core.graphics.toColorInt
import androidx.core.view.isVisible
import androidx.navigation.fragment.findNavController
import io.agora.convoai.convoaiApi.AgentState

class VoiceAssistantFragment : BaseFragment<FragmentVoiceAssistantBinding>() {

    private val viewModel: ConversationViewModel by activityViewModels()
    private val transcriptAdapter: TranscriptAdapter = TranscriptAdapter()

    // Track whether to automatically scroll to bottom
    private var autoScrollToBottom = true

    private var isScrollBottom = false
    private val statusHistory = mutableListOf<String>()
    private var lastStatusMessage = ""

    override fun getViewBinding(inflater: LayoutInflater, container: ViewGroup?): FragmentVoiceAssistantBinding? {
        return FragmentVoiceAssistantBinding.inflate(inflater, container, false)
    }

    override fun initData() {
        super.initData()

        // Observe UI state changes
        observeUiState()

        // Observe transcript list changes
        observeTranscriptList()
    }

    override fun initView() {
        mBinding?.apply {
            setOnApplyWindowInsets(root)

            // Get info from ViewModel state
            val currentState = viewModel.uiState.value
            val channelName = currentState.channelName
            val userUid = currentState.userUid
            val agentUid = currentState.agentUid

            tvChannel.text = "Channel: $channelName"
            tvUid.text = "UserId: $userUid"
            tvAgentUid.text = "AgentUid: $agentUid"

            // Setup TextView for scrollable status with max height
            setupScrollableStatus()

            // Setup RecyclerView for transcript list
            setupRecyclerView()

            btnMute.setOnClickListener {
                viewModel.toggleMute()
            }

            btnTranscript.setOnClickListener {
                viewModel.toggleTranscript()
            }

            btnHangup.setOnClickListener {
                handleHangup()
            }
        }
        
        // Start agent when fragment is created (after RTC and RTM are connected)
        viewModel.startAgent()
    }

    /**
     * Setup TextView for scrollable status with max height
     */
    private fun setupScrollableStatus() {
        mBinding?.apply {
            // Set max height (approximately 4-5 lines of text)
            val maxHeight = (tvStatus.textSize * 5).toInt()
            tvStatus.maxHeight = maxHeight

            // Enable scrolling
            tvStatus.isVerticalScrollBarEnabled = true
            tvStatus.movementMethod = android.text.method.ScrollingMovementMethod()
        }
    }

    /**
     *  Setup RecyclerView for transcript list
     */
    private fun setupRecyclerView() {
        mBinding?.rvTranscript?.apply {
            layoutManager = LinearLayoutManager(requireContext()).apply {
                reverseLayout = false
            }
            adapter = transcriptAdapter
            itemAnimator = null
            addOnScrollListener(object : RecyclerView.OnScrollListener() {
                override fun onScrollStateChanged(recyclerView: RecyclerView, newState: Int) {
                    super.onScrollStateChanged(recyclerView, newState)
                    when (newState) {
                        RecyclerView.SCROLL_STATE_IDLE -> {
                            // Check if at bottom when scrolling stops
                            isScrollBottom = !recyclerView.canScrollVertically(1)
                            if (isScrollBottom) {
                                autoScrollToBottom = true
                                isScrollBottom = true
                            }
                        }

                        RecyclerView.SCROLL_STATE_DRAGGING -> {
                            // When user actively drags
                            autoScrollToBottom = false
                        }
                    }
                }

                override fun onScrolled(recyclerView: RecyclerView, dx: Int, dy: Int) {
                    super.onScrolled(recyclerView, dx, dy)
                    // Show button when scrolling up a significant distance
                    if (dy < -50) {
                        if (recyclerView.canScrollVertically(1)) {
                            autoScrollToBottom = false
                        }
                    }
                }
            })
        }
    }

    override fun onHandleOnBackPressed() {
        // Handle back press (including swipe back gesture) same as hangup button
        handleHangup()
    }

    private fun handleHangup() {
        viewModel.hangup()
        if (isAdded) {
            findNavController().popBackStack()
        }
    }

    private fun observeUiState() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewModel.uiState.collect { state ->
                mBinding?.apply {
                    // Show/hide transcript list based on transcript enabled state
                    cardTranscript.isVisible = state.isTranscriptEnabled

                    // Show agent status indicator when transcript is hidden
                    agentSpeakingIndicator.isVisible = !state.isTranscriptEnabled

                    // Update status message - only show important connection/agent status
                    updateStatusMessage(state)

                    // Update channel, user, agent info from state
                    if (state.channelName.isNotEmpty()) {
                        tvChannel.text = "Channel: ${state.channelName}"
                    }
                    if (state.userUid != 0) {
                        tvUid.text = "UserId: ${state.userUid}"
                    }
                    if (state.agentUid != 0) {
                        tvAgentUid.text = "AgentUid: ${state.agentUid}"
                    }

                    // Update mute button icon
                    btnMute.setImageResource(if (state.isMuted) R.drawable.ic_mic_off else R.drawable.ic_mic)
                    // Update mute button background based on state (use selector for pressed state)
                    val muteBackground = if (state.isMuted) {
                        R.drawable.bg_button_mute_muted_selector
                    } else {
                        R.drawable.bg_button_mute_selector
                    }
                    btnMute.setBackgroundResource(muteBackground)

                    // Update transcript button icon
                    btnTranscript.setImageResource(
                        if (state.isTranscriptEnabled) R.drawable.ic_subtitles else R.drawable.ic_subtitles_off
                    )
                }

                // Show Snackbar based on connection state (only if fragment is visible)
                if (isAdded && isResumed) {
                    if (state.connectionState == ConversationViewModel.ConnectionState.Error) {
                        // Show error Snackbar for Error state
                        SnackbarHelper.showError(this@VoiceAssistantFragment, state.statusMessage)
                    } else if (state.statusMessage.isNotEmpty()) {
                        // Show normal Snackbar for other status messages
                        SnackbarHelper.showNormal(this@VoiceAssistantFragment, state.statusMessage)
                    }
                }
            }
        }

        lifecycleScope.launch {    // Observe agent state
            viewModel.agentState.collect { agentState ->
                agentState?.let {
                    if (agentState == AgentState.SPEAKING) {
                        mBinding?.agentSpeakingIndicator?.startAnimation()
                    } else {
                        mBinding?.agentSpeakingIndicator?.stopAnimation()
                    }
                }
            }
        }
    }

    /**
     * Update status message - accumulate status messages for history
     * Only show important connection/agent status, hide operational messages
     */
    private fun updateStatusMessage(state: ConversationViewModel.ConversationUiState) {
        // Filter out operational messages (mute, transcript, etc.)
        val shouldShowMessage = when {
            state.statusMessage.contains("muted", ignoreCase = true) -> false
            state.statusMessage.contains("unmuted", ignoreCase = true) -> false
            state.statusMessage.contains("Transcript", ignoreCase = true) -> false
            else -> true
        }

        // Add new status message to history if it should be shown and is different from the last one
        if (shouldShowMessage &&
            state.statusMessage.isNotEmpty() &&
            state.statusMessage != lastStatusMessage
        ) {
            statusHistory.add(state.statusMessage)
            lastStatusMessage = state.statusMessage
        }

        // Clear history when disconnected or idle
        if (state.connectionState == ConversationViewModel.ConnectionState.Idle) {
            statusHistory.clear()
            lastStatusMessage = ""
        }

        updateStatusDisplay()
    }

    /**
     * Update status display with accumulated history
     */
    private fun updateStatusDisplay() {
        mBinding?.apply {
            val displayMessage = statusHistory.joinToString("\n")
            tvStatus.text = displayMessage

            // Set text color based on message type
            when {
                displayMessage.contains("successfully", ignoreCase = true) ||
                        displayMessage.contains("initialized", ignoreCase = true) ||
                        displayMessage.contains("joined", ignoreCase = true) -> {
                    tvStatus.setTextColor("#4CAF50".toColorInt())
                }

                displayMessage.contains("error", ignoreCase = true) ||
                        displayMessage.contains("failed", ignoreCase = true) ||
                        displayMessage.contains("left", ignoreCase = true) -> {
                    tvStatus.setTextColor("#F44336".toColorInt())
                }

                else -> {
                    tvStatus.setTextColor("#666666".toColorInt())
                }
            }

            // Scroll to bottom when new message is added (post to ensure layout is complete)
            tvStatus.post {
                val scrollAmount = tvStatus.layout?.getLineTop(tvStatus.lineCount) ?: 0
                if (scrollAmount > tvStatus.height) {
                    tvStatus.scrollTo(0, scrollAmount - tvStatus.height)
                }
            }
        }
    }

    private fun observeTranscriptList() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewModel.transcriptList.collect { transcriptList ->
                // Update transcript list
                transcriptAdapter.submitList(transcriptList)
                if (autoScrollToBottom) {
                    scrollToBottom()
                }
            }
        }
    }

    private fun scrollToBottom() {
        mBinding?.rvTranscript?.apply {
            val lastPosition = transcriptAdapter.itemCount - 1
            if (lastPosition < 0) return

            // Stop any ongoing scrolling
            stopScroll()

            // Get layout manager
            val layoutManager = layoutManager as? LinearLayoutManager ?: return

            // Use single post call to handle all scrolling logic
            post {
                // First jump to target position
                layoutManager.scrollToPosition(lastPosition)

                // Handle extra-long messages within the same post
                val lastView = layoutManager.findViewByPosition(lastPosition)
                if (lastView != null) {
                    // For extra-long messages, ensure scrolling to bottom
                    if (lastView.height > height) {
                        val offset = height - lastView.height
                        layoutManager.scrollToPositionWithOffset(lastPosition, offset)
                    }
                }

                // Update UI state
                isScrollBottom = true
            }
        }
    }
}

class TranscriptAdapter : ListAdapter<Transcript, RecyclerView.ViewHolder>(TranscriptDiffCallback()) {

    companion object {
        private const val VIEW_TYPE_USER = 0
        private const val VIEW_TYPE_AGENT = 1
    }

    override fun getItemViewType(position: Int): Int {
        return when (getItem(position).type) {
            TranscriptType.USER -> VIEW_TYPE_USER
            TranscriptType.AGENT -> VIEW_TYPE_AGENT
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
        return when (viewType) {
            VIEW_TYPE_USER -> {
                UserViewHolder(ItemTranscriptUserBinding.inflate(LayoutInflater.from(parent.context), parent, false))
            }

            VIEW_TYPE_AGENT -> {
                AgentViewHolder(ItemTranscriptAgentBinding.inflate(LayoutInflater.from(parent.context), parent, false))
            }

            else -> throw IllegalArgumentException("Unknown view type: $viewType")
        }
    }

    override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
        val transcript = getItem(position)
        when (holder) {
            is UserViewHolder -> holder.bind(transcript)
            is AgentViewHolder -> holder.bind(transcript)
        }
    }

    class UserViewHolder(private val binding: ItemTranscriptUserBinding) : RecyclerView.ViewHolder(binding.root) {
        private val tvType: TextView = binding.tvTranscriptType
        private val tvText: TextView = binding.tvTranscriptText
        private val tvStatus: TextView = binding.tvTranscriptStatus

        fun bind(transcript: Transcript) {
            // Set transcript type with color for USER
            tvType.text = "USER"
            ContextCompat.getDrawable(binding.root.context, R.drawable.bg_type_badge)?.let { drawable ->
                drawable.setTint("#10B981".toColorInt())
                tvType.background = drawable
            }

            // Set transcript text
            tvText.text = transcript.text.ifEmpty { "(empty)" }

            // Set transcript status with color
            val (statusText, statusColor) = when (transcript.status) {
                TranscriptStatus.IN_PROGRESS -> "IN PROGRESS" to "#FF9800".toColorInt()
                TranscriptStatus.END -> "END" to "#4CAF50".toColorInt()
                TranscriptStatus.INTERRUPTED -> "INTERRUPTED" to "#F44336".toColorInt()
                TranscriptStatus.UNKNOWN -> "UNKNOWN" to "#9E9E9E".toColorInt()
            }
            tvStatus.text = statusText
            tvStatus.setTextColor(statusColor)
        }
    }

    class AgentViewHolder(private val binding: ItemTranscriptAgentBinding) : RecyclerView.ViewHolder(binding.root) {
        private val tvType: TextView = binding.tvTranscriptType
        private val tvText: TextView = binding.tvTranscriptText
        private val tvStatus: TextView = binding.tvTranscriptStatus

        fun bind(transcript: Transcript) {
            // Set transcript type with color for AGENT
            tvType.text = "AGENT"
            ContextCompat.getDrawable(binding.root.context, R.drawable.bg_type_badge)?.let { drawable ->
                drawable.setTint("#6366F1".toColorInt())
                tvType.background = drawable
            }

            // Set transcript text
            tvText.text = transcript.text.ifEmpty { "(empty)" }

            // Set transcript status with color
            val (statusText, statusColor) = when (transcript.status) {
                TranscriptStatus.IN_PROGRESS -> "IN PROGRESS" to "#FF9800".toColorInt()
                TranscriptStatus.END -> "END" to "#4CAF50".toColorInt()
                TranscriptStatus.INTERRUPTED -> "INTERRUPTED" to "#F44336".toColorInt()
                TranscriptStatus.UNKNOWN -> "UNKNOWN" to "#9E9E9E".toColorInt()
            }
            tvStatus.text = statusText
            tvStatus.setTextColor(statusColor)
        }
    }

    private class TranscriptDiffCallback : DiffUtil.ItemCallback<Transcript>() {
        override fun areItemsTheSame(oldItem: Transcript, newItem: Transcript): Boolean {
            return oldItem.turnId == newItem.turnId && oldItem.type == newItem.type
        }

        override fun areContentsTheSame(oldItem: Transcript, newItem: Transcript): Boolean {
            return oldItem == newItem
        }
    }
}


