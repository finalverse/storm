//
//  Engine/ECSComponents.swift
//  Storm
//
//  Defines ECS components used by Storm for entity state (position, mood, etc.).
//  UPDATED: Added missing SpinComponent and other components referenced by code
//
//  Created by Wenyan Qin on 2025-07-12.
//

import Foundation
import simd

/// Represents a position in 3D space for an ECS entity.
final class PositionComponent: Component {
    /// Position as SIMD3 vector (RealityKit-friendly).
    var position: SIMD3<Float>

    /// Initializes a PositionComponent with given position.
    init(position: SIMD3<Float>) {
        self.position = position
    }
}

/// Represents terrain characteristics for terrain entities.
final class TerrainComponent: Component {
    /// Size (width and depth) of the terrain plane.
    var size: Float

    /// Initializes a TerrainComponent with given size.
    init(size: Float) {
        self.size = size
    }
}

/// Represents mood metadata for an ECS entity (for styling / UI / logic).
final class MoodComponent: Component {
    /// Mood string (e.g., "happy", "angry", "neutral").
    var mood: String

    /// Initializes a MoodComponent with given mood string.
    init(mood: String) {
        self.mood = mood
    }
}

/// ECS component that marks an entity as spinnable.
/// This is the authoritative SpinComponent for the ECS system.
final class SpinComponent: Component {
    /// The axis around which the entity spins.
    var spinAxis: SIMD3<Float>
    
    /// Whether the entity is currently spinning.
    var isSpinning: Bool
    
    /// Spin speed in radians per second.
    var spinSpeed: Float
    
    /// Initializes a SpinComponent with default Y-axis spin.
    init(spinAxis: SIMD3<Float> = SIMD3<Float>(0, 1, 0), spinSpeed: Float = 2.0 * .pi) {
        self.spinAxis = spinAxis
        self.spinSpeed = spinSpeed
        self.isSpinning = false
    }
}

/// Component for chat messages in the world.
final class ChatMessageComponent: Component {
    let fromName: String
    let message: String
    let timestamp: Date
    let chatType: UInt8
    
    init(fromName: String, message: String, timestamp: Date, chatType: UInt8) {
        self.fromName = fromName
        self.message = message
        self.timestamp = timestamp
        self.chatType = chatType
    }
}

/// Component for local avatar entities.
final class LocalAvatarComponent: Component {
    let agentID: UUID
    let sessionID: UUID
    var lastMovementUpdate: Date
    
    init(agentID: UUID, sessionID: UUID) {
        self.agentID = agentID
        self.sessionID = sessionID
        self.lastMovementUpdate = Date()
    }
}

/// Component for OpenSim objects integration.
final class OpenSimObjectComponent: Component {
    let localID: UInt32
    let fullID: UUID
    let pcode: UInt8
    let material: UInt8
    let flags: UInt32
    var lastUpdateTime: Date
    
    init(localID: UInt32, fullID: UUID, pcode: UInt8, material: UInt8, flags: UInt32) {
        self.localID = localID
        self.fullID = fullID
        self.pcode = pcode
        self.material = material
        self.flags = flags
        self.lastUpdateTime = Date()
    }
}

/// Component for tracking entity visibility and LOD state
final class RenderStateComponent: Component {
    var isVisible: Bool = true
    var lodLevel: Int = 0
    var lastRenderTime: Date = Date()
    
    init(isVisible: Bool = true, lodLevel: Int = 0) {
        self.isVisible = isVisible
        self.lodLevel = lodLevel
    }
}

/// Component for tracking entity interaction capabilities
final class InteractionComponent: Component {
    var isInteractable: Bool = true
    var canCollide: Bool = true
    var lastInteractionTime: Date?
    
    init(isInteractable: Bool = true, canCollide: Bool = true) {
        self.isInteractable = isInteractable
        self.canCollide = canCollide
    }
}

