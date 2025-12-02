import { useState, useEffect, useRef } from 'react'
import { generateToken } from '../utils/api'
import { env } from '../config/env'
import AgoraRTM from 'agora-rtm'
import AgoraRTC from 'agora-rtc-sdk-ng'
import { ConversationalAIAPI } from '../conversational-ai-api'
import { EConversationalAIAPIEvents } from '../conversational-ai-api/type'
import AgentManager from '../utils/AgentManager'
import './chat-view.css'

function ChatView({ uid, channel, onClose }) {
  // MARK: - State
  const [transcripts, setTranscripts] = useState([])
  const [isMicMuted, setIsMicMuted] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [isError, setIsError] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')
  const scrollRef = useRef(null)
  
  // MARK: - Log State
  const [logs, setLogs] = useState([])
  const logScrollRef = useRef(null)

  // MARK: - Agora Components State
  const [token, setToken] = useState('')
  const [agentToken, setAgentToken] = useState('')
  const [agentId, setAgentId] = useState('')
  const agentUid = useRef(Math.floor(Math.random() * (99999999 - 10000000 + 1)) + 10000000)
  
  // RTM 和 RTC 引擎引用
  const rtmClientRef = useRef(null)
  const rtcClientRef = useRef(null)
  const convoAIAPIRef = useRef(null)
  const localAudioTrackRef = useRef(null) // 本地音频轨道引用

  // MARK: - Log Helper
  /**
   * 添加日志
   * @param {string} message - 日志消息
   * @param {string} type - 日志类型: 'success', 'error', 'info'
   */
  const addLog = (message, type = 'info') => {
    const timestamp = new Date().toLocaleTimeString('zh-CN', { hour12: false })
    const logEntry = {
      id: Date.now() + Math.random(),
      timestamp,
      message,
      type
    }
    setLogs(prev => [...prev, logEntry])
    // 自动滚动到底部
    setTimeout(() => {
      if (logScrollRef.current) {
        logScrollRef.current.scrollTop = logScrollRef.current.scrollHeight
      }
    }, 0)
  }

  // MARK: - Lifecycle - 6 个步骤的连接流程
  useEffect(() => {
    // 参数验证
    if (!channel || !uid) {
      setIsError(true)
      setErrorMessage('缺少频道名称或用户ID')
      return
    }

    let isCancelled = false

    const startConnection = async () => {
      setIsLoading(true)
      setIsError(false)
      setErrorMessage('')

      try {
        // 步骤 1: 生成用户 token
        const userToken = await generateUserToken()
        if (isCancelled) return

        // 步骤 2: RTM 登录
        await loginRTM(userToken)
        if (isCancelled) return

        // 步骤 3: RTC 加入频道
        await joinRTCChannel(userToken)
        if (isCancelled) return

        // 步骤 4: RTM 加入频道
        // 参考 VoiceAgent: await rtmHelper.join(channel_name)
        await joinRTMChannel()
        if (isCancelled) return

        // 步骤 5: 订阅 ConvoAI 消息
        await subscribeConvoAIMessage()
        if (isCancelled) return

        // 步骤 6: 生成 agentToken
        const agentTokenValue = await generateAgentToken()
        if (isCancelled) return

        // 步骤 7: 启动 Agent
        await startAgent(agentTokenValue)
        if (isCancelled) return

        if (!isCancelled) {
          setIsLoading(false)
          console.log('[Connection] Connection established successfully')
        }
      } catch (error) {
        if (!isCancelled) {
          console.error('[Connection] Connection failed:', error)
          setIsError(true)
          setErrorMessage(error.message || '连接失败')
          setIsLoading(false)
        }
      }
    }

    startConnection()

    // Cleanup function: 组件卸载或依赖变化时清理资源
    return () => {
      isCancelled = true
      resetConnectionState()
    }
  }, [channel, uid])

  // MARK: - Page Unload Handler
  /**
   * 监听页面刷新/关闭事件，确保在离开页面时停止 Agent
   * 对应 iOS: viewWillDisappear 或 deinit
   */
  useEffect(() => {
    const handleBeforeUnload = (event) => {
      // 如果 Agent 正在运行，尝试停止它
      if (agentId) {
        // 注意：beforeunload 事件中无法使用 async/await，所以使用 sendBeacon 或 fetch with keepalive
        try {
          // 构建停止 Agent 的 URL
          // 开发环境使用 localhost:3001，生产环境使用相对路径
          const isDev = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
          const baseUrl = isDev ? 'http://localhost:3001/api' : '/api'
          const url = `${baseUrl}/agent/stop`
          
          // 使用 fetch with keepalive（推荐方式，比 sendBeacon 更可靠）
          fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ agentId }),
            keepalive: true // 允许请求在页面卸载后继续
          }).catch(err => {
            console.error('[Agent] Failed to stop agent on page unload:', err)
          })
          
          console.log('[Agent] Stop agent request sent on page unload')
        } catch (error) {
          console.error('[Agent] Error stopping agent on page unload:', error)
        }
      }
    }

    // 监听 beforeunload 事件
    window.addEventListener('beforeunload', handleBeforeUnload)

    // 清理函数
    return () => {
      window.removeEventListener('beforeunload', handleBeforeUnload)
    }
  }, [agentId]) // 依赖 agentId，当 agentId 变化时重新绑定

  // MARK: - Engine Initialization
  /**
   * 初始化 RTM 引擎
   * 对应 iOS: initializeRTM()
   * 参考 VoiceAgent: RTMHelper.initClient()
   */
  const initializeRTM = () => {
    if (rtmClientRef.current) {
      console.warn('[RTM] RTM already initialized, skipping re-initialization')
      addLog('RTM Client 已初始化', 'info')
      return rtmClientRef.current
    }

    if (!env.AG_APP_ID) {
      addLog('RTM Client 初始化失败: AG_APP_ID 未配置', 'error')
      throw new Error('AG_APP_ID 未配置')
    }

    try {
      // 参考 VoiceAgent: new AgoraRTM.RTM(app_id, user_id)
      const userId = String(uid)
      console.log('[Engine Init] Initializing RTM with userId:', userId, 'uid type:', typeof uid, 'uid value:', uid)
      const rtmClient = new AgoraRTM.RTM(env.AG_APP_ID, userId)
      rtmClientRef.current = rtmClient

      console.log('[Engine Init] RTM initialized successfully')
      addLog('RTM Client 初始化成功', 'success')
      return rtmClient
    } catch (error) {
      console.error('[Engine Init] RTM initialization failed:', error)
      addLog(`RTM Client 初始化失败: ${error.message}`, 'error')
      throw error
    }
  }

  /**
   * 初始化 RTC 引擎
   * 对应 iOS: initializeRTC()
   * 参考 VoiceAgent: RTCHelper 构造函数
   */
  const initializeRTC = () => {
    if (rtcClientRef.current) {
      console.warn('[RTC] RTC already initialized, skipping re-initialization')
      addLog('RTC Engine 已初始化', 'info')
      return rtcClientRef.current
    }

    if (!env.AG_APP_ID) {
      addLog('RTC Engine 初始化失败: AG_APP_ID 未配置', 'error')
      throw new Error('AG_APP_ID 未配置')
    }

    try {
      // 参考 VoiceAgent: 设置必要的参数
      try {
        // 设置音频 PTS 参数（用于 ConvoAI）
        AgoraRTC.setParameter('ENABLE_AUDIO_PTS', true)
        console.log('[RTC] Audio PTS parameter set')
      } catch (error) {
        console.warn('[RTC] Failed to set audio PTS parameter:', error)
      }

      // 参考 VoiceAgent: AgoraRTC.createClient({ mode: 'rtc', codec: 'vp8' })
      const rtcClient = AgoraRTC.createClient({ mode: 'rtc', codec: 'vp8' })
      rtcClientRef.current = rtcClient

      // 绑定 RTC 事件监听（Web 使用事件监听模式，iOS 使用代理模式）
      bindRTCEvents(rtcClient)

      console.log('[Engine Init] RTC initialized successfully')
      addLog('RTC Engine 初始化成功', 'success')
      return rtcClient
    } catch (error) {
      console.error('[Engine Init] RTC initialization failed:', error)
      addLog(`RTC Engine 初始化失败: ${error.message}`, 'error')
      throw error
    }
  }

  /**
   * 绑定 RTC 事件监听
   * 对应 iOS: AgoraRtcEngineDelegate 代理方法
   * 参考 VoiceAgent: RTCHelper.bindRtcEvents()
   * @param {IAgoraRTCClient} client - RTC 客户端
   */
  const bindRTCEvents = (client) => {
    // 用户加入频道
    client.on('user-joined', (user) => {
      console.log('[RTC Callback] User joined:', user.uid)
      addLog(`onUserJoined: ${user.uid}`, 'success')
    })

    // 用户离开频道
    client.on('user-left', (user, reason) => {
      console.log('[RTC Callback] User left:', user.uid, 'reason:', reason)
    })

    // 用户发布音视频流（重要：订阅远程音频）
    client.on('user-published', async (user, mediaType) => {
      console.log('[RTC Callback] User published:', user.uid, 'mediaType:', mediaType)
      try {
        // 订阅远程用户的音频流
        await client.subscribe(user, mediaType)
        
        if (mediaType === 'audio' && user.audioTrack) {
          // 播放远程音频
          user.audioTrack.play()
          console.log('[RTC Callback] Remote audio track playing, userId:', user.uid)
        }
      } catch (error) {
        console.error('[RTC Callback] Failed to subscribe user:', error)
      }
    })

    // 用户取消发布音视频流
    client.on('user-unpublished', (user, mediaType) => {
      console.log('[RTC Callback] User unpublished:', user.uid, 'mediaType:', mediaType)
      if (mediaType === 'audio' && user.audioTrack) {
        user.audioTrack.stop()
      }
    })

    // 连接状态变化
    client.on('connection-state-change', (curState, revState, reason) => {
      console.log('[RTC Callback] Connection state changed:', {
        current: curState,
        previous: revState,
        reason: reason
      })
      if (curState === 'CONNECTED') {
        addLog('onJoinChannelSuccess', 'success')
      } else if (curState === 'DISCONNECTED' || curState === 'FAILED') {
        addLog(`onError: ${reason || '连接失败'}`, 'error')
      }
    })

    // 网络质量
    client.on('network-quality', (quality) => {
      // console.log('[RTC Callback] Network quality:', quality)
    })
  }

  // MARK: - Token Generation
  /**
   * 步骤 1: 生成用户 token
   * 对应 iOS: generateUserToken()
   * @returns {Promise<string>} 返回生成的 token
   */
  const generateUserToken = async () => {
    try {
      addLog('获取 Token 调用中...', 'info')
      const userId = String(uid)
      console.log('[Token] Generating token with userId:', userId, 'uid type:', typeof uid, 'uid value:', uid, 'channel:', channel)
      const userToken = await generateToken(channel, userId, 86400, [1, 2]) // types: [RTC, RTM]
      
      if (!userToken) {
        addLog('获取 Token 调用失败', 'error')
        throw new Error('获取 token 失败，请重试')
      }

      setToken(userToken) // 同时更新 state（用于后续步骤）
      console.log('[Token] User token generated successfully')
      addLog('获取 Token 调用成功', 'success')
      return userToken // 返回 token 供立即使用
    } catch (error) {
      console.error('[Token] User token generation failed:', error)
      addLog(`获取 Token 调用失败: ${error.message}`, 'error')
      throw new Error(`生成用户 token 失败: ${error.message}`)
    }
  }

  /**
   * 步骤 5: 生成 Agent Token
   * 对应 iOS: generateAgentToken()
   * 参考 VoiceAgent: NetworkManager.shared.generateToken(channelName: channel, uid: "\(agentUid)", types: [.rtc, .rtm])
   */
  const generateAgentToken = async () => {
    try {
      // 使用 agentUid 生成 token，类型为 RTC 和 RTM
      const token = await generateToken(channel, String(agentUid.current), 86400, [1, 2])
      
      if (!token) {
        throw new Error('获取 agent token 失败，请重试')
      }

      setAgentToken(token) // 保存到 state
      console.log('[Token] Agent token generated successfully, agentUid:', agentUid.current)
      return token
    } catch (error) {
      console.error('[Token] Agent token generation failed:', error)
      throw new Error(`生成 Agent token 失败: ${error.message}`)
    }
  }

  // MARK: - Agent Management
  /**
   * 步骤 6: 启动 Agent
   * 对应 iOS: startAgent()
   * 参考 VoiceAgent: AgentManager.startAgent(parameter:)
   * @param {string} agentTokenValue - Agent token（从步骤 5 获取）
   */
  const startAgent = async (agentTokenValue) => {
    try {
      // 检查必要的配置
      if (!env.AG_PIPELINE_ID) {
        throw new Error('请配置 VITE_AG_PIPELINE_ID')
      }

      if (!agentTokenValue) {
        throw new Error('Agent token 未生成，请先执行步骤 5')
      }

      // 构建启动参数
      // 参考 iOS: let parameter: [String: Any] = [
      //   "name": channel,
      //   "pipeline_id": KeyCenter.AG_PIPELINE_ID,
      //   "properties": [
      //     "channel": channel,
      //     "agent_rtc_uid": "\(agentUid)",
      //     "remote_rtc_uids": ["*"],
      //     "token": agentToken
      //   ]
      // ]
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

      console.log('[Agent] Starting agent with parameter:', {
        ...parameter,
        properties: {
          ...parameter.properties,
          token: '***' // 隐藏 token 日志
        }
      })

      addLog('Agent Start 调用中...', 'info')
      // 调用 AgentManager 启动 Agent
      const agentId = await AgentManager.startAgent(parameter)

      if (!agentId) {
        addLog('Agent Start 调用失败: 未返回 agentId', 'error')
        throw new Error('启动 Agent 失败：未返回 agentId')
      }

      setAgentId(agentId) // 保存 agentId
      console.log('[Agent] Agent started successfully, agentId:', agentId)
      addLog(`Agent Start 调用成功 (agentId: ${agentId})`, 'success')
      return agentId
    } catch (error) {
      console.error('[Agent] Start agent failed:', error)
      addLog(`Agent Start 调用失败: ${error.message}`, 'error')
      throw new Error(`启动 Agent 失败: ${error.message}`)
    }
  }

  // MARK: - Channel Connection
  /**
   * 步骤 2: RTM 登录
   * 对应 iOS: loginRTM()
   * 参考 VoiceAgent: RTMHelper.login()
   * @param {string} userToken - 用户 token（从步骤 1 获取）
   */
  const loginRTM = async (userToken) => {
    // 如果 RTM 客户端未初始化，先初始化
    if (!rtmClientRef.current) {
      initializeRTM()
    }

    if (!rtmClientRef.current) {
      throw new Error('RTM client 未初始化')
    }

    if (!userToken) {
      throw new Error('Token 未生成，请先执行步骤 1')
    }

    // 获取当前 RTM 客户端的 userId（用于调试）
    const currentUserId = rtmClientRef.current.userId || 'unknown'
    console.log('[RTM] Attempting login with userId:', currentUserId, 'token length:', userToken.length)

    try {
      // 参考 VoiceAgent: client.login({ token })
      await rtmClientRef.current.login({ token: userToken })
      console.log('[RTM] RTM login successful')
    } catch (error) {
      // 如果是重复登录错误，忽略它（可能已经登录成功）
      if (error.code === -10017 || error.message?.includes('Same subscribe, join or login request')) {
        console.warn('[RTM] Duplicate login request detected, assuming already logged in')
        return
      }
      
      console.error('[RTM] RTM login failed:', error)
      console.error('[RTM] Error details:', {
        errorCode: error.code,
        errorMessage: error.message,
        userId: rtmClientRef.current?.userId || 'unknown'
      })
      throw new Error(`rtm 登录失败: ${error.message || error}`)
    }
  }

  /**
   * 步骤 3: RTC 加入频道
   * 对应 iOS: joinRTCChannel()
   * 参考 VoiceAgent: RTCHelper.join() 和 createTracks()、publishTracks()
   * @param {string} userToken - 用户 token（从步骤 1 获取）
   */
  const joinRTCChannel = async (userToken) => {
    // 如果 RTC 客户端未初始化，先初始化
    if (!rtcClientRef.current) {
      initializeRTC()
    }

    if (!rtcClientRef.current) {
      throw new Error('RTC client 未初始化')
    }

    if (!env.AG_APP_ID) {
      throw new Error('AG_APP_ID 未配置')
    }

    if (!userToken) {
      throw new Error('Token 未生成，请先执行步骤 1')
    }

    const userId = typeof uid === 'number' ? uid : parseInt(uid, 10)
    console.log('[RTC] Attempting to join channel:', channel, 'with userId:', userId, 'token length:', userToken.length)

    try {
      // 1. 创建本地麦克风音频轨道
      // 参考 VoiceAgent: AgoraRTC.createMicrophoneAudioTrack()
      if (!localAudioTrackRef.current) {
        console.log('[RTC] Creating microphone audio track...')
        localAudioTrackRef.current = await AgoraRTC.createMicrophoneAudioTrack({
          AEC: true,  // 回声消除
          ANS: false, // 噪声抑制（可选）
          AGC: true   // 自动增益控制
        })
        console.log('[RTC] Microphone audio track created successfully')
      }

      // 2. 加入频道
      // 参考 VoiceAgent: client.join(appId, channel, token, userId)
      addLog(`joinChannel 调用中... (channel: ${channel}, uid: ${userId})`, 'info')
      const ret = await rtcClientRef.current.join(
        env.AG_APP_ID,
        channel,
        userToken,
        userId
      )
      console.log('[RTC] RTC joined channel successfully, ret:', ret)
      addLog(`joinChannel 调用成功 (ret: ${ret})`, 'success')

      // 3. 发布本地音频轨道
      // 参考 VoiceAgent: client.publish([audioTrack])
      if (localAudioTrackRef.current) {
        await rtcClientRef.current.publish([localAudioTrackRef.current])
        console.log('[RTC] Local audio track published successfully')
      }
    } catch (error) {
      console.error('[RTC] RTC join channel failed:', error)
      console.error('[RTC] Error details:', {
        errorCode: error.code,
        errorMessage: error.message,
        channel: channel,
        userId: userId
      })
      throw new Error(`RTC 加入频道失败: ${error.message || error}`)
    }
  }

  /**
   * 步骤 4: RTM 加入频道
   * 对应 VoiceAgent: rtmHelper.join(channel_name)
   * 参考 iOS: 在 RTC 加入频道之后，订阅 ConvoAI 消息之前
   */
  const joinRTMChannel = async () => {
    if (!rtmClientRef.current) {
      throw new Error('RTM client 未初始化')
    }

    try {
      // 参考 VoiceAgent: await rtmHelper.join(channel_name)
      // RTM SDK 使用 subscribe 方法加入频道
      await rtmClientRef.current.subscribe(channel)
      console.log('[RTM] RTM joined channel successfully:', channel)
    } catch (error) {
      console.error('[RTM] RTM join channel failed:', error)
      throw new Error(`RTM 加入频道失败: ${error.message || error}`)
    }
  }

  /**
   * 步骤 5: 订阅 ConvoAI 消息
   * 对应 iOS: subscribeConvoAIMessage()
   * 参考 VoiceAgent: ConversationalAIAPI.init() 和 subscribeMessage()
   */
  const subscribeConvoAIMessage = async () => {
    if (!rtcClientRef.current) {
      throw new Error('RTC client 未初始化')
    }

    if (!rtmClientRef.current) {
      throw new Error('RTM client 未初始化')
    }

    try {
      // 初始化 ConversationalAIAPI
      // 参考 VoiceAgent: ConversationalAIAPI.init({ rtcEngine, rtmEngine, enableLog, renderMode })
      console.log('[ConvoAI] Initializing ConversationalAIAPI...')
      const convoAIAPI = ConversationalAIAPI.init({
        rtcEngine: rtcClientRef.current,
        rtmEngine: rtmClientRef.current,
        enableLog: true, // 开发环境启用日志
        renderMode: undefined // 使用默认模式，会自动判断
      })
      convoAIAPIRef.current = convoAIAPI
      console.log('[ConvoAI] ConversationalAIAPI initialized successfully')

      // 注册转录更新事件回调
      // 参考 VoiceAgent: conversationalAIAPI.on(EConversationalAIAPIEvents.TRANSCRIPT_UPDATED, onTextChanged)
      // chatHistory 的类型是 ITranscriptHelperItem<Partial<IUserTranscription | IAgentTranscription>>[]
      console.log('[ConvoAI] Registering TRANSCRIPT_UPDATED event listener...')
      convoAIAPI.on(EConversationalAIAPIEvents.TRANSCRIPT_UPDATED, (chatHistory) => {
        console.log('[ConvoAI] ===== TRANSCRIPT_UPDATED event triggered =====')
        console.log('[ConvoAI] Transcript updated, items count:', chatHistory.length)
        console.log('[ConvoAI] Chat history (raw):', JSON.stringify(chatHistory, null, 2))
        
        if (!chatHistory || chatHistory.length === 0) {
          console.warn('[ConvoAI] Chat history is empty')
          return
        }
        
        // 将聊天历史转换为 transcripts 格式
        // 参考 VoiceAgent: src/components/home/subtitle.tsx transcription2subtitle()
        // 判断规则：Number(item.uid) === 0 是用户，否则是 Agent
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
            const transcript = {
              id: `${item.turn_id}-${item.uid}-${item._time}`,
              type: isAgent ? 'agent' : 'user',
              text: item.text || '',
              status: item.status || 'completed',
              timestamp: item._time || Date.now()
            }
            console.log('[ConvoAI] Converted transcript item:', transcript)
            return transcript
          })
        
        console.log('[ConvoAI] Converted transcripts (final):', newTranscripts)
        console.log('[ConvoAI] Setting transcripts state with', newTranscripts.length, 'items')
        setTranscripts(newTranscripts)
        console.log('[ConvoAI] ===== Transcripts state updated =====')
      })

      // 注册 Agent 状态变化事件回调（可选）
      convoAIAPI.on(EConversationalAIAPIEvents.AGENT_STATE_CHANGED, (agentUserId, event) => {
        console.log('[ConvoAI] Agent state changed:', agentUserId, event.state)
        // 可以在这里更新 Agent 状态 UI
      })

      // 注册错误事件回调（可选）
      convoAIAPI.on(EConversationalAIAPIEvents.AGENT_ERROR, (agentUserId, error) => {
        console.error('[ConvoAI] Agent error:', agentUserId, error)
      })

      // 订阅消息
      // 参考 VoiceAgent: conversationalAIAPI.subscribeMessage(channel_name)
      // 注意：必须在 RTM join 之后调用 subscribeMessage
      console.log('[ConvoAI] Subscribing to channel messages:', channel)
      convoAIAPI.subscribeMessage(channel)
      console.log('[ConvoAI] Subscribed to channel successfully:', channel)
    } catch (error) {
      console.error('[ConvoAI] Failed to subscribe message:', error)
      throw new Error(`订阅 ConvoAI 消息失败: ${error.message || error}`)
    }
  }

  // MARK: - Actions
  /**
   * 挂断通话
   * 对应 iOS: endCall()
   * 参考 VoiceAgent: AgentManager.stopAgent()
   */
  const handleEndCall = async () => {
    // 清理资源（停止 Agent、离开频道等）
    await resetConnectionState()
    onClose()
  }

  /**
   * 停止 Agent
   * 对应 iOS: AgentManager.stopAgent()
   */
  const stopAgent = async () => {
    if (!agentId) {
      console.warn('[Agent] Agent ID is empty, skip stop agent')
      return
    }

    try {
      await AgentManager.stopAgent(agentId)
      console.log('[Agent] Agent stopped successfully')
    } catch (error) {
      console.error('[Agent] Stop agent failed:', error)
      // 不抛出错误，继续清理其他资源
    }
  }

  const resetConnectionState = async () => {
    // 1. 先停止 Agent
    await stopAgent()

    // 2. 清理 ConvoAI API
    if (convoAIAPIRef.current) {
      try {
        convoAIAPIRef.current.unsubscribe()
        convoAIAPIRef.current.removeAllEventListeners()
        console.log('[ConvoAI] ConvoAI API cleanup successful')
      } catch (error) {
        console.error('[ConvoAI] ConvoAI API cleanup error:', error)
      }
      convoAIAPIRef.current = null
    }

    // 清理 RTM 连接
    if (rtmClientRef.current) {
      try {
        await rtmClientRef.current.logout()
        console.log('[RTM] RTM logout successful')
      } catch (error) {
        console.error('[RTM] RTM logout error:', error)
      }
      rtmClientRef.current = null
    }

    // 清理本地音频轨道
    if (localAudioTrackRef.current) {
      try {
        localAudioTrackRef.current.stop()
        localAudioTrackRef.current.close()
        console.log('[RTC] Local audio track cleanup successful')
      } catch (error) {
        console.error('[RTC] Local audio track cleanup error:', error)
      }
      localAudioTrackRef.current = null
    }

    // 清理 RTC 连接
    if (rtcClientRef.current) {
      try {
        await rtcClientRef.current.leave()
        await rtcClientRef.current.release()
        console.log('[RTC] RTC cleanup successful')
      } catch (error) {
        console.error('[RTC] RTC cleanup error:', error)
      }
      rtcClientRef.current = null
    }

    setToken('')
    setAgentToken('')
    setAgentId('')
    setTranscripts([])
    setIsMicMuted(false)
    setIsError(false)
    setErrorMessage('')
  }

  // MARK: - Error Handling
  useEffect(() => {
    if (isError) {
      const timer = setTimeout(() => {
        handleEndCall()
      }, 2000)
      return () => clearTimeout(timer)
    }
  }, [isError])

  // 自动滚动到底部
  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight
    }
  }, [transcripts])

  // 日志自动滚动到底部
  useEffect(() => {
    if (logScrollRef.current) {
      logScrollRef.current.scrollTop = logScrollRef.current.scrollHeight
    }
  }, [logs])

  /**
   * 切换麦克风静音状态
   * 对应 iOS: toggleMicrophone()
   * 参考 VoiceAgent: audioTrack.setMuted()
   */
  const toggleMicrophone = () => {
    const newMutedState = !isMicMuted
    setIsMicMuted(newMutedState)
    
    // 控制本地音频轨道的静音状态
    if (localAudioTrackRef.current) {
      try {
        localAudioTrackRef.current.setMuted(newMutedState)
        console.log('[Audio] Microphone muted:', newMutedState)
      } catch (error) {
        console.error('[Audio] Failed to set microphone mute state:', error)
      }
    }
  }

  return (
    <div className="chat-view">
      <div className="chat-view-container">
        {/* 左侧：聊天内容区域 */}
        <div className="chat-main-area">
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

        {/* 右侧：日志视图 */}
        <div className="log-view-area">
          <LogView logs={logs} scrollRef={logScrollRef} />
        </div>
      </div>

      {/* 加载提示 */}
      {isLoading && (
        <div className="loading-overlay">
          <div className="loading-spinner"></div>
        </div>
      )}

      {/* 错误提示 */}
      {isError && (
        <div className="error-toast">
          {errorMessage || '发生错误'}
        </div>
      )}
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

// 日志视图
function LogView({ logs, scrollRef }) {
  return (
    <div className="log-view" ref={scrollRef}>
      <div className="log-header">
        <h3>状态日志</h3>
      </div>
      <div className="log-list">
        {logs.length === 0 ? (
          <div className="empty-log">
            <p>等待连接...</p>
          </div>
        ) : (
          logs.map((log) => (
            <LogRow key={log.id} log={log} />
          ))
        )}
      </div>
    </div>
  )
}

// 日志行
function LogRow({ log }) {
  const getTypeClass = () => {
    switch (log.type) {
      case 'success':
        return 'log-success'
      case 'error':
        return 'log-error'
      default:
        return 'log-info'
    }
  }

  return (
    <div className={`log-row ${getTypeClass()}`}>
      <span className="log-timestamp">{log.timestamp}</span>
      <span className="log-message">{log.message}</span>
    </div>
  )
}

export default ChatView

