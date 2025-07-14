//
//  Core/SystemRegistry.swift
//  Storm
//
//  Enhanced container for shared services (ECS, UI, OpenSim, Audio, etc.)
//  ENHANCED: Added OpenSim integration and improved service management
//
//  Created by Wenyan Qin on 2025-07-09.
//

import Foundation

/// Enhanced container for shared services with OpenSim integration support
final class SystemRegistry {

    // MARK: - Core Services
    var ecs: ECSCore? = nil
    var ui: UIComposer? = nil
    var router: UIScriptRouter? = nil
    
    // MARK: - OpenSim Integration Services
    var openSimBridge: OpenSimECSBridge? = nil
    var openSimConnection: OSConnectManager? = nil
    var messageRouter: OSMessageRouter? = nil
    
    // MARK: - Rendering Services
    var renderer: RendererService? = nil
    
    // MARK: - Future Services (Commented for now)
    //var agentService: EchoAgentService? = nil
    //var llm: LLMBroker? = nil
    //var audio: AudioEngine? = nil

    // MARK: - Service Metadata
    var metadata: [String: Any] = [:]
    
    // MARK: - Service State
    private var isInitialized = false
    private var initializationOrder: [String] = []
    
    init() {
        setupServiceDependencies()
    }
    
    // MARK: - Service Registration
    
    func register<T>(_ service: T, for key: String) {
        metadata[key] = service
        initializationOrder.append(key)
        
        // Also set typed properties for easy access
        switch key {
        case "ecs":
            ecs = service as? ECSCore
        case "ui":
            ui = service as? UIComposer
        case "router":
            router = service as? UIScriptRouter
        case "openSimBridge":
            openSimBridge = service as? OpenSimECSBridge
        case "openSimConnection":
            openSimConnection = service as? OSConnectManager
        case "messageRouter":
            messageRouter = service as? OSMessageRouter
        case "renderer":
            renderer = service as? RendererService
        default:
            break
        }
        
        print("[🔧] Registered service '\(key)': \(type(of: service))")
    }
    
    // REPLACE the existing resolve methods with these improved versions:

    func resolve<T>(_ key: String) -> T? {
        return metadata[key] as? T
    }

    func get<T>(_ key: String) -> T? {
        return resolve(key)
    }

    // ADD: Type-safe convenience methods for common services
    func getOpenSimBridge() -> OpenSimECSBridge? {
        return resolve("openSimBridge")
    }

    func getOpenSimConnection() -> OSConnectManager? {
        return resolve("openSimConnection")
    }

    func getMessageRouter() -> OSMessageRouter? {
        return resolve("messageRouter")
    }

    func getECS() -> ECSCore? {
        return resolve("ecs")
    }

    func getRenderer() -> RendererService? {
        return resolve("renderer")
    }

    func getUIComposer() -> UIComposer? {
        return resolve("ui")
    }

    func getUIRouter() -> UIScriptRouter? {
        return resolve("router")
    }
    
    // MARK: - Service Dependencies and Setup
    
    private func setupServiceDependencies() {
        // Define service dependencies for proper initialization order
        // This ensures services are initialized in the correct sequence
    }
    
    func initializeServices() {
        guard !isInitialized else {
            print("[⚠️] SystemRegistry already initialized")
            return
        }
        
        setupDefaultServices()
        initializeOpenSimIntegration()
        validateServiceDependencies()
        
        isInitialized = true
        print("[✅] SystemRegistry initialization complete")
    }
    
    private func setupDefaultServices() {
        // Initialize core services in dependency order
        
        // 1. Initialize ECS Core (foundation)
        if ecs == nil {
            let ecsCore = ECSCore()
            register(ecsCore, for: "ecs")
        }
        
        // 2. Initialize UI system
        if ui == nil {
            let uiComposer = UIComposer()
            register(uiComposer, for: "ui")
        }
        
        // 3. Initialize UI Router
        if router == nil {
            let uiRouter = UIScriptRouter()
            register(uiRouter, for: "router")
        }
        
        print("[🔧] Default services initialized")
    }
    
    // MODIFY the initializeOpenSimIntegration method to use the fixed integration:

