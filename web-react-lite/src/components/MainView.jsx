import { useState, useEffect, useRef } from 'react'
import { saveConfig, loadConfig } from '../utils/configStorage'
import { generateToken } from '../utils/api'
import AgoraRTM from 'agora-rtm'
import AgoraRTC from 'agora-rtc-sdk-ng'
import { ConversationalAIAPI } from '../conversational-ai-api'
import { EConversationalAIAPIEvents } from '../conversational-ai-api/type'
import './main-view.css'

function MainView({ addLog, clearLogs }) {
  // MARK: - View State
  const [viewMode, setViewMode] = useState('config') // 'config' | 'chat'
  
  // MARK: - Config State
  const [channelName, setChannelName] = useState('')
  const [appId, setAppId] = useState('')
  const [appCertificate, setAppCertificate] = useState('')
  const [logoError, setLogoError] = useState(false)
  const [isConnecting, setIsConnecting] = useState(false)
  
  // MARK: - Chat State
  const [transcripts, setTranscripts] = useState([])
  const [isMicMuted, setIsMicMuted] = useState(false)
  const scrollRef = useRef(null)
  
  // MARK: - Agora Components
  const [token, setToken] = useState('')
  const rtmClientRef = useRef(null)
  const rtcClientRef = useRef(null)
  const convoAIAPIRef = useRef(null)
  const localAudioTrackRef = useRef(null)
  const uidRef = useRef(null)

  // 页面加载时从 localStorage 读取已保存的配置
  useEffect(() => {
    const savedConfig = loadConfig()
    if (savedConfig) {
      setAppId(savedConfig.appId)
      setAppCertificate(savedConfig.appCertificate)
      setChannelName(savedConfig.channelName)
    }
    // 添加初始日志
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

  // MARK: - Engine Initialization
  const initializeRTM = (uid) => {
    if (rtmClientRef.current) {
      safeAddLog('RTM Client 已初始化', 'info')
      return rtmClientRef.current
    }

    if (!appId) {
      safeAddLog('RTM Client 初始化失败: AG_APP_ID 未配置', 'error')
      throw new Error('AG_APP_ID 未配置')
    }

    try {
      const userId = String(uid)
      const rtmClient = new AgoraRTM.RTM(appId, userId)
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

    if (!appId) {
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
      
      // 绑定 RTC 事件监听
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
    // 用户加入频道
    client.on('user-joined', (user) => {
      console.log('[RTC Callback] User joined:', user.uid)
      safeAddLog(`onUserJoined: ${user.uid}`, 'success')
    })

    // 用户发布音视频流
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

    // 连接状态变化
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

    // 注册转录更新事件回调
    convoAIAPI.on(EConversationalAIAPIEvents.TRANSCRIPT_UPDATED, (chatHistory) => {
      console.log('[ConvoAI] ===== TRANSCRIPT_UPDATED event triggered =====')
      console.log('[ConvoAI] Transcript updated, items count:', chatHistory.length)
      
      if (!chatHistory || chatHistory.length === 0) {
        console.warn('[ConvoAI] Chat history is empty')
        return
      }
      
      // 将聊天历史转换为 transcripts 格式
      const newTranscripts = chatHistory
        .sort((a, b) => {
          // 先按 turn_id 排序
          if (a.turn_id !== b.turn_id) {
            return a.turn_id - b.turn_id
          }
          // 再按 uid 排序
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
          // 判断是用户还是 Agent：uid === 0 是用户，否则是 Agent
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

    // 注册 Agent 状态变化事件回调
    convoAIAPI.on(EConversationalAIAPIEvents.AGENT_STATE_CHANGED, (agentUserId, event) => {
      console.log('[ConvoAI] Agent state changed:', agentUserId, event.state)
    })

    // 注册错误事件回调
    convoAIAPI.on(EConversationalAIAPIEvents.AGENT_ERROR, (agentUserId, error) => {
      console.error('[ConvoAI] Agent error:', agentUserId, error)
    })
  }

  // MARK: - Connection Flow
  const handleConnect = async (e) => {
    e.preventDefault()
    if (channelName.trim() && appId.trim() && !isConnecting) {
      setIsConnecting(true)
      
      // 清除之前的日志，开始新的连接
      if (clearLogs) {
        clearLogs()
      }
      
      // 保存配置到 localStorage
      saveConfig(appId, appCertificate, channelName)
      
      const uid = Math.floor(Math.random() * (9999999 - 1000 + 1)) + 1000
      uidRef.current = uid
      const channel = channelName.trim()
      
      try {
        safeAddLog('开始连接...', 'info')
        safeAddLog(`App ID: ${appId}`, 'info')
        safeAddLog(`频道名称: ${channel}`, 'info')

        // 步骤 1: 初始化引擎
        safeAddLog('初始化 RTM 引擎...', 'info')
        initializeRTM(uid)
        
        safeAddLog('初始化 RTC 引擎...', 'info')
        initializeRTC()

        // 步骤 2: 生成用户 token
        safeAddLog('获取 Token 调用中...', 'info')
        const userToken = await generateToken(channel, String(uid), 86400, [1, 2], appId, appCertificate)
        // userToken 可以是 null（不使用 token），这是有效的
        if (userToken === undefined) {
          throw new Error('获取 token 失败，请重试')
        }
        setToken(userToken || '')
        if (userToken === null) {
          safeAddLog('不使用 Token（App Certificate 未配置）', 'info')
        } else {
          safeAddLog('获取 Token 调用成功', 'success')
        }

        // 步骤 3: RTM 登录
        safeAddLog('RTM Login 调用中...', 'info')
        try {
          // 如果 userToken 是 null，不传 token 参数
          if (userToken === null) {
            await rtmClientRef.current.login()
          } else {
            await rtmClientRef.current.login({ token: userToken })
          }
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
        
        // 创建本地音频轨道
        if (!localAudioTrackRef.current) {
          localAudioTrackRef.current = await AgoraRTC.createMicrophoneAudioTrack({
            AEC: true,
            ANS: false,
            AGC: true
          })
        }

        // 加入频道（如果 userToken 是 null，传递 null 给 join 方法）
        const userId = typeof uid === 'number' ? uid : parseInt(uid, 10)
        await rtcClientRef.current.join(appId, channel, userToken, userId)
        safeAddLog('joinChannel 调用成功', 'success')

        // 发布本地音频轨道
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

        // 设置 ConvoAI 事件监听
        setupConvoAIEvents()

        safeAddLog('连接成功，进入聊天页面', 'success')
        
        // 所有步骤成功，切换到聊天视图
        setIsConnecting(false)
        setViewMode('chat')
      } catch (error) {
        console.error('[Connection] Connection failed:', error)
        safeAddLog(`连接失败: ${error.message}`, 'error')
        setIsConnecting(false)
        
        // 清理已创建的资源
        await cleanupResources()
      }
    }
  }

  // MARK: - Cleanup
  const cleanupResources = async () => {
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
    if (rtmClientRef.current) {
      try {
        await rtmClientRef.current.logout()
      } catch (e) {}
      rtmClientRef.current = null
    }
    if (convoAIAPIRef.current) {
      try {
        convoAIAPIRef.current.unsubscribe()
        convoAIAPIRef.current.removeAllEventListeners()
      } catch (e) {}
      convoAIAPIRef.current = null
    }
  }

  const handleEndCall = async () => {
    await cleanupResources()
    setToken('')
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


  const isDisabled = !channelName.trim() || !appId.trim() || isConnecting

  // MARK: - Render
  if (viewMode === 'chat') {
    return (
      <div className="chat-view">
        <div className="chat-view-container">
          {/* 字幕滚动视图 */}
          <TranscriptScrollView 
            transcripts={transcripts} 
            scrollRef={scrollRef}
          />

          {/* 控制栏 */}
          <ControlBar
            isMicMuted={isMicMuted}
            onToggleMicrophone={toggleMicrophone}
            onEndCall={handleEndCall}
          />
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
            <label htmlFor="app-id" className="form-label">
              App ID
            </label>
            <input
              id="app-id"
              type="text"
              placeholder="请输入 Agora App ID"
              value={appId}
              onChange={(e) => setAppId(e.target.value)}
              className="channel-input"
              autoFocus
              disabled={isConnecting}
            />
          </div>

          <div className="form-group">
            <label htmlFor="app-certificate" className="form-label">
              App Certificate <span style={{ color: '#9ca3af', fontSize: '0.75rem' }}>(选填)</span>
            </label>
            <input
              id="app-certificate"
              type="text"
              placeholder="请输入 Agora App Certificate（可选）"
              value={appCertificate}
              onChange={(e) => setAppCertificate(e.target.value)}
              className="channel-input"
              disabled={isConnecting}
            />
          </div>

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
          {/* 麦克风控制 */}
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

          {/* 结束通话按钮 */}
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

