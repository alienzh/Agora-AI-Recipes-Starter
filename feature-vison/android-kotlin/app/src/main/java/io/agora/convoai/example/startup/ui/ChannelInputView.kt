package io.agora.convoai.example.startup.ui

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.widget.LinearLayout
import androidx.core.widget.addTextChangedListener
import io.agora.convoai.example.startup.databinding.ViewChannelInputBinding

/**
 * Data class for channel input
 */
data class ChannelInputData(
    val channelName: String,
    val userId: Int?,
    val agentUid: Int?
)

/**
 * Callback interface for join channel action
 */
interface OnJoinChannelListener {
    fun onJoinChannel(data: ChannelInputData)
}

/**
 * Custom view for channel input with all input fields and join button
 */
class ChannelInputView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : LinearLayout(context, attrs, defStyleAttr) {

    private val binding: ViewChannelInputBinding =
        ViewChannelInputBinding.inflate(LayoutInflater.from(context), this)

    var onJoinChannelListener: OnJoinChannelListener? = null

    init {
        orientation = VERTICAL
        gravity = android.view.Gravity.CENTER
        val padding = (16 * resources.displayMetrics.density).toInt()
        setPadding(padding, padding, padding, padding)
        
        // Setup text change listener for channel name to enable/disable button
        binding.etChannelName.addTextChangedListener {
            updateButtonState()
        }
        
        // Setup join button click listener
        binding.btnJoinChannel.setOnClickListener {
            handleJoinChannel()
        }
        
        // Initially disable button
        updateButtonState()
    }

    /**
     * Load saved channel name and fill input field
     */
    fun loadSavedChannelName(channelName: String?) {
        channelName?.takeIf { it.isNotEmpty() }?.let {
            binding.etChannelName.setText(it)
        }
    }
    
    /**
     * Load saved UIDs and fill input fields
     */
    fun loadSavedUIDs(userId: Int?, agentUid: Int?) {
        userId?.let {
            if (it > 0) {
                binding.etUserId.setText(it.toString())
            }
        }
        agentUid?.let {
            if (it > 0) {
                binding.etAgentUid.setText(it.toString())
            }
        }
    }

    /**
     * Update button enabled state based on channel name
     */
    private fun updateButtonState() {
        val channelName = binding.etChannelName.text?.toString()?.trim() ?: ""
        binding.btnJoinChannel.isEnabled = channelName.isNotEmpty()
    }

    /**
     * Handle join channel button click
     */
    private fun handleJoinChannel() {
        val channelName = binding.etChannelName.text?.toString()?.trim() ?: ""
        val userIdText = binding.etUserId.text?.toString()?.trim()
        val agentUidText = binding.etAgentUid.text?.toString()?.trim()

        val userId = userIdText?.toIntOrNull()
        val agentUid = agentUidText?.toIntOrNull()

        val inputData = ChannelInputData(
            channelName = channelName,
            userId = userId,
            agentUid = agentUid
        )

        onJoinChannelListener?.onJoinChannel(inputData)
    }
}

