import { useState } from 'react'
import './entrance-view.css'

function EntranceView({ onStart }) {
  const [channelName, setChannelName] = useState('')
  const [logoError, setLogoError] = useState(false)

  const handleSubmit = (e) => {
    e.preventDefault()
    if (channelName.trim()) {
      const uid = Math.floor(Math.random() * (9999999 - 1000 + 1)) + 1000
      onStart(uid, channelName.trim())
    }
  }

  const isDisabled = !channelName.trim()

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

        <form onSubmit={handleSubmit} className="entrance-form">
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
            />
          </div>

          <button
            type="submit"
            disabled={isDisabled}
            className={`start-button ${isDisabled ? 'disabled' : ''}`}
          >
            开始
          </button>
        </form>
      </div>
    </div>
  )
}

export default EntranceView

