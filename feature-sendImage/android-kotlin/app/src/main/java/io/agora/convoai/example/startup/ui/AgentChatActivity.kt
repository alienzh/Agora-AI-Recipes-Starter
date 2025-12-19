package io.agora.convoai.example.startup.ui

import android.content.Context
import android.util.Log
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.ViewTreeObserver
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
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
import android.widget.ImageView
import com.bumptech.glide.Glide
import com.bumptech.glide.load.engine.DiskCacheStrategy

/**
 * Activity for agent chat interface
 * Layout: log, agent status, transcript, start/control buttons
 */
class AgentChatActivity : BaseActivity<ActivityAgentChatBinding>() {

    companion object {
        private const val TAG = "AgentChatActivity"
    }

    private lateinit var viewModel: AgentChatViewModel
    private lateinit var mPermissionHelp: PermissionHelp
    private val transcriptAdapter: TranscriptAdapter = TranscriptAdapter()

    // Track whether to automatically scroll to bottom
    private var autoScrollToBottom = true
    private var isScrollBottom = false

    // Keyboard layout listener
    private var keyboardLayoutListener: ViewTreeObserver.OnGlobalLayoutListener? = null
    
    // Store original bottom padding of transcript list (not used anymore)
    private var originalTranscriptBottomPadding = 12

    override fun getViewBinding(): ActivityAgentChatBinding {
        return ActivityAgentChatBinding.inflate(layoutInflater)
    }

    override fun initData() {
        super.initData()
        viewModel = ViewModelProvider(this)[AgentChatViewModel::class.java]
        mPermissionHelp = PermissionHelp(this)

        // Observe UI state changes
        observeUiState()

        // Observe transcript list changes
        observeTranscriptList()

        // Observe debug log changes
        observeDebugLogs()

        // Observe image message success
        observeImageMessageSuccess()

        // Observe image message error
        observeImageMessageError()
    }

