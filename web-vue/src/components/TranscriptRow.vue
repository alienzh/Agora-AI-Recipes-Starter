<template>
  <div :class="['transcript-row', isAgent ? 'agent' : 'user']">
    <div
      class="transcript-avatar"
      :style="{ backgroundColor: isAgent ? '#3b82f6' : '#10b981' }"
    >
      {{ isAgent ? 'AI' : '我' }}
    </div>
    <div class="transcript-content">
      <p>{{ transcript.text }}</p>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  transcript: {
    type: Object,
    required: true
  }
})

const isAgent = computed(() => props.transcript.type === 'agent')
</script>

