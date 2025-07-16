//
//  Engine/RendererService.swift
//  Storm
//
//  Unified RendererService with protocol definition and shared functionality.
//  Provides platform-agnostic rendering interface with RealityKit integration.
//  Supports iOS, macOS, and future visionOS with proper camera controls.
//
//  Created by Wenyan Qin on 2025-07-15.
//

import Foundation
import RealityKit
import simd
import SwiftUI

// MARK: - RendererService Protocol

/// Protocol defining the interface for platform-specific rendering services
/// All RendererService implementations must conform to this protocol
protocol RendererServiceProtocol {
    /// The ARView instance for rendering 3D content
    var arView: ARView { get }
    
    /// Updates the 3D scene based on current ECS state
    func updateScene()
    
    /// Rotates the camera/scene by the specified angles
    /// - Parameters:
    ///   - yaw: Rotation around Y-axis (left/right)
    ///   - pitch: Rotation around X-axis (up/down)
    func rotateCamera(yaw: Float, pitch: Float)
    
    /// Zooms the camera in/out by the specified delta
    /// - Parameter delta: Zoom amount (positive = zoom in, negative = zoom out)
    func zoomCamera(delta: Float)
    
    /// Pans the camera by the specified amounts
    /// - Parameters:
    ///   - x: Horizontal pan amount
    ///   - y: Vertical pan amount
    func panCamera(x: Float, y: Float)
}

// MARK: - Shared RendererService Base

/// Base class providing shared functionality for all platform-specific RendererService implementations
/// This class contains common setup, entity management, and utility methods
class RendererServiceBase {
    
    // MARK: - Core Dependencies
    let ecs: ECSCore
    let arView: ARView
    
    // MARK: - Entity Management
    private(set) var agentEntities: [EntityID: ModelEntity] = [:]
    private(set) var agentAnchors: [EntityID: AnchorEntity] = [:]
    private(set) var terrainEntities: [EntityID: ModelEntity] = [:]
    
    // MARK: - Scene State
    private(set) var time: Float = 0.0
    let rootAnchor = AnchorEntity(world: .zero)
    
    // MARK: - Initialization
    
    init(ecs: ECSCore, arView: ARView) {
        self.ecs = ecs
        self.arView = arView
        setupSharedDefaults()
    }
    
    // MARK: - Shared Setup
    
    /// Sets up common scene elements that are shared across all platforms
    private func setupSharedDefaults() {
        // Create directional lighting
        let lightEntity = Entity()
        lightEntity.components.set(DirectionalLightComponent(color: .white, intensity: 10000))
        lightEntity.position = SIMD3<Float>(0, 10, 10)
        
        // Create light anchor and add to scene
        let lightAnchor = AnchorEntity(world: .zero)
        lightAnchor.addChild(lightEntity)
        arView.scene.addAnchor(lightAnchor)
        
        // Add root anchor to scene
        arView.scene.addAnchor(rootAnchor)
        
        // Create default test geometry
        setupDefaultGeometry()
    }
    
    /// Creates default test geometry visible on all platforms
    private func setupDefaultGeometry() {
        // Central red cube
        let cube = ModelEntity(
            mesh: MeshResource.generateBox(size: 0.4),
            materials: [SimpleMaterial(color: .red, isMetallic: false)]
        )
        cube.position = SIMD3<Float>(0, 1, 0)
        rootAnchor.addChild(cube)
    }
    
    // MARK: - Entity Management Methods
    
    /// Adds an agent entity to the scene
    /// - Parameters:
    ///   - entityID: Unique identifier for the entity
    ///   - position: World position for the entity
    ///   - color: Color for the entity material
    func addAgent(entityID: EntityID, position: SIMD3<Float>, color: Color = .blue) {
        #if os(iOS) || os(visionOS)
        let resolvedColor = UIColor(color)
        #else
        let resolvedColor = NSColor(color)
        #endif
        let agent = ModelEntity(
            mesh: MeshResource.generateSphere(radius: 0.2),
            materials: [SimpleMaterial(color: resolvedColor, isMetallic: false)]
        )
        agent.position = position
        
        let anchor = AnchorEntity(world: position)
        anchor.addChild(agent)
        
        agentEntities[entityID] = agent
        agentAnchors[entityID] = anchor
        arView.scene.addAnchor(anchor)
    }
    
    /// Updates an existing agent's position
    /// - Parameters:
    ///   - entityID: Identifier of the entity to update
    ///   - position: New world position
    func updateAgent(entityID: EntityID, position: SIMD3<Float>) {
        guard let agent = agentEntities[entityID] else { return }
        agent.position = position
    }
    
