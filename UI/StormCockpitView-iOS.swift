#if os(iOS)
//
//  UI/StormCockpitView-iOS.swift
//  Storm
//
//  Cockpit view for RealityKit-powered Storm client (iOS version).
//
//  Created by Wenyan Qin on 2025-07-12.
//

import SwiftUI
import RealityKit
import GameController

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
    ZStack(alignment: .top) {
            if let renderer: RendererService = registry?.resolve("renderer") {
                ARViewContainer(renderer: renderer)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Color.black.edgesIgnoringSafeArea(.all)
            }

            VStack {
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
            }

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
                        withAnimation { minimapState = (minimapState + 1) % 3 }
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

            if minimapState == 1, let renderer: RendererService = registry?.resolve("renderer") {
                VStack {
                    Spacer()
                    HStack {
                        MiniMapView(renderer: renderer)
                            .frame(width: 100, height: 100)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(50)
                            .padding(12)
                        Spacer()
                    }
                }
            }
            // Add CompassMiniMapView for minimapState == 2
            if minimapState == 2, let renderer: RendererService = registry?.resolve("renderer") {
                VStack {
                    Spacer()
                    HStack {
                        CompassMiniMapView(cameraYaw: 0) // You can wire in actual cameraYaw if available
                            .frame(width: 100, height: 100)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(50)
                            .padding(12)
                        Spacer()
                    }
                }
            }
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    let renderer: RendererService

    func makeUIView(context: Context) -> ARView {
        let view = renderer.arView
        view.environment.background = .color(.black)

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)

        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(renderer: renderer)
    }

    class Coordinator: NSObject {
        let renderer: RendererService

        init(renderer: RendererService) {
            self.renderer = renderer
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            renderer.rotateCamera(yaw: Float(translation.x) * 0.005, pitch: Float(-translation.y) * 0.005)
            gesture.setTranslation(.zero, in: gesture.view)
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            renderer.zoomCamera(delta: Float((gesture.scale - 1.0)) * 0.2)
            gesture.scale = 1.0
        }
    }
}

#endif
