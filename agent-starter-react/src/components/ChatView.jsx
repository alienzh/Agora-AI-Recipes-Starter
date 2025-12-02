import { useState, useEffect, useRef } from 'react'
import { generateToken } from '../utils/api'
import './chat-view.css'

function ChatView({ uid, channel, onClose }) {
  const [transcripts, setTranscripts] = useState([])
  const [isMicMuted, setIsMicMuted] = useState(false)
  const [isLoading, setIsLoading] = useState(true)
  const [isError, setIsError] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')
  const [token, setToken] = useState(null)
  const scrollRef = useRef(null)

  // 初始化：请求 token
  useEffect(() => {
    const initChat = async () => {
      if (!channel || !uid) {
        setIsError(true)
        setErrorMessage('缺少频道名称或用户ID')
        setIsLoading(false)
        return
      }

      try {
        setIsLoading(true)
        setIsError(false)
        
        // 请求 token，types 默认为 [1]（可以根据需要调整）
        const userToken = await generateToken(channel, uid, 86400, [1,2])
        const agentToken = await generateToken(channel, uid, 86400, [1,2])
        if (userToken) {
          setToken(userToken)
          console.log('Token generated successfully:', userToken)
          
          // Token 获取成功后，添加假数据（实际项目中这里应该初始化语音通话）
          setTranscripts([
            { id: 1, type: 'agent', text: '你好！我是 AI 语音助手，很高兴为您服务。' },
            { id: 2, type: 'user', text: '你好，我想了解一下你们的产品。' },
            { id: 3, type: 'agent', text: '当然可以！我们的产品主要面向企业用户，提供智能语音交互解决方案。您想了解哪个方面呢？' },
            { id: 4, type: 'user', text: '价格是多少？' },
            { id: 5, type: 'agent', text: '我们的定价方案非常灵活，根据您的使用量和使用场景来定制。基础版每月 99 元起，企业版可以联系我们获取定制报价。' },
          ])
        } else {
          setIsError(true)
          setErrorMessage('Token 生成失败，请检查配置')
        }
      } catch (error) {
        console.error('Initialization error:', error)
        setIsError(true)
        setErrorMessage(error.message || '初始化失败')
      } finally {
        setIsLoading(false)
      }
    }

    initChat()
  }, [channel, uid])

  const handleEndCall = () => {
    // 清理资源
    onClose()
  }

  // 错误处理
  useEffect(() => {
    if (isError) {
      const timer = setTimeout(() => {
        handleEndCall()
      }, 2000)
      return () => clearTimeout(timer)
    }
  }, [isError, onClose])

  // 自动滚动到底部
  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight
    }
  }, [transcripts])

  const toggleMicrophone = () => {
    setIsMicMuted(!isMicMuted)
  }

  return (
    <div className="chat-view">
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
            <span className="mic-icon">{isMicMuted ? '🔇' : '🎤'}</span>
          </button>

          {/* 结束通话按钮 */}
          <button
            className="end-call-button"
            onClick={onEndCall}
            aria-label="结束通话"
          >
            <span className="phone-icon">📞</span>
          </button>
        </div>
      </div>
    </div>
  )
}

export default ChatView
