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
    val baseBarWidth = 5.dp
    val baseBarSpacing = 6.dp
    val baseBarCornerRadius = 3.dp
    val baseBarHeightMin = 5.dp
    val baseBarHeightMax = 12.dp
    
    val barWidth = baseBarWidth * scale
    val barSpacing = baseBarSpacing * scale
    val barCornerRadius = baseBarCornerRadius * scale
    val barHeightMin = baseBarHeightMin * scale
    val barHeightMax = baseBarHeightMax * scale

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
    
    // Bar heights
    val barHeights = remember { mutableStateListOf<Float>().apply {
        repeat(barCount) { add(barHeightMin.value) }
    }}

    // Update bar heights when animating
    LaunchedEffect(isAnimating, animationProgress) {
        if (isAnimating) {
            for (i in 0 until barCount) {
                // Update phase offset with drift
                phaseOffsets[i] = (phaseOffsets[i] + phaseDriftPerFrame) % (2f * PI.toFloat())
                
                // Calculate wave height
                val wave = sin(2 * PI * (animationProgress + phaseOffsets[i])).toFloat()
                val base = barHeightMin.value + (barHeightMax.value - barHeightMin.value) * ((wave + 1f) / 2f)
                
                // Add random jitter
                val jitter = Random.nextFloat() * 2f - 1f // [-1, 1]
                val baseJitterAmplitude = 2f.dp.value
                val jitterAmplitude = baseJitterAmplitude * scale
                val height = (base + jitter * jitterAmplitude).coerceIn(barHeightMin.value, barHeightMax.value)
                
                barHeights[i] = height
            }
        } else {
            // Reset to min height when not animating
            for (i in 0 until barCount) {
                barHeights[i] = barHeightMin.value
            }
        }
    }

    Canvas(
        modifier = modifier
            .size(
                width = (barCount * barWidth.value + (barCount - 1) * barSpacing.value).dp,
                height = barHeightMax * 1.5f // Add extra height to prevent clipping and ensure proper aspect ratio
            )
    ) {
        val centerY = size.height / 2f
        val totalWidth = barCount * barWidth.toPx() + (barCount - 1) * barSpacing.toPx()
        val startX = (size.width - totalWidth) / 2f

        for (i in 0 until barCount) {
            val barX = startX + i * (barWidth.toPx() + barSpacing.toPx())
            val currentBarHeight = barHeights[i]
            val barTop = centerY - currentBarHeight / 2f

            drawRoundRect(
                color = color,
                topLeft = Offset(barX, barTop),
                size = Size(barWidth.toPx(), currentBarHeight),
                cornerRadius = CornerRadius(barCornerRadius.toPx(), barCornerRadius.toPx())
            )
        }
    }
}

