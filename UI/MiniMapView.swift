//
//  UI/MiniMapView.swift
//  Storm
//
//  RealityKit-compatible minimap overlay.
//
//  Created by Wenyan Qin on 2025-07-12.
//

import SwiftUI
import RealityKit

struct MiniMapView: View {
    let renderer: RendererService
    @State private var refreshID = UUID()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))

                // Convert anchors to Array to allow indexed ForEach
                let anchorsArray = Array(renderer.arView.scene.anchors)
                ForEach(anchorsArray.indices, id: \.self) { index in
                    let anchor = anchorsArray[index]
                    let pos = anchor.position

                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                        .position(x: geo.size.width / 2 + CGFloat(pos.x * 10),
                                  y: geo.size.height / 2 - CGFloat(pos.z * 10))
                }
            }
            .id(refreshID)
            .onReceive(Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()) { _ in
                refreshID = UUID()
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(width: 100, height: 100)
        .background(Color.black.opacity(0.7))
        .clipShape(Circle())
    }
}
