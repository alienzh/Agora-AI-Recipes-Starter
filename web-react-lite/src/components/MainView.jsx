import { useState, useEffect, useLayoutEffect, useRef } from 'react'
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

  // Load saved configuration from localStorage on page load
  useEffect(() => {
    const savedConfig = loadConfig()
    if (savedConfig) {
      setAppId(savedConfig.appId)
      setAppCertificate(savedConfig.appCertificate)
      setChannelName(savedConfig.channelName)
    }
    // Add initial log
    if (addLog) {
      addLog('Waiting for connection...', 'info')
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // Safely add log
  const safeAddLog = (message, type = 'info') => {
    if (addLog && typeof addLog === 'function') {
      addLog(message, type)
    }
  }

  // MARK: - Engine Initialization
  const initializeRTM = (uid) => {
    if (rtmClientRef.current) {
      safeAddLog('RTM Client already initialized', 'info')
      return rtmClientRef.current
    }

    if (!appId) {
      safeAddLog('RTM Client initialization failed: AG_APP_ID not configured', 'error')
      throw new Error('AG_APP_ID not configured')
    }

    try {
      const userId = String(uid)
      const rtmClient = new AgoraRTM.RTM(appId, userId)
      rtmClientRef.current = rtmClient
      safeAddLog('RTM Client initialized successfully', 'success')
      return rtmClient
    } catch (error) {
      safeAddLog(`RTM Client initialization failed: ${error.message}`, 'error')
      throw error
    }
  }

  const initializeRTC = () => {
    if (rtcClientRef.current) {
      safeAddLog('RTC Engine already initialized', 'info')
      return rtcClientRef.current
    }

    if (!appId) {
      safeAddLog('RTC Engine initialization failed: AG_APP_ID not configured', 'error')
      throw new Error('AG_APP_ID not configured')
    }

    try {
      try {
        AgoraRTC.setParameter('ENABLE_AUDIO_PTS', true)
      } catch (error) {
        console.warn('[RTC] Failed to set audio PTS parameter:', error)
      }

      const rtcClient = AgoraRTC.createClient({ mode: 'rtc', codec: 'vp8' })
      rtcClientRef.current = rtcClient
      
      // Bind RTC event listeners
      bindRTCEvents(rtcClient)
      
      safeAddLog('RTC Engine initialized successfully', 'success')
      return rtcClient
    } catch (error) {
      safeAddLog(`RTC Engine initialization failed: ${error.message}`, 'error')
      throw error
    }
  }

  // Bind RTC event listeners
  const bindRTCEvents = (client) => {
    // User joined channel
    client.on('user-joined', (user) => {
      console.log('[RTC Callback] User joined:', user.uid)
      safeAddLog(`onUserJoined: ${user.uid}`, 'success')
    })

    // User left channel
    client.on('user-left', (user, reason) => {
      console.log('[RTC Callback] User left:', user.uid, 'reason:', reason)
      safeAddLog(`User left: ${user.uid} (${reason || 'Unknown reason'})`, 'info')
    })

    // User published audio/video stream
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

    // Connection state change
    client.on('connection-state-change', (curState, revState, reason) => {
      console.log('[RTC Callback] Connection state changed:', { current: curState, previous: revState, reason })
      if (curState === 'CONNECTED') {
        safeAddLog('onJoinChannelSuccess', 'success')
      } else if (curState === 'DISCONNECTED') {
        if (reason === 'LEAVE') {
          safeAddLog('Left channel', 'info')
        } else {
          safeAddLog(`Connection disconnected: ${reason || 'Unknown reason'}`, 'error')
        }
      } else if (curState === 'FAILED') {
        safeAddLog(`Connection failed: ${reason || 'Unknown reason'}`, 'error')
      }
    })
  }

  // Setup ConvoAI event listeners
  const setupConvoAIEvents = () => {
    if (!convoAIAPIRef.current) return

    const convoAIAPI = convoAIAPIRef.current

    // Register transcript update event callback
    convoAIAPI.on(EConversationalAIAPIEvents.TRANSCRIPT_UPDATED, (chatHistory) => {
      console.log('[ConvoAI] ===== TRANSCRIPT_UPDATED event triggered =====')
      console.log('[ConvoAI] Transcript updated, items count:', chatHistory.length)
      
      if (!chatHistory || chatHistory.length === 0) {
        console.warn('[ConvoAI] Chat history is empty')
        return
      }
      
      // Convert chat history to transcripts format
      const newTranscripts = chatHistory
        .sort((a, b) => {
          // Sort by turn_id first
          if (a.turn_id !== b.turn_id) {
            return a.turn_id - b.turn_id
          }
          // Then sort by uid
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
          // Determine if user or Agent: uid === 0 is user, otherwise Agent
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

    // Register Agent state change event callback
    convoAIAPI.on(EConversationalAIAPIEvents.AGENT_STATE_CHANGED, (agentUserId, event) => {
      console.log('[ConvoAI] Agent state changed:', agentUserId, event.state)
    })

    // Register error event callback
    convoAIAPI.on(EConversationalAIAPIEvents.AGENT_ERROR, (agentUserId, error) => {
      console.error('[ConvoAI] Agent error:', agentUserId, error)
    })
  }

  // MARK: - Constants
  const UID_MIN = 1000
  const UID_MAX = 9999999
  const TOKEN_EXPIRE_TIME = 86400 // 24 hours

  // MARK: - Connection Flow
  const handleConnect = async (e) => {
    e.preventDefault()
    if (channelName.trim() && appId.trim() && !isConnecting) {
      setIsConnecting(true)
      
      // Clear previous logs and start new connection
      if (clearLogs) {
        clearLogs()
      }
      
      // Save configuration to localStorage
      saveConfig(appId, appCertificate, channelName)
      
      const uid = Math.floor(Math.random() * (UID_MAX - UID_MIN + 1)) + UID_MIN
      uidRef.current = uid
      const channel = channelName.trim()
      
      try {
        safeAddLog('Starting connection...', 'info')
        safeAddLog(`App ID: ${appId}`, 'info')
        safeAddLog(`Channel Name: ${channel}`, 'info')

        // Step 1: Initialize engines
        safeAddLog('Initializing RTM engine...', 'info')
        initializeRTM(uid)
        
        safeAddLog('Initializing RTC engine...', 'info')
        initializeRTC()

        // Step 2: Generate user token
        safeAddLog('Requesting token...', 'info')
        const userToken = await generateToken(channel, String(uid), TOKEN_EXPIRE_TIME, [1, 2], appId, appCertificate)
        // userToken can be null (no token used), which is valid
        if (userToken === undefined) {
          throw new Error('Failed to get token, please try again')
        }
        setToken(userToken || '')
        if (userToken === null) {
          safeAddLog('No token used (App Certificate not configured)', 'info')
        } else {
          safeAddLog('Token retrieved successfully', 'success')
        }

        // Step 3: RTM login
        safeAddLog('RTM Login calling...', 'info')
        try {
          // If userToken is null, don't pass token parameter
          if (userToken === null) {
            await rtmClientRef.current.login()
          } else {
            await rtmClientRef.current.login({ token: userToken })
          }
          safeAddLog('RTM Login successful', 'success')
        } catch (error) {
          if (error.code === -10017 || error.message?.includes('Same subscribe, join or login request')) {
            safeAddLog('RTM Login successful (already logged in)', 'success')
          } else {
            throw error
          }
        }

        // Step 4: RTC join channel
        safeAddLog('joinChannel calling...', 'info')
        
        // Create local audio track
        if (!localAudioTrackRef.current) {
          localAudioTrackRef.current = await AgoraRTC.createMicrophoneAudioTrack({
            AEC: true,
            ANS: false,
            AGC: true
          })
        }

        // Join channel (if userToken is null, pass null to join method)
        const userId = typeof uid === 'number' ? uid : parseInt(uid, 10)
        await rtcClientRef.current.join(appId, channel, userToken, userId)
        safeAddLog('joinChannel successful', 'success')

        // Publish local audio track
        if (localAudioTrackRef.current) {
          await rtcClientRef.current.publish([localAudioTrackRef.current])
        }

        // Step 5: RTM join channel
        safeAddLog('RTM joining channel...', 'info')
        await rtmClientRef.current.subscribe(channel)
        safeAddLog('RTM joined channel successfully', 'success')

        // Step 6: Initialize ConvoAI API
        safeAddLog('Initializing ConvoAI API...', 'info')
        const convoAIAPI = ConversationalAIAPI.init({
          rtcEngine: rtcClientRef.current,
          rtmEngine: rtmClientRef.current,
          enableLog: true,
          renderMode: undefined
        })
        convoAIAPIRef.current = convoAIAPI
        safeAddLog('ConvoAI API initialized successfully', 'success')

        // Step 7: Subscribe to ConvoAI messages
        safeAddLog('Subscribing to ConvoAI messages...', 'info')
        convoAIAPI.subscribeMessage(channel)
        safeAddLog('Subscribed to ConvoAI messages successfully', 'success')

        // Setup ConvoAI event listeners
        setupConvoAIEvents()

        safeAddLog('Connection successful, entering chat page', 'success')
        
        // All steps successful, switch to chat view
        setIsConnecting(false)
        setViewMode('chat')
      } catch (error) {
        console.error('[Connection] Connection failed:', error)
        
        // Optimize error messages
        let errorMessage = 'Connection failed'
        if (error.message) {
          if (error.message.includes('App ID')) {
            errorMessage = `Connection failed: ${error.message}, please check App ID configuration`
          } else if (error.message.includes('token') || error.message.includes('Token')) {
            errorMessage = `Connection failed: ${error.message}, please check App Certificate configuration`
          } else if (error.message.includes('network') || error.message.includes('Network')) {
            errorMessage = `Connection failed: Network error, please check network connection`
          } else if (error.message.includes('timeout') || error.message.includes('Timeout')) {
            errorMessage = `Connection failed: Request timeout, please try again later`
          } else {
            errorMessage = `Connection failed: ${error.message}`
          }
        } else if (error.code) {
          errorMessage = `Connection failed: Error code ${error.code}`
        }
        
        safeAddLog(errorMessage, 'error')
        setIsConnecting(false)
        
        // Cleanup created resources
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
          {/* Transcript scroll view */}
          <TranscriptScrollView 
            transcripts={transcripts} 
            scrollRef={scrollRef}
          />

          {/* Control bar */}
          <ControlBar
            isMicMuted={isMicMuted}
            onToggleMicrophone={toggleMicrophone}
            onEndCall={handleEndCall}
          />
        </div>
      </div>
    )
  }

  // Configuration view
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
              placeholder="Enter Agora App ID"
              value={appId}
              onChange={(e) => setAppId(e.target.value)}
              className="channel-input"
              autoFocus
              disabled={isConnecting}
            />
          </div>

          <div className="form-group">
            <label htmlFor="app-certificate" className="form-label">
              App Certificate <span style={{ color: '#9ca3af', fontSize: '0.75rem' }}>(Optional)</span>
            </label>
            <input
              id="app-certificate"
              type="text"
              placeholder="Enter Agora App Certificate (optional)"
              value={appCertificate}
              onChange={(e) => setAppCertificate(e.target.value)}
              className="channel-input"
              disabled={isConnecting}
            />
          </div>

          <div className="form-group">
            <label htmlFor="channel-name" className="form-label">
              Channel Name
            </label>
            <input
              id="channel-name"
              type="text"
              placeholder="Enter channel name"
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
                Connecting...
              </>
            ) : (
              'Connect Conversational AI Engine'
            )}
          </button>
        </form>
      </div>
    </div>
  )
}

// Transcript scroll view
function TranscriptScrollView({ transcripts, scrollRef }) {
  // Use useLayoutEffect to scroll immediately after DOM update for better reliability
  useLayoutEffect(() => {
    if (scrollRef.current && transcripts.length > 0) {
      // Use requestAnimationFrame to ensure execution before browser paint
      requestAnimationFrame(() => {
        if (scrollRef.current) {
          scrollRef.current.scrollTo({
            top: scrollRef.current.scrollHeight,
            behavior: 'smooth'
          })
        }
      })
    }
  }, [transcripts, scrollRef])

  return (
    <div className="transcript-scroll-view" ref={scrollRef}>
      <div className="transcript-list">
        {transcripts.length === 0 ? (
          <div className="empty-transcript">
            <p>Waiting for conversation to start...</p>
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

// Transcript row
function TranscriptRow({ transcript }) {
  const isAgent = transcript.type === 'agent'
  
  return (
    <div className={`transcript-row ${isAgent ? 'agent' : 'user'}`}>
      <div className="transcript-avatar" style={{ backgroundColor: isAgent ? '#3b82f6' : '#10b981' }}>
        {isAgent ? 'AI' : 'Me'}
      </div>
      <div className="transcript-content">
        <p>{transcript.text}</p>
      </div>
    </div>
  )
}

// Control bar
function ControlBar({ isMicMuted, onToggleMicrophone, onEndCall }) {
  return (
    <div className="control-bar">
      <div className="control-bar-content">
        <div className="control-group">
          {/* Microphone control */}
          <button
            className={`microphone-button ${isMicMuted ? 'muted' : ''}`}
            onClick={onToggleMicrophone}
            aria-label={isMicMuted ? 'Unmute' : 'Mute'}
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

          {/* End call button */}
          <button
            className="end-call-button"
            onClick={onEndCall}
            aria-label="End call"
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

