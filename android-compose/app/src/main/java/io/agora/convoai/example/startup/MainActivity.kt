package io.agora.convoai.example.startup

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import io.agora.convoai.example.startup.tools.PermissionHelp
import io.agora.convoai.example.startup.ui.AgentChatScreen
import io.agora.convoai.example.startup.ui.theme.AgentstarterconvoaicomposeTheme

class MainActivity : ComponentActivity() {
    private lateinit var permissionHelp: PermissionHelp

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        permissionHelp = PermissionHelp(this)
        setContent {
            AgentstarterconvoaicomposeTheme {
                VoiceAssistantApp(
                    permissionHelp = permissionHelp
                )
            }
        }
    }
}

@Composable
fun VoiceAssistantApp(permissionHelp: PermissionHelp) {
    AgentChatScreen(permissionHelp = permissionHelp)
}
