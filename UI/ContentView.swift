//
//  UI/ContentView.swift
//  Storm
//
//  Fixed ContentView that properly integrates with StormRuntime and SystemRegistry
//  Resolves renderer initialization hanging, type casting issues, and blank screen
//  Now properly displays CockpitView as per design
//
//  Created for Finalverse Storm - Fixed Integration

import SwiftUI
import RealityKit

struct ContentView: View {
    @EnvironmentObject var composer: UIComposer
    @Environment(\.systemRegistry) var registry
    
    // Fixed initialization: Use @StateObject instead of @State for proper lifecycle management
    @StateObject private var openSimConnection = OSConnectManager()
    @State private var ecsOpenSimBridge: OpenSimECSBridge? = nil
    @State private var isInitialized = false
    @State private var initializationError: String?
    
    var body: some View {
        Group {
            #if os(macOS)
            if #available(macOS 14.0, *) {
                // Use the professional cockpit view for macOS 14+
                professionalCockpitView
            } else {
                // Fallback to simple view for older macOS versions
                Text("macOS 13 and below not supported")
                    .foregroundColor(.red)
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
        if isInitialized {
            // Fixed: Remove the conditional check that was causing blank screen
            // Always show CockpitView once initialized, with openSimConnection as environment object
            CockpitView()
                .environmentObject(openSimConnection)
        } else if let error = initializationError {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                
                Text("Initialization Error")
                    .font(.headline)
                
                Text(error)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button("Retry") {
                    initializationError = nil
                    isInitialized = false
                    setupEnhancedEnvironment()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        } else {
            // Create and register renderer service if it doesn't exist
            RendererServiceBootstrap { renderer in
                VStack {
                    ProgressView("Finalizing Setup...")
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Preparing Finalverse Storm")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .onAppear {
                    finializeSetup(renderer: renderer)
                }
            }
        }
    }
    
    private func setupEnhancedEnvironment() {
        print("[🌟] Setting up enhanced Finalverse Storm environment")
        
        // Add timeout protection for initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            if !isInitialized && initializationError == nil {
                initializationError = "Initialization timed out after 15 seconds"
                print("[⏰] Environment setup timed out")
            }
        }
        
        // Setup OpenSim connection manager (avoid duplicates)
        setupOpenSimConnection()
        
        // Setup UI routing handlers
        setupUIRouting()
        
        // Setup UI schema for enhanced controls
        setupEnhancedUISchema()
        
        // Setup notification observers for system events
        setupSystemNotifications()
        
        // Configure debug settings based on build configuration
        configureDebugSettings()
        
        // Setup performance monitoring
        setupPerformanceMonitoring()
        
        print("[✅] Enhanced environment setup complete")
    }

    // MARK: - Helper Methods for Enhanced Environment Setup

    private func setupOpenSimConnection() {
        print("[🌐] Setting up OpenSim connection...")
        
        // Check if connection already exists in registry to avoid duplicates
        if let existingConnection: OSConnectManager = registry?.resolve("openSimConnection") {
            // Use existing connection from registry
            print("[🔗] Using existing OpenSim connection from registry")
            
            // Configure the existing connection if needed
            if let systemRegistry = registry {
                existingConnection.setSystemRegistry(systemRegistry)
                print("[🔧] OpenSim connection configured with system registry")
            }
        } else {
            // Register our connection in the registry
            registry?.register(openSimConnection, for: "openSimConnection")
            print("[📝] Registered OpenSim connection in system registry")
        }
        
        // Setup the connection
        openSimConnection.setup()
        
        // Configure connection for enhanced features
        if let systemRegistry = registry {
            openSimConnection.setSystemRegistry(systemRegistry)
            print("[🔧] OpenSim connection configured with system registry")
        }
        
        print("[✅] OpenSim connection setup complete")
    }