    override fun initView() {
        mBinding?.apply {
            // Set window insets listener but only handle system bars, not keyboard
            ViewCompat.setOnApplyWindowInsetsListener(root) { v, insets ->
                val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
                // Only apply top, left, right padding for system bars, not bottom (to avoid keyboard interference)
                v.setPaddingRelative(
                    systemBars.left + v.paddingLeft,
                    systemBars.top,
                    systemBars.right + v.paddingRight,
                    v.paddingBottom // Keep original bottom padding, don't add system bar bottom
                )
                insets
            }

            // Setup RecyclerView for transcript list
            setupRecyclerView()
            
            // Store original bottom padding (not used anymore, but kept for compatibility)
            originalTranscriptBottomPadding = rvTranscript.paddingBottom

            // Start button click listener
            btnStart.setOnClickListener {
                // Generate random channel name each time joining channel
                val channelName = AgentChatViewModel.generateRandomChannelName()

                // Check microphone permission before joining channel
                checkMicrophonePermission { granted ->
                    if (granted) {
                        viewModel.joinChannelAndLogin(channelName)
                    } else {
                        Toast.makeText(
                            this@AgentChatActivity,
                            "Microphone permission is required to join channel",
                            Toast.LENGTH_LONG
                        ).show()
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

            // Set default image URL
            etImageUrl.setText("https://gips2.baidu.com/it/u=195724436,3554684702&fm=3028&app=3028&f=JPEG&fmt=auto?w=1280&h=960")

            // Listen for keyboard enter key and send button
            etImageUrl.setOnEditorActionListener { _, actionId, event ->
                if (actionId == EditorInfo.IME_ACTION_SEND ||
                    (event != null && event.keyCode == KeyEvent.KEYCODE_ENTER && event.action == KeyEvent.ACTION_DOWN)
                ) {
                    sendImageMessage()
                    true
                } else {
                    false
                }
            }

            // Click listener to show keyboard when input field is clicked
            etImageUrl.setOnClickListener {
                etImageUrl.requestFocus()
                showKeyboard(etImageUrl)
            }

            // Handle click on the message input card to show keyboard
            llMessageInput.setOnClickListener {
                etImageUrl.requestFocus()
                showKeyboard(etImageUrl)
            }

            // Listen for input field focus to scroll to bottom when keyboard appears
            etImageUrl.setOnFocusChangeListener { view, hasFocus ->
                if (hasFocus) {
                    // Show keyboard when focus is gained
                    showKeyboard(view)
                    // Delay to ensure keyboard animation completes
                    root.postDelayed({
                        scrollToBottom()
                        // Also scroll RecyclerView to show latest messages
                        rvTranscript.post {
                            val lastPosition = transcriptAdapter.itemCount - 1
                            if (lastPosition >= 0) {
                                rvTranscript.smoothScrollToPosition(lastPosition)
                            }
                        }
                    }, 200)
                }
            }

            // Listen for layout changes to handle keyboard show/hide
            keyboardLayoutListener = object : ViewTreeObserver.OnGlobalLayoutListener {
                private var wasKeyboardVisible = false

                override fun onGlobalLayout() {
                    val rect = android.graphics.Rect()
                    root.getWindowVisibleDisplayFrame(rect)
                    val screenHeight = root.rootView.height
                    val keypadHeight = screenHeight - rect.bottom
                    
                    // Keyboard is considered visible if height difference > 15% of screen height
                    val isKeyboardVisible = keypadHeight > screenHeight * 0.15

                    if (isKeyboardVisible != wasKeyboardVisible) {
                        wasKeyboardVisible = isKeyboardVisible
                        
                        if (isKeyboardVisible) {
                            // Calculate input field position to determine how much to move
                            val inputLocation = IntArray(2)
                            llBottomContainer.getLocationOnScreen(inputLocation)
                            val inputTop = inputLocation[1]
                            val inputBottom = inputLocation[1] + llBottomContainer.height
                            
                            // Get cardTranscript position
                            val cardTranscriptLocation = IntArray(2)
                            cardTranscript.getLocationOnScreen(cardTranscriptLocation)
                            val cardTranscriptBottom = cardTranscriptLocation[1] + cardTranscript.height
                            
                            // Calculate keyboard top position
                            val keyboardTop = screenHeight - keypadHeight
                            
                            // Calculate overlap - how much the input field is obscured
                            val overlap = inputBottom - keyboardTop
                            
                            // Calculate translation: move up by overlap + some margin (8dp)
                            val margin = (8 * resources.displayMetrics.density).toInt()
                            val translationY = if (overlap > 0) {
                                -(overlap + margin).toFloat()
                            } else {
                                // No overlap, but still move up to ensure input is clearly visible
                                -keypadHeight.toFloat()
                            }
                            
                            // Calculate how much cardTranscript needs to move up to avoid blocking input
                            // After input moves up, its new top will be: inputTop + translationY
                            val newInputTop = inputTop + translationY
                            // Card should move up so its bottom is above the new input top with some margin
                            val cardMargin = (8 * resources.displayMetrics.density).toInt()
                            val cardTargetBottom = newInputTop - cardMargin
                            val cardTranslationY = cardTargetBottom - cardTranscriptBottom
                            
                            // Move both input field and cardTranscript up
                            llBottomContainer.animate()
                                .translationY(translationY)
                                .setDuration(250L)
                                .start()
                            
                            cardTranscript.animate()
                                .translationY(cardTranslationY)
                                .setDuration(250L)
                                .start()
                            
                            // Scroll to bottom
                            root.postDelayed({
                                scrollToBottom()
                                rvTranscript.post {
                                    val lastPosition = transcriptAdapter.itemCount - 1
                                    if (lastPosition >= 0) {
                                        rvTranscript.smoothScrollToPosition(lastPosition)
                                    }
                                }
                            }, 100)
                        } else {
                            // Keyboard hidden, restore input field and cardTranscript position
                            llBottomContainer.animate()
                                .translationY(0f)
                                .setDuration(250L)
                                .start()
                            
                            cardTranscript.animate()
                                .translationY(0f)
                                .setDuration(250L)
                                .start()
                        }
                    }
                }
            }
            keyboardLayoutListener?.let {
                root.viewTreeObserver.addOnGlobalLayoutListener(it)
            }
        }
    }

    /**
     * Show keyboard for the given view
     */
    private fun showKeyboard(view: View) {
        view.post {
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.showSoftInput(view, InputMethodManager.SHOW_IMPLICIT)
        }
    }

    /**
     * Hide keyboard
     */
    private fun hideKeyboard(view: View) {
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        imm.hideSoftInputFromWindow(view.windowToken, 0)
    }

    /**
     * Send image message from input field
     */
    private fun sendImageMessage() {
        mBinding?.etImageUrl?.let { editText ->
            val imageUrl = editText.text?.toString()?.trim()
            if (!imageUrl.isNullOrBlank()) {
                // Generate UUID for the image message
                val uuid = "img_${System.currentTimeMillis()}"
                viewModel.sendImageMessage(
                    uuid = uuid,
                    imageUrl = imageUrl,
                    imageBase64 = null
                ) { error ->
                    if (error != null) {
                        Toast.makeText(
                            this@AgentChatActivity,
                            "Failed to send image: ${error.errorMessage}",
                            Toast.LENGTH_SHORT
                        ).show()
                    }
                }
                // Don't clear the input, keep the URL for easy resending
                // Hide keyboard after sending
                hideKeyboard(editText)
            } else {
                Toast.makeText(
                    this@AgentChatActivity,
                    "Please enter an image URL",
                    Toast.LENGTH_SHORT
                ).show()
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

                    // Show/hide buttons
                    llStart.visibility = if (isConnected) View.GONE else View.VISIBLE
                    llBottomContainer.visibility = if (isConnected) View.VISIBLE else View.GONE
                    // Update button loading state
                    if (isConnecting) {
                        btnStart.text = "Starting..."
                        btnStart.isEnabled = false
                    } else {
                        btnStart.text = "Start Agent"
                        btnStart.isEnabled = true
                    }

                    // Update mute button UI
                    btnMute.setImageResource(
                        if (state.isMuted) R.drawable.ic_mic_off else R.drawable.ic_mic
                    )
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
     * Observe image message success
     */
    private fun observeImageMessageSuccess() {
        lifecycleScope.launch {
            viewModel.mediaInfoUpdate.collect { pictureInfo ->
                pictureInfo?.let {
                    // Add image message to transcript list
                    // sourceValue contains the image URL when sourceType is "url"
                    val imageUrl = it.sourceValue
                    
                    if (imageUrl.isNotEmpty()) {
                        viewModel.addImageMessageToTranscript(imageUrl, it.uuid)
                        Log.d(TAG, "Image message added to transcript: $imageUrl")
                    } else {
                        Log.w(TAG, "Image message success but no URL found in PictureInfo (uuid: ${it.uuid})")
                    }
                    // Clear the update to avoid duplicate processing
                    viewModel.clearMediaInfoUpdate()
                }
            }
        }
    }

    /**
     * Observe image message error
     */
    private fun observeImageMessageError() {
        lifecycleScope.launch {
            viewModel.resourceError.collect { pictureError ->
                pictureError?.let {
                    Toast.makeText(
                        this@AgentChatActivity,
                        "Failed to send image: ${it.errorMessage ?: "Unknown error"}",
                        Toast.LENGTH_LONG
                    ).show()
                    // Clear the error to avoid duplicate processing
                    viewModel.clearResourceError()
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Remove keyboard layout listener to prevent memory leak
        mBinding?.root?.let { root ->
            keyboardLayoutListener?.let { listener ->
                root.viewTreeObserver.removeOnGlobalLayoutListener(listener)
            }
        }
        keyboardLayoutListener = null
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
        private val ivImage: ImageView = binding.ivTranscriptImage
        private val tvStatus: TextView = binding.tvTranscriptStatus

        fun bind(transcript: Transcript) {
            // Set transcript type badge with green color for USER
            tvType.text = "USER"
            ContextCompat.getDrawable(binding.root.context, R.drawable.bg_type_badge)?.let { drawable ->
                drawable.setTint("#10B981".toColorInt())
                tvType.background = drawable
            }

            // Check if transcript text is an image URL
            val text = transcript.text
            val isImageUrl = text.startsWith("http://") || text.startsWith("https://")

            if (isImageUrl) {
                // Show image, hide text and status
                tvText.visibility = View.GONE
                ivImage.visibility = View.VISIBLE
                tvStatus.visibility = View.GONE
                
                // Load image using Glide
                Glide.with(binding.root.context)
                    .load(text)
                    .diskCacheStrategy(DiskCacheStrategy.ALL)
                    .placeholder(android.R.drawable.ic_menu_gallery)
                    .error(android.R.drawable.ic_dialog_alert)
                    .into(ivImage)
            } else {
                // Show text and status, hide image
                tvText.visibility = View.VISIBLE
                ivImage.visibility = View.GONE
                tvStatus.visibility = View.VISIBLE
                tvText.text = text.ifEmpty { "(empty)" }

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


