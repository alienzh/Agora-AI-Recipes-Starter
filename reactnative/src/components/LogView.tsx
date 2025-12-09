import React, { useRef, useEffect } from 'react';
import { View, Text, ScrollView, StyleSheet } from 'react-native';

interface LogViewProps {
  logs: string[];
}

export const LogView: React.FC<LogViewProps> = ({ logs }) => {
  const scrollViewRef = useRef<ScrollView>(null);

  // Auto scroll to bottom when new logs are added
  useEffect(() => {
    if (scrollViewRef.current && logs.length > 0) {
      setTimeout(() => {
        scrollViewRef.current?.scrollToEnd({ animated: true });
      }, 100);
    }
  }, [logs.length]);

  return (
    <View style={styles.container}>
      <ScrollView
        ref={scrollViewRef}
        style={styles.scrollView}
        contentContainerStyle={styles.scrollContent}
      >
        {logs.length === 0 ? (
          <Text style={styles.emptyText}>暂无日志</Text>
        ) : (
          logs.map((log, index) => (
            <Text key={index} style={styles.logItem}>
              {log}
            </Text>
          ))
        )}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    height: 150,
    backgroundColor: '#f5f5f5',
    padding: 8,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    flexGrow: 1,
  },
  logItem: {
    fontSize: 12,
    color: '#666',
    marginBottom: 2,
    fontFamily: 'monospace',
  },
  emptyText: {
    fontSize: 12,
    color: '#999',
    fontStyle: 'italic',
    textAlign: 'center',
    marginTop: 20,
  },
});