    /// Removes an agent from the scene
    /// - Parameter entityID: Identifier of the entity to remove
    func removeAgent(entityID: EntityID) {
        if let anchor = agentAnchors[entityID] {
            arView.scene.removeAnchor(anchor)
        }
        agentEntities.removeValue(forKey: entityID)
        agentAnchors.removeValue(forKey: entityID)
    }
    
    /// Adds terrain entity to the scene
    /// - Parameters:
    ///   - entityID: Unique identifier for the terrain
    ///   - position: World position
    ///   - size: Size of the terrain block
    func addTerrain(entityID: EntityID, position: SIMD3<Float>, size: Float = 1.0) {
        let terrain = ModelEntity(
            mesh: MeshResource.generateBox(size: size),
            materials: [SimpleMaterial(color: .brown, isMetallic: false)]
        )
        terrain.position = position
        
        terrainEntities[entityID] = terrain
        rootAnchor.addChild(terrain)
    }
    
    // MARK: - Scene Update Methods
    
    /// Updates scene based on current ECS state - called by platform implementations
    func updateSharedScene() {
        time += 0.016 // Approximate 60fps delta
        
        // Sync with ECS entities
        syncWithECS()
        
        // Update any time-based animations
        updateAnimations()
    }
    
    /// Synchronizes RealityKit entities with ECS component data
    private func syncWithECS() {
        // Query ECS for entities with Position and RenderState components
        let renderableEntities = ecs.getEntitiesWithComponents([PositionComponent.self, RenderStateComponent.self])
        
        for entityID in renderableEntities {
            guard let position = ecs.getComponent(ofType: PositionComponent.self, for: entityID),
                  let renderState = ecs.getComponent(ofType: RenderStateComponent.self, for: entityID) else {
                continue
            }
            
            // Update or create RealityKit entity based on ECS state
            if agentEntities[entityID] == nil && renderState.isVisible {
                addAgent(entityID: entityID, position: position.position)
            } else if let _ = agentEntities[entityID] {
                if renderState.isVisible {
                    updateAgent(entityID: entityID, position: position.position)
                } else {
                    removeAgent(entityID: entityID)
                }
            }
        }
    }
    
    /// Updates time-based animations and effects
    private func updateAnimations() {
        // Rotate any entities with SpinComponent
        let spinningEntities = ecs.getEntitiesWithComponents([SpinComponent.self])
        
        for entityID in spinningEntities {
            guard let spin = ecs.getComponent(ofType: SpinComponent.self, for: entityID),
                  let agent = agentEntities[entityID] else {
                continue
            }
            
            // Apply rotation based on spin rate
            let rotation = simd_quatf(angle: spin.spinSpeed * time, axis: SIMD3<Float>(0, 1, 0))
            agent.orientation = rotation
        }
    }
    
    // MARK: - Utility Methods
    
    /// Creates a quaternion for camera orientation
    /// - Parameters:
    ///   - yaw: Rotation around Y-axis
    ///   - pitch: Rotation around X-axis
    /// - Returns: Combined quaternion rotation
    func createCameraRotation(yaw: Float, pitch: Float) -> simd_quatf {
        let yawRotation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
        let pitchRotation = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
        return yawRotation * pitchRotation
    }
    
    /// Calculates forward vector from camera orientation
    /// - Parameter orientation: Camera quaternion orientation
    /// - Returns: Forward direction vector
    func getForwardVector(from orientation: simd_quatf) -> SIMD3<Float> {
        return orientation.act(SIMD3<Float>(0, 0, -1))
    }
    
    /// Calculates right vector from camera orientation
    /// - Parameter orientation: Camera quaternion orientation
    /// - Returns: Right direction vector
    func getRightVector(from orientation: simd_quatf) -> SIMD3<Float> {
        return orientation.act(SIMD3<Float>(1, 0, 0))
    }
    
    /// Calculates up vector from camera orientation
    /// - Parameter orientation: Camera quaternion orientation
    /// - Returns: Up direction vector
    func getUpVector(from orientation: simd_quatf) -> SIMD3<Float> {
        return orientation.act(SIMD3<Float>(0, 1, 0))
    }
}

// MARK: - Platform Detection

/// Utility for detecting current platform capabilities
enum PlatformCapabilities {
    static var isIOS: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }
    
    static var isMacOS: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }
    
    static var isVisionOS: Bool {
        #if os(visionOS)
        return true
        #else
        return false
        #endif
    }
    
    static var supportsARCamera: Bool {
        return isIOS || isVisionOS
    }
    
    static var supportsPerspectiveCamera: Bool {
        return isMacOS || isVisionOS
    }
}
