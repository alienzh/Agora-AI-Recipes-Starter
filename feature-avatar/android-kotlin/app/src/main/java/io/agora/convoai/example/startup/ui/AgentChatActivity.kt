package io.agora.convoai.example.startup.ui

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import android.widget.Toast
import androidx.constraintlayout.widget.ConstraintLayout
import androidx.core.content.ContextCompat
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import io.agora.convoai.example.startup.R
import io.agora.convoai.example.startup.databinding.ActivityAgentChatBinding
import io.agora.convoai.example.startup.databinding.ItemTranscriptAgentBinding
import io.agora.convoai.example.startup.databinding.ItemTranscriptUserBinding
import io.agora.convoai.example.startup.ui.common.BaseActivity
import io.agora.convoai.convoaiApi.Transcript
import io.agora.convoai.convoaiApi.TranscriptStatus
import io.agora.convoai.convoaiApi.TranscriptType
import kotlinx.coroutines.launch
import kotlin.text.ifEmpty
import androidx.core.graphics.toColorInt
import io.agora.convoai.example.startup.tools.PermissionHelp

/**
 * Activity for agent chat interface
 * Layout: log, agent status, transcript, start/control buttons
 */
class AgentChatActivity : BaseActivity<ActivityAgentChatBinding>() {

    private lateinit var viewModel: AgentChatViewModel
    private lateinit var mPermissionHelp: PermissionHelp
    private val transcriptAdapter: TranscriptAdapter = TranscriptAdapter()

    // Track whether to automatically scroll to bottom
    private var autoScrollToBottom = true
    private var isScrollBottom = false

    // Avatar video display state
    private var isAvatarExpanded = false
    private val avatarViewSmallWidth = 120  // dp
    private val avatarViewSmallHeight = 160  // dp

    override fun getViewBinding(): ActivityAgentChatBinding {
        return ActivityAgentChatBinding.inflate(layoutInflater)
    }

    override fun initData() {
        super.initData()
        viewModel = ViewModelProvider(this)[AgentChatViewModel::class.java]
        mPermissionHelp = PermissionHelp(this)
        
        // Load saved UIDs and fill input fields
        loadSavedUIDs()

        // Observe UI state changes
        observeUiState()

        // Observe transcript list changes
        observeTranscriptList()

        // Observe debug log changes
        observeDebugLogs()

        // Observe avatar joined state
        observeAvatarJoined()
    }

    override fun initView() {
        mBinding?.apply {
            setOnApplyWindowInsetsListener(root)

            // Setup RecyclerView for transcript list
            setupRecyclerView()

            // Setup ChannelInputView callback
            channelInputView.onJoinChannelListener = object : OnJoinChannelListener {
                override fun onJoinChannel(data: ChannelInputData) {
                    // Generate random channel name each time joining channel
                    val channelName = data.channelName.ifEmpty { 
                        AgentChatViewModel.generateRandomChannelName() 
                    }
                    
                    // Validate UIDs
                    if (data.userId == null || data.userId <= 0) {
                        viewModel.addStatusLog("ERROR: 用户UID不能为空")
                        return
                    }
                    if (data.agentUid == null || data.agentUid <= 0) {
                        viewModel.addStatusLog("ERROR: Agent UID不能为空")
                        return
                    }
                    if (data.avatarUid == null || data.avatarUid <= 0) {
                        viewModel.addStatusLog("ERROR: Avatar UID不能为空")
                        return
                    }

                    // Check microphone permission before joining channel
                    checkMicrophonePermission { granted ->
                        if (granted) {
                            viewModel.joinChannelAndLogin(channelName, data.userId, data.agentUid, data.avatarUid)
                        } else {
                            Toast.makeText(
                                this@AgentChatActivity,
                                "Microphone permission is required to join channel",
                                Toast.LENGTH_LONG
                            ).show()
                        }
                    }
                }
            }

            // Mute button click listener
            btnMute.setOnClickListener {
                viewModel.toggleMute()
            }

            // Stop button click listener
            btnStop.setOnClickListener {
                viewModel.hangup()
            }

            // Avatar video container click listener - expand/collapse
            avatarVideoContainer.setOnClickListener {
                val state = viewModel.uiState.value
                val isConnected = state.connectionState == AgentChatViewModel.ConnectionState.Connected
                if (isConnected) {
                    toggleAvatarSize()
                }
            }
        }
    }

