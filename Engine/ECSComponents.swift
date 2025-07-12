//
//  Engine/ECSComponents.swift
//  Storm
//
//  Defines ECS components used by Storm for entity state (position, mood, etc.).
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
