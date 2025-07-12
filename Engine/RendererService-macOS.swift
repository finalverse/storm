#if os(macOS)
//
//  RendererService-macOS.swift
//  Storm
//
//  macOS-specific RendererService implementation.
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
    private let cameraAnchor = AnchorEntity(world: SIMD3<Float>(0, 1.5, 3))
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
        rootAnchor.addChild(lightAnchor)

        arView.scene.addAnchor(rootAnchor)

        cameraAnchor.components.set(PerspectiveCameraComponent())
        rootAnchor.addChild(cameraAnchor)

        let lookAt = SIMD3<Float>(0, 1, 0)
        let eye = cameraAnchor.position
        let forward = normalize(lookAt - eye)
        cameraAnchor.orientation = simd_quatf(from: SIMD3<Float>(0, 0, -1), to: forward)

        let cube = ModelEntity(mesh: MeshResource.generateBox(size: 0.4), materials: [SimpleMaterial(color: .red, isMetallic: false)])
        cube.position = SIMD3<Float>(0, 1, 0)
        rootAnchor.addChild(cube)

        let rightPyramid = ModelEntity(mesh: MeshResource.generateCone(height: 0.5, radius: 0.3), materials: [SimpleMaterial(color: .green, isMetallic: false)])
        rightPyramid.position = SIMD3<Float>(1, 1, 0)
        rootAnchor.addChild(rightPyramid)

        let leftPyramid = ModelEntity(mesh: MeshResource.generateCone(height: 0.5, radius: 0.3), materials: [SimpleMaterial(color: .blue, isMetallic: false)])
        leftPyramid.position = SIMD3<Float>(-1, 1, 0)
        rootAnchor.addChild(leftPyramid)

        let cubeMesh = MeshResource.generateBox(size: 0.2)
        let cubeMaterial = SimpleMaterial(color: .yellow, isMetallic: false)
        let offsets: [SIMD3<Float>] = [
            SIMD3<Float>(1, 0, 0),
            SIMD3<Float>(-1, 0, 0),
            SIMD3<Float>(0, 1, 0),
            SIMD3<Float>(0, -1, 0),
            SIMD3<Float>(0, 0, 1),
            SIMD3<Float>(0, 0, -1),
            SIMD3<Float>(1, 1, 1),
            SIMD3<Float>(-1, -1, -1)
        ]

        for offset in offsets {
            let testCube = ModelEntity(mesh: cubeMesh, materials: [cubeMaterial])
            testCube.position = offset
            rootAnchor.addChild(testCube)
        }
    }

    func updateScene() {
        // Optional: ECS-driven updates for macOS can go here.
    }

    func rotateCamera(yaw: Float, pitch: Float) {
        let yawRotation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
        let pitchRotation = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
        cameraAnchor.orientation = yawRotation * pitchRotation * cameraAnchor.orientation
    }

    func zoomCamera(delta: Float) {
        let forward = cameraAnchor.orientation.act(SIMD3<Float>(0, 0, delta))
        cameraAnchor.position += forward
    }

    func panCamera(x: Float, y: Float) {
        let right = cameraAnchor.orientation.act(SIMD3<Float>(1, 0, 0))
        let up = cameraAnchor.orientation.act(SIMD3<Float>(0, 1, 0))
        cameraAnchor.position += right * x
        cameraAnchor.position += up * y
    }
}
#endif
