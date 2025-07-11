//
//  Engine/RendererService.swift
//  Storm
//
//  RealityKit-based renderer that visualizes ECS entities.
//
//  Created by Wenyan Qin on 2025-07-12.
//

import Foundation
import RealityKit
import simd

/// Service that manages RealityKit rendering via ARView and ECS entities.
final class RendererService {
    let arView: ARView
    private let ecs: ECSCore
    private var agentEntities: [EntityID: ModelEntity] = [:]
    private var agentAnchors: [EntityID: AnchorEntity] = [:]
    private var time: Float = 0.0

    init(ecs: ECSCore, arView: ARView) {
        self.ecs = ecs
        self.arView = arView
        setupDefaults()
    }

    /// Setup lighting and camera anchor defaults.
    private func setupDefaults() {
        let lightEntity = Entity()
        lightEntity.components.set(DirectionalLightComponent(color: .white, intensity: 10000))
        lightEntity.position = SIMD3<Float>(x: 0, y: 10, z: 10)
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(lightEntity)
        arView.scene.addAnchor(anchor)
    }

    /// Refresh the RealityKit scene from ECSWorld state.
    func updateScene() {
        time += 0.02

        let world = ecs.getWorld()

        var seenEntities = Set<EntityID>()

        for (entityID, positionComp) in world.entities(with: PositionComponent.self) {
            seenEntities.insert(entityID)

            if agentEntities[entityID] == nil {
                // New agent entity
                let sphere = MeshResource.generateSphere(radius: 0.2)
                let material = SimpleMaterial(color: .white, isMetallic: false)
                let model = ModelEntity(mesh: sphere, materials: [material])
                model.name = "agent"
                agentEntities[entityID] = model

                // Explicitly tag anchor for minimap visibility
                let anchor = AnchorEntity(world: positionComp.position)
                anchor.name = "agentAnchor_\(entityID.uuidString)"
                anchor.addChild(model)
                arView.scene.addAnchor(anchor)
                agentAnchors[entityID] = anchor
            }

            agentEntities[entityID]?.position = positionComp.position
        }

        // Cleanup removed entities and their anchors
        for (entityID, entity) in agentEntities where !seenEntities.contains(entityID) {
            if let anchor = agentAnchors[entityID] {
                arView.scene.removeAnchor(anchor)
                agentAnchors.removeValue(forKey: entityID)
            }
            agentEntities.removeValue(forKey: entityID)
        }
    }
}
