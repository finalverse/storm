//
//  Engine/OpenSimECSBridge.swift
//  Storm
//
//  Integration bridge between OpenSim protocol and Storm ECS system
//  Converts OpenSim objects to ECS entities and synchronizes world state
//  CLEANED: Removed duplicate component definitions, uses authoritative ECS components
//
//  Created for Finalverse Storm - ECS Integration

import Foundation
import RealityKit
import SwiftUI
import simd

#if os(macOS)
import AppKit
typealias PlatformColor = NSColor
#else
import UIKit
typealias PlatformColor = UIColor
#endif

// MARK: - Missing Notification Definitions
extension Notification.Name {
    static let openSimObjectUpdate = Notification.Name("openSimObjectUpdate")
    static let openSimChatMessage = Notification.Name("openSimChatMessage")
    static let localAvatarMoved = Notification.Name("localAvatarMoved")
    static let openSimObjectRemoved = Notification.Name("openSimObjectRemoved")
}

class OpenSimECSBridge: ObservableObject {
    private let ecs: ECSCore
    private let renderer: RendererService
    private var openSimToECSMap: [UInt32: EntityID] = [:] // OpenSim LocalID -> ECS EntityID
    private var ecsToOpenSimMap: [EntityID: UInt32] = [:] // ECS EntityID -> OpenSim LocalID
    
    // Entity type mapping
    private var entityRenderMap: [EntityID: ModelEntity] = [:]
    
    init(ecs: ECSCore, renderer: RendererService) {
        self.ecs = ecs
        self.renderer = renderer
        setupNotificationObservers()
    }
    
    // MARK: - Notification Setup
    
    private func setupNotificationObservers() {
        // Listen for OpenSim object updates
        NotificationCenter.default.addObserver(
            forName: .openSimObjectUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let objectUpdate = notification.object as? ObjectUpdateMessage {
                self?.handleObjectUpdate(objectUpdate)
            }
        }
        
        // Listen for OpenSim chat messages
        NotificationCenter.default.addObserver(
            forName: .openSimChatMessage,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let chatMessage = notification.object as? ChatFromSimulatorMessage {
                self?.handleChatMessage(chatMessage)
            }
        }
    }
    
    // MARK: - Object Update Handling
    
    private func handleObjectUpdate(_ update: ObjectUpdateMessage) {
        let world = ecs.getWorld()
        
        for objectData in update.objects {
            if let existingEntityID = openSimToECSMap[objectData.localID] {
                // Update existing entity
                updateExistingEntity(existingEntityID, with: objectData)
            } else {
                // Create new entity
                createNewEntity(from: objectData)
            }
        }
    }
    
    private func createNewEntity(from objectData: ObjectUpdateMessage.ObjectUpdateData) {
        let world = ecs.getWorld()
        let entityID = world.createEntity()
        
        // Map OpenSim object to ECS entity
        openSimToECSMap[objectData.localID] = entityID
        ecsToOpenSimMap[entityID] = objectData.localID
        
        // Add position component (using authoritative ECS component)
        let position = PositionComponent(position: objectData.position)
        world.addComponent(position, to: entityID)
        
        // Add OpenSim-specific component (using authoritative ECS component)
        let openSimComponent = OpenSimObjectComponent(
            localID: objectData.localID,
            fullID: objectData.fullID,
            pcode: objectData.pcode,
            material: objectData.material,
            flags: objectData.flags
        )
        world.addComponent(openSimComponent, to: entityID)
        
        // Create visual representation
        createVisualRepresentation(for: entityID, objectData: objectData)
        
        print("[🔗] Created ECS entity \(entityID) for OpenSim object \(objectData.localID)")
    }
    
    private func updateExistingEntity(_ entityID: EntityID, with objectData: ObjectUpdateMessage.ObjectUpdateData) {
        let world = ecs.getWorld()
        
        // Update position component
        if let positionComponent = world.getComponent(ofType: PositionComponent.self, from: entityID) {
            positionComponent.position = objectData.position
        }
        
        // Update visual representation
        updateVisualRepresentation(for: entityID, objectData: objectData)
    }
    
    // MARK: - Visual Representation
    
