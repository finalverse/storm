//
//  UI/AgentDetailCard.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-11.
//

import SwiftUI

struct AgentDetailCard: View {
    let agent: EchoAgentComponent?

    var body: some View {
        if let agent = agent {
            VStack(alignment: .leading, spacing: 8) {
                Text("🧠 Agent Details")
                    .font(.headline)
                Text("Mood: \(agent.mood)")
                    .font(.subheadline)
                if !agent.memory.isEmpty {
                    Text("Memory:")
                        .font(.caption)
                    ForEach(agent.memory, id: \.self) { mem in
                        Text("- \(mem)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color.black.opacity(0.85))
            .cornerRadius(12)
            .frame(width: 220)
            .foregroundColor(.white)
            .shadow(radius: 10)
        }
    }
}
