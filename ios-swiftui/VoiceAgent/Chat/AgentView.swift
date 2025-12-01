//
//  AgentView.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

import SwiftUI
import AlertToast

struct AgentView: View {
    @StateObject private var viewModel = AgentViewModel()
    
    init() {
        print("[AgentView] AgentView initialized")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 明确的背景色
                Color.white
                    .ignoresSafeArea()
                
                // Config View
                if viewModel.showConfigView {
                    ConfigView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            print("[AgentView] ConfigView appeared")
                        }
                }
                
                // Chat View
                if viewModel.showChatView {
                    ChatView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            print("[AgentView] ChatView appeared")
                        }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("VoiceAgent")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.black)
                }
            }
            .toast(isPresenting: $viewModel.isLoading) {
                AlertToast(type: .loading)
            }
            .toast(isPresenting: $viewModel.isError) {
                AlertToast(displayMode: .alert, type: .error(.red), title: viewModel.initializationError?.localizedDescription ?? "发生错误")
            }
            .onChange(of: viewModel.isError) {
                if viewModel.isError {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        viewModel.endCall()
                    }
                }
            }
        }
    }
}

// MARK: - Config View
struct ConfigView: View {
    @ObservedObject var viewModel: AgentViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Image("logo")
            
            TextField("输入频道名称", text: $viewModel.channelName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .frame(width: 250, height: 50)
//                .foregroundColor(.white)
            
            Button(action: {
                viewModel.startConnection()
            }) {
                Text("Start")
                    .foregroundColor(.white)
                    .frame(width: 250, height: 50)
                    .background(viewModel.channelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.blue.opacity(0.4) : Color.blue)
                    .cornerRadius(25)
            }
            .disabled(viewModel.channelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
            .padding(.top, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

// MARK: - Chat View
struct ChatView: View {
    @ObservedObject var viewModel: AgentViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 字幕滚动视图
            TranscriptScrollView(transcripts: viewModel.transcripts)
            
            Spacer()
            
            // 通话控制栏
            ControlBarView(
                viewModel: viewModel,
                onEndCall: {
                    viewModel.endCall()
                }
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color.white)
    }
}

// MARK: - Control Bar View
struct ControlBarView: View {
    @ObservedObject var viewModel: AgentViewModel
    let onEndCall: () -> Void
    
    var body: some View {
        HStack {
            Spacer()
            
            // 居中的按钮组
            HStack(spacing: 30) {
                // 麦克风控制组
                MicrophoneControlGroup(viewModel: viewModel)
                
                // 结束通话按钮
                EndCallButton(onEndCall: onEndCall)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Microphone Control Group
struct MicrophoneControlGroup: View {
    @ObservedObject var viewModel: AgentViewModel
    
    var body: some View {
        HStack(spacing: 8) {
            // 麦克风图标
            Button {
                viewModel.toggleMicrophone()
            } label: {
                Image(systemName: viewModel.isMicMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.black)
            }
        }
    }
}

// MARK: - End Call Button
struct EndCallButton: View {
    let onEndCall: () -> Void
    
    var body: some View {
        Button {
            onEndCall()
        } label: {
            Image(systemName: "phone.down.fill")
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(Color.red)
                .clipShape(Circle())
        }
    }
}

// MARK: - Transcript Scroll View
struct TranscriptScrollView: View {
    let transcripts: [Transcript]
    
    // 为每个字幕生成唯一标识符
    private func transcriptId(_ transcript: Transcript) -> String {
        return "\(transcript.turnId)_\(transcript.type.rawValue)_\(transcript.userId)"
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(transcripts.indices, id: \.self) { index in
                        let transcript = transcripts[index]
                        TranscriptRow(transcript: transcript)
                            .id(transcriptId(transcript))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(maxHeight: .infinity)
            .background(Color.white)
            .onChange(of: transcripts.count) {
                // 当有新字幕添加时，滚动到底部
                if let lastTranscript = transcripts.last {
                    let lastId = transcriptId(lastTranscript)
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Transcript Row
struct TranscriptRow: View {
    let transcript: Transcript
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 头像或标识
            Circle()
                .fill(transcript.type == .agent ? Color.blue : Color.green)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(transcript.type == .agent ? "AI" : "我")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                )
            
            // 字幕内容
            Text(transcript.text)
                .font(.system(size: 15))
                .foregroundColor(.black)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(white: 0.95))
        .cornerRadius(8)
    }
}

#Preview {
    AgentView()
}

