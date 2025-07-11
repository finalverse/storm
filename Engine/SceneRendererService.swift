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
    private let mainCameraNode = SCNNode()
    private var agentNodes: [EntityID: SCNNode] = [:]
    private var time: Float = 0.0

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

        mainCameraNode.camera = SCNCamera()
        mainCameraNode.position = SCNVector3(x: 0, y: 2, z: 8)
        scene.rootNode.addChildNode(mainCameraNode)
    }

    /// Call this to refresh all ECS entities as nodes.
    func updateScene() {
        time += 0.02

        let seenEntities = Set<EntityID>()

        // Remove nodes for entities no longer present
        for (entityID, node) in agentNodes {
            if !seenEntities.contains(entityID) {
                node.removeFromParentNode()
                agentNodes.removeValue(forKey: entityID)
            }
        }
    }

    private func color(for mood: String) -> NSColor {
        switch mood.lowercased() {
        case "happy":
            return .systemYellow
        case "curious":
            return .systemBlue
        case "angry":
            return .systemRed
        case "neutral":
            return .systemGray
        default:
            return .white
        }
    }

    func setCameraPosition(_ position: SCNVector3) {
        mainCameraNode.position = position
    }

    /// Returns the agent node at the given point in the specified SCNView, if any.
    public func node(at point: CGPoint, in view: SCNView) -> SCNNode? {
        let hitResults = view.hitTest(point, options: nil)
        return hitResults.first { $0.node.name == "agent" }?.node
    }

    /// Highlights the specified node (e.g., to indicate selection).
    public func highlight(node: SCNNode) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3
        node.geometry?.firstMaterial?.emission.contents = NSColor.green
        SCNTransaction.commit()
    }
    
    /// Returns the EntityID associated with a given SCNNode if known.
    public func entityID(for node: SCNNode) -> EntityID? {
        return agentNodes.first(where: { $0.value == node })?.key
    }
    /// Returns the positions of all agent nodes in the scene.
    public var agentPositions: [SCNVector3] {
        let positions = agentNodes.values.map { $0.position }
        print("[MiniMap] agentPositions count: \(positions.count), positions: \(positions)")
        return positions
    }

    /// Returns the current position of the main camera node.
    public var cameraPosition: SCNVector3 {
        print("[MiniMap] cameraPosition: \(mainCameraNode.position)")
        return mainCameraNode.position
    }

    /// Returns the yaw (rotation around Y axis) of the main camera node in radians.
    public var cameraYaw: Float {
        return Float(mainCameraNode.eulerAngles.y)
    }
}