    private func createVisualRepresentation(for entityID: EntityID, objectData: ObjectUpdateMessage.ObjectUpdateData) {
        // Determine mesh type based on pcode
        let mesh = createMeshForPCode(objectData.pcode, scale: objectData.scale)
        let material = createMaterialForObject(objectData)
        
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])
        modelEntity.position = objectData.position
        modelEntity.orientation = objectData.rotation
        
        // Add to scene
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(modelEntity)
        renderer.arView.scene.addAnchor(anchor)
        
        // Store mapping
        entityRenderMap[entityID] = modelEntity
        
        // Add metadata for interaction
        modelEntity.name = "opensim_\(objectData.localID)"
    }
    
    private func updateVisualRepresentation(for entityID: EntityID, objectData: ObjectUpdateMessage.ObjectUpdateData) {
        guard let modelEntity = entityRenderMap[entityID] else { return }
        
        // Update transform
        modelEntity.position = objectData.position
        modelEntity.orientation = objectData.rotation
        
        // Update scale if needed
        modelEntity.scale = objectData.scale
    }
    
    private func createMeshForPCode(_ pcode: UInt8, scale: SIMD3<Float>) -> MeshResource {
        // OpenSim primitive codes
        switch pcode {
        case 9: // Box
            return MeshResource.generateBox(size: scale)
        case 10: // Cylinder
            return MeshResource.generateCylinder(height: scale.y, radius: max(scale.x, scale.z) / 2)
        case 11: // Prism
            return MeshResource.generateBox(size: scale) // Simplified as box
        case 12: // Sphere
            return MeshResource.generateSphere(radius: max(scale.x, max(scale.y, scale.z)) / 2)
        case 13: // Torus
            return MeshResource.generateSphere(radius: max(scale.x, scale.z) / 2) // Simplified as sphere
        case 14: // Tube
            return MeshResource.generateCylinder(height: scale.y, radius: max(scale.x, scale.z) / 2)
        case 15: // Ring
            return MeshResource.generateSphere(radius: max(scale.x, scale.z) / 2) // Simplified as sphere
        default:
            // Default to box for unknown primitives
            return MeshResource.generateBox(size: scale.x > 0 ? scale : SIMD3<Float>(0.5, 0.5, 0.5))
        }
    }
    
    private func createMaterialForObject(_ objectData: ObjectUpdateMessage.ObjectUpdateData) -> RealityKit.Material {
        var color: PlatformColor = .gray
        var metallic = false

        switch objectData.material {
        case 0: // Stone
            color = .lightGray
        case 1: // Metal
            color = .darkGray
            metallic = true
        case 2: // Glass
            color = .cyan
        case 3: // Wood
            color = .brown
        case 4: // Flesh
            color = PlatformColor.systemPink
        case 5: // Plastic
            color = .white
        case 6: // Rubber
            color = .black
        default:
            color = .gray
        }

        return SimpleMaterial(color: color, isMetallic: metallic)
    }
    
    // MARK: - Chat Integration
    
    private func handleChatMessage(_ chatMessage: ChatFromSimulatorMessage) {
        // Create a chat entity for visualization (using authoritative ECS component)
        let world = ecs.getWorld()
        let entityID = world.createEntity()
        
        // Add position component at chat location
        let position = PositionComponent(position: chatMessage.position)
        world.addComponent(position, to: entityID)
        
        // Add chat component (using authoritative ECS component)
        let chatComponent = ChatMessageComponent(
            fromName: chatMessage.fromName,
            message: chatMessage.message,
            timestamp: Date(),
            chatType: chatMessage.chatType
        )
        world.addComponent(chatComponent, to: entityID)
        
        // Create visual chat bubble
        createChatBubble(at: chatMessage.position, message: chatMessage.message, from: chatMessage.fromName)
        
        print("[💬] Chat from \(chatMessage.fromName): \(chatMessage.message)")
    }
    
    private func createChatBubble(at position: SIMD3<Float>, message: String, from sender: String) {
        // Create a text entity for the chat message
        let textMesh = MeshResource.generateText(
            message,
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.1),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        
        let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
        
        // Position above the chat location
        textEntity.position = position + SIMD3<Float>(0, 2, 0)
        
        // Create background panel
        let panelMesh = MeshResource.generateBox(size: SIMD3<Float>(1, 0.5, 0.02))
        let panelMaterial = SimpleMaterial(color: .black.withAlphaComponent(0.7), isMetallic: false)
        let panelEntity = ModelEntity(mesh: panelMesh, materials: [panelMaterial])
        panelEntity.position = SIMD3<Float>(0, 0, -0.01)
        
        // Group them together
        let chatBubbleAnchor = AnchorEntity(world: position + SIMD3<Float>(0, 2, 0))
        chatBubbleAnchor.addChild(panelEntity)
        chatBubbleAnchor.addChild(textEntity)
        
        renderer.arView.scene.addAnchor(chatBubbleAnchor)
        
        // Auto-remove after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.renderer.arView.scene.removeAnchor(chatBubbleAnchor)
        }
    }
    
    // MARK: - Avatar Movement Integration
    
    func moveLocalAvatar(to position: SIMD3<Float>, rotation: SIMD2<Float>) {
        // Update local avatar in ECS (using authoritative ECS component)
        let world = ecs.getWorld()
        
        // Find local avatar entity (would be created during login)
        let avatarEntities = world.entities(with: LocalAvatarComponent.self)
        
        if let (avatarEntityID, _) = avatarEntities.first {
            // Update position
            if let positionComponent = world.getComponent(ofType: PositionComponent.self, from: avatarEntityID) {
                positionComponent.position = position
            }
            
            // Send update to OpenSim server via notification
            NotificationCenter.default.post(
                name: .localAvatarMoved,
                object: AvatarMovementUpdate(position: position, rotation: rotation)
            )
        }
    }
    
    // MARK: - Entity Cleanup
    
    func removeOpenSimObject(localID: UInt32) {
        guard let entityID = openSimToECSMap[localID] else { return }
        
        let world = ecs.getWorld()
        world.removeEntity(entityID)
        
        // Remove visual representation
        if let modelEntity = entityRenderMap[entityID] {
            modelEntity.removeFromParent()
            entityRenderMap.removeValue(forKey: entityID)
        }
        
        // Clean up mappings
        openSimToECSMap.removeValue(forKey: localID)
        ecsToOpenSimMap.removeValue(forKey: entityID)
        
        print("[🗑️] Removed ECS entity \(entityID) for OpenSim object \(localID)")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Movement Update Structure

struct AvatarMovementUpdate {
    let position: SIMD3<Float>
    let rotation: SIMD2<Float>
    let timestamp: Date
    
    init(position: SIMD3<Float>, rotation: SIMD2<Float>) {
        self.position = position
        self.rotation = rotation
        self.timestamp = Date()
    }
}
