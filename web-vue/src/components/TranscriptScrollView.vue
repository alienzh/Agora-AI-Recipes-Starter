<template>
  <div class="transcript-scroll-view" ref="scrollRef">
    <div class="transcript-list">
      <div v-if="transcripts.length === 0" class="empty-transcript">
        <p>等待对话开始...</p>
      </div>
      <TranscriptRow
        v-else
        v-for="(transcript, index) in transcripts"
        :key="transcript.id || index"
        :transcript="transcript"
      />
    </div>
  </div>
</template>

<script setup>
import { defineProps, ref } from 'vue'
import TranscriptRow from './TranscriptRow.vue'

defineProps({
  transcripts: {
    type: Array,
    required: true
  },
  scrollRef: {
    type: Object,
    default: null
  }
})

const scrollRef = ref(null)
</script>

