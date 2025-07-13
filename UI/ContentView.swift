//
//  UI/ContentView.swift
//  Storm
//
//  Enhanced ContentView that integrates the professional cockpit with OpenSim connectivity
//  Serves as the main entry point for the complete Finalverse Storm experience
//
//  Created for Finalverse Storm - Main Integration

import SwiftUI
import RealityKit

struct ContentView: View {
    @EnvironmentObject var composer: UIComposer
    @Environment(\.systemRegistry) var registry
    @StateObject private var openSimConnection = OSConnectManager()
    @State private var ecsOpenSimBridge: OpenSimECSBridge? = nil
    
    var body: some View {
        Group {
            #if os(macOS)
            if #available(macOS 14.0, *) {
                // Use the professional cockpit view for macOS 14+
                professionalCockpitView
            } else {
                // Fallback to simple view for older macOS versions
               // SimpleView_macOS()
            }
            #else
            // iOS uses the professional cockpit
            professionalCockpitView
            #endif
        }
        .onAppear {
            setupEnhancedEnvironment()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    @ViewBuilder
    private var professionalCockpitView: some View {
        if let renderer: RendererService = registry?.resolve("renderer") {
            CockpitView()
                .environmentObject(openSimConnection)
                .onAppear {
                    setupECSOpenSimBridge(renderer: renderer)
                }
        } else {
            // Create and register renderer service if it doesn't exist
            RendererServiceBootstrap { renderer in
                CockpitView()
                    .environmentObject(openSimConnection)
                    .onAppear {
                        setupECSOpenSimBridge(renderer: renderer)
                    }
            }
        }
    }
    
    private func setupEnhancedEnvironment() {
        print("[🌟] Setting up enhanced Finalverse Storm environment")
        
        // Setup OpenSim connection manager
        openSimConnection.setup()
        
        // Register additional UI handlers for OpenSim integration
        registry?.router?.registerHandler(namespace: "opensim") { command, args in
            handleOpenSimCommand(command: command, args: args)
        }
        
        // Setup UI schema for enhanced controls
        setupEnhancedUISchema()
    }
    
    private func setupECSOpenSimBridge(renderer: RendererService) {
        guard let ecs = registry?.ecs else {
            print("[❌] ECS not available for OpenSim bridge")
            return
        }
        
        // Create and setup the ECS-OpenSim bridge
        let bridge = OpenSimECSBridge(ecs: ecs, renderer: renderer)
        
        // Register the bridge in the system registry
        registry?.register(bridge, for: "openSimBridge")
        
        print("[🔗] ECS-OpenSim bridge established")
    }
    
    private func handleOpenSimCommand(command: String, args: [String]) {
        switch command {
        case "connect":
            let hostname = args.first ?? "localhost"
            let port = UInt16(args.count > 1 ? args[1] : "9000") ?? 9000
            openSimConnection.connect(to: hostname, port: port)
            
        case "disconnect":
            openSimConnection.disconnect()
            
        case "teleport":
            if args.count >= 3,
               let x = Float(args[0]),
               let y = Float(args[1]),
               let z = Float(args[2]) {
                openSimConnection.teleportAvatar(to: SIMD3<Float>(x, y, z))
            }
            
        case "move":
            if args.count >= 3,
               let x = Float(args[0]),
               let y = Float(args[1]),
               let z = Float(args[2]) {
                openSimConnection.moveAvatar(
                    position: SIMD3<Float>(x, y, z),
                    rotation: SIMD3<Float>(0, 0, 0)
                )
            }
            
        default:
            print("[⚠️] Unknown OpenSim command: \(command)")
        }
    }
    
    private func setupEnhancedUISchema() {
        let enhancedSchema = UISchema(
            id: "finalverse_professional",
            type: "panel",
            label: "Finalverse Professional Controls",
            children: [
                UISchema(
                    id: "opensim_panel",
                    type: "panel",
                    label: "OpenSim Connection",
                    children: [
                        UISchema(
                            id: "connect_btn",
                            type: "button",
                            label: "Connect to OpenSim",
                            icon: "network",
                            action: "opensim.connect.localhost.9000"
                        ),
                        UISchema(
                            id: "disconnect_btn",
                            type: "button",
                            label: "Disconnect",
                            icon: "network.slash",
                            action: "opensim.disconnect"
                        ),
                        UISchema(
                            id: "teleport_home_btn",
                            type: "button",
                            label: "Teleport Home",
                            icon: "house",
                            action: "opensim.teleport.128.128.25"
                        )
                    ]
                ),
                UISchema(
                    id: "avatar_panel",
                    type: "panel",
                    label: "Avatar Controls",
                    children: [
                        UISchema(
                            id: "avatar_status",
                            type: "bindLabel",
                            label: "Avatar Status",
                            bind: "avatar.status"
                        )
                    ]
                )
            ]
        )
        
        composer.rootSchema = enhancedSchema
    }
    
    private func cleanup() {
        print("[🧹] Cleaning up enhanced environment")
        openSimConnection.disconnect()
    }
}

// MARK: - Renderer Service Bootstrap

struct RendererServiceBootstrap<Content: View>: View {
    let content: (RendererService) -> Content
    @Environment(\.systemRegistry) var registry
    @State private var renderer: RendererService?
    
    var body: some View {
        Group {
            if let renderer = renderer {
                content(renderer)
            } else {
                VStack {
                    ProgressView("Initializing Renderer...")
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Setting up RealityKit environment")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .onAppear {
                    setupRenderer()
                }
            }
        }
    }
    
    private func setupRenderer() {
        guard let ecs = registry?.ecs else {
            print("[❌] ECS not available for renderer setup")
            return
        }
        
        // Create ARView
        let arView = ARView(frame: .zero)
        arView.environment.background = .color(.black)
        
        // Create renderer service
        let rendererService = RendererService(ecs: ecs, arView: arView)
        
        // Register in system registry
        registry?.register(rendererService, for: "renderer")
        
        // Set local state
        self.renderer = rendererService
        
        print("[✅] Renderer service initialized and registered")
    }
}

#Preview {
    ContentView()
        .environmentObject(UIComposer())
        .environment(\.systemRegistry, SystemRegistry())
}
