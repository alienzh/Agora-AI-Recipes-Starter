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
    val agentUid: Int?,
    val avatarUid: Int?
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
        gravity = android.view.Gravity.TOP
        val padding = (12 * resources.displayMetrics.density).toInt()
        setPadding(padding, padding, padding, padding)
        
        // Setup text change listener for channel name to enable/disable button
        binding.etChannelName.addTextChangedListener {
            updateButtonState()
        }
        
        // Setup join button click listener
        binding.btnJoinChannel.setOnClickListener {
            handleJoinChannel()
        }
        
        // Set default values
        binding.etChannelName.setText("channel_avatar_001")
        binding.etUserId.setText("1001")
        binding.etAgentUid.setText("2001")
        binding.etAvatarUid.setText("3001")
        
        // Initially disable button
        updateButtonState()
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
        val avatarUidText = binding.etAvatarUid.text?.toString()?.trim()

        val userId = userIdText?.toIntOrNull()
        val agentUid = agentUidText?.toIntOrNull()
        val avatarUid = avatarUidText?.toIntOrNull()

        val inputData = ChannelInputData(
            channelName = channelName,
            userId = userId,
            agentUid = agentUid,
            avatarUid = avatarUid
        )

        onJoinChannelListener?.onJoinChannel(inputData)
    }
}

