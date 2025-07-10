//
//  Plugins/EchoAgentPlugin.swift
//  Storm
//
//  ECS-driven EchoAgent example plugin with simple mood/memory state.
//
//  Created by Wenyan Qin on 2025-07-10.
//

import Foundation

/// A component representing an Echo Agent's state.
final class EchoAgentComponent: Component {
    var mood: String
    var memory: [String]
    var countdown: TimeInterval

    init(mood: String, memory: [String], countdown: TimeInterval = 5.0) {
        self.mood = mood
        self.memory = memory
        self.countdown = countdown
    }
}

/// A simple ECS system that logs EchoAgent mood every 5 seconds.
final class EchoAgentSystem: ECSStepSystem {

    func update(world: ECSWorld, deltaTime: TimeInterval) {
        for (id, agent) in world.entities(with: EchoAgentComponent.self) {
            agent.countdown -= deltaTime
            if agent.countdown <= 0 {
                print("[🧠] EchoAgent \(id) mood: \(agent.mood) memory: \(agent.memory.joined(separator: ", "))")
                agent.countdown = 5.0 // Reset interval
            }
        }
    }
}

/// A StormPlugin that installs EchoAgent ECS system and spawns an agent.
final class EchoAgentPlugin: StormPlugin {
    private var ecs: ECSCore?

    func setup(registry: SystemRegistry) {
        print("[🤖] EchoAgentPlugin setup...")

        guard let ecs = registry.ecs else {
            print("[⚠️] ECSCore not available for EchoAgentPlugin.")
            return
        }

        self.ecs = ecs

        // Register system.
        ecs.registerSystem(EchoAgentSystem())

    }

    func update(deltaTime: TimeInterval) {
        // Delegate tick to ECS.
        ecs?.tick(deltaTime: deltaTime)
    }
}
