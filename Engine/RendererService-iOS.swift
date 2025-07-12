#if os(iOS)
//
//  Engine/RendererService-iOS.swift
//  Storm
//
//  iOS-specific RendererService implementation.
//

import Foundation
import RealityKit
import simd

final class RendererService: RendererServiceProtocol {
    let arView: ARView
    private let ecs: ECSCore
    private var agentEntities: [EntityID: ModelEntity] = [:]
    private var agentAnchors: [EntityID: AnchorEntity] = [:]
    private var terrainEntities: [EntityID: ModelEntity] = [:]
    private var time: Float = 0.0
    private let rootAnchor = AnchorEntity(world: .zero)

    init(ecs: ECSCore, arView: ARView) {
        self.ecs = ecs
        self.arView = arView
        setupDefaults()
    }

    private func setupDefaults() {
        let lightEntity = Entity()
        lightEntity.components.set(DirectionalLightComponent(color: .white, intensity: 10000))
        lightEntity.position = SIMD3<Float>(0, 10, 10)
        let lightAnchor = AnchorEntity(world: .zero)
        lightAnchor.addChild(lightEntity)
        arView.scene.addAnchor(lightAnchor)

        arView.scene.addAnchor(rootAnchor)

        let cube = ModelEntity(mesh: MeshResource.generateBox(size: 0.4), materials: [SimpleMaterial(color: .red, isMetallic: false)])
        cube.position = SIMD3<Float>(0, 1, 0)
        rootAnchor.addChild(cube)
    }

    func updateScene() {
        // Optional: ECS-driven updates for iOS can go here.
    }

    func rotateCamera(yaw: Float, pitch: Float) {
        let yawRotation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
        let pitchRotation = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
        rootAnchor.orientation = yawRotation * pitchRotation * rootAnchor.orientation
    }

    func zoomCamera(delta: Float) {
        rootAnchor.transform.translation.z += delta
    }

    func panCamera(x: Float, y: Float) {
        rootAnchor.transform.translation.x += x
        rootAnchor.transform.translation.y += y
    }
}
#endif
