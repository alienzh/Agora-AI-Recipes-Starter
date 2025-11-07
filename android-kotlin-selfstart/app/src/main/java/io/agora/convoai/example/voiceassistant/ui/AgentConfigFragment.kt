package io.agora.convoai.example.voiceassistant.ui

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.activityViewModels
import io.agora.convoai.example.voiceassistant.ui.common.SnackbarHelper
import io.agora.convoai.example.voiceassistant.R
import androidx.lifecycle.lifecycleScope
import androidx.navigation.fragment.findNavController
import io.agora.convoai.example.voiceassistant.KeyCenter
import io.agora.convoai.example.voiceassistant.databinding.FragmentAgentConfigBinding
import io.agora.convoai.example.voiceassistant.ui.common.BaseFragment
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.random.Random

class AgentConfigFragment : BaseFragment<FragmentAgentConfigBinding>() {

    private val viewModel: ConversationViewModel by activityViewModels()
    private var hasNavigated = false
    private val statusHistory = mutableListOf<String>()
    private var lastStatusMessage = ""

    override fun getViewBinding(inflater: LayoutInflater, container: ViewGroup?): FragmentAgentConfigBinding? {
        return FragmentAgentConfigBinding.inflate(inflater, container, false)
    }

    override fun initView() {
        mBinding?.apply {
            setOnApplyWindowInsets(root)

            // Display App ID first 5 characters
            val appIdPrefix = KeyCenter.AGORA_APP_ID.take(5) + "***"
            tvAppId.text = appIdPrefix

            // Display Pipeline ID first 5 characters
            val pipelineIdPrefix = KeyCenter.PIPELINE_ID.take(5) + "***"
            tvPipelineId.text = pipelineIdPrefix

            // Generate random channel name for joining (client-side start)
            val randomChannelName = "android_kotlin_selfstart_${Random.nextInt(10000, 100000000)}"
            etChannel.setText(randomChannelName)

            btnStarter.setOnClickListener {
                val channelName = etChannel.text?.toString()?.trim() ?: ""

                // Clear status history when starting new connection
                statusHistory.clear()
                lastStatusMessage = ""
                updateStatusDisplay()

                // Check microphone permission before joining channel
                val mainActivity = activity as? MainActivity ?: return@setOnClickListener
                mainActivity.checkMicrophonePermission { granted ->
                    if (granted) {
                        viewModel.joinChannelAndLogin(channelName)
                    } else {
                        SnackbarHelper.showError(
                            this@AgentConfigFragment,
                            "Microphone permission is required to join channel"
                        )
                    }
                }
            }
        }

        // Observe UI state changes
        observeUiState()
    }

    private fun observeUiState() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewModel.uiState.collect { state ->
                mBinding?.apply {
                    // Reset hasNavigated flag when disconnected (after hangup)
                    if (state.connectionState != ConversationViewModel.ConnectionState.Connected && hasNavigated) {
                        hasNavigated = false
                    }

                    // Update status - accumulate status messages for history
                    updateStatusMessage(state)

                    // Update loading state
                    btnStarter.isEnabled = state.connectionState != ConversationViewModel.ConnectionState.Connecting
                    progressBar.visibility =
                        if (state.connectionState == ConversationViewModel.ConnectionState.Connecting) View.VISIBLE else View.GONE

                    // Show error via Snackbar if status message contains error keywords
                    if (state.connectionState != ConversationViewModel.ConnectionState.Connecting &&
                        state.statusMessage.isNotEmpty() &&
                        (state.statusMessage.contains("error", ignoreCase = true) ||
                                state.statusMessage.contains("failed", ignoreCase = true))
                    ) {
                        SnackbarHelper.showError(this@AgentConfigFragment, state.statusMessage)
                    }

                    // Check if agent start failed, show error and navigate back after 3s
                    if (state.agentStartFailed && !hasNavigated) {
                        SnackbarHelper.showError(
                            this@AgentConfigFragment,
                            "Agent启动失败: ${state.statusMessage}"
                        )
                        // Delay 3s and navigate back to first page
                        launch {
                            delay(3000)
                            if (isAdded && !hasNavigated) {
                                findNavController().popBackStack()
                            }
                        }
                        return@apply
                    }

                    // Navigate to voice assistant when agent is started successfully (only once)
                    if (state.connectionState == ConversationViewModel.ConnectionState.Connected && !hasNavigated
                    ) {
                        hasNavigated = true
                        findNavController().navigate(R.id.action_agentConfig_to_voiceAssistant)
                    }
                }
            }
        }
    }

    /**
     * Update status message - accumulate status messages for history
     * Only show when connecting, hide when idle/connected/disconnected
     */
    private fun updateStatusMessage(state: ConversationViewModel.ConversationUiState) {
        // Add new status message to history if it's different from the last one
        if (state.connectionState == ConversationViewModel.ConnectionState.Connecting &&
            state.statusMessage.isNotEmpty() &&
            state.statusMessage != lastStatusMessage
        ) {
            statusHistory.add(state.statusMessage)
            lastStatusMessage = state.statusMessage
        }

        // Clear history when disconnected or idle
        if (state.connectionState == ConversationViewModel.ConnectionState.Idle ||
            state.connectionState == ConversationViewModel.ConnectionState.Disconnected
        ) {
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
        }
    }
}

