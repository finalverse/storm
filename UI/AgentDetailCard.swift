//
//  UI/AgentDetailCard.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-11.
//

import SwiftUI

struct AgentDetailCard: View {
    let mood: String
    let memory: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("🧠 Agent Details")
                .font(.headline)
            Text("Mood: \(mood)")
                .font(.subheadline)
            if !memory.isEmpty {
                Text("Memory:")
                    .font(.caption)
                ForEach(memory, id: \.self) { mem in
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
