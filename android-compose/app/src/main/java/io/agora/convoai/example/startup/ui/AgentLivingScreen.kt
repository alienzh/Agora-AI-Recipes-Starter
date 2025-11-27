package io.agora.convoai.example.startup.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import io.agora.convoai.convoaiApi.Transcript
import io.agora.convoai.convoaiApi.TranscriptStatus
import io.agora.convoai.convoaiApi.TranscriptType
import kotlinx.coroutines.launch
import android.util.Log
import kotlinx.coroutines.flow.first

private const val TAG = "VoiceAssistantScreen"

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AgentLivingScreen(
    viewModel: ConversationViewModel = viewModel(),
    onNavigateBack: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    val transcriptList by viewModel.transcriptList.collectAsState()
    val agentState by viewModel.agentState.collectAsState()

    val listState = rememberLazyListState()
    val scope = rememberCoroutineScope()

    // Track whether to automatically scroll to bottom
    var autoScrollToBottom by remember { mutableStateOf(true) }

    // Handle hangup
    fun handleHangup() {
        Log.d(TAG, "[handleHangup] Called - starting hangup process")
        viewModel.hangup()

        // Wait for hangup to complete (connectionState becomes Idle) then navigate back
        scope.launch {
            try {
                // Wait for state to become Idle
                viewModel.uiState.first { it.connectionState == ConversationViewModel.ConnectionState.Idle }
                onNavigateBack()
                Log.d(TAG, "[handleHangup] onNavigateBack() completed successfully")
            } catch (e: Exception) {
                Log.e(TAG, "[handleHangup] Error waiting for hangup or navigating: ${e.message}", e)
            }
        }
    }

    // Track scroll state and update autoScrollToBottom
    LaunchedEffect(listState.isScrollInProgress) {
        if (!listState.isScrollInProgress) {
            // Check if at bottom when scrolling stops
            val canScrollForward = listState.canScrollForward
            if (!canScrollForward) {
                autoScrollToBottom = true
            }
        }
    }

    // Track user scroll gestures to disable auto-scroll
    LaunchedEffect(listState.firstVisibleItemIndex, listState.firstVisibleItemScrollOffset) {
        if (listState.isScrollInProgress) {
            // Check if user is scrolling up (can scroll forward means not at bottom)
            val canScrollForward = listState.canScrollForward
            if (canScrollForward) {
                autoScrollToBottom = false
            }
        }
    }

    // Scroll to bottom when new transcript is added
    LaunchedEffect(transcriptList) {
        if (transcriptList.isNotEmpty() && autoScrollToBottom) {
            scope.launch {
                scrollToBottom(listState, transcriptList.size)
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Agent Living") },
                navigationIcon = {
                    IconButton(onClick = {
                        handleHangup()
                    }) {
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
                .padding(start = 16.dp, end = 16.dp, bottom = 16.dp, top = 4.dp),
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
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    if (uiState.channelName.isNotEmpty()) {
                        Text(
                            text = "Channel: ${uiState.channelName}",
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                    if (uiState.userUid != 0) {
                        Text(
                            text = "UserId: ${uiState.userUid}",
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                    if (uiState.agentUid != 0) {
                        Text(
                            text = "AgentUid: ${uiState.agentUid}",
                            style = MaterialTheme.typography.bodySmall
                        )
                    }

                    // Agent status
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "Agent Status:",
                            style = MaterialTheme.typography.bodySmall
                        )
                        Text(
                            text = agentState?.value ?: "Unknown",
                            style = MaterialTheme.typography.bodySmall,
                            fontWeight = FontWeight.Bold,
                            color = if (agentState?.value == "speaking") 
                                MaterialTheme.colorScheme.primary 
                            else 
                                MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            // Transcript list
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

                // Hangup button
                FloatingActionButton(
                    onClick = {
                        handleHangup()
                    },
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
                style = MaterialTheme.typography.bodySmall
            )
        }
    }
}

/**
 * Scroll to bottom of the list
 * Reference: Kotlin version scrollToBottom() method
 */
private suspend fun scrollToBottom(listState: LazyListState, itemCount: Int) {
    val lastPosition = itemCount - 1
    if (lastPosition < 0) return

    // First jump to target position
    listState.scrollToItem(lastPosition)

    // Handle extra-long messages within the same coroutine
    // In Compose, we check if the last item extends beyond the viewport
    val layoutInfo = listState.layoutInfo
    val lastVisibleItem = layoutInfo.visibleItemsInfo.lastOrNull()

    if (lastVisibleItem != null && lastVisibleItem.index == lastPosition) {
        // Check if the last item extends beyond viewport (extra-long message)
        val viewportHeight = layoutInfo.viewportEndOffset - layoutInfo.viewportStartOffset
        val itemEndOffset = lastVisibleItem.offset + lastVisibleItem.size
        val viewportEndOffset = layoutInfo.viewportEndOffset

        // If item extends beyond viewport, ensure scrolling to bottom
        if (itemEndOffset > viewportEndOffset) {
            // For extra-long messages, calculate offset to align bottom of item with bottom of viewport
            // Similar to Kotlin version: offset = height - lastView.height
            // In Compose, scrollOffset is the offset from item top to viewport top
            // To align item bottom with viewport bottom: offset = viewportHeight - itemSize
            val offset = viewportHeight - lastVisibleItem.size
            if (offset < 0) {
                // Only apply offset if item is taller than viewport
                listState.scrollToItem(lastPosition, scrollOffset = offset)
            }
        }
    }
}
