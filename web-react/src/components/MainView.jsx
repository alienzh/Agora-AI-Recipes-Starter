import { useState, useEffect, useRef } from 'react'
import { generateToken } from '../utils/api'
import { env } from '../config/env'
import AgoraRTM from 'agora-rtm'
import AgoraRTC from 'agora-rtc-sdk-ng'
import { ConversationalAIAPI } from '../conversational-ai-api'
import { EConversationalAIAPIEvents } from '../conversational-ai-api/type'
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
  const scrollRef = useRef(null)
  
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
    if (!convoAIAPIRef.current) return

    const convoAIAPI = convoAIAPIRef.current

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
      
      setTranscripts(newTranscripts)
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
          enableLog: true,
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
      console.log('[Agent] Agent stopped successfully')
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
        console.log('[Audio] Microphone muted:', newMutedState)
      } catch (error) {
        console.error('[Audio] Failed to set microphone mute state:', error)
      }
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
              scrollRef={scrollRef}
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
function TranscriptScrollView({ transcripts, scrollRef }) {
  return (
    <div className="transcript-scroll-view" ref={scrollRef}>
      <div className="transcript-list">
        {transcripts.length === 0 ? (
          <div className="empty-transcript">
            <p>等待对话开始...</p>
          </div>
        ) : (
          transcripts.map((transcript, index) => (
            <TranscriptRow key={transcript.id || index} transcript={transcript} />
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