    private fun checkMicrophonePermission(granted: (Boolean) -> Unit) {
        if (mPermissionHelp.hasMicPerm()) {
            granted.invoke(true)
        } else {
            mPermissionHelp.checkMicPerm(
                granted = { granted.invoke(true) },
                unGranted = {
                    showPermissionDialog(
                        "Permission Required",
                        "Microphone permission is required for voice chat. Please grant the permission to continue.",
                        onResult = {
                            if (it) {
                                mPermissionHelp.launchAppSettingForMic(
                                    granted = { granted.invoke(true) },
                                    unGranted = { granted.invoke(false) }
                                )
                            } else {
                                granted.invoke(false)
                            }
                        }
                    )
                }
            )
        }
    }

    private fun showPermissionDialog(title: String, content: String, onResult: (Boolean) -> Unit) {
        if (isFinishing || isDestroyed || supportFragmentManager.isStateSaved) return

        CommonDialog.Builder()
            .setTitle(title)
            .setContent(content)
            .setPositiveButton("Retry") {
                onResult.invoke(true)
            }
            .setNegativeButton("Exit") {
                onResult.invoke(false)
            }
            .setCancelable(false)
            .build()
            .show(supportFragmentManager, "permission_dialog")
    }

    private fun handleStop() {
        viewModel.hangup()
    }

