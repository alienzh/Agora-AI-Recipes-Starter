/**
 * Voice Wave View Component
 * Four bars with wave-like random animation for agent speaking indicator
 */
@Component
@Preview
export struct VoiceWaveView {
  @State private barHeights: number[] = [5, 5, 5, 5];
  @State private animationProgress: number = 0;
  private phaseOffsets: number[] = [0, 0, 0, 0];
  private isAnimating: boolean = false;
  private animationTimer: number | null = null;
  private startTime: number = 0;

  // Constants
  private readonly BAR_COUNT = 4;
  private readonly BAR_WIDTH = 8; // Increased from 5 for better visibility
  private readonly BAR_SPACING = 8; // Increased from 6 for better spacing
  private readonly BAR_CORNER_RADIUS = 4; // Increased from 3 for better appearance
  private readonly BAR_HEIGHT_MIN = 8; // Increased from 5 for better visibility
  private readonly BAR_HEIGHT_MAX = 24; // Increased from 12 for better visibility
  private readonly ANIMATION_DURATION = 1400; // ms
  private readonly PHASE_DRIFT_PER_FRAME = 0.018;
  private readonly JITTER_AMPLITUDE = 0.5;
  private readonly ANIMATION_INTERVAL = 16; // ~60fps

  aboutToAppear(): void {
    // Initialize phase offsets with random values
    for (let i = 0; i < this.BAR_COUNT; i++) {
      this.phaseOffsets[i] = Math.random() * 2 * Math.PI;
    }
    // Start animation when component appears (will be shown only when agent is speaking)
    this.startAnimation();
  }

  aboutToDisappear(): void {
    this.stopAnimation();
  }

  /**
   * Start wave animation
   * Public method to be called from parent component
   */
  startAnimation(): void {
    if (this.isAnimating) {
      return;
    }
    this.isAnimating = true;
    this.animate();
  }

  /**
   * Stop animation and reset bars to min height
   */
  stopAnimation(): void {
    this.isAnimating = false;
    if (this.animationTimer !== null) {
      clearInterval(this.animationTimer);
      this.animationTimer = null;
    }
    for (let i = 0; i < this.BAR_COUNT; i++) {
      this.barHeights[i] = this.BAR_HEIGHT_MIN;
    }
  }

  private animate(): void {
    if (!this.isAnimating) {
      return;
    }

    this.startTime = Date.now();
    
    const animateFrame = () => {
      if (!this.isAnimating) {
        return;
      }

      const currentTime = Date.now();
      const elapsed = currentTime - this.startTime;
      this.animationProgress = (elapsed % this.ANIMATION_DURATION) / this.ANIMATION_DURATION;
      this.updateBarHeights();
    };

    // Use setInterval instead of requestAnimationFrame
    this.animationTimer = setInterval(animateFrame, this.ANIMATION_INTERVAL);
  }

  private updateBarHeights(): void {
    // Wave-like random: each bar has a drifting phase offset, plus a little random jitter
    for (let i = 0; i < this.BAR_COUNT; i++) {
      this.phaseOffsets[i] = (this.phaseOffsets[i] + this.PHASE_DRIFT_PER_FRAME) % (2 * Math.PI);
      const wave = Math.sin(2 * Math.PI * (this.animationProgress + this.phaseOffsets[i]));
      const base = this.BAR_HEIGHT_MIN + (this.BAR_HEIGHT_MAX - this.BAR_HEIGHT_MIN) * ((wave + 1) / 2);
      const jitter = (Math.random() * 2 - 1); // [-1, 1]
      const height = base + jitter * this.JITTER_AMPLITUDE;
      this.barHeights[i] = Math.max(this.BAR_HEIGHT_MIN, Math.min(this.BAR_HEIGHT_MAX, height));
    }
  }

  build() {
    Row() {
      ForEach([0, 1, 2, 3], (index: number) => {
        Rect()
          .width(this.BAR_WIDTH)
          .height(this.barHeights[index])
          .radius(this.BAR_CORNER_RADIUS)
          .fill('#6366F1') // Purple/blue color to be visible on white background
          .margin({ left: index > 0 ? this.BAR_SPACING : 0 })
      })
    }
    .width(this.BAR_COUNT * this.BAR_WIDTH + (this.BAR_COUNT - 1) * this.BAR_SPACING)
    .height(this.BAR_HEIGHT_MAX)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }
}

