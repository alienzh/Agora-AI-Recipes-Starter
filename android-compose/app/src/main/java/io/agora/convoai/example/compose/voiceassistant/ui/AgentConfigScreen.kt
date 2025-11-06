package io.agora.convoai.example.compose.voiceassistant.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import io.agora.convoai.example.compose.voiceassistant.KeyCenter
import io.agora.convoai.example.compose.voiceassistant.ui.ConversationViewModel.ConnectionState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AgentConfigScreen(
    viewModel: ConversationViewModel = viewModel(),
    permissionHelp: io.agora.convoai.example.compose.voiceassistant.tools.PermissionHelp,
    onNavigateToVoiceAssistant: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    var channelName by remember { mutableStateOf(ConversationViewModel.defaultChannel) }
    var hasNavigated by remember { mutableStateOf(false) }
    var showPermissionDialog by remember { mutableStateOf(false) }

    // Reset hasNavigated flag when disconnected
    LaunchedEffect(uiState.connectionState) {
        if (uiState.connectionState != ConnectionState.Connected && hasNavigated) {
            hasNavigated = false
        }
    }

    // Navigate to voice assistant when connected
    LaunchedEffect(uiState.connectionState) {
        if (uiState.connectionState == ConnectionState.Connected && !hasNavigated) {
            hasNavigated = true
            onNavigateToVoiceAssistant()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Agent Configuration") }
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
            // App ID display
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant
                )
            ) {
                Column(
                    modifier = Modifier.padding(16.dp)
                ) {
                    Text(
                        text = "App ID",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = KeyCenter.AGORA_APP_ID.take(5) + "***",
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = FontWeight.Bold
                    )
                }
            }

            // Channel name input
            OutlinedTextField(
                value = channelName,
                onValueChange = { channelName = it },
                label = { Text("Channel Name") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )

            // Status display (only show when connecting)
            if (uiState.connectionState == ConnectionState.Connecting) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant
                    )
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp)
                    ) {
                        Text(
                            text = "Status",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = uiState.statusMessage,
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }

            // Start button
            Button(
                onClick = {
                    if (permissionHelp.hasMicPerm()) {
                        viewModel.joinChannelAndLogin(channelName.trim())
                    } else {
                        permissionHelp.checkMicPerm(
                            granted = {
                                viewModel.joinChannelAndLogin(channelName.trim())
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
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        color = MaterialTheme.colorScheme.onPrimary
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Connecting...")
                } else {
                    Text("Start")
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
                                        viewModel.joinChannelAndLogin(channelName.trim())
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

            // Error message display
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
        }
    }
}

