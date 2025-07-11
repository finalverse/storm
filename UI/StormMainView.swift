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

    private func agentComponent(for node: SCNNode) -> EchoAgentComponent? {
        if let registry = registry,
           let sceneRenderer: SceneRendererService = registry.resolve("sceneRenderer"),
           let entityID = sceneRenderer.entityID(for: node),
           let ecs = registry.ecs {
            return ecs.getWorld().getComponent(ofType: EchoAgentComponent.self, from: entityID)
        }
        return nil
    }

    var body: some View {
        ZStack {
            // Full-screen 3D scene
            if let sceneRenderer: SceneRendererService = registry?.resolve("sceneRenderer") {
                SceneViewContainer(scene: sceneRenderer.scene, onSelect: { node in
                    selectedNode = node
                })
                .edgesIgnoringSafeArea(.all)
            } else {
                Color.black.edgesIgnoringSafeArea(.all)
            }

            // Top bar: branding + status
            HStack {
                VStack(alignment: .leading) {
                    Text("🌩️ Finalverse Storm")
                        .font(.title2)
                        .bold()
                    Text("v0.1.x")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Text("🛰️ Online")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            .padding()
            .background(Color.black.opacity(0.7).blur(radius: 10))
            .cornerRadius(12)
            .padding([.horizontal, .top], 16)

            // Floating action bar (bottom-right)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ActionBar(
                        onInspect: {
                            if let node = selectedNode {
                                print("Inspecting node: \(node)")
                                // Future: show AgentDetailCard for node
                            }
                        },
                        onTeleport: {
                            if let sceneRenderer: SceneRendererService = registry?.resolve("sceneRenderer") {
                                sceneRenderer.setCameraPosition(SCNVector3(x: 0, y: 3, z: 0))
                                print("Teleported camera to default position")
                            }
                        },
                        onClearSelection: {
                            selectedNode = nil
                            print("Selection cleared")
                        }
                    )
                    .padding()
                }
            }

            // Console log tray (optional, placeholder)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("Console Log Tray [placeholder]")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding()

            if let sceneRenderer: SceneRendererService = registry?.resolve("sceneRenderer") {
                VStack {
                    Spacer()
                    HStack {
                        MiniMapView(sceneRenderer: sceneRenderer)
                        Spacer()
                    }
                }
                .padding()
            }

            if let node = selectedNode,
               let agent = agentComponent(for: node) {
                HStack {
                    Spacer()
                    AgentDetailCard(agent: agent)
                        .padding()
                }
            }
        }
    }
}
