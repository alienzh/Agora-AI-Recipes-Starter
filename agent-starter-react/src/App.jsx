import { useState } from 'react'
import EntranceView from './components/EntranceView'
import ChatView from './components/ChatView'
import './App.css'

function App() {
  const [currentView, setCurrentView] = useState('entrance')
  const [chatData, setChatData] = useState(null)

  const handleStart = (uid, channel) => {
    setChatData({ uid, channel })
    setCurrentView('chat')
  }

  const handleClose = () => {
    setCurrentView('entrance')
    setChatData(null)
  }

  return (
    <div className="App">
      {currentView === 'entrance' ? (
        <EntranceView onStart={handleStart} />
      ) : (
        <ChatView 
          uid={chatData?.uid} 
          channel={chatData?.channel} 
          onClose={handleClose}
        />
      )}
    </div>
  )
}

export default App