    /**
     * Setup RecyclerView for transcript list
     */
    private fun setupRecyclerView() {
        mBinding?.rvTranscript?.apply {
            layoutManager = LinearLayoutManager(this@AgentChatActivity).apply {
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

    private fun observeUiState() {
        lifecycleScope.launch {
            viewModel.uiState.collect { state ->
                mBinding?.apply {
                    // Update button visibility based on connection state
                    val isConnected = state.connectionState == AgentChatViewModel.ConnectionState.Connected
                    val isConnecting = state.connectionState == AgentChatViewModel.ConnectionState.Connecting
                    val isIdle = state.connectionState == AgentChatViewModel.ConnectionState.Idle

                    // Show/hide views based on connection state
                    scrollView.visibility = if (isConnected) View.GONE else View.VISIBLE
                    cardTranscript.visibility = if (isConnected) View.VISIBLE else View.GONE
                    llControls.visibility = if (isConnected) View.VISIBLE else View.GONE
                    // Button state is managed by ChannelInputView

                    // Update mute button UI
                    btnMute.setImageResource(
                        if (state.isMuted) R.drawable.ic_mic_off else R.drawable.ic_mic
                    )

                    // Auto collapse avatar view when agent stops
                    if (isIdle && isAvatarExpanded) {
                        isAvatarExpanded = false
                        updateAvatarViewSize()
                    }
                }
            }
        }

        // Observe agent state
        lifecycleScope.launch {
            viewModel.agentState.collect { agentState ->
                mBinding?.apply {
                    agentState?.let {
                        // Update agent status text using state.value
                        tvAgentStatus.text = it.value
                    } ?: run {
                        // Agent state is null, show default text
                        tvAgentStatus.text = "Unknown"
                    }
                }
            }
        }
    }

    private fun observeTranscriptList() {
        lifecycleScope.launch {
            viewModel.transcriptList.collect { transcriptList ->
                // Update transcript list
                transcriptAdapter.submitList(transcriptList)
                if (autoScrollToBottom) {
                    scrollToBottom()
                }
            }
        }
    }

    private fun observeDebugLogs() {
        lifecycleScope.launch {
            viewModel.debugLogList.collect { logList ->
                mBinding?.apply {
                    // Update log text with all logs, separated by newlines
                    tvLog.text = logList.joinToString("\n").ifEmpty { "log" }
                    // Auto scroll to bottom
                    tvLog.post {
                        val scrollView = tvLog.parent as? android.widget.ScrollView
                        scrollView?.fullScroll(android.view.View.FOCUS_DOWN)
                    }
                }
            }
        }
    }

    /**
     * Observe avatar joined state to setup remote video
     */
    private fun observeAvatarJoined() {
        lifecycleScope.launch {
            viewModel.avatarJoined.collect { joined ->
                if (joined) {
                    setupAvatarVideo()
                } else {
                    hideAvatarVideo()
                }
            }
        }
    }

    /**
     * Setup avatar video view when avatar joins the channel
     */
    private fun setupAvatarVideo() {
        mBinding?.apply {
            // Setup remote video rendering using the SurfaceView in layout
            viewModel.setupRemoteVideo(avatarVideoView)

            // Show avatar video container
            avatarVideoContainer.visibility = View.VISIBLE
            isAvatarExpanded = false
            updateAvatarViewSize()
        }
    }

    /**
     * Hide avatar video when disconnected
     */
    private fun hideAvatarVideo() {
        mBinding?.apply {
            avatarVideoContainer.visibility = View.GONE
            isAvatarExpanded = false
            updateAvatarViewSize()
        }
    }

    /**
     * Toggle avatar video size between small and expanded
     */
    private fun toggleAvatarSize() {
        isAvatarExpanded = !isAvatarExpanded
        updateAvatarViewSize()
    }

    /**
     * Update avatar video view size based on expanded state
     * When expanded: cover the entire transcript area
     * When collapsed: small window at top-right corner of transcript area
     */
    private fun updateAvatarViewSize() {
        mBinding?.let { binding ->
            val container = binding.avatarVideoContainer
            val params = container.layoutParams as ConstraintLayout.LayoutParams
            val density = resources.displayMetrics.density

            if (isAvatarExpanded) {
                // Expanded: match cardTranscript size (cover entire transcript area)
                params.width = 0  // match_constraint
                params.height = 0  // match_constraint
                params.topToTop = binding.cardTranscript.id
                params.bottomToBottom = binding.cardTranscript.id
                params.startToStart = binding.cardTranscript.id
                params.endToEnd = binding.cardTranscript.id
                params.topMargin = 0
                params.marginEnd = 0
                params.marginStart = 0
                params.bottomMargin = 0
                // Corner radius is handled by drawable background
            } else {
                // Collapsed: small window at top-right corner
                params.width = (avatarViewSmallWidth * density).toInt()
                params.height = (avatarViewSmallHeight * density).toInt()
                params.topToTop = binding.cardTranscript.id
                params.bottomToBottom = ConstraintLayout.LayoutParams.UNSET
                params.startToStart = ConstraintLayout.LayoutParams.UNSET
                params.endToEnd = binding.cardTranscript.id
                val margin = (8 * density).toInt()
                params.topMargin = margin
                params.marginEnd = margin
                // Corner radius is handled by drawable background
            }
            container.layoutParams = params
        }
    }

    /**
     * Load saved channel name and UIDs and fill input fields
     */
    private fun loadSavedUIDs() {
        val (savedChannelName, uids) = viewModel.loadSavedChannelNameAndUIDs()
        val (savedUserId, savedAgentUid, savedAvatarUid) = uids
        mBinding?.channelInputView?.apply {
            loadSavedChannelName(savedChannelName)
            loadSavedUIDs(savedUserId, savedAgentUid, savedAvatarUid)
        }
    }
    
    /**
     * Scroll RecyclerView to the bottom to show latest transcript
     */
    private fun scrollToBottom() {
        mBinding?.rvTranscript?.apply {
            val lastPosition = transcriptAdapter.itemCount - 1
            if (lastPosition < 0) return

            stopScroll()
            val layoutManager = layoutManager as? LinearLayoutManager ?: return

            // Use single post call to handle all scrolling logic
            post {
                layoutManager.scrollToPosition(lastPosition)

                // Handle extra-long messages that exceed viewport height
                val lastView = layoutManager.findViewByPosition(lastPosition)
                if (lastView != null && lastView.height > height) {
                    val offset = height - lastView.height
                    layoutManager.scrollToPositionWithOffset(lastPosition, offset)
                }

                isScrollBottom = true
            }
        }
    }
}

/**
 * Adapter for displaying transcript list with different view types for USER and AGENT
 */
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

    /**
     * ViewHolder for USER transcript items
     */
    class UserViewHolder(private val binding: ItemTranscriptUserBinding) : RecyclerView.ViewHolder(binding.root) {
        private val tvType: TextView = binding.tvTranscriptType
        private val tvText: TextView = binding.tvTranscriptText
        private val tvStatus: TextView = binding.tvTranscriptStatus

        fun bind(transcript: Transcript) {
            // Set transcript type badge with green color for USER
            tvType.text = "USER"
            ContextCompat.getDrawable(binding.root.context, R.drawable.bg_type_badge)?.let { drawable ->
                drawable.setTint("#10B981".toColorInt())
                tvType.background = drawable
            }

            // Set transcript text
            tvText.text = transcript.text.ifEmpty { "(empty)" }

            // Set transcript status with appropriate color
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

    /**
     * ViewHolder for AGENT transcript items
     */
    class AgentViewHolder(private val binding: ItemTranscriptAgentBinding) : RecyclerView.ViewHolder(binding.root) {
        private val tvType: TextView = binding.tvTranscriptType
        private val tvText: TextView = binding.tvTranscriptText
        private val tvStatus: TextView = binding.tvTranscriptStatus

        fun bind(transcript: Transcript) {
            // Set transcript type badge with indigo color for AGENT
            tvType.text = "AGENT"
            ContextCompat.getDrawable(binding.root.context, R.drawable.bg_type_badge)?.let { drawable ->
                drawable.setTint("#6366F1".toColorInt())
                tvType.background = drawable
            }

            // Set transcript text
            tvText.text = transcript.text.ifEmpty { "(empty)" }

            // Set transcript status with appropriate color
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


