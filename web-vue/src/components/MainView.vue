<template>
  <!-- 聊天视图 -->
  <div v-if="viewMode === 'chat'" class="chat-view">
    <div class="chat-view-container">
      <div class="chat-main-area">
        <TranscriptScrollView :transcripts="transcripts" :scrollRef="scrollRef" />

        <ControlBar
          :isMicMuted="isMicMuted"
          @toggle-microphone="toggleMicrophone"
          @end-call="handleEndCall"
        />
      </div>
    </div>
  </div>

  <!-- 配置视图 -->
  <div v-else class="entrance-view">
    <div class="entrance-container">
      <div class="logo-container">
        <img
          v-if="!logoError"
          src="/logo.png"
          alt="Logo"
          class="logo"
          @error="logoError = true"
        />
        <div v-else class="logo-placeholder">
          <div class="logo-icon">🎤</div>
        </div>
      </div>

      <form @submit.prevent="handleConnect" class="entrance-form">
        <div class="form-group">
          <label for="channel-name" class="form-label">
            频道名称
          </label>
          <input
            id="channel-name"
            type="text"
            placeholder="请输入频道名称"
            v-model="channelName"
            class="channel-input"
            autofocus
            :disabled="isConnecting"
          />
        </div>

        <button
          type="submit"
          :disabled="isDisabled"
          :class="['start-button', { disabled: isDisabled }]"
        >
          <span v-if="isConnecting" class="loading-spinner"></span>
          {{ isConnecting ? '连接中...' : '连接对话式AI引擎' }}
        </button>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref, shallowRef, computed, onMounted, onBeforeUnmount } from 'vue'
import { generateToken } from '../utils/api'
import { env } from '../config/env'
import AgoraRTM from 'agora-rtm'
import AgoraRTC from 'agora-rtc-sdk-ng'
import { ConversationalAIAPI } from '../conversational-ai-api'
import { EConversationalAIAPIEvents } from '../conversational-ai-api/type'
import AgentManager from '../utils/AgentManager'
import TranscriptScrollView from './TranscriptScrollView.vue'
import ControlBar from './ControlBar.vue'
import './entrance-view.css'
import './chat-view.css'

const props = defineProps({
  addLog: {
    type: Function,
    default: null
  },
  clearLogs: {
    type: Function,
    default: null
  }
})

// MARK: - View State
const viewMode = ref('config') // 'config' | 'chat'

// MARK: - Config State
const channelName = ref('')
const logoError = ref(false)
const isConnecting = ref(false)

// MARK: - Chat State
const transcripts = ref([])
const isMicMuted = ref(false)
const scrollRef = ref(null)

// MARK: - Agora Components
const token = ref('')
const agentToken = ref('')
const agentId = ref('')
// 使用 shallowRef 避免深度响应式，防止 Vue Proxy 干扰 Agora SDK 内部属性访问
const rtmClientRef = shallowRef(null)
const rtcClientRef = shallowRef(null)
const convoAIAPIRef = shallowRef(null)
const localAudioTrackRef = shallowRef(null)
const uidRef = ref(null)
const agentUidValue = Math.floor(Math.random() * (99999999 - 10000000 + 1)) + 10000000
const agentUid = ref(agentUidValue)

// 安全添加日志
const safeAddLog = (message, type = 'info') => {
  if (props.addLog && typeof props.addLog === 'function') {
    props.addLog(message, type)
  }
}

// 页面加载时添加初始日志
onMounted(() => {
  if (props.addLog) {
    props.addLog('等待连接...', 'info')
  }
})

// MARK: - Page Unload Handler
onBeforeUnmount(() => {
  if (agentId.value) {
    try {
      const isDev = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
      const baseUrl = isDev ? 'http://localhost:3001/api' : '/api'
      const url = `${baseUrl}/agent/stop`
      
      fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ agentId: agentId.value }),
        keepalive: true
      }).catch(err => {
        console.error('[Agent] Failed to stop agent on page unload:', err)
      })
    } catch (error) {
      console.error('[Agent] Error stopping agent on page unload:', error)
    }
  }
})

