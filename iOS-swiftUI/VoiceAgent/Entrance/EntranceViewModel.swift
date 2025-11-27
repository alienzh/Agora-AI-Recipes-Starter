//
//  EntranceViewModel.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/3.
//

import Foundation
import SwiftUI

class EntranceViewModel: ObservableObject {
    @Published var shouldNavigate: Bool = false
    @Published var channelName: String = ""
    let uid: Int
    
    init() {
        self.uid = Int.random(in: 1000...9999999)
    }
}
