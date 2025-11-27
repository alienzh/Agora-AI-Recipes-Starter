//
//  EntranceView.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/3.
//

import SwiftUI

struct EntranceView: View {
    @StateObject private var viewModel = EntranceViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Image("logo")
                
                TextField("输入频道名称", text: $viewModel.channelName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .frame(width: 250, height: 50)
                
                Button(action: {
                    viewModel.shouldNavigate = true
                }) {
                    Text("Start")
                        .foregroundColor(.white)
                        .frame(width: 250, height: 50)
                        .background(viewModel.channelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.blue.opacity(0.4) : Color.blue)
                        .cornerRadius(25)
                }
                .disabled(viewModel.channelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.top, 30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("VoiceAgent")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            .navigationDestination(isPresented: $viewModel.shouldNavigate) {
                ChatView(uid: viewModel.uid, channel: viewModel.channelName)
            }
        }
    }
}

#Preview {
    EntranceView()
}
