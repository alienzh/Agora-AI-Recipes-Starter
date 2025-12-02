package io.agora.convoai.example.startup.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material3.*
import androidx.compose.ui.draw.clip
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.platform.LocalContext
import androidx.activity.compose.BackHandler
import androidx.lifecycle.viewmodel.compose.viewModel
import android.app.Activity
import io.agora.convoai.convoaiApi.Transcript
import io.agora.convoai.convoaiApi.TranscriptStatus
import io.agora.convoai.convoaiApi.TranscriptType
import io.agora.convoai.example.startup.tools.PermissionHelp
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AgentChatScreen(
    viewModel: AgentChatViewModel = viewModel(),
    permissionHelp: PermissionHelp
) {
    val context = LocalContext.current
    val activity = context as? Activity

    // Handle back button/gesture to finish activity
    BackHandler {
        activity?.finish()
    }

    val uiState by viewModel.uiState.collectAsState()
    val transcriptList by viewModel.transcriptList.collectAsState()
    val agentState by viewModel.agentState.collectAsState()
    val debugLogList by viewModel.debugLogList.collectAsState()

    val listState = rememberLazyListState()
    val logScrollState = rememberScrollState()
    val scope = rememberCoroutineScope()

    var showPermissionDialog by remember { mutableStateOf(false) }

    // Track whether to automatically scroll to bottom
    var autoScrollToBottom by remember { mutableStateOf(true) }

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

    // Auto scroll log to bottom
    LaunchedEffect(debugLogList) {
        if (debugLogList.isNotEmpty()) {
            scope.launch {
                logScrollState.animateScrollTo(logScrollState.maxValue)
            }
        }
    }

    // Background gradient matching Kotlin version
    val gradientBrush = Brush.linearGradient(
        colors = listOf(
            Color(0xFF6366F1), // startColor
            Color(0xFF8B5CF6), // centerColor
            Color(0xFFEC4899)  // endColor
        ),
        start = androidx.compose.ui.geometry.Offset(0f, 0f),
        end = androidx.compose.ui.geometry.Offset(1000f, 1000f) // 135 degree angle approximation
    )

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        containerColor = Color.Transparent,
        contentWindowInsets = WindowInsets(0.dp)
    ) { _ ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(gradientBrush)
                .windowInsetsPadding(WindowInsets.statusBars)
                .windowInsetsPadding(WindowInsets.navigationBars)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Log Section
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(120.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = Color.White
                    ),
                    shape = RoundedCornerShape(12.dp),
                    elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(12.dp)
                    ) {
                        Text(
                            text = if (debugLogList.isNotEmpty()) {
                                debugLogList.joinToString("\n")
                            } else {
                                "log"
                            },
                            modifier = Modifier
                                .weight(1f)
                                .verticalScroll(logScrollState),
                            style = MaterialTheme.typography.bodySmall.copy(fontSize = 12.sp),
                            fontFamily = FontFamily.Monospace,
                            color = Color(0xFF666666)
                        )
                    }
                }

                // Transcript List and Agent Status (combined in one card)
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                        .padding(bottom = 16.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = Color.White
                    ),
                    shape = RoundedCornerShape(12.dp),
                    elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
                ) {
                    Column(
                        modifier = Modifier.fillMaxSize()
                    ) {
                        // Transcript List
                        LazyColumn(
                            state = listState,
                            modifier = Modifier.weight(1f),
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 12.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            items(transcriptList) { transcript ->
                                TranscriptItem(transcript = transcript)
                            }
                        }

                        // Agent Status Section (at bottom of transcript area)
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                            horizontalArrangement = Arrangement.Center,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "Agent Status:",
                                style = MaterialTheme.typography.bodySmall.copy(fontSize = 14.sp),
                                color = Color(0xFF666666)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = agentState?.value ?: "Unknown",
                                style = MaterialTheme.typography.bodySmall.copy(fontSize = 14.sp),
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF666666)
                            )
                        }
                    }
                }

                // Control Buttons
                val isConnected = uiState.connectionState == AgentChatViewModel.ConnectionState.Connected
                val isConnecting = uiState.connectionState == AgentChatViewModel.ConnectionState.Connecting

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 16.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Mute button - 64dp icon button (shown when connected)
                    if (isConnected) {
                        IconButton(
                            onClick = { viewModel.toggleMute() },
                            modifier = Modifier.size(64.dp)
                        ) {
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .background(
                                        color = Color(0xFFF4CAF50),
                                        shape = RoundedCornerShape(12.dp)
                                    ),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = if (uiState.isMuted) "🔇" else "🎤",
                                    fontSize = 24.sp
                                )
                            }
                        }

                        Spacer(modifier = Modifier.width(24.dp))
                    }

                    // Start Button (shown when not connected)
                    Button(
                        onClick = {
                            // Generate random channel name each time joining channel
                            val channelName = AgentChatViewModel.generateRandomChannelName()
                            if (permissionHelp.hasMicPerm()) {
                                viewModel.joinChannelAndLogin(channelName)
                            } else {
                                permissionHelp.checkMicPerm(
                                    granted = {
                                        viewModel.joinChannelAndLogin(channelName)
                                    },
                                    unGranted = {
                                        showPermissionDialog = true
                                    }
                                )
                            }
                        },
                        modifier = Modifier
                            .then(
                                if (isConnected) {
                                    Modifier.width(0.dp).height(64.dp)
                                } else {
                                    Modifier.fillMaxWidth().height(64.dp)
                                }
                            ),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Color.Transparent
                        ),
                        shape = RoundedCornerShape(16.dp),
                        elevation = ButtonDefaults.buttonElevation(defaultElevation = 8.dp),
                        contentPadding = PaddingValues(0.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .fillMaxHeight()
                                .background(brush = gradientBrush, shape = RoundedCornerShape(16.dp)),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = if (isConnecting) "Starting..." else "Start Agent",
                                fontSize = 18.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color.White,
                                letterSpacing = 0.02.sp
                            )
                        }
                    }

                    // Stop button - MaterialButton with red background (shown when connected)
                    if (isConnected) {
                        Button(
                            onClick = { viewModel.hangup() },
                            modifier = Modifier
                                .weight(2f)
                                .height(64.dp),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Color(0xFFF44336) // Red color
                            ),
                            shape = RoundedCornerShape(16.dp),
                            elevation = ButtonDefaults.buttonElevation(defaultElevation = 8.dp),
                            contentPadding = PaddingValues(0.dp)
                        ) {
                            Text(
                                text = "Stop Agent",
                                fontSize = 18.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color.White,
                                letterSpacing = 0.02.sp
                            )
                        }
                    }
                }
            }
        }
    }

    // Permission dialog
    if (showPermissionDialog) {
        AlertDialog(
            onDismissRequest = { showPermissionDialog = false },
            title = {
                Text("Permission Required")
            },
            text = {
                Text("Microphone permission is required for voice chat. Please grant the permission to continue.")
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showPermissionDialog = false
                        permissionHelp.launchAppSettingForMic(
                            granted = {
                                val channelName = AgentChatViewModel.generateRandomChannelName()
                                viewModel.joinChannelAndLogin(channelName)
                            },
                            unGranted = {
                                // Permission still not granted
                            }
                        )
                    }
                ) {
                    Text("Retry")
                }
            },
            dismissButton = {
                TextButton(
                    onClick = { showPermissionDialog = false }
                ) {
                    Text("Exit")
                }
            }
        )
    }
}