// MARK: - Engine Initialization
const initializeRTM = (uid) => {
  if (rtmClientRef.value) {
    safeAddLog('RTM Client 已初始化', 'info')
    return rtmClientRef.value
  }

  if (!env.AG_APP_ID) {
    safeAddLog('RTM Client 初始化失败: AG_APP_ID 未配置', 'error')
    throw new Error('AG_APP_ID 未配置')
  }

  try {
    const userId = String(uid)
    const rtmClient = new AgoraRTM.RTM(env.AG_APP_ID, userId)
    rtmClientRef.value = rtmClient
    safeAddLog('RTM Client 初始化成功', 'success')
    return rtmClient
  } catch (error) {
    safeAddLog(`RTM Client 初始化失败: ${error.message}`, 'error')
    throw error
  }
}

const initializeRTC = () => {
  if (rtcClientRef.value) {
    safeAddLog('RTC Engine 已初始化', 'info')
    return rtcClientRef.value
  }

  if (!env.AG_APP_ID) {
    safeAddLog('RTC Engine 初始化失败: AG_APP_ID 未配置', 'error')
    throw new Error('AG_APP_ID 未配置')
  }

  try {
    try {
      AgoraRTC.setParameter('ENABLE_AUDIO_PTS', true)
    } catch (error) {
      console.warn('[RTC] Failed to set audio PTS parameter:', error)
    }

    const rtcClient = AgoraRTC.createClient({ mode: 'rtc', codec: 'vp8' })
    rtcClientRef.value = rtcClient
    
    bindRTCEvents(rtcClient)
    
    safeAddLog('RTC Engine 初始化成功', 'success')
    return rtcClient
  } catch (error) {
    safeAddLog(`RTC Engine 初始化失败: ${error.message}`, 'error')
    throw error
  }
}

// 绑定 RTC 事件监听
const bindRTCEvents = (client) => {
  client.on('user-joined', (user) => {
    console.log('[RTC Callback] User joined:', user.uid)
    safeAddLog(`onUserJoined: ${user.uid}`, 'success')
  })

  client.on('user-published', async (user, mediaType) => {
    console.log('[RTC Callback] User published:', user.uid, 'mediaType:', mediaType)
    try {
      await client.subscribe(user, mediaType)
      if (mediaType === 'audio' && user.audioTrack) {
        user.audioTrack.play()
        console.log('[RTC Callback] Remote audio track playing, userId:', user.uid)
      }
    } catch (error) {
      console.error('[RTC Callback] Failed to subscribe user:', error)
    }
  })

  client.on('connection-state-change', (curState, revState, reason) => {
    console.log('[RTC Callback] Connection state changed:', { current: curState, previous: revState, reason })
    if (curState === 'CONNECTED') {
      safeAddLog('onJoinChannelSuccess', 'success')
    } else if (curState === 'DISCONNECTED') {
      if (reason === 'LEAVE') {
        safeAddLog('已离开频道', 'info')
      } else {
        safeAddLog(`连接断开: ${reason || '未知原因'}`, 'error')
      }
    } else if (curState === 'FAILED') {
      safeAddLog(`连接失败: ${reason || '未知原因'}`, 'error')
    }
  })
}

// 设置 ConvoAI 事件监听
const setupConvoAIEvents = () => {
  if (!convoAIAPIRef.value) return

  const convoAIAPI = convoAIAPIRef.value

  convoAIAPI.on(EConversationalAIAPIEvents.TRANSCRIPT_UPDATED, (chatHistory) => {
    console.log('[ConvoAI] ===== TRANSCRIPT_UPDATED event triggered =====')
    console.log('[ConvoAI] Transcript updated, items count:', chatHistory.length)
    
    if (!chatHistory || chatHistory.length === 0) {
      console.warn('[ConvoAI] Chat history is empty')
      return
    }
    
    const newTranscripts = chatHistory
      .sort((a, b) => {
        if (a.turn_id !== b.turn_id) {
          return a.turn_id - b.turn_id
        }
        try {
          const aUidNumber = Number(a.uid)
          const bUidNumber = Number(b.uid)
          return aUidNumber - bUidNumber
        } catch (error) {
          console.error('[ConvoAI] Error parsing uid to number:', error)
          return 0
        }
      })
      .map((item) => {
        const isAgent = Number(item.uid) !== 0
        return {
          id: `${item.turn_id}-${item.uid}-${item._time}`,
          type: isAgent ? 'agent' : 'user',
          text: item.text || '',
          status: item.status || 'completed',
          timestamp: item._time || Date.now()
        }
      })
    
    transcripts.value = newTranscripts
  })

  convoAIAPI.on(EConversationalAIAPIEvents.AGENT_STATE_CHANGED, (agentUserId, event) => {
    console.log('[ConvoAI] Agent state changed:', agentUserId, event.state)
  })

  convoAIAPI.on(EConversationalAIAPIEvents.AGENT_ERROR, (agentUserId, error) => {
    console.error('[ConvoAI] Agent error:', agentUserId, error)
  })
}

