<template>
  <div class="App">
    <div class="app-container">
      <!-- 左侧：主内容区域 -->
      <div class="app-main-area">
        <MainView :addLog="addLog" :clearLogs="clearLogs" />
      </div>

      <!-- 右侧：Debug 日志视图 -->
      <div class="app-log-area">
        <LogView :logs="logs" ref="logScrollRef" />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, watch, nextTick } from 'vue'
import MainView from './components/MainView.vue'
import LogView from './components/LogView.vue'
import './App.css'

const logs = ref([])
const logScrollRef = ref(null)

// Debug 日志管理
const addLog = (message, type = 'info') => {
  const timestamp = new Date().toLocaleTimeString('zh-CN', { hour12: false })
  const logEntry = {
    id: Date.now() + Math.random(),
    timestamp,
    message,
    type
  }
  logs.value.push(logEntry)
  // 自动滚动到底部
  nextTick(() => {
    if (logScrollRef.value && logScrollRef.value.logListRef) {
      logScrollRef.value.logListRef.scrollTop = logScrollRef.value.logListRef.scrollHeight
    }
  })
}

const clearLogs = () => {
  logs.value = []
}

// 日志自动滚动到底部
watch(logs, () => {
  nextTick(() => {
    if (logScrollRef.value && logScrollRef.value.logListRef) {
      logScrollRef.value.logListRef.scrollTop = logScrollRef.value.logListRef.scrollHeight
    }
  })
}, { deep: true })
</script>

