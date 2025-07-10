//
//  UI/SceneViewContainer.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-11.
//

import Foundation

//
//  SceneViewContainer.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-11.
//

import SwiftUI
import SceneKit

struct SceneViewContainer: NSViewRepresentable {
    let scene: SCNScene

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.backgroundColor = .black
        return scnView
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        // Future dynamic updates for ECS-driven entities can go here
    }
}