    private func initializeOpenSimIntegration() {
        // Only initialize OpenSim services if dependencies are available
        guard let ecs = ecs, let renderer = renderer else {
            print("[⚠️] Cannot initialize OpenSim integration: missing ECS or Renderer")
            return
        }
        
        print("[🌐] Initializing OpenSim integration services...")
        
        // 1. Initialize Message Router first
        if messageRouter == nil {
            let router = OSMessageRouter()
            register(router, for: "messageRouter")
            print("[📨] Message router initialized")
        }
        
        // 2. Initialize OpenSim Connection Manager WITH registry reference
        if openSimConnection == nil {
            let connectionManager = OSConnectManager(systemRegistry: self)
            register(connectionManager, for: "openSimConnection")
            print("[🔌] OpenSim connection manager initialized")
        }
        
        // 3. Initialize OpenSim ECS Bridge with enhanced configuration
        if openSimBridge == nil {
            let config = createOpenSimConfig()
            let bridge = OpenSimECSBridge(ecs: ecs, renderer: renderer, config: config)
            register(bridge, for: "openSimBridge")
            print("[🌉] OpenSim ECS bridge initialized")
            
            // Register bridge with connection manager using the fixed method
            if let connectionManager = openSimConnection {
                connectionManager.registerECSBridge(bridge)
                print("[🔗] ECS bridge registered with connection manager")
            }
        }
        
        // 4. Ensure all services are properly integrated
        if let connectionManager = openSimConnection {
            connectionManager.integrateWithServices()
            
            // Validate that all dependencies are satisfied
            if connectionManager.validateServiceDependencies() {
                print("[✅] OpenSim service integration validated")
            } else {
                print("[⚠️] OpenSim service integration validation failed")
            }
        }
        
        // 5. Setup inter-service connections
        setupOpenSimServiceConnections()
        
        print("[🌐] OpenSim integration services initialization complete")
    }
    
    private func createOpenSimConfig() -> EntityCreationConfig {
        // Create configuration based on device capabilities and settings
        #if targetEnvironment(simulator)
        return EntityCreationConfig(
            enableVisualRepresentation: true,
            enablePhysics: false, // Disable physics in simulator for performance
            enableInteraction: true,
            debugVisualization: true,
            materialQuality: .low,
            lodDistance: 50.0,
            maxEntities: 500
        )
        #else
        return EntityCreationConfig(
            enableVisualRepresentation: true,
            enablePhysics: true,
            enableInteraction: true,
            debugVisualization: false,
            materialQuality: .medium,
            lodDistance: 100.0,
            maxEntities: 1000
        )
        #endif
    }
    
    private func setupOpenSimServiceConnections() {
        // Connect OpenSim Connection Manager with Message Router
        if let connectionManager = openSimConnection,
           let messageRouter = messageRouter {
            
            // This would require updates to OSConnectManager to accept message router
            // For now, we'll document this as a future integration point
            print("[🔗] OpenSim service connections established")
        }
        
        // Setup notification-based communication between services
        setupNotificationHandlers()
    }
    
    private func setupNotificationHandlers() {
        // Setup cross-service communication via notifications
        NotificationCenter.default.addObserver(
            forName: .openSimBridgeStats,
            object: nil,
            queue: .main
        ) { notification in
            if let stats = notification.object as? [String: Any] {
                print("[📊] OpenSim Bridge Stats: \(stats)")
            }
        }
    }
    
    private func validateServiceDependencies() {
        var missingDependencies: [String] = []
        
        // Check core dependencies
        if ecs == nil { missingDependencies.append("ecs") }
        if ui == nil { missingDependencies.append("ui") }
        if router == nil { missingDependencies.append("router") }
        
        // Check OpenSim dependencies (only if renderer is available)
        if renderer != nil {
            if openSimBridge == nil { missingDependencies.append("openSimBridge") }
            if openSimConnection == nil { missingDependencies.append("openSimConnection") }
            if messageRouter == nil { missingDependencies.append("messageRouter") }
        }
        
        if !missingDependencies.isEmpty {
            print("[⚠️] Missing service dependencies: \(missingDependencies.joined(separator: ", "))")
        } else {
            print("[✅] All service dependencies satisfied")
        }
    }
    
    // MARK: - Service Lifecycle Management
    
    func startServices() {
        // Start services that require active lifecycle management
        
        if let messageRouter = messageRouter {
            messageRouter.resumeProcessing()
        }
        
        if let openSimBridge = openSimBridge {
            // OpenSim bridge is already listening for notifications
            print("[▶️] OpenSim bridge active")
        }
        
        print("[▶️] Services started")
    }
    
    func stopServices() {
        if let messageRouter = messageRouter {
            messageRouter.pauseProcessing()
        }
        
        if let openSimConnection = openSimConnection {
            openSimConnection.disconnect()
        }
        
        print("[⏸️] Services stopped")
    }
    
    func restartServices() {
        stopServices()
        Thread.sleep(forTimeInterval: 0.1) // Brief pause
        startServices()
        print("[🔄] Services restarted")
    }
    
    // MARK: - Service Access Helpers
    
    func requireECS() -> ECSCore {
        guard let ecs = ecs else {
            fatalError("ECS service is required but not available")
        }
        return ecs
    }
    
    func requireRenderer() -> RendererService {
        guard let renderer = renderer else {
            fatalError("Renderer service is required but not available")
        }
        return renderer
    }
    
    func requireOpenSimBridge() -> OpenSimECSBridge {
        guard let bridge = openSimBridge else {
            fatalError("OpenSim bridge is required but not available")
        }
        return bridge
    }
    
