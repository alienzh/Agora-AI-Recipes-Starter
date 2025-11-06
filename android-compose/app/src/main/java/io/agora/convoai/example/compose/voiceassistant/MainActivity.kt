package io.agora.convoai.example.compose.voiceassistant

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import io.agora.convoai.example.compose.voiceassistant.tools.PermissionHelp
import io.agora.convoai.example.compose.voiceassistant.ui.AgentConfigScreen
import io.agora.convoai.example.compose.voiceassistant.ui.ConversationViewModel
import io.agora.convoai.example.compose.voiceassistant.ui.VoiceAssistantScreen
import io.agora.convoai.example.compose.voiceassistant.ui.theme.AgentstarterconvoaicomposeTheme

class MainActivity : ComponentActivity() {
    private lateinit var permissionHelp: PermissionHelp

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        permissionHelp = PermissionHelp(this)
        setContent {
            AgentstarterconvoaicomposeTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    VoiceAssistantApp(
                        permissionHelp = permissionHelp
                    )
                }
            }
        }
    }
}

@Composable
fun VoiceAssistantApp(
    permissionHelp: PermissionHelp
) {
    val navController = rememberNavController()
    val viewModel: ConversationViewModel = viewModel()

    NavHost(
        navController = navController,
        startDestination = "agent_config"
    ) {
        composable("agent_config") {
            AgentConfigScreen(
                viewModel = viewModel,
                permissionHelp = permissionHelp,
                onNavigateToVoiceAssistant = {
                    navController.navigate("voice_assistant") {
                        popUpTo("agent_config") { inclusive = false }
                    }
                }
            )
        }
        composable("voice_assistant") {
            VoiceAssistantScreen(
                viewModel = viewModel,
                onNavigateBack = {
                    navController.popBackStack()
                }
            )
        }
    }
}
