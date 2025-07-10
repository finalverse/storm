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
        HStack(alignment: .top) {
            VStack(spacing: 16) {
                // App title
                Text("🌩️ Finalverse Storm v0.1.0")
                    .font(.title)
                    .bold()

                // Display current EchoAgent mood if service is available
                if let agentService = registry?.agentService {
                    AgentMoodView(agentService: agentService)
                }

                // Render HUD from UIComposer schema if available
                if let root = composer.rootSchema {
                    UISchemaView(schema: root)
                } else {
                    Text("No HUD loaded.")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.95))
            .foregroundColor(.white)

            // Console log panel on right
            if let console: ConsoleLogService = registry?.resolve("consoleLog") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Console Log")
                        .font(.caption)
                        .foregroundColor(.black)
                    ConsoleLogView(console: console)
                }
            }
        }
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
