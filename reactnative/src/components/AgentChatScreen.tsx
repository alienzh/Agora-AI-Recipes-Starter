import React, { useEffect } from 'react';
import { View, StyleSheet, Alert } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useAgentChatStore } from '../stores/AgentChatStore';
import { LogView } from './LogView';
import { TranscriptList } from './TranscriptList';
import { ControlButtons } from './ControlButtons';
import { requestAudioPermission } from '../utils/PermissionHelper';
import { ConnectionState } from '../types';

export const AgentChatScreen: React.FC = () => {
  const insets = useSafeAreaInsets();
  const {
    connectionState,
    agentState,
    transcripts,
    logs,
    isMuted,
    startConnection,
    stopAgent,
    toggleMute,
    initRtcEngine,
  } = useAgentChatStore();

  // Initialize RTC engine when component mounts
  useEffect(() => {
    initRtcEngine();
  }, [initRtcEngine]);

  const handleStart = async () => {
    try {
      // 1. 请求权限
      const hasPermission = await requestAudioPermission();
      if (!hasPermission) {
        Alert.alert('需要音频权限', '应用需要访问麦克风以进行语音对话');
        return;
      }

      // 2. 开始连接
      await startConnection();
    } catch (error: any) {
      Alert.alert('启动失败', error?.message || '未知错误');
    }
  };

  useEffect(() => {
    // 当连接状态变为错误时，可以显示错误提示
    if (connectionState === ConnectionState.Error) {
      // 错误信息已经在 logs 中显示，这里可以添加额外的错误处理
    }
  }, [connectionState]);

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      {/* 日志区域 */}
      <LogView logs={logs} />

      {/* 转录列表区域 */}
      <TranscriptList transcripts={transcripts} agentState={agentState} />

      {/* 控制按钮 */}
      <ControlButtons
        connectionState={connectionState}
        isMuted={isMuted}
        onStart={handleStart}
        onStop={stopAgent}
        onToggleMute={toggleMute}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
});