// MARK: - Connection Flow
const handleConnect = async (e) => {
  e.preventDefault()
  if (channelName.value.trim() && !isConnecting.value) {
    isConnecting.value = true
    
    if (props.clearLogs) {
      props.clearLogs()
    }
    
    const uid = Math.floor(Math.random() * (9999999 - 1000 + 1)) + 1000
    uidRef.value = uid
    const channel = channelName.value.trim()
    
    try {
      safeAddLog('开始连接...', 'info')
      safeAddLog(`频道名称: ${channel}`, 'info')
      safeAddLog(`App ID: ${env.AG_APP_ID ? env.AG_APP_ID.substring(0, 8) + '...' : '未配置'}`, 'info')

      // 步骤 1: 初始化引擎
      safeAddLog('初始化 RTM 引擎...', 'info')
      initializeRTM(uid)
      
      safeAddLog('初始化 RTC 引擎...', 'info')
      initializeRTC()

      // 步骤 2: 生成用户 token
      safeAddLog('获取 Token 调用中...', 'info')
      const userToken = await generateToken(channel, String(uid), 86400, [1, 2])
      if (!userToken) {
        throw new Error('获取 token 失败，请重试')
      }
      token.value = userToken
      safeAddLog('获取 Token 调用成功', 'success')

      // 步骤 3: RTM 登录
      safeAddLog('RTM Login 调用中...', 'info')
      safeAddLog(`RTM User ID: ${String(uid)}`, 'info')
      safeAddLog(`Token 长度: ${userToken.length}`, 'info')
      try {
        if (!rtmClientRef.value) {
          throw new Error('RTM Client 未初始化')
        }
        await rtmClientRef.value.login({ token: userToken })
        safeAddLog('RTM Login 调用成功', 'success')
      } catch (error) {
        console.error('[RTM] Login error details:', {
          error,
          code: error.code,
          message: error.message,
          reason: error.reason,
          rtmClientExists: !!rtmClientRef.value,
          appId: env.AG_APP_ID ? env.AG_APP_ID.substring(0, 8) + '...' : '未配置',
          tokenLength: userToken.length,
          uid: String(uid)
        })
        if (error.code === -10017 || error.message?.includes('Same subscribe, join or login request')) {
          safeAddLog('RTM Login 调用成功（已登录）', 'success')
        } else {
          safeAddLog(`RTM Login 失败: ${error.message || error.reason || '未知错误'} (code: ${error.code || 'N/A'})`, 'error')
          throw error
        }
      }

      // 步骤 4: RTC 加入频道
      safeAddLog('joinChannel 调用中...', 'info')
      
      if (!localAudioTrackRef.value) {
        localAudioTrackRef.value = await AgoraRTC.createMicrophoneAudioTrack({
          AEC: true,
          ANS: false,
          AGC: true
        })
      }

      const userId = typeof uid === 'number' ? uid : parseInt(uid, 10)
      await rtcClientRef.value.join(env.AG_APP_ID, channel, userToken, userId)
      safeAddLog('joinChannel 调用成功', 'success')

      if (localAudioTrackRef.value) {
        await rtcClientRef.value.publish([localAudioTrackRef.value])
      }

      // 步骤 5: RTM 加入频道
      safeAddLog('RTM 加入频道中...', 'info')
      await rtmClientRef.value.subscribe(channel)
      safeAddLog('RTM 加入频道成功', 'success')

      // 步骤 6: 初始化 ConvoAI API
      safeAddLog('初始化 ConvoAI API...', 'info')
      const convoAIAPI = ConversationalAIAPI.init({
        rtcEngine: rtcClientRef.value,
        rtmEngine: rtmClientRef.value,
        enableLog: true,
        renderMode: undefined
      })
      convoAIAPIRef.value = convoAIAPI
      safeAddLog('ConvoAI API 初始化成功', 'success')

      // 步骤 7: 订阅 ConvoAI 消息
      safeAddLog('订阅 ConvoAI 消息...', 'info')
      convoAIAPI.subscribeMessage(channel)
      safeAddLog('订阅 ConvoAI 消息成功', 'success')

      setupConvoAIEvents()

      // 步骤 8: 生成 Agent Token
      safeAddLog('生成 Agent Token...', 'info')
      const agentTokenValue = await generateToken(channel, String(agentUid.value), 86400, [1, 2])
      if (!agentTokenValue) {
        throw new Error('获取 agent token 失败，请重试')
      }
      agentToken.value = agentTokenValue
      safeAddLog('生成 Agent Token 成功', 'success')

      // 步骤 9: 启动 Agent
      safeAddLog('Agent Start 调用中...', 'info')
      
      if (!env.AG_PIPELINE_ID) {
        throw new Error('请配置 VITE_AG_PIPELINE_ID')
      }

      const parameter = {
        name: channel,
        pipeline_id: env.AG_PIPELINE_ID,
        properties: {
          channel: channel,
          agent_rtc_uid: String(agentUid.value),
          remote_rtc_uids: ['*'],
          token: agentTokenValue
        }
      }

      const newAgentId = await AgentManager.startAgent(parameter)
      if (!newAgentId) {
        throw new Error('启动 Agent 失败：未返回 agentId')
      }

      agentId.value = newAgentId
      safeAddLog(`Agent Start 调用成功 (agentId: ${newAgentId})`, 'success')

      safeAddLog('连接成功，进入聊天页面', 'success')
      
      isConnecting.value = false
      viewMode.value = 'chat'
    } catch (error) {
      console.error('[Connection] Connection failed:', error)
      safeAddLog(`连接失败: ${error.message}`, 'error')
      isConnecting.value = false
      
      await cleanupResources()
    }
  }
}

