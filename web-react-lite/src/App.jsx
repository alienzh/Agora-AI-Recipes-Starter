import { useState, useRef, useEffect, useCallback } from 'react'
import MainView from './components/MainView'
import './App.css'

function App() {
  const [logs, setLogs] = useState([])
  const logScrollRef = useRef(null)

  // Debug log management - use useCallback to stabilize function reference
  const addLog = useCallback((message, type = 'info') => {
    const timestamp = new Date().toLocaleTimeString('en-US', { hour12: false })
    const logEntry = {
      id: Date.now() + Math.random(),
      timestamp,
      message,
      type
    }
    setLogs(prev => [...prev, logEntry])
    // Auto scroll to bottom
    setTimeout(() => {
      if (logScrollRef.current) {
        logScrollRef.current.scrollTop = logScrollRef.current.scrollHeight
      }
    }, 0)
  }, [])

  const clearLogs = () => {
    setLogs([])
  }

  // Auto scroll logs to bottom
  useEffect(() => {
    if (logScrollRef.current) {
      logScrollRef.current.scrollTop = logScrollRef.current.scrollHeight
    }
  }, [logs])

  return (
    <div className="App">
      <div className="app-container">
        {/* Left: Main content area */}
        <div className="app-main-area">
          <MainView addLog={addLog} clearLogs={clearLogs} />
        </div>

        {/* Right: Debug log view */}
        <div className="app-log-area">
          <LogView logs={logs} scrollRef={logScrollRef} onClear={clearLogs} />
        </div>
      </div>
    </div>
  )
}

// Log view component
function LogView({ logs, scrollRef, onClear }) {
  return (
    <div className="log-view" ref={scrollRef}>
      <div className="log-header">
        <h3>Status Logs</h3>
        {logs.length > 0 && (
          <button className="log-clear-btn" onClick={onClear} title="Clear logs">
            Clear
          </button>
        )}
      </div>
      <div className="log-list">
        {logs.length === 0 ? (
          <div className="empty-log">
            <p>Waiting for connection...</p>
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

// Log row component
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

