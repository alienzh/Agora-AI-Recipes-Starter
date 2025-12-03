import { useState, useRef, useEffect, useCallback } from 'react'
import MainView from './components/MainView'
import './App.css'

function App() {
  const [logs, setLogs] = useState([])
  const logScrollRef = useRef(null)

  // Debug 日志管理 - 使用 useCallback 稳定函数引用
  const addLog = useCallback((message, type = 'info') => {
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
  }, [])

  const clearLogs = () => {
    setLogs([])
  }

  // 日志自动滚动到底部
  useEffect(() => {
    if (logScrollRef.current) {
      logScrollRef.current.scrollTop = logScrollRef.current.scrollHeight
    }
  }, [logs])

  return (
    <div className="App">
      <div className="app-container">
        {/* 左侧：主内容区域 */}
        <div className="app-main-area">
          <MainView addLog={addLog} clearLogs={clearLogs} />
        </div>

        {/* 右侧：Debug 日志视图 */}
        <div className="app-log-area">
          <LogView logs={logs} scrollRef={logScrollRef} />
        </div>
      </div>
    </div>
  )
}

// 日志视图组件
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

// 日志行组件
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

export default App

