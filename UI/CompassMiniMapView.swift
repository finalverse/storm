//
//  CompassMiniMapView.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-11.
//

import SwiftUI
import SceneKit

struct CompassMiniMapView: NSViewRepresentable {
    let cameraYaw: Float

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.allowsCameraControl = false
        scnView.backgroundColor = .clear

        let scene = SCNScene()

        // Add a sphere to act as compass/minimap globe
        let sphere = SCNSphere(radius: 1.0)
        sphere.firstMaterial?.diffuse.contents = NSColor.gray.withAlphaComponent(0.2)
        sphere.firstMaterial?.isDoubleSided = true
        let sphereNode = SCNNode(geometry: sphere)
        scene.rootNode.addChildNode(sphereNode)

        // Add simple directional markers
        let marker = SCNCone(topRadius: 0, bottomRadius: 0.1, height: 0.3)
        marker.firstMaterial?.diffuse.contents = NSColor.red
        let markerNode = SCNNode(geometry: marker)
        markerNode.position = SCNVector3(0, 1.2, 0)
        markerNode.name = "directionMarker"
        scene.rootNode.addChildNode(markerNode)

        // Add ambient light
        let light = SCNLight()
        light.type = .ambient
        light.color = NSColor.white
        let lightNode = SCNNode()
        lightNode.light = light
        scene.rootNode.addChildNode(lightNode)

        // Camera setup
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 3)
        scene.rootNode.addChildNode(cameraNode)

        scnView.scene = scene
        return scnView
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        if let markerNode = nsView.scene?.rootNode.childNode(withName: "directionMarker", recursively: true) {
            markerNode.eulerAngles.y = CGFloat(cameraYaw)
        }
    }
}