// MARK: - Cleanup
const stopAgent = async () => {
  if (!agentId.value) {
    console.warn('[Agent] Agent ID is empty, skip stop agent')
    return
  }

  try {
    await AgentManager.stopAgent(agentId.value)
    console.log('[Agent] Agent stopped successfully')
    safeAddLog('Agent Stop 调用成功', 'success')
  } catch (error) {
    console.error('[Agent] Stop agent failed:', error)
    safeAddLog(`Agent Stop 调用失败: ${error.message}`, 'error')
  }
}

const cleanupResources = async () => {
  await stopAgent()

  if (convoAIAPIRef.value) {
    try {
      convoAIAPIRef.value.unsubscribe()
      convoAIAPIRef.value.removeAllEventListeners()
    } catch (e) {}
    convoAIAPIRef.value = null
  }

  if (rtmClientRef.value) {
    try {
      await rtmClientRef.value.logout()
    } catch (e) {}
    rtmClientRef.value = null
  }

  if (localAudioTrackRef.value) {
    try {
      localAudioTrackRef.value.stop()
      localAudioTrackRef.value.close()
    } catch (e) {}
    localAudioTrackRef.value = null
  }

  if (rtcClientRef.value) {
    try {
      await rtcClientRef.value.leave()
    } catch (e) {}
    rtcClientRef.value = null
  }
}

const handleEndCall = async () => {
  await cleanupResources()
  token.value = ''
  agentToken.value = ''
  agentId.value = ''
  transcripts.value = []
  isMicMuted.value = false
  viewMode.value = 'config'
  if (props.clearLogs) {
    props.clearLogs()
  }
}

// MARK: - Chat Actions
const toggleMicrophone = () => {
  const newMutedState = !isMicMuted.value
  isMicMuted.value = newMutedState
  
  if (localAudioTrackRef.value) {
    try {
      localAudioTrackRef.value.setMuted(newMutedState)
      console.log('[Audio] Microphone muted:', newMutedState)
    } catch (error) {
      console.error('[Audio] Failed to set microphone mute state:', error)
    }
  }
}

const isDisabled = computed(() => !channelName.value.trim() || isConnecting.value)
</script>

