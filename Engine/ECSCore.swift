//
//  Engine/ECSCore.swift
//  Storm
//
//  Minimal ECS (Entity-Component-System) core engine.
//
//  Created by Wenyan Qin on 2025-07-09.
//

import Foundation

// MARK: - Entity & Component Model

public typealias EntityID = UUID

/// Marker protocol for any component attached to an entity
protocol Component {}

/// A simple ECS storage of entity -> component sets
final class ECSWorld {
    private var components: [EntityID: [String: Component]] = [:]

    func createEntity() -> EntityID {
        let id = UUID()
        components[id] = [:]
        return id
    }

    func addComponent<T: Component>(_ component: T, to entity: EntityID) {
        components[entity]?[String(describing: T.self)] = component
    }

    func getComponent<T: Component>(ofType type: T.Type, from entity: EntityID) -> T? {
        return components[entity]?[String(describing: T.self)] as? T
    }

    func entities<T: Component>(with type: T.Type) -> [(EntityID, T)] {
        components.compactMap { (id, comps) in
            if let comp = comps[String(describing: T.self)] as? T {
                return (id, comp)
            }
            return nil
        }
    }
}

// MARK: - System Execution

protocol ECSStepSystem {
    func update(world: ECSWorld, deltaTime: TimeInterval)
}

// MARK: - ECS Core Engine

final class ECSCore {
    private let world = ECSWorld()
    private var systems: [ECSStepSystem] = []

    func registerSystem(_ system: ECSStepSystem) {
        systems.append(system)
    }

    func tick(deltaTime: TimeInterval) {
        for system in systems {
            system.update(world: world, deltaTime: deltaTime)
        }
    }

    // For external access (e.g., plugins)
    func getWorld() -> ECSWorld {
        return world
    }
}
