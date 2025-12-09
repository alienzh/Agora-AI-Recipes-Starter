<template>
  <div :class="['log-row', getTypeClass()]">
    <span class="log-timestamp">{{ log.timestamp }}</span>
    <span class="log-message">{{ log.message }}</span>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  log: {
    type: Object,
    required: true
  }
})

const getTypeClass = () => {
  switch (props.log.type) {
    case 'success':
      return 'log-success'
    case 'error':
      return 'log-error'
    default:
      return 'log-info'
  }
}
</script>