    private func setupUIRouting() {
        print("[🎯] Setting up UI routing handlers...")
        
        // Register OpenSim command handlers
        registry?.router?.registerHandler(namespace: "opensim") { command, args in
            print("[🌐] Processing OpenSim command: \(command)")
            
            switch command {
            case "connect":
                let hostname = args.first ?? "localhost"
                let port = UInt16(args.count > 1 ? args[1] : "9000") ?? 9000
                print("[🔌] Connecting to \(hostname):\(port)")
                openSimConnection.connect(to: hostname, port: port)
                
            case "disconnect":
                print("[🔌] Disconnecting from OpenSim server")
                openSimConnection.disconnect()
                
            case "teleport":
                if args.count >= 3,
                   let x = Float(args[0]),
                   let y = Float(args[1]),
                   let z = Float(args[2]) {
                    let position = SIMD3<Float>(x, y, z)
                    print("[🚀] Teleporting to position: \(position)")
                    openSimConnection.teleportAvatar(to: position)
                } else {
                    print("[⚠️] Invalid teleport arguments. Expected: x y z")
                }
                
            case "move":
                if args.count >= 3,
                   let x = Float(args[0]),
                   let y = Float(args[1]),
                   let z = Float(args[2]) {
                    let position = SIMD3<Float>(x, y, z)
                    let rotation = SIMD2<Float>(0, 0)
                    print("[🚶] Moving avatar to position: \(position)")
                    openSimConnection.moveAvatar(position: position, rotation: rotation)
                } else {
                    print("[⚠️] Invalid move arguments. Expected: x y z")
                }
                
            case "status":
                print("[📊] OpenSim Connection Status:")
                print("  Status: \(openSimConnection.connectionStatus)")
                print("  Connected: \(openSimConnection.isConnected)")
                print("  Latency: \(openSimConnection.latency)ms")
                
            default:
                print("[⚠️] Unknown OpenSim command: \(command)")
            }
        }
        
        // Register system command handlers
        registry?.router?.registerHandler(namespace: "system") { command, args in
            print("[🔧] Processing system command: \(command)")
            
            guard let registry = registry else { return }
            
            switch command {
            case "status":
                print("[📊] System Status Check")
                if let enhancedRegistry = registry as? SystemRegistry {
                    enhancedRegistry.dumpServiceStatus()
                } else {
                    print("  ECS: \(registry.ecs != nil ? "✅" : "❌")")
                    print("  UI: \(registry.ui != nil ? "✅" : "❌")")
                    print("  Router: \(registry.router != nil ? "✅" : "❌")")
                }
                
            case "debug":
                let enabled = args.first?.lowercased() == "true"
                print("[🐛] Debug mode: \(enabled ? "enabled" : "disabled")")
                // Apply debug settings to relevant services
                if let enhancedRegistry = registry as? SystemRegistry {
                    enhancedRegistry.enableDebugMode(enabled)
                }
                
            case "restart":
                print("[🔄] System restart requested")
                // Implementation would depend on your app architecture
                
            case "health":
                print("[🏥] System health check")
                if let enhancedRegistry = registry as? SystemRegistry {
                    let healthStatus = enhancedRegistry.checkServiceHealth()
                    for (service, health) in healthStatus {
                        let status = health.isHealthy ? "✅" : "❌"
                        print("  \(status) \(service): \(health.isHealthy ? "Healthy" : "Issues")")
                    }
                }
                
            default:
                print("[⚠️] Unknown system command: \(command)")
            }
        }
        
        // Register UI command handlers
        registry?.router?.registerHandler(namespace: "ui") { command, args in
            print("[🎨] Processing UI command: \(command)")
            
            switch command {
            case "reload":
                print("[🔄] Reloading UI schema")
                // Note: We cannot call setupEnhancedUISchema() from a closure
                // This would need to be handled differently, perhaps through notifications
                
            case "theme":
                let theme = args.first ?? "default"
                print("[🎨] Switching to theme: \(theme)")
                // Theme switching implementation would go here
                
            default:
                print("[⚠️] Unknown UI command: \(command)")
            }
        }
        
        print("[✅] UI routing handlers configured")
    }

