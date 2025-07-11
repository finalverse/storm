//
//  UI/StormMainView.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-11.
//

import SwiftUI
import SceneKit

struct StormMainView: View {
@Environment(\.systemRegistry) var registry
@State private var selectedNode: SCNNode?
@State private var topBarAtTop: Bool = true
@State private var minimapState: Int = 0  // 0 = hidden, 1 = minimap, 2 = 3D compass
@State private var showConsoleLog: Bool = true
@State private var localLogs: [String] = []

// Computed property for agent status summary
private var agentStatusSummary: String {
    guard let sceneRenderer: SceneRendererService = registry?.resolve("sceneRenderer") else { return "No agents." }
    return "Agents: \(sceneRenderer.agentPositions.count)"
}


func addLog(_ message: String) {
    localLogs.append(message)
    if localLogs.count > 100 {
        localLogs.removeFirst(localLogs.count - 100)
    }
}

private var topBarView: some View {
    HStack {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .foregroundColor(.yellow)
            Text("Finalverse Storm")
                .font(.headline)
                .foregroundColor(.white)
            Text("v0.1.x")
                .font(.caption)
                .foregroundColor(.gray)
        }
        Spacer()
        HStack(spacing: 4) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundColor(.green)
            Text("Online")
                .font(.caption)
                .foregroundColor(.green)
        }
    }
    .padding(12)
    .background(Color.black.opacity(0.85).blur(radius: 10))
    .cornerRadius(10)
    .shadow(radius: 4)
    .padding(.horizontal, 16)
    .onTapGesture {
        topBarAtTop.toggle()
    }
}

var body: some View {
    ZStack {
        // Full-screen 3D scene
        if let sceneRenderer: SceneRendererService = registry?.resolve("sceneRenderer") {
            SceneViewContainer(scene: sceneRenderer.scene, onSelect: { node in
                selectedNode = node
            })
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                sceneRenderer.setCameraPosition(SCNVector3(x: 0, y: 3, z: 8))
            }
        } else {
            Color.black.edgesIgnoringSafeArea(.all)
        }

        // Top-middle console message overlay
        VStack {
            Text("Console message: \(agentStatusSummary)")
                .font(.caption)
                .padding(6)
                .background(Color.black.opacity(0.7))
                .cornerRadius(6)
                .foregroundColor(.white)
                .padding(.top, 60)
            Spacer()
        }
        .frame(maxWidth: .infinity)

        // Top bar: branding + status
        VStack {
            if topBarAtTop {
                topBarView
                Spacer()
            } else {
                Spacer()
                topBarView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        // Floating action bar (bottom-right)
        VStack {
            Spacer()
            HStack {
                Spacer()
                ActionBar(
                    onInspect: {
                        if let node = selectedNode {
                            addLog("Inspecting node: \(node)")
                            // Future: show AgentDetailCard for node
                        }
                    },
                    onTeleport: {
                        if let sceneRenderer: SceneRendererService = registry?.resolve("sceneRenderer") {
                            sceneRenderer.setCameraPosition(SCNVector3(x: 0, y: 3, z: 0))
                            addLog("Teleported camera to default position")
                        }
                    },
                    onClearSelection: {
                        selectedNode = nil
                        addLog("Selection cleared")
                    },
                    onToggleMinimap: {
                        withAnimation(.easeInOut) {
                            minimapState = (minimapState + 1) % 3
                        }
                    },
                    onToggleConsoleLog: {
                        withAnimation(.easeInOut) {
                            showConsoleLog.toggle()
                        }
                    }
                )
                .padding()
            }
        }

        // Simple local log tray (live)
        if showConsoleLog {
            VStack {
                Spacer()
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(localLogs.indices, id: \.self) { index in
                                Text(localLogs[index])
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(4)
                        .onChange(of: localLogs.count) { _, _ in
                            if let last = localLogs.indices.last {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }
                    .frame(width: 400, height: 120)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(8)
                }
            }
            .padding()
        }

        // Minimap/Compass with animated transitions
        Group {
            if minimapState == 1, let sceneRenderer: SceneRendererService = registry?.resolve("sceneRenderer") {
                VStack {
                    Spacer()
                    HStack {
                        MiniMapView(sceneRenderer: sceneRenderer)
                            .transition(.opacity.combined(with: .scale))
                        Spacer()
                    }
                }
                .padding()
            } else if minimapState == 2 {
                VStack {
                    Spacer()
                    HStack {
                        CompassMiniMapView(cameraYaw: cameraYaw)
                            .frame(width: 120, height: 120)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(60)
                            .transition(.opacity.combined(with: .scale))
                        Spacer()
                    }
                }
                .padding()
            }
        }

        // Minimap mode indicator overlay
        if minimapState != 0 {
            VStack {
                HStack {
                    Spacer()
                    Text(minimapState == 1 ? "MiniMap" : "3D Compass")
                        .font(.caption)
                        .padding(6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(6)
                        .foregroundColor(.white)
                        .padding(.trailing, 16)
                        .padding(.top, 40)
                }
                Spacer()
            }
        }

        // AgentDetailCard placeholder: deprecated EchoAgentComponent reference removed.
    }
}
}

private extension StormMainView {
var cameraYaw: Float {
    if let sceneRenderer: SceneRendererService = registry?.resolve("sceneRenderer") {
        return sceneRenderer.cameraYaw
    }
    return 0.0
}
}
