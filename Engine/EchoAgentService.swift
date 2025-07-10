//
//  Engine/EchoAgentService.swift
//  Storm
//
//  Provides query and mutation helpers for EchoAgent entities.
//
//  Created by Wenyan Qin on 2025-07-10.
//

import Foundation

/// Helper service for working with EchoAgent entities.
final class EchoAgentService: ObservableObject {

    private let ecs: ECSCore
    private let agentEntityID: EntityID
    @Published var currentMood: String = "Unknown"

    init(ecs: ECSCore, agentID: EntityID) {
        self.ecs = ecs
        self.agentEntityID = agentID
        refreshMood()
    }

    /// Updates mood of the tracked agent and publishes it.
    func updateAgentMood(to mood: String) {
        if let agent = ecs.getWorld().getComponent(ofType: EchoAgentComponent.self, from: agentEntityID) {
            agent.mood = mood
            currentMood = mood
            print("[📝] Updated EchoAgent \(agentEntityID) mood → \(mood)")
        } else {
            print("[⚠️] No EchoAgent found for stored agentID.")
        }
    }

    /// Appends a message to the agent's memory.
    func appendMemory(_ message: String) {
        if let agent = ecs.getWorld().getComponent(ofType: EchoAgentComponent.self, from: agentEntityID) {
            agent.memory.append(message)
            print("[📝] Appended to EchoAgent \(agentEntityID) memory → \(message)")
        }
    }

    /// Refreshes the published mood property.
    func refreshMood() {
        if let agent = ecs.getWorld().getComponent(ofType: EchoAgentComponent.self, from: agentEntityID) {
            currentMood = agent.mood
        } else {
            currentMood = "Unknown"
        }
    }
}
