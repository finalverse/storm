//
//  Plugins/LocalWorldPlugin.swift
//  Storm
//
//  Defines the LocalWorldPlugin that seeds a default local agent using Rust FFI for procedural scene fallback.
//
//  Created by Wenyan Qin on 2025-07-12.
//

import Foundation
import RealityKit
import RustStorm

final class LocalWorldPlugin: StormPlugin {
    func setup(registry: SystemRegistry) {
        guard let ecs = registry.ecs else { return }
        let world = ecs.getWorld()

        // Use RustStorm.AgentSpec directly (no local duplicate struct)
        var spec = RustStorm.AgentSpec(x: 0, y: 0, z: 0, mood: 0)
        let count = storm_local_world_init(&spec, 1)
        if count > 0 {
            let entity = world.createEntity()
            world.addComponent(PositionComponent(position: SIMD3<Float>(spec.x, spec.y, spec.z)), to: entity)
            world.addComponent(MoodComponent(mood: moodString(from: spec.mood)), to: entity)
            print("[🌍] LocalWorldPlugin: Spawned default local agent at (\(spec.x), \(spec.y), \(spec.z)) with mood \(moodString(from: spec.mood))")
        }
    }

    func update(deltaTime: TimeInterval) {
        // Optional: animate agent locally
    }

    private func moodString(from mood: UInt32) -> String {
        switch mood {
        case 1: return "happy"
        case 2: return "angry"
        case 3: return "curious"
        default: return "neutral"
        }
    }
}
