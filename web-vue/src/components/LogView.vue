<template>
  <div class="log-view" ref="scrollRef">
    <div class="log-header">
      <h3>状态日志</h3>
    </div>
    <div class="log-list" ref="logListRef">
      <div v-if="logs.length === 0" class="empty-log">
        <p>等待连接...</p>
      </div>
      <LogRow v-else v-for="log in logs" :key="log.id" :log="log" />
    </div>
  </div>
</template>

<script setup>
import { defineProps, ref, defineExpose } from 'vue'
import LogRow from './LogRow.vue'

defineProps({
  logs: {
    type: Array,
    required: true
  }
})

const scrollRef = ref(null)
const logListRef = ref(null)

defineExpose({
  scrollRef,
  logListRef
})
</script>

