package io.agora.convoai.example.compose.voiceassistant.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import io.agora.convoai.example.compose.voiceassistant.ui.ConversationViewModel.ConnectionState
import io.agora.scene.convoai.convoaiApi.AgentState
import io.agora.scene.convoai.convoaiApi.Transcript
import io.agora.scene.convoai.convoaiApi.TranscriptStatus
import io.agora.scene.convoai.convoaiApi.TranscriptType
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VoiceAssistantScreen(
    viewModel: ConversationViewModel = viewModel(),
    onNavigateBack: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    val transcriptList by viewModel.transcriptList.collectAsState()
    val agentState by viewModel.agentState.collectAsState()
    
    val statusHistory = remember { mutableStateListOf<String>() }
    var lastStatusMessage by remember { mutableStateOf("") }
    
    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    // Update status history
    LaunchedEffect(uiState.statusMessage, uiState.connectionState) {
        // Filter out operational messages (mute, transcript, etc.)
        val shouldShowMessage = when {
            uiState.statusMessage.contains("muted", ignoreCase = true) -> false
            uiState.statusMessage.contains("unmuted", ignoreCase = true) -> false
            uiState.statusMessage.contains("Transcript", ignoreCase = true) -> false
            uiState.statusMessage.contains("Agent joined", ignoreCase = true) -> false
            uiState.statusMessage.contains("Agent left", ignoreCase = true) -> false
            else -> true
        }

        // Add new status message to history if it should be shown and is different from the last one
        if (shouldShowMessage &&
            uiState.statusMessage.isNotEmpty() &&
            uiState.statusMessage != lastStatusMessage
        ) {
            statusHistory.add(uiState.statusMessage)
            lastStatusMessage = uiState.statusMessage
        }

        // Clear history when disconnected or idle
        if (uiState.connectionState == ConnectionState.Idle ||
            uiState.connectionState == ConnectionState.Disconnected
        ) {
            statusHistory.clear()
            lastStatusMessage = ""
        }
    }

    // Navigate back when disconnected
    LaunchedEffect(uiState.connectionState) {
        if (uiState.connectionState == ConnectionState.Disconnected) {
            onNavigateBack()
        }
    }

    // Scroll to bottom when new transcript is added
    LaunchedEffect(transcriptList.size) {
        if (transcriptList.isNotEmpty()) {
            scope.launch {
                listState.animateScrollToItem(transcriptList.size - 1)
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Voice Assistant") },
                navigationIcon = {
                    IconButton(onClick = { viewModel.hangup() }) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Channel info
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant
                )
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    if (uiState.channelName.isNotEmpty()) {
                        Text(
                            text = "Channel: ${uiState.channelName}",
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                    if (uiState.userUid != 0) {
                        Text(
                            text = "UserId: ${uiState.userUid}",
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                    if (uiState.agentUid != 0) {
                        Text(
                            text = "AgentUid: ${uiState.agentUid}",
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }

            // Status display
            if (statusHistory.isNotEmpty()) {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = 120.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant
                    )
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp)
                    ) {
                        Text(
                            text = statusHistory.joinToString("\n"),
                            style = MaterialTheme.typography.bodySmall,
                            color = when {
                                statusHistory.joinToString("\n").contains("successfully", ignoreCase = true) ||
                                        statusHistory.joinToString("\n").contains("initialized", ignoreCase = true) ||
                                        statusHistory.joinToString("\n").contains("joined", ignoreCase = true) -> {
                                    Color(0xFF4CAF50)
                                }
                                statusHistory.joinToString("\n").contains("error", ignoreCase = true) ||
                                        statusHistory.joinToString("\n").contains("failed", ignoreCase = true) ||
                                        statusHistory.joinToString("\n").contains("left", ignoreCase = true) -> {
                                    Color(0xFFF44336)
                                }
                                else -> {
                                    Color(0xFF666666)
                                }
                            }
                        )
                    }
                }
            }

            // Transcript list or voice wave indicator
            if (uiState.isTranscriptEnabled) {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant
                    )
                ) {
                    LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        items(transcriptList) { transcript ->
                            TranscriptItem(transcript = transcript)
                        }
                    }
                }
            } else {
                // Voice wave indicator
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                    contentAlignment = Alignment.Center
                ) {
                    VoiceWaveView(
                        modifier = Modifier,
                        isAnimating = agentState == AgentState.SPEAKING,
                        color = MaterialTheme.colorScheme.primary,
                        scale = 5f // Scale up by 5x for better visibility
                    )
                }
            }

            // Control buttons
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Mute button
                FloatingActionButton(
                    onClick = { viewModel.toggleMute() },
                    modifier = Modifier.weight(1f),
                    containerColor = if (uiState.isMuted) {
                        MaterialTheme.colorScheme.errorContainer
                    } else {
                        MaterialTheme.colorScheme.primaryContainer
                    },
                    contentColor = if (uiState.isMuted) {
                        MaterialTheme.colorScheme.onErrorContainer
                    } else {
                        MaterialTheme.colorScheme.onPrimaryContainer
                    }
                ) {
                    Text(
                        text = if (uiState.isMuted) "🔇" else "🎤",
                        style = MaterialTheme.typography.titleLarge
                    )
                }

                // Transcript toggle button
                FloatingActionButton(
                    onClick = { viewModel.toggleTranscript() },
                    modifier = Modifier.weight(1f),
                    containerColor = if (uiState.isTranscriptEnabled) {
                        MaterialTheme.colorScheme.primaryContainer
                    } else {
                        MaterialTheme.colorScheme.surfaceVariant
                    },
                    contentColor = if (uiState.isTranscriptEnabled) {
                        MaterialTheme.colorScheme.onPrimaryContainer
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    }
                ) {
                    Text(
                        text = if (uiState.isTranscriptEnabled) "📝" else "📄",
                        style = MaterialTheme.typography.titleLarge
                    )
                }

                // Hangup button
                FloatingActionButton(
                    onClick = { viewModel.hangup() },
                    modifier = Modifier.weight(1f),
                    containerColor = MaterialTheme.colorScheme.errorContainer,
                    contentColor = MaterialTheme.colorScheme.onErrorContainer
                ) {
                    Icon(
                        imageVector = Icons.Default.Phone,
                        contentDescription = "Hangup"
                    )
                }
            }
        }
    }
}

