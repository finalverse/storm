//
//  Core/StormRuntime.swift
//  Storm
//
//  Enhanced orchestrator for Finalverse Storm app lifecycle with OpenSim integration
//  Coordinates kernel ticking, plugin loading, system setup, service injection, and OpenSim connectivity
//  ENHANCED: Proper service initialization order, OpenSim integration, and renderer injection support
//
//  Created by Wenyan Qin on 2025-07-10.
//

import Foundation
import RealityKit

final class StormRuntime {

    // MARK: - Core Subsystems
    private let kernel = Kernel()
    private let registry = SystemRegistry()
    private let pluginHost = PluginHost()
    private let composer = UIComposer()
    
    // MARK: - Runtime State
    private var isStarted = false
    private var isSystemsSetup = false
    
    init() {
        print("[🧠] StormRuntime initialized.")
        setupCoreServices()
    }

    // MARK: - Runtime Lifecycle
    
    /// Starts the runtime: initializes services, loads plugins, starts kernel ticking.
    func start() {
        guard !isStarted else {
            print("[⚠️] StormRuntime already started")
            return
        }
        
        print("[▶️] StormRuntime starting...")
        
        // Ensure all systems are properly setup
        if !isSystemsSetup {
            setupCoreServices()
        }
        
        // Initialize plugins with enhanced registry
        pluginHost.initializePlugins(kernel: kernel, registry: registry)
        
        // Setup renderer system integration
        setupRendererIntegration()
        
        // Setup OpenSim integration if available
        setupOpenSimIntegration()
        
        // Start all services
        registry.startServices()
        
        // Start kernel ticking
        kernel.start()
        
        isStarted = true
        print("[✅] StormRuntime started successfully")
    }

    /// Stops the runtime and all services
    func stop() {
        guard isStarted else {
            print("[⚠️] StormRuntime not started")
            return
        }
        
        print("[⏹️] StormRuntime stopping...")
        
        // Stop kernel first
        kernel.stop()
        
        // Stop all services
        registry.stopServices()
        
        isStarted = false
        print("[✅] StormRuntime stopped")
    }
    
    /// Restarts the runtime
    func restart() {
        stop()
        start()
        print("[🔄] StormRuntime restarted")
    }

    // MARK: - Core Service Setup
    
    /// Initializes core shared services and registers them in SystemRegistry.
    private func setupCoreServices() {
        guard !isSystemsSetup else { return }
        
        print("[🔧] Setting up core services...")
        
        // 1. Initialize ECS Core (foundation service)
        let ecs = ECSCore()
        registry.registerECS(ecs)
        
        // 2. Initialize UI services
        registry.register(composer, for: "ui")
        
        let router = UIScriptRouter()
        registry.register(router, for: "router")
        
        // 3. Setup UI routing handlers
        setupUIRouting(router)
        
        isSystemsSetup = true
        print("[✅] Core services setup complete")
    }
    
    private func setupUIRouting(_ router: UIScriptRouter) {
        // Register OpenSim command handlers
        router.registerHandler(namespace: "opensim") { [weak self] command, args in
            self?.handleOpenSimCommand(command, args: args)
        }
        
        // Register system command handlers
        router.registerHandler(namespace: "system") { [weak self] command, args in
            self?.handleSystemCommand(command, args: args)
        }
        
        // Register debug command handlers
        router.registerHandler(namespace: "debug") { [weak self] command, args in
            self?.handleDebugCommand(command, args: args)
        }
    }
    
    // MARK: - Renderer Integration
    
    private func setupRendererIntegration() {
        // Setup renderer update system in kernel
        if let renderer: RendererService = registry.resolve("renderer") {
            kernel.registerSystem { [weak renderer] deltaTime in
                renderer?.updateScene()
            }
            print("[🎨] Renderer integration established")
        } else {
            print("[ℹ️] Renderer not yet available - will integrate when registered")
        }
    }
    
    /// Called by ContentView when renderer is ready
    func registerRenderer(_ renderer: RendererService) {
        print("[🎨] Registering renderer with runtime...")
        
        // Register renderer in system registry
        registry.registerRenderer(renderer)
        
        // Setup kernel integration if runtime is started
        if isStarted {
            kernel.registerSystem { [weak renderer] deltaTime in
                renderer?.updateScene()
            }
        }
        
        // Initialize OpenSim services now that renderer is available
        initializeOpenSimServices()
        
        print("[✅] Renderer registration complete")
    }
    
    // MARK: - OpenSim Integration
    
    private func setupOpenSimIntegration() {
        // OpenSim services are initialized when renderer becomes available
        // This ensures proper dependency order
        if registry.hasOpenSimSupport() {
            print("[🌐] OpenSim integration ready")
        } else {
            print("[ℹ️] OpenSim integration pending renderer availability")
        }
    }
    
