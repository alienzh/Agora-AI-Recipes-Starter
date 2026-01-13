import { useState, useEffect, useRef } from 'react'
import { generateToken } from '../utils/api'
import { env } from '../config/env'
import AgoraRTM from 'agora-rtm'
import AgoraRTC from 'agora-rtc-sdk-ng'
import { ConversationalAIAPI } from '../conversational-ai-api'
import { EConversationalAIAPIEvents, EAgentState, EChatMessageType, EChatMessagePriority, EMessageType, EModuleType } from '../conversational-ai-api/type'
import AgentManager from '../utils/AgentManager'
import './entrance-view.css'
import './chat-view.css'

function MainView({ addLog, clearLogs }) {
  // MARK: - View State
  const [viewMode, setViewMode] = useState('config') // 'config' | 'chat'
  
  // MARK: - Config State
  const [channelName, setChannelName] = useState('')
  const [logoError, setLogoError] = useState(false)
  const [isConnecting, setIsConnecting] = useState(false)
  
  // MARK: - Chat State
  const [transcripts, setTranscripts] = useState([])
  const [isMicMuted, setIsMicMuted] = useState(false)
  const [agentState, setAgentState] = useState(EAgentState.IDLE)
  const [inputText, setInputText] = useState('http://e.hiphotos.baidu.com/image/pic/item/a1ec08fa513d2697e542494057fbb2fb4316d81e.jpg')
  const [isSending, setIsSending] = useState(false)
  const scrollRef = useRef(null)
  const [imageMessages, setImageMessages] = useState({}) // 存储图片消息状态 {uuid: {url, status}}
  
  // MARK: - Agora Components
  const [token, setToken] = useState('')
  const [agentToken, setAgentToken] = useState('')
  const [agentId, setAgentId] = useState('')
  const rtmClientRef = useRef(null)
  const rtcClientRef = useRef(null)
  const convoAIAPIRef = useRef(null)
  const localAudioTrackRef = useRef(null)
  const uidRef = useRef(null)
  const agentUidValue = Math.floor(Math.random() * (99999999 - 10000000 + 1)) + 10000000
  const agentUid = useRef(agentUidValue)

  // 页面加载时添加初始日志
  useEffect(() => {
    if (addLog) {
      addLog('等待连接...', 'info')
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // 安全添加日志
  const safeAddLog = (message, type = 'info') => {
    if (addLog && typeof addLog === 'function') {
      addLog(message, type)
    }
  }

  // MARK: - Page Unload Handler
  useEffect(() => {
    const handleBeforeUnload = (event) => {
      if (agentId) {
        try {
          const isDev = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
          const baseUrl = isDev ? 'http://localhost:3001/api' : '/api'
          const url = `${baseUrl}/agent/stop`
          
          fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ agentId }),
            keepalive: true
          }).catch(err => {
            console.error('[Agent] Failed to stop agent on page unload:', err)
          })
        } catch (error) {
          console.error('[Agent] Error stopping agent on page unload:', error)
        }
      }
    }

    window.addEventListener('beforeunload', handleBeforeUnload)
    return () => {
      window.removeEventListener('beforeunload', handleBeforeUnload)
    }
  }, [agentId])

  // MARK: - Engine Initialization
  const initializeRTM = (uid) => {
    if (rtmClientRef.current) {
      safeAddLog('RTM Client 已初始化', 'info')
      return rtmClientRef.current
    }

    if (!env.AG_APP_ID) {
      safeAddLog('RTM Client 初始化失败: AG_APP_ID 未配置', 'error')
      throw new Error('AG_APP_ID 未配置')
    }

    try {
      const userId = String(uid)
      const rtmClient = new AgoraRTM.RTM(env.AG_APP_ID, userId)
      rtmClientRef.current = rtmClient
      safeAddLog('RTM Client 初始化成功', 'success')
      return rtmClient
    } catch (error) {
      safeAddLog(`RTM Client 初始化失败: ${error.message}`, 'error')
      throw error
    }
  }

  const initializeRTC = () => {
    if (rtcClientRef.current) {
      safeAddLog('RTC Engine 已初始化', 'info')
      return rtcClientRef.current
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
      rtcClientRef.current = rtcClient
      
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
      safeAddLog(`onUserJoined: ${user.uid}`, 'success')
    })

    client.on('user-published', async (user, mediaType) => {
      try {
        await client.subscribe(user, mediaType)
        if (mediaType === 'audio' && user.audioTrack) {
          user.audioTrack.play()
        }
      } catch (error) {
        console.error('[RTC Callback] Failed to subscribe user:', error)
      }
    })

    client.on('connection-state-change', (curState, revState, reason) => {
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
    if (!convoAIAPIRef.current) return

    const convoAIAPI = convoAIAPIRef.current

    convoAIAPI.on(EConversationalAIAPIEvents.TRANSCRIPT_UPDATED, (chatHistory) => {
      if (!chatHistory || chatHistory.length === 0) {
        return
      }
      
      const newTranscripts = chatHistory
        .sort((a, b) => {
          if (a.turn_id !== b.turn_id) {
            return a.turn_id - b.turn_id
          }
          
          const aIsAgent = a.metadata?.object === EMessageType.AGENT_TRANSCRIPTION
          const bIsAgent = b.metadata?.object === EMessageType.AGENT_TRANSCRIPTION
          const aIsUser = a.metadata?.object === EMessageType.USER_TRANSCRIPTION
          const bIsUser = b.metadata?.object === EMessageType.USER_TRANSCRIPTION
          
          if (aIsUser && bIsAgent) return -1
          if (aIsAgent && bIsUser) return 1
          
          try {
            const aUidNumber = Number(a.uid)
            const bUidNumber = Number(b.uid)
            if (aUidNumber !== bUidNumber) {
              return aUidNumber - bUidNumber
            }
          } catch (error) {
            console.error('[ConvoAI] Error parsing uid to number:', error)
          }
          
          if (a._time !== b._time) {
            return a._time - b._time
          }
          
          return (a.stream_id || 0) - (b.stream_id || 0)
        })
        .map((item, index) => {
          const isAgent = item.metadata?.object === EMessageType.AGENT_TRANSCRIPTION
          const isUser = item.metadata?.object === EMessageType.USER_TRANSCRIPTION
          
          const messageType = isAgent ? 'agent' : (isUser ? 'user' : (Number(item.uid) !== 0 ? 'agent' : 'user'))
          
          const id = `${messageType}-${item.turn_id}-${item.uid}-${item.stream_id || 0}-${item._time}-${index}`
          
          return {
            id: id,
            type: messageType,
            text: item.text || '',
            status: item.status || 'completed',
            timestamp: item._time || Date.now()
          }
        })
      
      setTranscripts(newTranscripts)
    })

    convoAIAPI.on(EConversationalAIAPIEvents.AGENT_STATE_CHANGED, (agentUserId, event) => {
      setAgentState(event.state)
    })

    convoAIAPI.on(EConversationalAIAPIEvents.AGENT_ERROR, (agentUserId, error) => {
      console.error('[ConvoAI] Agent error:', agentUserId, error)
    })

    convoAIAPI.on(EConversationalAIAPIEvents.MESSAGE_RECEIPT_UPDATED, (agentUserId, messageReceipt) => {
      console.log('🔔 [MESSAGE_RECEIPT] Received:', {
        agentUserId,
        moduleType: messageReceipt.moduleType,
        messageType: messageReceipt.messageType,
        message: messageReceipt.message,
        fullReceipt: messageReceipt
      })
      
      if (messageReceipt.moduleType === EModuleType.CONTEXT && messageReceipt.messageType === EChatMessageType.IMAGE) {
        console.log('✅ [MESSAGE_RECEIPT] Image receipt detected!')
        try {
          const messageData = JSON.parse(messageReceipt.message)
          const uuid = messageData.uuid
          console.log('🔑 [MESSAGE_RECEIPT] UUID:', uuid)
          console.log('📄 [MESSAGE_RECEIPT] Message data:', messageData)
          
          setImageMessages(prev => {
            console.log('📦 [MESSAGE_RECEIPT] All UUIDs in state:', Object.keys(prev))
            console.log('🔍 [MESSAGE_RECEIPT] Looking for UUID:', uuid)
            console.log('🔍 [MESSAGE_RECEIPT] Found in state:', prev[uuid])
            
            if (prev[uuid]) {
              console.log('✨ [MESSAGE_RECEIPT] Updating status to success for uuid:', uuid)
              return {
                ...prev,
                [uuid]: { ...prev[uuid], status: 'success' }
              }
            } else {
              console.warn('⚠️ [MESSAGE_RECEIPT] UUID not found in imageMessages:', uuid)
              console.warn('⚠️ [MESSAGE_RECEIPT] Available UUIDs:', Object.keys(prev))
            }
            return prev
          })
        } catch (error) {
          console.error('❌ [MESSAGE_RECEIPT] Failed to parse:', error)
        }
      } else {
        console.log('⏭️ [MESSAGE_RECEIPT] Not an image receipt, skipping')
      }
    })

    convoAIAPI.on(EConversationalAIAPIEvents.MESSAGE_ERROR, (agentUserId, error) => {
      console.error('[ConvoAI] Message error:', agentUserId, error)
      
      if (error.type === EChatMessageType.IMAGE) {
        try {
          const messageData = JSON.parse(error.message)
          const uuid = messageData.uuid
          console.log('[ConvoAI] Image error uuid:', uuid)
          
          setImageMessages(prev => {
            if (prev[uuid]) {
              return {
                ...prev,
                [uuid]: { ...prev[uuid], status: 'failed' }
              }
            }
            return prev
          })
        } catch (parseError) {
          console.error('[ConvoAI] Failed to parse message error:', parseError)
        }
      }
    })
  }

  // MARK: - Connection Flow
  const handleConnect = async (e) => {
    e.preventDefault()
    if (channelName.trim() && !isConnecting) {
      setIsConnecting(true)
      
      if (clearLogs) {
        clearLogs()
      }
      
      const uid = Math.floor(Math.random() * (9999999 - 1000 + 1)) + 1000
      uidRef.current = uid
      const channel = channelName.trim()
      
      try {
        safeAddLog('开始连接...', 'info')
        safeAddLog(`频道名称: ${channel}`, 'info')

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
        setToken(userToken)
        safeAddLog('获取 Token 调用成功', 'success')

        // 步骤 3: RTM 登录
        safeAddLog('RTM Login 调用中...', 'info')
        try {
          await rtmClientRef.current.login({ token: userToken })
          safeAddLog('RTM Login 调用成功', 'success')
        } catch (error) {
          if (error.code === -10017 || error.message?.includes('Same subscribe, join or login request')) {
            safeAddLog('RTM Login 调用成功（已登录）', 'success')
          } else {
            throw error
          }
        }

        // 步骤 4: RTC 加入频道
        safeAddLog('joinChannel 调用中...', 'info')
        
        if (!localAudioTrackRef.current) {
          localAudioTrackRef.current = await AgoraRTC.createMicrophoneAudioTrack({
            AEC: true,
            ANS: false,
            AGC: true
          })
        }

        const userId = typeof uid === 'number' ? uid : parseInt(uid, 10)
        await rtcClientRef.current.join(env.AG_APP_ID, channel, userToken, userId)
        safeAddLog('joinChannel 调用成功', 'success')

        if (localAudioTrackRef.current) {
          await rtcClientRef.current.publish([localAudioTrackRef.current])
        }

        // 步骤 5: RTM 加入频道
        safeAddLog('RTM 加入频道中...', 'info')
        await rtmClientRef.current.subscribe(channel)
        safeAddLog('RTM 加入频道成功', 'success')

        // 步骤 6: 初始化 ConvoAI API
        safeAddLog('初始化 ConvoAI API...', 'info')
        const convoAIAPI = ConversationalAIAPI.init({
          rtcEngine: rtcClientRef.current,
          rtmEngine: rtmClientRef.current,
          enableLog: false,
          renderMode: undefined
        })
        convoAIAPIRef.current = convoAIAPI
        safeAddLog('ConvoAI API 初始化成功', 'success')

        // 步骤 7: 订阅 ConvoAI 消息
        safeAddLog('订阅 ConvoAI 消息...', 'info')
        convoAIAPI.subscribeMessage(channel)
        safeAddLog('订阅 ConvoAI 消息成功', 'success')

        setupConvoAIEvents()

        // 步骤 8: 生成 Agent Token
        safeAddLog('生成 Agent Token...', 'info')
        const agentTokenValue = await generateToken(channel, String(agentUid.current), 86400, [1, 2])
        if (!agentTokenValue) {
          throw new Error('获取 agent token 失败，请重试')
        }
        setAgentToken(agentTokenValue)
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
            agent_rtc_uid: String(agentUid.current),
            remote_rtc_uids: ['*'],
            token: agentTokenValue
          }
        }

        const newAgentId = await AgentManager.startAgent(parameter)
        if (!newAgentId) {
          throw new Error('启动 Agent 失败：未返回 agentId')
        }

        setAgentId(newAgentId)
        safeAddLog(`Agent Start 调用成功 (agentId: ${newAgentId})`, 'success')

        safeAddLog('连接成功，进入聊天页面', 'success')
        
        setIsConnecting(false)
        setViewMode('chat')
      } catch (error) {
        console.error('[Connection] Connection failed:', error)
        safeAddLog(`连接失败: ${error.message}`, 'error')
        setIsConnecting(false)
        
        await cleanupResources()
      }
    }
  }

  // MARK: - Cleanup
  const stopAgent = async () => {
    if (!agentId) {
      console.warn('[Agent] Agent ID is empty, skip stop agent')
      return
    }

    try {
      await AgentManager.stopAgent(agentId)
      safeAddLog('Agent Stop 调用成功', 'success')
    } catch (error) {
      console.error('[Agent] Stop agent failed:', error)
      safeAddLog(`Agent Stop 调用失败: ${error.message}`, 'error')
    }
  }

  const cleanupResources = async () => {
    await stopAgent()

    if (convoAIAPIRef.current) {
      try {
        convoAIAPIRef.current.unsubscribe()
        convoAIAPIRef.current.removeAllEventListeners()
      } catch (e) {}
      convoAIAPIRef.current = null
    }

    if (rtmClientRef.current) {
      try {
        await rtmClientRef.current.logout()
      } catch (e) {}
      rtmClientRef.current = null
    }

    if (localAudioTrackRef.current) {
      try {
        localAudioTrackRef.current.stop()
        localAudioTrackRef.current.close()
      } catch (e) {}
      localAudioTrackRef.current = null
    }

    if (rtcClientRef.current) {
      try {
        await rtcClientRef.current.leave()
      } catch (e) {}
      rtcClientRef.current = null
    }
  }

  const handleEndCall = async () => {
    await cleanupResources()
    setToken('')
    setAgentToken('')
    setAgentId('')
    setTranscripts([])
    setIsMicMuted(false)
    setAgentState(EAgentState.IDLE)
    setInputText('http://e.hiphotos.baidu.com/image/pic/item/a1ec08fa513d2697e542494057fbb2fb4316d81e.jpg')
    setIsSending(false)
    setImageMessages({})
    setViewMode('config')
    if (clearLogs) {
      clearLogs()
    }
  }

  // MARK: - Chat Actions
  const toggleMicrophone = () => {
    const newMutedState = !isMicMuted
    setIsMicMuted(newMutedState)
    
    if (localAudioTrackRef.current) {
      try {
        localAudioTrackRef.current.setMuted(newMutedState)
      } catch (error) {
        console.error('[Audio] Failed to set microphone mute state:', error)
      }
    }
  }

  // MARK: - Send Image
  const sendImage = async () => {
    if (!convoAIAPIRef.current || !inputText.trim() || isSending) {
      return
    }

    const imageUrl = inputText.trim()
    const uuid = `img-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
    
    const message = {
      messageType: EChatMessageType.IMAGE,
      uuid: uuid,
      url: imageUrl
    }

    console.warn('🖼️ [SEND_IMAGE] ==========================================')
    console.warn('🖼️ [SEND_IMAGE] Sending image:', imageUrl)
    console.warn('🖼️ [SEND_IMAGE] UUID:', uuid)
    console.warn('🖼️ [SEND_IMAGE] Agent UID:', String(agentUid.current))
    console.warn('🖼️ [SEND_IMAGE] Message:', message)
    console.warn('🖼️ [SEND_IMAGE] ==========================================')

    setImageMessages(prev => ({
      ...prev,
      [uuid]: { url: imageUrl, status: 'sending', timestamp: Date.now() }
    }))

    setIsSending(true)
    try {
      await convoAIAPIRef.current.chat(String(agentUid.current), message)
      safeAddLog('图片发送成功', 'success')
    } catch (error) {
      console.error('[Chat] Failed to send image:', error)
      const errorMessage = error?.message || error?.toString() || '未知错误'
      safeAddLog(`图片发送失败: ${errorMessage}`, 'error')
      
      setImageMessages(prev => ({
        ...prev,
        [uuid]: { ...prev[uuid], status: 'failed' }
      }))
    } finally {
      setIsSending(false)
    }
  }

  const handleInputKeyPress = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      sendImage()
    }
  }

  const isDisabled = !channelName.trim() || isConnecting

  // MARK: - Render
  if (viewMode === 'chat') {
    return (
      <div className="chat-view">
        <div className="chat-view-container">
          <div className="chat-main-area">
            <TranscriptScrollView 
              transcripts={transcripts} 
              imageMessages={imageMessages}
              scrollRef={scrollRef}
            />

            {/* Agent 状态视图 */}
            <AgentStateView state={agentState} />

            {/* 输入框容器 */}
            <InputContainer
              inputText={inputText}
              onInputChange={setInputText}
              onSendImage={sendImage}
              onKeyPress={handleInputKeyPress}
              isSending={isSending}
            />

            <ControlBar
              isMicMuted={isMicMuted}
              onToggleMicrophone={toggleMicrophone}
              onEndCall={handleEndCall}
            />
          </div>
        </div>
      </div>
    )
  }

  // 配置视图
  return (
    <div className="entrance-view">
      <div className="entrance-container">
        <div className="logo-container">
          {!logoError ? (
            <img 
              src="/logo.png" 
              alt="Logo" 
              className="logo"
              onError={() => setLogoError(true)}
            />
          ) : (
            <div className="logo-placeholder">
              <div className="logo-icon">🎤</div>
            </div>
          )}
        </div>

        <form onSubmit={handleConnect} className="entrance-form">
          <div className="form-group">
            <label htmlFor="channel-name" className="form-label">
              频道名称
            </label>
            <input
              id="channel-name"
              type="text"
              placeholder="请输入频道名称"
              value={channelName}
              onChange={(e) => setChannelName(e.target.value)}
              className="channel-input"
              autoFocus
              disabled={isConnecting}
            />
          </div>

          <button
            type="submit"
            disabled={isDisabled}
            className={`start-button ${isDisabled ? 'disabled' : ''}`}
          >
            {isConnecting ? (
              <>
                <span className="loading-spinner"></span>
                连接中...
              </>
            ) : (
              '连接对话式AI引擎'
            )}
          </button>
        </form>
      </div>
    </div>
  )
}

// 字幕滚动视图
function TranscriptScrollView({ transcripts, imageMessages, scrollRef }) {
  // 合并文本消息和图片消息
  const allMessages = [
    ...transcripts.map(t => ({ ...t, messageType: 'text' })),
    ...Object.entries(imageMessages).map(([uuid, data]) => ({
      id: uuid,
      type: 'user',
      messageType: 'image',
      url: data.url,
      status: data.status,
      timestamp: data.timestamp
    }))
  ].sort((a, b) => (a.timestamp || 0) - (b.timestamp || 0))

  return (
    <div className="transcript-scroll-view" ref={scrollRef}>
      <div className="transcript-list">
        {allMessages.length === 0 ? (
          <div className="empty-transcript">
            <p>等待对话开始...</p>
          </div>
        ) : (
          allMessages.map((message, index) => (
            message.messageType === 'image' ? (
              <ImageMessageRow key={message.id || index} message={message} />
            ) : (
              <TranscriptRow key={message.id || index} transcript={message} />
            )
          ))
        )}
      </div>
    </div>
  )
}

// 字幕行
function TranscriptRow({ transcript }) {
  const isAgent = transcript.type === 'agent'
  
  return (
    <div className={`transcript-row ${isAgent ? 'agent' : 'user'}`}>
      <div className="transcript-avatar" style={{ backgroundColor: isAgent ? '#3b82f6' : '#10b981' }}>
        {isAgent ? 'AI' : '我'}
      </div>
      <div className="transcript-content">
        <p>{transcript.text}</p>
      </div>
    </div>
  )
}

// 图片消息行
function ImageMessageRow({ message }) {
  const getStatusText = () => {
    switch (message.status) {
      case 'sending':
        return '发送中...'
      case 'success':
        return '发送成功'
      case 'failed':
        return '发送失败'
      default:
        return ''
    }
  }

  const getStatusColor = () => {
    switch (message.status) {
      case 'sending':
        return '#3b82f6'
      case 'success':
        return '#10b981'
      case 'failed':
        return '#ef4444'
      default:
        return '#6b7280'
    }
  }

  return (
    <div className="transcript-row user">
      <div className="transcript-avatar" style={{ backgroundColor: '#10b981' }}>
        我
      </div>
      <div className="transcript-content image-content">
        <img 
          src={message.url} 
          alt="发送的图片" 
          className="message-image"
          onError={(e) => {
            e.target.onerror = null
            e.target.src = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="200" height="150" viewBox="0 0 200 150"%3E%3Crect fill="%23f3f4f6" width="200" height="150"/%3E%3Ctext x="50%25" y="50%25" dominant-baseline="middle" text-anchor="middle" font-family="sans-serif" font-size="14" fill="%239ca3af"%3E加载失败%3C/text%3E%3C/svg%3E'
          }}
        />
        <p className="image-status" style={{ color: getStatusColor() }}>
          {getStatusText()}
        </p>
      </div>
    </div>
  )
}

// Agent 状态视图
function AgentStateView({ state }) {
  const getStateText = () => {
    switch (state) {
      case EAgentState.IDLE:
        return '空闲中'
      case EAgentState.SILENT:
        return '静默中'
      case EAgentState.LISTENING:
        return '正在聆听'
      case EAgentState.THINKING:
        return '思考中'
      case EAgentState.SPEAKING:
        return '正在说话'
      default:
        return ''
    }
  }

  const stateText = getStateText()
  
  // 如果没有状态文本，不显示视图
  if (!stateText) {
    return null
  }

  return (
    <div className="agent-state-view">
      <span className="agent-state-text">{stateText}</span>
    </div>
  )
}

// 输入框容器
function InputContainer({ inputText, onInputChange, onSendImage, onKeyPress, isSending }) {
  return (
    <div className="input-container">
      <input
        type="text"
        className="input-text-field"
        placeholder="请输入图片地址"
        value={inputText}
        onChange={(e) => onInputChange(e.target.value)}
        onKeyPress={onKeyPress}
        disabled={isSending}
      />
      <button
        className="send-button send-image-button"
        onClick={onSendImage}
        disabled={!inputText.trim() || isSending}
        aria-label="发送图片"
      >
        发送图片
      </button>
    </div>
  )
}

// 控制栏
function ControlBar({ isMicMuted, onToggleMicrophone, onEndCall }) {
  return (
    <div className="control-bar">
      <div className="control-bar-content">
        <div className="control-group">
          <button
            className={`microphone-button ${isMicMuted ? 'muted' : ''}`}
            onClick={onToggleMicrophone}
            aria-label={isMicMuted ? '取消静音' : '静音'}
          >
            {isMicMuted ? (
              <svg className="mic-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <line x1="1" y1="1" x2="23" y2="23"></line>
                <path d="M9 9v3a3 3 0 0 0 5.12 2.12M15 9.34V4a3 3 0 0 0-5.94-.6"></path>
                <path d="M17 16.95A7 7 0 0 1 5 12v-2M14 14.05V19a3 3 0 0 1-6 0v-1"></path>
                <path d="M12 20h.01"></path>
              </svg>
            ) : (
              <svg className="mic-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"></path>
                <path d="M19 10v2a7 7 0 0 1-14 0v-2"></path>
                <line x1="12" y1="19" x2="12" y2="23"></line>
                <line x1="8" y1="23" x2="16" y2="23"></line>
              </svg>
            )}
          </button>

          <button
            className="end-call-button"
            onClick={onEndCall}
            aria-label="结束通话"
          >
            <svg className="phone-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"></path>
            </svg>
          </button>
        </div>
      </div>
    </div>
  )
}

export default MainView

