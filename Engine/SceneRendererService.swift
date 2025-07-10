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

        let agents = ecs.getWorld().entities(with: EchoAgentComponent.self)
        var seenEntities = Set<EntityID>()

        let radius: Float = 2.0

        for (index, (entityID, agent)) in agents.enumerated() {
            seenEntities.insert(entityID)

            let targetColor = color(for: agent.mood)

            let angle = Float(index) / Float(max(agents.count, 1)) * Float.pi * 2

            let speed: Float
            switch agent.mood.lowercased() {
            case "happy": speed = 1.5
            case "curious": speed = 1.0
            case "angry": speed = 2.0
            default: speed = 1.0
            }
            let animatedRadius = radius + 0.5 * sin(time * speed + Float(index))
            let x = animatedRadius * cos(angle)
            let z = animatedRadius * sin(angle)

            if let node = agentNodes[entityID] {
                // Animate color change if needed
                if let material = node.geometry?.firstMaterial,
                   let currentColor = material.diffuse.contents as? NSColor,
                   currentColor != targetColor {
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.5
                    material.diffuse.contents = targetColor
                    SCNTransaction.commit()
                }
                node.position = SCNVector3(x, 0, z)

                // Update label if mood changed
                if let textNode = node.childNode(withName: "label", recursively: false),
                   let textGeometry = textNode.geometry as? SCNText,
                   (textGeometry.string as? String) != agent.mood {
                    textGeometry.string = agent.mood
                }
            } else {
                // New node
                let sphere = SCNSphere(radius: 0.3)
                let material = SCNMaterial()
                material.diffuse.contents = targetColor
                sphere.materials = [material]

                let node = SCNNode(geometry: sphere)
                node.position = SCNVector3(x, 0, z)
                node.name = "agent"

                // Add floating text label above agent node
                let text = SCNText(string: agent.mood, extrusionDepth: 0.1)
                text.font = NSFont.systemFont(ofSize: 0.2)
                text.flatness = 0.05
                text.firstMaterial?.diffuse.contents = NSColor.white
                text.firstMaterial?.emission.contents = NSColor.white
                text.firstMaterial?.lightingModel = .constant

                let textNode = SCNNode(geometry: text)
                textNode.position = SCNVector3(0, 0.5, 0)
                textNode.scale = SCNVector3(0.2, 0.2, 0.2)
                textNode.name = "label"
                textNode.castsShadow = false
                // Billboard so label always faces camera
                let billboardConstraint = SCNBillboardConstraint()
                billboardConstraint.freeAxes = .Y
                textNode.constraints = [billboardConstraint]
                node.addChildNode(textNode)

                scene.rootNode.addChildNode(node)
                agentNodes[entityID] = node
            }
        }

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
}