    private func setupEnhancedUISchema() {
        print("[🎨] Setting up enhanced UI schema...")
        
        let enhancedSchema = UISchema(
            id: "finalverse_professional",
            type: "panel",
            label: "Finalverse Professional Controls",
            children: [
                // OpenSim Connection Panel
                UISchema(
                    id: "opensim_panel",
                    type: "panel",
                    label: "OpenSim Connection",
                    children: [
                        UISchema(
                            id: "quick_connect_btn",
                            type: "button",
                            label: "Quick Connect (Local)",
                            icon: "network",
                            action: "opensim.connect.localhost.9000"
                        ),
                        UISchema(
                            id: "connect_custom_btn",
                            type: "button",
                            label: "Connect to sim.example.com",
                            icon: "network",
                            action: "opensim.connect.sim.example.com.9000"
                        ),
                        UISchema(
                            id: "disconnect_btn",
                            type: "button",
                            label: "Disconnect",
                            icon: "network.slash",
                            action: "opensim.disconnect"
                        ),
                        UISchema(
                            id: "connection_status",
                            type: "bindLabel",
                            label: "Connection Status",
                            bind: "opensim.status"
                        )
                    ]
                ),
                
                // Avatar Controls Panel
                UISchema(
                    id: "avatar_panel",
                    type: "panel",
                    label: "Avatar Controls",
                    children: [
                        UISchema(
                            id: "teleport_home_btn",
                            type: "button",
                            label: "Teleport Home",
                            icon: "house",
                            action: "opensim.teleport.128.128.25"
                        ),
                        UISchema(
                            id: "teleport_center_btn",
                            type: "button",
                            label: "Teleport to Center",
                            icon: "location",
                            action: "opensim.teleport.128.128.30"
                        ),
                        UISchema(
                            id: "move_forward_btn",
                            type: "button",
                            label: "Move Forward",
                            icon: "arrow.up",
                            action: "opensim.move.130.128.25"
                        ),
                        UISchema(
                            id: "avatar_status",
                            type: "bindLabel",
                            label: "Avatar Status",
                            bind: "avatar.status"
                        )
                    ]
                ),
                
                // System Controls Panel
                UISchema(
                    id: "system_panel",
                    type: "panel",
                    label: "System Controls",
                    children: [
                        UISchema(
                            id: "system_status_btn",
                            type: "button",
                            label: "System Status",
                            icon: "info.circle",
                            action: "system.status"
                        ),
                        UISchema(
                            id: "health_check_btn",
                            type: "button",
                            label: "Health Check",
                            icon: "heart",
                            action: "system.health"
                        ),
                        UISchema(
                            id: "debug_toggle_btn",
                            type: "button",
                            label: "Toggle Debug",
                            icon: "ladybug",
                            action: "system.debug.true"
                        ),
                        UISchema(
                            id: "reload_ui_btn",
                            type: "button",
                            label: "Reload UI",
                            icon: "arrow.clockwise",
                            action: "ui.reload"
                        )
                    ]
                ),
                
                // Debug Panel (for development)
                UISchema(
                    id: "debug_panel",
                    type: "panel",
                    label: "Debug & Monitoring",
                    children: [
                        UISchema(
                            id: "entity_count",
                            type: "bindLabel",
                            label: "Active Entities",
                            bind: "ecs.entity_count"
                        ),
                        UISchema(
                            id: "performance_info",
                            type: "bindLabel",
                            label: "Performance",
                            bind: "system.performance"
                        ),
                        UISchema(
                            id: "memory_usage",
                            type: "bindLabel",
                            label: "Memory Usage",
                            bind: "system.memory"
                        )
                    ]
                )
            ]
        )
        
        // Apply the schema to the UI composer
        composer.rootSchema = enhancedSchema
        print("[✅] Enhanced UI schema configured with \(enhancedSchema.children?.count ?? 0) panels")
    }

    private func setupSystemNotifications() {
        print("[📢] Setting up system notifications...")
        
        // Listen for OpenSim connection status changes
        NotificationCenter.default.addObserver(
            forName: .openSimConnectionStateChanged,
            object: nil,
            queue: .main
        ) { notification in
            if let status = notification.object as? OSConnectionStatus {
                print("[📡] OpenSim connection status changed: \(status)")
                // Update UI or handle status change
            }
        }
        
        // Listen for entity creation/removal
        NotificationCenter.default.addObserver(
            forName: .openSimEntityCreated,
            object: nil,
            queue: .main
        ) { notification in
            if let entityInfo = notification.object as? [String: Any] {
                print("[🎭] Entity created: \(entityInfo)")
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .openSimEntityUpdated,
            object: nil,
            queue: .main
        ) { notification in
            if let entityInfo = notification.object as? [String: Any] {
                print("[🔄] Entity updated: \(entityInfo)")
            }
        }
        
        // Listen for chat messages
        NotificationCenter.default.addObserver(
            forName: .openSimChatMessage,
            object: nil,
            queue: .main
        ) { notification in
            if let chatMessage = notification.object as? ChatFromSimulatorMessage {
                print("[💬] Chat received from \(chatMessage.fromName): \(chatMessage.message)")
            }
        }
        
        print("[✅] System notifications configured")
    }

    private func configureDebugSettings() {
        print("[🐛] Configuring debug settings...")
        
        #if DEBUG
        // Enable debug mode in development builds
        if let enhancedRegistry = registry as? SystemRegistry {
            enhancedRegistry.enableDebugMode(true)
            print("[🐛] Debug mode enabled for development build")
        }
        
        // Configure additional debug features
        print("[🐛] Additional debug features enabled")
        #else
        print("[🐛] Production build - debug features disabled")
        #endif
    }

    private func setupPerformanceMonitoring() {
        print("[📊] Setting up performance monitoring...")
        
        // Setup periodic performance checks
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.updatePerformanceMetrics()
        }
        
        print("[✅] Performance monitoring configured")
    }

