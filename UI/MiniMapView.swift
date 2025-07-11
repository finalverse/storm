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

                // Draw agent positions with mood-based coloring
                ForEach(Array(sceneRenderer.agentPositions.enumerated()), id: \.offset) { index, pos in
                    let moodColor = Color.white

                    Circle()
                        .fill(moodColor)
                        .frame(width: 6, height: 6)
                        .position(x: geo.size.width / 2 + CGFloat(pos.x * 10),
                                  y: geo.size.height / 2 - CGFloat(pos.z * 10))
                }

                let cx = geo.size.width / 2
                let cy = geo.size.height - 10  // Static at bottom edge of minimap

                Path { path in
                    let size: CGFloat = 10
                    path.move(to: CGPoint(x: cx, y: cy - size))
                    path.addLine(to: CGPoint(x: cx - size * 0.5, y: cy + size * 0.5))
                    path.addLine(to: CGPoint(x: cx + size * 0.5, y: cy + size * 0.5))
                    path.closeSubpath()
                }
                .fill(Color.red)

                Circle()
                    .stroke(Color.red, lineWidth: 1)
                    .frame(width: 10, height: 10)
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

    private func color(for mood: String) -> Color {
        switch mood.lowercased() {
        case "happy":
            return .yellow
        case "curious":
            return .blue
        case "angry":
            return .red
        default:
            return .white
        }
    }
}
