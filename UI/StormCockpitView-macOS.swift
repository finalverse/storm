#if os(macOS)
//
//  UI/StormCockpitView-macOS.swift
//  Storm
//
//  Cockpit view for RealityKit-powered Storm client (macOS version).
//
//  Created by Wenyan Qin on 2025-07-11.
//

import SwiftUI
import RealityKit

struct StormCockpitView: View {
    @Environment(\.systemRegistry) var registry

    @State private var selectedEntityID: EntityID?
    @State private var topBarAtTop: Bool = true
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
            if let renderer: RendererService = registry?.resolve("renderer") {
                ARViewContainer(arView: renderer.arView)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Color.black.edgesIgnoringSafeArea(.all)
            }

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

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ActionBar(
                        onInspect: {
                            if let id = selectedEntityID {
                                addLog("Inspecting entity: \(id)")
                            }
                        },
                        onTeleport: {
                            addLog("Teleport not implemented for RealityKit renderer")
                        },
                        onClearSelection: {
                            selectedEntityID = nil
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
        }
    }
}

struct ARViewContainer: NSViewRepresentable {
    let arView: ARView

    func makeNSView(context: Context) -> ARView { arView }
    func updateNSView(_ nsView: ARView, context: Context) { }
}
#endif
