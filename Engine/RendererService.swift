//
//  Engine/RendererService.swift
//  Storm
//
//  Shared protocol and common definitions for RendererService.
//  Split into platform-specific implementations in RendererService-iOS.swift and RendererService-macOS.swift.
//
//  Created by Wenyan Qin on 2025-07-12.
//

import Foundation
import RealityKit

protocol RendererServiceProtocol {
    var arView: ARView { get }
    func updateScene()
}
