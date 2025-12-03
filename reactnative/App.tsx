/**
 * Agora Conversational AI - React Native Startup
 *
 * @format
 */

import React from 'react';
import { StatusBar, useColorScheme } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { AgentChatScreen } from './src/components/AgentChatScreen';

function App() {
  const isDarkMode = useColorScheme() === 'dark';

  return (
    <SafeAreaProvider>
      <StatusBar barStyle={isDarkMode ? 'light-content' : 'dark-content'} />
      <AgentChatScreen />
    </SafeAreaProvider>
  );
}

export default App;