@Composable
fun TranscriptItem(transcript: Transcript) {
    val (typeColor, typeText) = when (transcript.type) {
        TranscriptType.USER -> Color(0xFF10B981) to "USER"
        TranscriptType.AGENT -> Color(0xFF6366F1) to "AGENT"
    }

    val (statusColor, statusText) = when (transcript.status) {
        TranscriptStatus.IN_PROGRESS -> Color(0xFFFF9800) to "IN PROGRESS"
        TranscriptStatus.END -> Color(0xFF4CAF50) to "END"
        TranscriptStatus.INTERRUPTED -> Color(0xFFF44336) to "INTERRUPTED"
        TranscriptStatus.UNKNOWN -> Color(0xFF9E9E9E) to "UNKNOWN"
    }

    // Determine alignment based on transcript type
    val isUser = transcript.type == TranscriptType.USER
    val horizontalAlignment = if (isUser) Alignment.End else Alignment.Start

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start
    ) {
        Card(
            modifier = Modifier.widthIn(max = 280.dp), // Limit max width for better readability
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant
            )
        ) {
            Column(
                modifier = Modifier.padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                horizontalAlignment = horizontalAlignment
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (!isUser) {
                        // Type badge for AGENT (on the left)
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
                        Spacer(modifier = Modifier.width(8.dp))
                    }

                    // Status badge
                    Text(
                        text = statusText,
                        style = MaterialTheme.typography.labelSmall,
                        color = statusColor,
                        fontWeight = FontWeight.Bold
                    )

                    if (isUser) {
                        Spacer(modifier = Modifier.width(8.dp))
                        // Type badge for USER (on the right)
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
                    }
                }

                // Transcript text
                Text(
                    text = transcript.text.ifEmpty { "(empty)" },
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}

/**
 * Scroll to bottom of the list
 */
private suspend fun scrollToBottom(listState: LazyListState, itemCount: Int) {
    val lastPosition = itemCount - 1
    if (lastPosition < 0) return

    // First jump to target position
    listState.scrollToItem(lastPosition)

    // Handle extra-long messages within the same coroutine
    val layoutInfo = listState.layoutInfo
    val lastVisibleItem = layoutInfo.visibleItemsInfo.lastOrNull()

    if (lastVisibleItem != null && lastVisibleItem.index == lastPosition) {
        // Check if the last item extends beyond viewport (extra-long message)
        val viewportHeight = layoutInfo.viewportEndOffset - layoutInfo.viewportStartOffset
        val itemEndOffset = lastVisibleItem.offset + lastVisibleItem.size
        val viewportEndOffset = layoutInfo.viewportEndOffset

        // If item extends beyond viewport, ensure scrolling to bottom
        if (itemEndOffset > viewportEndOffset) {
            val offset = viewportHeight - lastVisibleItem.size
            if (offset < 0) {
                // Only apply offset if item is taller than viewport
                listState.scrollToItem(lastPosition, scrollOffset = offset)
            }
        }
    }
}

