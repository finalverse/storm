//
//  UI/MiniMapView.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-11.
//

import SwiftUI
import SceneKit

struct MiniMapView: View {
    let sceneRenderer: SceneRendererService
    @State private var refreshID = UUID()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))

                // Draw agent positions
                ForEach(sceneRenderer.agentPositions.indices, id: \.self) { index in
                    let pos = sceneRenderer.agentPositions[index]
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .position(x: geo.size.width / 2 + CGFloat(pos.x * 10),
                                  y: geo.size.height / 2 - CGFloat(pos.z * 10))
                }

                // Draw camera position
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .position(x: geo.size.width / 2 + CGFloat(sceneRenderer.cameraPosition.x * 10),
                              y: geo.size.height / 2 - CGFloat(sceneRenderer.cameraPosition.z * 10))
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
