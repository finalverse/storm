//
//  UI/ContentView.swift
//  Storm
//
//  Displays main UI including dynamic HUD, agent mood, and background.
//
//  Created by Wenyan Qin on 2025-07-09.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var composer: UIComposer
    @Environment(\.systemRegistry) var registry

    var body: some View {
        StormMainView()
    }
}

struct AgentMoodView: View {
    @ObservedObject var agentService: EchoAgentService

    var body: some View {
        Text("Agent Mood: \(agentService.currentMood)")
            .font(.subheadline)
            .foregroundColor(.green)
    }
}