    private func initializeOpenSimServices() {
        print("[🌐] Initializing OpenSim services...")
        
        // This will be called by the enhanced SystemRegistry
        // when renderer is registered
        registry.initializeServices()
        
        // Setup OpenSim-specific kernel systems
        setupOpenSimKernelSystems()
        
        print("[✅] OpenSim services initialized")
    }
    
    private func setupOpenSimKernelSystems() {
        // Register OpenSim bridge update system
        if let bridge: OpenSimECSBridge = registry.resolve("openSimBridge") {
            kernel.registerSystem { deltaTime in
                // OpenSim bridge handles updates via notifications
                // This system could be used for periodic maintenance
                // For now, it's a placeholder for future enhancements
            }
        }
        
        // Register message router maintenance system
        if let messageRouter: OSMessageRouter = registry.resolve("messageRouter") {
            kernel.registerSystem { deltaTime in
                // Periodic maintenance for message router
                // Could include timeout checking, queue cleanup, etc.
            }
        }
    }
    
    // MARK: - Command Handlers
    
    private func handleOpenSimCommand(_ command: String, args: [String]) {
        guard let connection: OSConnectManager = registry.resolve("openSimConnection") else {
            print("[❌] OpenSim connection not available")
            return
        }
        
        switch command {
        case "connect":
            let hostname = args.count > 0 ? args[0] : "localhost"
            let port = UInt16(args.count > 1 ? args[1] : "9000") ?? 9000
            connection.connect(to: hostname, port: port)
            
        case "disconnect":
            connection.disconnect()
            
        case "teleport":
            if args.count >= 3,
               let x = Float(args[0]),
               let y = Float(args[1]),
               let z = Float(args[2]) {
                connection.teleportAvatar(to: SIMD3<Float>(x, y, z))
            }
            
        case "move":
            if args.count >= 3,
               let x = Float(args[0]),
               let y = Float(args[1]),
               let z = Float(args[2]) {
                connection.moveAvatar(
                    position: SIMD3<Float>(x, y, z),
                    rotation: SIMD2<Float>(0, 0)
                )
            }
            
        case "status":
            dumpOpenSimStatus()
            
        default:
            print("[⚠️] Unknown OpenSim command: \(command)")
        }
    }
    
    private func handleSystemCommand(_ command: String, args: [String]) {
        switch command {
        case "status":
            dumpSystemStatus()
            
        case "restart":
            restart()
            
        case "debug":
            let enabled = args.first?.lowercased() == "true"
            registry.enableDebugMode(enabled)
            
        case "clear_cache":
            if let bridge: OpenSimECSBridge = registry.resolve("openSimBridge") {
                bridge.clearCache()
            }
            
        case "health":
            checkSystemHealth()
            
        default:
            print("[⚠️] Unknown system command: \(command)")
        }
    }
    
    private func handleDebugCommand(_ command: String, args: [String]) {
        switch command {
        case "entities":
            dumpEntityInfo()
            
        case "services":
            registry.dumpServiceStatus()
            
        case "performance":
            dumpPerformanceInfo()
            
        case "visualize":
            let enabled = args.first?.lowercased() == "true"
            if let bridge: OpenSimECSBridge = registry.resolve("openSimBridge") {
                bridge.enableDebugVisualization(enabled)
            }
            
        default:
            print("[⚠️] Unknown debug command: \(command)")
        }
    }
    
    // MARK: - Status and Debug Methods
    
    private func dumpSystemStatus() {
        print("=== StormRuntime System Status ===")
        print("Runtime Started: \(isStarted)")
        print("Systems Setup: \(isSystemsSetup)")
        print("Kernel Running: \(kernel.isRunning)")
        print("")
        
        registry.dumpServiceStatus()
        print("===================================")
    }
    
    private func dumpOpenSimStatus() {
        print("=== OpenSim Status ===")
        
        if let connection: OSConnectManager = registry.resolve("openSimConnection") {
            print("Connection Status: \(connection.connectionStatus)")
            print("Is Connected: \(connection.isConnected)")
            print("Latency: \(connection.latency)ms")
        } else {
            print("OpenSim Connection: Not Available")
        }
        
        if let bridge: OpenSimECSBridge = registry.resolve("openSimBridge") {
            let stats = bridge.getEntityStats()
            print("Active Entities: \(stats.activeEntities)")
            print("Total Created: \(stats.totalEntities)")
        } else {
            print("OpenSim Bridge: Not Available")
        }
        
        print("======================")
    }
    
