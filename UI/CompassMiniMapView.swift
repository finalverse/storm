//
//  UI/CompassMiniMapView.swift
//  Storm
//
//  RealityKit-compatible compass minimap view.
//
//  Created by Wenyan Qin on 2025-07-12.
//

import SwiftUI
import RealityKit

#if os(macOS)
struct CompassMiniMapView: NSViewRepresentable {
    let cameraYaw: Float

    func makeNSView(context: Context) -> ARView {
        createCompassARView()
    }

    func updateNSView(_ nsView: ARView, context: Context) {
        updateMarkerYaw(in: nsView)
    }
}
#else
struct CompassMiniMapView: UIViewRepresentable {
    let cameraYaw: Float

    func makeUIView(context: Context) -> ARView {
        createCompassARView()
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        updateMarkerYaw(in: uiView)
    }
}
#endif

private extension CompassMiniMapView {
    func createCompassARView() -> ARView {
        let arView = ARView(frame: .zero)
        arView.environment.background = .color(.clear)

        let anchor = AnchorEntity(world: .zero)

        let sphere = MeshResource.generateSphere(radius: 1.0)
        let material = SimpleMaterial(color: .gray.withAlphaComponent(0.2), isMetallic: false)
        let sphereEntity = ModelEntity(mesh: sphere, materials: [material])
        anchor.addChild(sphereEntity)

        let cone = MeshResource.generateCone(height: 0.3, radius: 0.1)
        let coneMaterial = SimpleMaterial(color: .red, isMetallic: false)
        let markerEntity = ModelEntity(mesh: cone, materials: [coneMaterial])
        markerEntity.position = SIMD3<Float>(0, 1.2, 0)
        markerEntity.name = "directionMarker"
        anchor.addChild(markerEntity)

        arView.scene.addAnchor(anchor)
        return arView
    }

    func updateMarkerYaw(in arView: ARView) {
        if let markerEntity = arView.scene.anchors.first?.children.first(where: { $0.name == "directionMarker" }) {
            markerEntity.transform.rotation = simd_quatf(angle: cameraYaw, axis: [0, 1, 0])
        }
    }
}
