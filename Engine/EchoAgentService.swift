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
final class EchoAgentService {

    private let ecs: ECSCore

    init(ecs: ECSCore) {
        self.ecs = ecs
    }

    /// Finds the first EchoAgent entity (for simplicity).
    func findFirstAgent() -> (EntityID, EchoAgentComponent)? {
        return ecs.getWorld().entities(with: EchoAgentComponent.self).first
    }

    /// Updates mood of the first agent found.
    func updateAgentMood(to mood: String) {
        if let (id, agent) = findFirstAgent() {
            agent.mood = mood
            print("[📝] Updated EchoAgent \(id) mood → \(mood)")
        } else {
            print("[⚠️] No EchoAgent found to update.")
        }
    }

    /// Appends a message to the agent's memory.
    func appendMemory(_ message: String) {
        if let (id, agent) = findFirstAgent() {
            agent.memory.append(message)
            print("[📝] Appended to EchoAgent \(id) memory → \(message)")
        }
    }
}