    private func updatePerformanceMetrics() {
        // Update performance metrics for UI binding
        guard let ecs = registry?.ecs else { return }
        
        let entityCount = ecs.getEntityCount()
        
        // You could update UI bindings here if implemented
        // For now, just log periodically
        if entityCount > 0 {
            print("[📊] Performance: \(entityCount) entities active")
        }
    }
    
    
    private func finializeSetup(renderer: RendererService) {
        print("[🔗] Finalizing setup with renderer...")
        
        DispatchQueue.main.async {
            do {
                // Setup ECS-OpenSim bridge
                try self.setupECSOpenSimBridge(renderer: renderer)
                
                // Mark as initialized - this will trigger the CockpitView to appear
                self.isInitialized = true
                
                print("[✅] Finalverse Storm initialization complete!")
                
            } catch {
                print("[❌] Finalization failed: \(error)")
                self.initializationError = "Setup failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func setupECSOpenSimBridge(renderer: RendererService) throws {
        guard let ecs = registry?.ecs else {
            throw SetupError.ecsNotAvailable
        }
        
        print("[🔗] Creating ECS-OpenSim bridge...")
        
        // Create and setup the ECS-OpenSim bridge
        let bridge = OpenSimECSBridge(ecs: ecs, renderer: renderer)
        
        // Register the bridge in the system registry
        registry?.register(bridge, for: "openSimBridge")
        
        // Store reference for cleanup
        self.ecsOpenSimBridge = bridge
        
        print("[✅] ECS-OpenSim bridge established")
    }
    
    private func cleanup() {
        print("[🧹] Cleaning up enhanced environment")
        openSimConnection.disconnect()
        ecsOpenSimBridge = nil
    }
    
    // Add this to your UI to show connection status:
    private var connectionStatusView: some View {
        HStack {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 8, height: 8)
            
            Text(connectionStatusText)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    private var connectionStatusColor: Color {
        switch openSimConnection.connectionStatus {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .red
        case .error: return .red
        }
    }

    private var connectionStatusText: String {
        switch openSimConnection.connectionStatus {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .disconnected: return "Disconnected"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

// MARK: - Setup Errors

enum SetupError: Error, LocalizedError {
    case ecsNotAvailable
    case rendererNotAvailable
    case registryNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .ecsNotAvailable:
            return "ECS system not available"
        case .rendererNotAvailable:
            return "Renderer service not available"
        case .registryNotAvailable:
            return "System registry not available"
        }
    }
}

// MARK: - Fixed Renderer Service Bootstrap

struct RendererServiceBootstrap<Content: View>: View {
    let content: (RendererService) -> Content
    @Environment(\.systemRegistry) var registry
    @State private var renderer: RendererService?
    @State private var setupError: String?
    
    var body: some View {
        Group {
            if let renderer = renderer {
                content(renderer)
            } else if let error = setupError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    
                    Text("Renderer Setup Error")
                        .font(.headline)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("Retry") {
                        setupError = nil
                        setupRenderer()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                VStack(spacing: 12) {
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
        print("[🎨] Setting up renderer...")
        
        // Add timeout protection
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if renderer == nil && setupError == nil {
                setupError = "Renderer setup timed out"
            }
        }
        
        // Setup on background queue to prevent UI blocking
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let registry = registry else {
                    throw SetupError.registryNotAvailable
                }
                
                // Check if renderer already exists
                if let existingRenderer: RendererService = registry.resolve("renderer") {
                    DispatchQueue.main.async {
                        self.renderer = existingRenderer
                        print("[✅] Using existing renderer from registry")
                    }
                    return
                }
                
                // Get ECS
                guard let ecs = registry.ecs else {
                    throw SetupError.ecsNotAvailable
                }
                
                // Create renderer on main thread
                DispatchQueue.main.async {
                    do {
                        print("[🎨] Creating new renderer...")
                        
                        // Create ARView
                        let arView = ARView(frame: .zero)
                        arView.environment.background = .color(.black)
                        
                        // Create renderer service
                        let rendererService = RendererService(ecs: ecs, arView: arView)
                        
                        // Register in registry
                        registry.register(rendererService, for: "renderer")
                        
                        // Set state
                        self.renderer = rendererService
                        
                        print("[✅] Renderer created and registered successfully")
                        
                    } catch {
                        print("[❌] Failed to create renderer: \(error)")
                        self.setupError = "Failed to create renderer: \(error.localizedDescription)"
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    print("[❌] Renderer setup failed: \(error)")
                    self.setupError = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(UIComposer())
        .environment(\.systemRegistry, SystemRegistry())
}
