#if os(iOS)
//
//  StormCockpitView-iOS.swift
//  Storm
//
//  Cockpit view for RealityKit-powered Storm client (iOS version).
//
//  Created by Wenyan Qin on 2025-07-12.
//

import SwiftUI
import RealityKit

struct StormCockpitView: View {
    @Environment(\.systemRegistry) var registry

    @State private var selectedEntityID: EntityID?
    @State private var minimapState: Int = 0
    @State private var showConsoleLog: Bool = true
    @State private var localLogs: [String] = []

    private var agentStatusSummary: String {
        guard let renderer: RendererService = registry?.resolve("renderer") else { return "No agents." }
        return "Agents: \(renderer.arView.scene.anchors.count)"
    }

    func addLog(_ message: String) {
        localLogs.append(message)
        if localLogs.count > 100 {
            localLogs.removeFirst(localLogs.count - 100)
        }
    }

    var body: some View {
        ZStack {
            if let renderer: RendererService = registry?.resolve("renderer") {
                ARViewContainer(arView: renderer.arView)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Color.black.edgesIgnoringSafeArea(.all)
            }

            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                Text("Storm iOS")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(agentStatusSummary)
                    .font(.caption2)
                    .foregroundColor(.green)
            }
            .padding(8)
            .background(Color.black.opacity(0.8).blur(radius: 8))
            .cornerRadius(10)
            .padding(.horizontal, 12)
            .padding(.top, 20)
            .frame(maxWidth: .infinity, alignment: .top)

            VStack {
                Spacer()
                HStack(spacing: 16) {
                    Button(action: {
                        if let id = selectedEntityID {
                            addLog("Inspecting entity: \(id)")
                        }
                    }) {
                        Image(systemName: "magnifyingglass")
                    }
                    Button(action: {
                        addLog("Teleport not implemented (iOS)")
                    }) {
                        Image(systemName: "location.north.line")
                    }
                    Button(action: {
                        selectedEntityID = nil
                        addLog("Selection cleared")
                    }) {
                        Image(systemName: "xmark.circle")
                    }
                    Button(action: {
                        withAnimation { minimapState = (minimapState + 1) % 2 }
                    }) {
                        Image(systemName: "map")
                    }
                    Button(action: {
                        withAnimation { showConsoleLog.toggle() }
                    }) {
                        Image(systemName: "terminal")
                    }
                }
                .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(20)
                .shadow(radius: 8)
                .padding(.bottom, 20)
            }

            if showConsoleLog {
                VStack {
                    Spacer()
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
                    }
                    .frame(height: 100)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(8)
                    .padding(.bottom, 80)
                    .padding(.horizontal, 12)
                }
            }
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    let arView: ARView

    func makeUIView(context: Context) -> ARView { arView }
    func updateUIView(_ uiView: ARView, context: Context) { }
}
#endif