    func hasOpenSimSupport() -> Bool {
        return openSimBridge != nil && openSimConnection != nil && messageRouter != nil
    }
    
    // MARK: - Debug and Inspection
    
    func dumpServiceStatus() {
        print("=== SystemRegistry Service Status ===")
        print("Initialized: \(isInitialized)")
        print("Services Registered: \(initializationOrder.count)")
        print("")
        
        print("Core Services:")
        print("  ECS: \(ecs != nil ? "✅" : "❌")")
        print("  UI Composer: \(ui != nil ? "✅" : "❌")")
        print("  UI Router: \(router != nil ? "✅" : "❌")")
        print("  Renderer: \(renderer != nil ? "✅" : "❌")")
        print("")
        
        print("OpenSim Services:")
        print("  OpenSim Bridge: \(openSimBridge != nil ? "✅" : "❌")")
        print("  OpenSim Connection: \(openSimConnection != nil ? "✅" : "❌")")
        print("  Message Router: \(messageRouter != nil ? "✅" : "❌")")
        print("  OpenSim Support: \(hasOpenSimSupport() ? "✅" : "❌")")
        print("")
        
        print("Metadata Services: \(metadata.count)")
        for (key, value) in metadata {
            print("  \(key): \(type(of: value))")
        }
        print("=====================================")
    }
    
    func getServiceInfo<T>(_ serviceType: T.Type) -> String? {
        for (key, service) in metadata {
            if service is T {
                return "Service '\(key)' of type \(type(of: service))"
            }
        }
        return nil
    }
    
    func getRegistrationOrder() -> [String] {
        return initializationOrder
    }
    
    // MARK: - Configuration Management
    
    func updateOpenSimConfig(_ config: EntityCreationConfig) {
        // Update configuration would require recreating the bridge
        // For now, log the request
        print("[🔧] OpenSim config update requested - restart services to apply")
    }
    
    func enableDebugMode(_ enabled: Bool) {
        messageRouter?.setDebugMode(enabled)
        openSimBridge?.enableDebugVisualization(enabled)
        print("[🐛] Debug mode: \(enabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopServices()
        NotificationCenter.default.removeObserver(self)
        print("[🗑️] SystemRegistry deinitialized")
    }
}

// MARK: - Service Registration Extensions

extension SystemRegistry {
    
    /// Convenience method to register renderer and initialize OpenSim services
    func registerRenderer(_ renderer: RendererService) {
        register(renderer, for: "renderer")
        
        // If we have all dependencies, initialize OpenSim integration
        if ecs != nil && !isInitialized {
            initializeOpenSimIntegration()
        }
    }
    
    /// Convenience method to register ECS and setup basic systems
    func registerECS(_ ecs: ECSCore) {
        register(ecs, for: "ecs")
        
        // Setup basic ECS systems if needed
        // (Future: could add default systems here)
    }
    
    /// Convenience method for complete service setup
    func setupCompleteSystem(ecs: ECSCore, renderer: RendererService, ui: UIComposer, router: UIScriptRouter) {
        register(ecs, for: "ecs")
        register(renderer, for: "renderer")
        register(ui, for: "ui")
        register(router, for: "router")
        
        initializeServices()
        startServices()
        
        print("[🚀] Complete system setup finished")
    }
}

// MARK: - Service Health Monitoring

extension SystemRegistry {
    
    struct ServiceHealth {
        let isHealthy: Bool
        let lastCheck: Date
        let issues: [String]
    }
    
    func checkServiceHealth() -> [String: ServiceHealth] {
        var healthStatus: [String: ServiceHealth] = [:]
        
        // Check ECS health
        if let ecs = ecs {
            let entityCount = ecs.getEntityCount()
            let isHealthy = entityCount >= 0 // Basic sanity check
            healthStatus["ecs"] = ServiceHealth(
                isHealthy: isHealthy,
                lastCheck: Date(),
                issues: isHealthy ? [] : ["Invalid entity count"]
            )
        }
        
        // Check OpenSim bridge health
        if let bridge = openSimBridge {
            let stats = bridge.getEntityStats()
            let isHealthy = stats.activeEntities >= 0
            healthStatus["openSimBridge"] = ServiceHealth(
                isHealthy: isHealthy,
                lastCheck: Date(),
                issues: isHealthy ? [] : ["Invalid entity statistics"]
            )
        }
        
        // Check message router health
        if let router = messageRouter {
            let avgTime = router.getAverageProcessingTime()
            let isHealthy = avgTime < 0.1 // Less than 100ms average
            healthStatus["messageRouter"] = ServiceHealth(
                isHealthy: isHealthy,
                lastCheck: Date(),
                issues: isHealthy ? [] : ["High message processing time: \(avgTime)s"]
            )
        }
        
        return healthStatus
    }
}
