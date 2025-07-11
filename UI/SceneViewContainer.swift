//
//  UI/SceneViewContainer.swift
//  Storm
//
//  RealityKit view container for embedding a RealityKit.Scene.
//
//  Created by Wenyan Qin on 2025-07-12.
//

import SwiftUI
import RealityKit

/// RealityKit view container for embedding anchors/entities directly.
struct SceneViewContainer {
    func makeView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.environment.background = .color(.black)
        return arView
    }

    func updateView(_ arView: ARView, context: Context) {
        // No-op: RendererService drives updates.
    }
}

#if os(macOS)
extension SceneViewContainer: NSViewRepresentable {
    func makeNSView(context: Context) -> ARView { makeView(context: context) }
    func updateNSView(_ nsView: ARView, context: Context) { updateView(nsView, context: context) }
}
#else
extension SceneViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView { makeView(context: context) }
    func updateUIView(_ uiView: ARView, context: Context) { updateView(uiView, context: context) }
}
#endif
