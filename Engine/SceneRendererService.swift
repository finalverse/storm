//
//  Engine/SceneRendererService.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-11.
//

import Foundation

//
//  SceneRendererService.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-11.
//

import Foundation
import SceneKit

/// Service that owns the shared SCNScene and renders ECS entities.
final class SceneRendererService {
    let scene: SCNScene
    private let ecs: ECSCore

    init(ecs: ECSCore) {
        self.ecs = ecs
        self.scene = SCNScene()

        // Initial scene setup (light, camera)
        setupDefaults()
    }

    private func setupDefaults() {
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 5)
        scene.rootNode.addChildNode(cameraNode)
    }

    /// Call this to refresh all ECS entities as nodes.
    func updateScene() {
        // Clear previous agent nodes (simple example)
        scene.rootNode.childNodes.filter { $0.name == "agent" }.forEach { $0.removeFromParentNode() }

        // For each EchoAgentComponent entity, add a sphere at a computed position
        let agents = ecs.getWorld().entities(with: EchoAgentComponent.self)
        for (index, (entityID, agent)) in agents.enumerated() {
            let node = SCNNode(geometry: SCNSphere(radius: 0.3))
            node.position = SCNVector3(x: CGFloat(Float(index)) * 1.0, y: 0, z: 0)
            node.name = "agent"
            scene.rootNode.addChildNode(node)
        }
    }
}