@Composable
fun TranscriptItem(transcript: Transcript) {
    val (typeColor, typeText) = when (transcript.type) {
        TranscriptType.USER -> Color(0xFF10B981) to "USER"
        TranscriptType.AGENT -> Color(0xFF6366F1) to "AGENT"
        else -> Color(0xFF9E9E9E) to "UNKNOWN"
    }

    val (statusColor, statusText) = when (transcript.status) {
        TranscriptStatus.IN_PROGRESS -> Color(0xFFFF9800) to "IN PROGRESS"
        TranscriptStatus.END -> Color(0xFF4CAF50) to "END"
        TranscriptStatus.INTERRUPTED -> Color(0xFFF44336) to "INTERRUPTED"
        TranscriptStatus.UNKNOWN -> Color(0xFF9E9E9E) to "UNKNOWN"
    }

    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        )
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Type badge
                Text(
                    text = typeText,
                    modifier = Modifier
                        .background(
                            color = typeColor,
                            shape = RoundedCornerShape(4.dp)
                        )
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )

                Spacer(modifier = Modifier.weight(1f))

                // Status badge
                Text(
                    text = statusText,
                    style = MaterialTheme.typography.labelSmall,
                    color = statusColor,
                    fontWeight = FontWeight.Bold
                )
            }

            // Transcript text
            Text(
                text = transcript.text.ifEmpty { "(empty)" },
                style = MaterialTheme.typography.bodyMedium
            )
        }
    }
}

