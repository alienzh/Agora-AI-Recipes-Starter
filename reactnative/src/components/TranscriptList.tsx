import React from 'react';
import { FlatList, View, Text, StyleSheet } from 'react-native';
import { Transcript, AgentState, TranscriptType, TranscriptStatus } from '../types';

interface TranscriptListProps {
  transcripts: Transcript[];
  agentState: AgentState;
}

const getAgentStateText = (state: AgentState): string => {
  switch (state) {
    case AgentState.IDLE:
      return 'IDLE';
    case AgentState.SILENT:
      return 'SILENT';
    case AgentState.LISTENING:
      return 'LISTENING';
    case AgentState.THINKING:
      return 'THINKING';
    case AgentState.SPEAKING:
      return 'SPEAKING';
    default:
      return 'UNKNOWN';
  }
};

export const TranscriptList: React.FC<TranscriptListProps> = ({
  transcripts,
  agentState,
}) => {
  const renderItem = ({ item }: { item: Transcript }) => {
    const isUser = item.type === TranscriptType.USER;
    const isInProgress = item.status === TranscriptStatus.IN_PROGRESS;
    const isInterrupted = item.status === TranscriptStatus.INTERRUPTED;
    
    return (
      <View
        style={[
          styles.transcriptItem,
          isUser ? styles.userItem : styles.agentItem,
        ]}
      >
        <Text style={styles.roleLabel}>
          {isUser ? 'USER' : 'AGENT'}
        </Text>
        <Text style={styles.text}>{item.text}</Text>
        {isInProgress && <Text style={styles.statusLabel}>进行中...</Text>}
        {isInterrupted && <Text style={styles.statusLabel}>已中断</Text>}
      </View>
    );
  };

  return (
    <View style={styles.container}>
      {transcripts.length === 0 ? (
        <View style={styles.emptyContainer}>
          <Text style={styles.emptyText}>暂无转录内容</Text>
          <Text style={styles.emptyHint}>
            启动 Agent 后，对话内容将显示在这里
          </Text>
        </View>
      ) : (
        <FlatList
          data={transcripts}
          renderItem={renderItem}
          keyExtractor={(item) => `${item.type}-${item.turnId}`}
          contentContainerStyle={styles.listContent}
        />
      )}
      {/* Agent 状态显示（固定在底部） */}
      <View style={styles.agentStateContainer}>
        <Text style={styles.agentStateText}>
          Agent 状态: {getAgentStateText(agentState)}
        </Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  listContent: {
    padding: 16,
  },
  transcriptItem: {
    marginBottom: 12,
    padding: 12,
    borderRadius: 8,
    maxWidth: '80%',
  },
  userItem: {
    alignSelf: 'flex-end',
    backgroundColor: '#10B981', // 绿色背景
  },
  agentItem: {
    alignSelf: 'flex-start',
    backgroundColor: '#6366F1', // 蓝色背景
  },
  roleLabel: {
    fontSize: 12,
    fontWeight: '600',
    color: '#fff',
    marginBottom: 4,
  },
  text: {
    fontSize: 14,
    color: '#fff',
    lineHeight: 20,
  },
  statusLabel: {
    fontSize: 12,
    color: '#FF9800', // 橙色
    marginTop: 4,
    fontStyle: 'italic',
  },
  agentStateContainer: {
    padding: 16,
    backgroundColor: '#f5f5f5',
    borderTopWidth: 1,
    borderTopColor: '#e0e0e0',
  },
  agentStateText: {
    fontSize: 14,
    fontWeight: '500',
    color: '#333',
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 32,
  },
  emptyText: {
    fontSize: 16,
    color: '#999',
    marginBottom: 8,
  },
  emptyHint: {
    fontSize: 14,
    color: '#ccc',
    textAlign: 'center',
  },
});
