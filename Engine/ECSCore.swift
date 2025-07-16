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

/// Marker protocol for any component attached to an entity.
public protocol Component: AnyObject {}

/// A simple ECS storage of entity -> component sets.
final class ECSWorld {
    // Storage: entity ID -> [component type name: component instance]
    private var components: [EntityID: [String: Component]] = [:]

    /// Creates a new entity and returns its unique ID.
    func createEntity() -> EntityID {
        let id = UUID()
        components[id] = [:]
        return id
    }

    /// Removes an entity and all its components.
    func removeEntity(_ entity: EntityID) {
        components.removeValue(forKey: entity)
    }

    /// Adds or replaces a component for a given entity.
    func addComponent<T: Component>(_ component: T, to entity: EntityID) {
        components[entity]?[String(describing: T.self)] = component
    }

    /// Retrieves a component of a specific type for an entity.
    func getComponent<T: Component>(ofType type: T.Type, from entity: EntityID) -> T? {
        return components[entity]?[String(describing: T.self)] as? T
    }

    /// Checks if an entity has a specific component type.
    func hasComponent<T: Component>(_ type: T.Type, for entity: EntityID) -> Bool {
        return components[entity]?[String(describing: T.self)] != nil
    }

    /// Removes a specific component type from an entity.
    func removeComponent<T: Component>(_ type: T.Type, from entity: EntityID) {
        components[entity]?.removeValue(forKey: String(describing: T.self))
    }

    /// Returns all entities that have a given component type.
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
    
    /// Helper function for UI to get entity count safely
    func getEntityCount() -> Int {
        let world = getWorld()
        let positionEntities = world.entities(with: PositionComponent.self)
        return positionEntities.count
    }
    
    /// Helper function for UI to check if entity has spinning capability
    func canEntitySpin(_ entityID: EntityID) -> Bool {
        let world = getWorld()
        return world.hasComponent(SpinComponent.self, for: entityID)
    }
    
    /// Returns all entities that have both given component types.
    func getEntitiesWithComponents<T: Component, U: Component>(_ type1: T.Type, _ type2: U.Type) -> [EntityID] {
        let world = getWorld()
        return world.entities(with: T.self).compactMap { (entityID, _) in
            if world.hasComponent(U.self, for: entityID) {
                return entityID
            }
            return nil
        }
    }
    
    /// Returns all entities that have all given component types (variadic form).
    func getEntitiesWithComponents(_ types: [any Component.Type]) -> [EntityID] {
        let world = getWorld()
        return world.entities(with: PositionComponent.self).map { $0.0 }.filter { entityID in
            types.allSatisfy { type in
                world.hasComponent(type, for: entityID)
            }
        }
    }
    
    /// Retrieves a component of a specific type for an entity.
    func getComponent<T: Component>(ofType type: T.Type, for entityID: EntityID) -> T? {
        let world = getWorld()
        return world.getComponent(ofType: type, from: entityID)
    }
    
}
