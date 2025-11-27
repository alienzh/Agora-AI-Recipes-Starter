package io.agora.convoai.example.startup.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import io.agora.convoai.example.startup.KeyCenter
import io.agora.convoai.example.startup.tools.PermissionHelp
import io.agora.convoai.example.startup.ui.ConversationViewModel.ConnectionState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AgentHomeScreen(
    viewModel: ConversationViewModel = viewModel(),
    permissionHelp: PermissionHelp,
    onNavigateToVoiceAssistant: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    var hasNavigated by remember { mutableStateOf(false) }
    var showPermissionDialog by remember { mutableStateOf(false) }

    // Reset hasNavigated flag when disconnected
    LaunchedEffect(uiState.connectionState) {
        if (uiState.connectionState != ConnectionState.Connected && hasNavigated) {
            hasNavigated = false
        }
    }

    // Navigate to voice assistant when connected AND agent started
    LaunchedEffect(uiState.connectionState, uiState.agentStarted) {
        if (uiState.agentStarted && uiState.connectionState == ConnectionState.Connected && !hasNavigated) {
            hasNavigated = true
            onNavigateToVoiceAssistant()
        }
    }

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("Startup Compose", style = MaterialTheme.typography.titleLarge)
                        Text(
                            "Start your conversational AI agent",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
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
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // App ID and Pipeline ID display
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant
                )
            ) {
                Column(
                    modifier = Modifier.padding(16.dp)
                ) {
                    // App ID Section
                    Text(
                        text = "App ID",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = KeyCenter.AGORA_APP_ID.take(5) + "***",
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace
                    )

                    Spacer(modifier = Modifier.height(16.dp))
                    HorizontalDivider()
                    Spacer(modifier = Modifier.height(16.dp))

                    // Pipeline ID Section
                    Text(
                        text = "Pipeline ID",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = KeyCenter.PIPELINE_ID.take(5) + "***",
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace
                    )
                }
            }

            // Start button
            Button(
                onClick = {
                    // Generate random channel name each time joining channel
                    val channelName = ConversationViewModel.generateRandomChannelName()
                    if (permissionHelp.hasMicPerm()) {
                        viewModel.joinChannelAndLogin(channelName)
                    } else {
                        permissionHelp.checkMicPerm(
                            granted = {
                                viewModel.joinChannelAndLogin(channelName)
                            },
                            unGranted = {
                                // Show permission dialog when permission is denied
                                showPermissionDialog = true
                            }
                        )
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                enabled = uiState.connectionState != ConnectionState.Connecting
            ) {
                if (uiState.connectionState == ConnectionState.Connecting) {
                    // Text only loading state as requested
                    Text("Starting...")
                } else {
                    Text("Start Agent")
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            // Error message display (only show critical errors)
            if (uiState.connectionState != ConnectionState.Connecting &&
                uiState.statusMessage.isNotEmpty() &&
                (uiState.statusMessage.contains("error", ignoreCase = true) ||
                        uiState.statusMessage.contains("failed", ignoreCase = true))
            ) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.errorContainer
                    )
                ) {
                    Text(
                        text = uiState.statusMessage,
                        modifier = Modifier.padding(16.dp),
                        color = MaterialTheme.colorScheme.onErrorContainer
                    )
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
                                        val channelName = ConversationViewModel.generateRandomChannelName()
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
    }
}
