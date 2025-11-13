package io.agora.convoai.example.compose.voiceassistant.ui

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.times
import kotlin.math.PI
import kotlin.math.sin
import kotlin.random.Random

/**
 * Agent Speaking Indicator
 * Four bars, wave-like random animation
 * @param scale Scale factor for all dimensions (default: 1.0f)
 */
@Composable
@Preview
fun VoiceWaveView(
    modifier: Modifier = Modifier,
    isAnimating: Boolean = false,
    color: Color = Color.White,
    scale: Float = 1.0f
) {
    val barCount = 4
    val baseBarWidth = 6.dp
    val baseBarSpacing = 8.dp
    val baseBarCornerRadius = 3.dp
    val baseBarHeightMin = 6.dp
    val baseBarHeightMax = 15.dp
    
    val barWidth = (baseBarWidth * scale)
    val barSpacing = (baseBarSpacing * scale)
    val barCornerRadius = (baseBarCornerRadius * scale)
    val barHeightMin = (baseBarHeightMin * scale)
    val barHeightMax = (baseBarHeightMax * scale)

    val animationDuration = 1400 // ms
    val phaseDriftPerFrame = 0.018f

    // Animation state
    val infiniteTransition = rememberInfiniteTransition(label = "voice_wave")
    val animationProgress by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(animationDuration, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "progress"
    )

    // Phase offsets for each bar
    val phaseOffsets = remember { FloatArray(barCount) { Random.nextFloat() * 2f * PI.toFloat() } }
    
    // Bar heights (stored as normalized values 0.0-1.0, will be converted to pixels in Canvas)
    val barHeights = remember { mutableStateListOf<Float>().apply {
        repeat(barCount) { add(0f) } // Start at minimum (0.0 = min height)
    }}

    // Update bar heights when animating
    LaunchedEffect(isAnimating, animationProgress) {
        if (isAnimating) {
            for (i in 0 until barCount) {
                // Update phase offset with drift
                phaseOffsets[i] = (phaseOffsets[i] + phaseDriftPerFrame) % (2f * PI.toFloat())
                
                // Calculate wave height (normalized 0.0-1.0)
                val wave = sin(2 * PI * (animationProgress + phaseOffsets[i])).toFloat()
                val normalized = ((wave + 1f) / 2f) // Convert from [-1, 1] to [0, 1]
                
                // Add random jitter
                val jitter = Random.nextFloat() * 2f - 1f // [-1, 1]
                val jitterAmplitude = 0.1f // 10% jitter
                val height = (normalized + jitter * jitterAmplitude).coerceIn(0f, 1f)
                
                barHeights[i] = height
            }
        } else {
            // Reset to min height when not animating
            for (i in 0 until barCount) {
                barHeights[i] = 0f
            }
        }
    }

    Canvas(
        modifier = modifier
            .size(
                width = (barCount * barWidth + (barCount - 1) * barSpacing),
                height = barHeightMax * 1.2f // Add extra height to prevent clipping and ensure proper aspect ratio
            )
    ) {
        val centerY = size.height / 2f
        val barWidthPx = barWidth.toPx()
        val barSpacingPx = barSpacing.toPx()
        val barCornerRadiusPx = barCornerRadius.toPx()
        val totalWidth = barCount * barWidthPx + (barCount - 1) * barSpacingPx
        val startX = (size.width - totalWidth) / 2f

        // Convert Dp to pixels for height calculations
        val barHeightMinPx = barHeightMin.toPx()
        val barHeightMaxPx = barHeightMax.toPx()
        
        for (i in 0 until barCount) {
            val barX = startX + i * (barWidthPx + barSpacingPx)
            // Convert normalized height (0.0-1.0) to actual pixel height
            val normalizedHeight = barHeights[i]
            val currentBarHeight = barHeightMinPx + (barHeightMaxPx - barHeightMinPx) * normalizedHeight
            val barTop = centerY - currentBarHeight / 2f

            drawRoundRect(
                color = color,
                topLeft = Offset(barX, barTop),
                size = Size(barWidthPx, currentBarHeight),
                cornerRadius = CornerRadius(barCornerRadiusPx, barCornerRadiusPx)
            )
        }
    }
}