    private func dumpEntityInfo() {
        guard let ecs = registry.ecs else {
            print("[❌] ECS not available")
            return
        }
        
        let entityCount = ecs.getEntityCount()
        print("=== Entity Information ===")
        print("Total ECS Entities: \(entityCount)")
        
        if let bridge: OpenSimECSBridge = registry.resolve("openSimBridge") {
            bridge.dumpEntityInfo()
        }
        
        print("===========================")
    }
    
    private func dumpPerformanceInfo() {
        print("=== Performance Information ===")
        
        if let bridge: OpenSimECSBridge = registry.resolve("openSimBridge") {
            let metrics = bridge.getPerformanceMetrics()
            print("Entity Count: \(metrics.entityCount)")
            print("Render Count: \(metrics.renderCount)")
            print("Memory Usage: \(metrics.memoryUsage / 1024)KB")
            print("Average Update Time: \(metrics.averageUpdateTime() * 1000)ms")
        }
        
        if let messageRouter: OSMessageRouter = registry.resolve("messageRouter") {
            let avgTime = messageRouter.getAverageProcessingTime()
            let stats = messageRouter.getMessageTypeStats()
            print("Message Processing Time: \(avgTime * 1000)ms")
            print("Messages Processed: \(stats.values.reduce(0, +))")
        }
        
        print("===============================")
    }
    
    private func checkSystemHealth() {
        let healthStatus = registry.checkServiceHealth()
        
        print("=== System Health Check ===")
        for (service, health) in healthStatus {
            let status = health.isHealthy ? "✅" : "❌"
            print("\(status) \(service): \(health.isHealthy ? "Healthy" : "Issues")")
            
            if !health.issues.isEmpty {
                for issue in health.issues {
                    print("  - \(issue)")
                }
            }
        }
        print("============================")
    }

    // MARK: - Public Accessors
    
    /// Accessor for SystemRegistry.
    func getRegistry() -> SystemRegistry {
        return registry
    }

    /// Accessor for UIComposer instance.
    func getUIComposer() -> UIComposer {
        return composer
    }
    
    /// Get runtime status
    func getStatus() -> RuntimeStatus {
        return RuntimeStatus(
            isStarted: isStarted,
            isSystemsSetup: isSystemsSetup,
            kernelRunning: kernel.isRunning,
            hasRenderer: registry.resolve("renderer") != nil,
            hasOpenSimSupport: registry.hasOpenSimSupport()
        )
    }
    
    /// Check if specific service is available
    func hasService<T>(_ type: T.Type, key: String) -> Bool {
        let service: T? = registry.resolve(key)
        return service != nil
    }
    
    /// Get service safely
    func getService<T>(_ type: T.Type, key: String) -> T? {
        return registry.resolve(key)
    }
}

// MARK: - Supporting Types

struct RuntimeStatus {
    let isStarted: Bool
    let isSystemsSetup: Bool
    let kernelRunning: Bool
    let hasRenderer: Bool
    let hasOpenSimSupport: Bool
    
    var isFullyOperational: Bool {
        return isStarted && isSystemsSetup && kernelRunning && hasRenderer
    }
    
    var description: String {
        return """
        Runtime: \(isStarted ? "Started" : "Stopped")
        Systems: \(isSystemsSetup ? "Setup" : "Not Setup")
        Kernel: \(kernelRunning ? "Running" : "Stopped")
        Renderer: \(hasRenderer ? "Available" : "Not Available")
        OpenSim: \(hasOpenSimSupport ? "Available" : "Not Available")
        Status: \(isFullyOperational ? "Fully Operational" : "Partial")
        """
    }
}

// MARK: - Kernel Extensions

extension Kernel {
    var isRunning: Bool {
        // This would need to be implemented in the Kernel class
        // For now, assume it's running if systems are registered
        return true // Placeholder
    }
}

// MARK: - Runtime Extensions for ContentView Integration

extension StormRuntime {
    
    /// Called by ContentView when it's ready to setup renderer
    func setupRenderer(with arView: ARView) -> RendererService? {
        guard let ecs = registry.ecs else {
            print("[❌] Cannot setup renderer: ECS not available")
            return nil
        }
        
        let renderer = RendererService(ecs: ecs, arView: arView)
        registerRenderer(renderer)
        return renderer
    }
    
    /// Get OpenSim connection manager for UI binding
    func getOpenSimConnection() -> OSConnectManager? {
        return registry.resolve("openSimConnection")
    }
    
    /// Get OpenSim bridge for UI inspection
    func getOpenSimBridge() -> OpenSimECSBridge? {
        return registry.resolve("openSimBridge")
    }
    
    /// Execute UI command directly
    func executeCommand(_ action: String) {
        registry.router?.route(action: action)
    }
}
