//
//  Core/PingPlugin.swift
//  Storm
//
//  Demonstrates ECS registration and ticking by printing periodic messages.
//
//  Created by Wenyan Qin on 2025-07-09.
//

import Foundation

final class PingComponent: Component {
    var countdown: TimeInterval

    init(countdown: TimeInterval) {
        self.countdown = countdown
    }
}

final class PingSystem: ECSStepSystem {
    func update(world: ECSWorld, deltaTime: TimeInterval) {
        for (id, comp) in world.entities(with: PingComponent.self) {
            let updated = comp
            updated.countdown -= deltaTime

            if updated.countdown <= 0 {
                print("[📡] Ping from entity \(id)")
                updated.countdown = 3.0 // reset
            }

            world.addComponent(updated, to: id)
        }
    }
}

final class PingPlugin: StormPlugin {
    private var ecs: ECSCore?

    func setup(registry: SystemRegistry) {
        print("[📡] PingPlugin setup")

        guard let ecs = registry.ecs else {
            print("[⚠️] ECSCore not found in registry.")
            return
        }

        self.ecs = ecs

        // Register system
        ecs.registerSystem(PingSystem())

        // Add entity
        let entity = ecs.getWorld().createEntity()
        ecs.getWorld().addComponent(PingComponent(countdown: 2.0), to: entity)
    }

    func update(deltaTime: TimeInterval) {
        ecs?.tick(deltaTime: deltaTime)
    }
}
