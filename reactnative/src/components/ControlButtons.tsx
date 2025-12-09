import React from 'react';
import { View, TouchableOpacity, Text, StyleSheet, Alert } from 'react-native';
import { ConnectionState } from '../types';

interface ControlButtonsProps {
  connectionState: ConnectionState;
  isMuted: boolean;
  onStart: () => Promise<void>;
  onStop: () => Promise<void>;
  onToggleMute: () => void;
}

export const ControlButtons: React.FC<ControlButtonsProps> = ({
  connectionState,
  isMuted,
  onStart,
  onStop,
  onToggleMute,
}) => {
  const handleStart = async () => {
    try {
      await onStart();
    } catch (error: any) {
      Alert.alert('启动失败', error?.message || '未知错误');
    }
  };

  const handleStop = async () => {
    try {
      await onStop();
    } catch (error: any) {
      Alert.alert('停止失败', error?.message || '未知错误');
    }
  };

  return (
    <View style={styles.container}>
      {connectionState === ConnectionState.Idle && (
        <TouchableOpacity
          style={[styles.button, styles.startButton]}
          onPress={handleStart}
        >
          <Text style={styles.buttonText}>Start Agent</Text>
        </TouchableOpacity>
      )}

      {connectionState === ConnectionState.Connecting && (
        <TouchableOpacity style={[styles.button, styles.buttonDisabled]} disabled>
          <Text style={styles.buttonText}>连接中...</Text>
        </TouchableOpacity>
      )}

      {connectionState === ConnectionState.Connected && (
        <>
          <TouchableOpacity
            style={[styles.button, styles.muteButton]}
            onPress={onToggleMute}
          >
            <Text style={styles.buttonText}>
              {isMuted ? '🔇 取消静音' : '🎤 静音'}
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.button, styles.stopButton]}
            onPress={handleStop}
          >
            <Text style={styles.buttonText}>停止 Agent</Text>
          </TouchableOpacity>
        </>
      )}

      {connectionState === ConnectionState.Error && (
        <>
          <TouchableOpacity
            style={[styles.button, styles.startButton]}
            onPress={handleStart}
          >
            <Text style={styles.buttonText}>重试</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.button, styles.stopButton]}
            onPress={handleStop}
          >
            <Text style={styles.buttonText}>停止</Text>
          </TouchableOpacity>
        </>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 16,
    backgroundColor: '#f5f5f5',
    borderTopWidth: 1,
    borderTopColor: '#e0e0e0',
    gap: 12,
  },
  button: {
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
    minWidth: 120,
    alignItems: 'center',
  },
  startButton: {
    backgroundColor: '#007AFF',
  },
  muteButton: {
    backgroundColor: '#34C759',
  },
  muteButtonActive: {
    backgroundColor: '#FF3B30',
  },
  stopButton: {
    backgroundColor: '#FF3B30',
  },
  buttonDisabled: {
    backgroundColor: '#ccc',
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
});

