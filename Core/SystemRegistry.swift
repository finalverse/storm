//
//  Core/SystemRegistry.swift
//  Storm
//
//  Central service registry and dependency injection container
//  Manages all system services and their dependencies
//  UPDATED: Removed UIScriptRouter dependency, routing now handled by UIComposer
//
//  Created by Wenyan Qin on 2025-07-15.
//

import Foundation
import SwiftUI

// MARK: - ServiceMetadata

struct ServiceMetadata {
    let name: String
    let type: Any.Type
    let dependencies: [String]
    let priority: Int
    
    init<T>(name: String, type: T.Type, dependencies: [String] = [], priority: Int = 100) {
        self.name = name
        self.type = type
        self.dependencies = dependencies
        self.priority = priority
    }
}

// MARK: - ServiceHealth

struct ServiceHealth {
    let isHealthy: Bool
    let issues: [String]
    let lastChecked: Date
    
    init(isHealthy: Bool, issues: [String] = []) {
        self.isHealthy = isHealthy
        self.issues = issues
        self.lastChecked = Date()
    }
}

// MARK: - SystemRegistry

final class SystemRegistry: ObservableObject {
    
    // MARK: - Core Services (Always Available)
    
    private(set) var ecs: ECSCore?
    private(set) var ui: UIComposer?
    
    // MARK: - Optional Services (Platform/Feature Dependent)
    
    private(set) var renderer: RendererService?
    private(set) var openSimBridge: OpenSimECSBridge?
    private(set) var openSimConnection: OSConnectManager?
    private(set) var messageRouter: OSMessageRouter?
    
    // MARK: - Service Management
    
    private var metadata: [String: Any] = [:]
    private var serviceMetadata: [String: ServiceMetadata] = [:]
    private var initializationOrder: [String] = []
    private var isInitialized = false
    private var isDebugMode = false
    
    // MARK: - Singleton
    
    static let shared = SystemRegistry()
    
    init() {
        print("[🔧] SystemRegistry initialized")
    }
    
    // MARK: - Service Registration
    
    func register<T>(_ service: T, for key: String, metadata: ServiceMetadata? = nil) {
        self.metadata[key] = service
        
        if let meta = metadata {
            serviceMetadata[key] = meta
        }
        
        if !initializationOrder.contains(key) {
            initializationOrder.append(key)
        }
        
        // Update specific service references for type safety
        updateServiceReferences(key: key, service: service)
        
        print("[✅] Registered service: \(key) (\(type(of: service)))")
    }
    
    /// Special registration method for ECS (foundation service)
    func registerECS(_ ecsService: ECSCore) {
        register(ecsService, for: "ecs")
        print("[🏗️] ECS Core registered as foundation service")
    }
    
    /// Special registration method for Renderer
    func registerRenderer(_ rendererService: RendererService) {
        register(rendererService, for: "renderer")
        
        // Initialize OpenSim services now that renderer is available
        if !hasOpenSimSupport() {
            enableOpenSimSupport()
        }
        
        print("[🎨] Renderer registered - OpenSim services available")
    }
    
    private func updateServiceReferences<T>(key: String, service: T) {
        switch key {
        case "ecs":
            if let ecsService = service as? ECSCore {
                self.ecs = ecsService
            }
        case "ui":
            if let uiService = service as? UIComposer {
                self.ui = uiService
            }
        case "renderer":
            if let rendererService = service as? RendererService {
                self.renderer = rendererService
            }
        case "openSimBridge":
            if let bridgeService = service as? OpenSimECSBridge {
                self.openSimBridge = bridgeService
            }
        case "openSimConnection":
            if let connectionService = service as? OSConnectManager {
                self.openSimConnection = connectionService
            }
        case "messageRouter":
            if let routerService = service as? OSMessageRouter {
                self.messageRouter = routerService
            }
        default:
            // Store in metadata but don't maintain specific reference
            break
        }
    }
    
    // MARK: - Service Resolution
    
    func resolve<T>(_ key: String) -> T? {
        return metadata[key] as? T
    }
    
    func resolve<T>(_ type: T.Type) -> T? {
        for (_, service) in metadata {
            if let typedService = service as? T {
                return typedService
            }
        }
        return nil
    }
    
    // MARK: - Type-Safe Service Access
    
    func requireECS() -> ECSCore {
        guard let ecs = ecs else {
            fatalError("ECS service is required but not available")
        }
        return ecs
    }
    
    func requireUI() -> UIComposer {
        guard let ui = ui else {
            fatalError("UI service is required but not available")
        }
        return ui
    }
    
    // MARK: - Service Initialization
    
    func initializeCore() {
        guard !isInitialized else {
            print("[⚠️] SystemRegistry already initialized")
            return
        }
        
        // Initialize core services in dependency order
        initializeECS()
        initializeUI()
        
        isInitialized = true
        print("[✅] Core services initialized")
    }
    
    private func initializeECS() {
        if ecs == nil {
            let ecsCore = ECSCore()
            register(ecsCore, for: "ecs")
        }
    }
    
    private func initializeUI() {
        if ui == nil {
            let uiComposer = UIComposer(systemRegistry: self)
            register(uiComposer, for: "ui")
        }
    }
    
    // MARK: - Service Lifecycle Management
    
    func startServices() {
        print("[▶️] Starting registered services...")
        
        // Start services in initialization order
        for serviceKey in initializationOrder {
            if let service = metadata[serviceKey] {
                startService(key: serviceKey, service: service)
            }
        }
        
        print("[✅] All services started")
    }
    
    func stopServices() {
        print("[⏹️] Stopping registered services...")
        
        // Stop services in reverse order
        for serviceKey in initializationOrder.reversed() {
            if let service = metadata[serviceKey] {
                stopService(key: serviceKey, service: service)
            }
        }
        
        print("[✅] All services stopped")
    }
    
    private func startService(key: String, service: Any) {
        // Check if service has a start method and call it
        if let startableService = service as? any ServiceLifecycle {
            startableService.start()
            print("[▶️] Started service: \(key)")
        }
    }
    
    private func stopService(key: String, service: Any) {
        // Check if service has a stop method and call it
        if let stoppableService = service as? any ServiceLifecycle {
            stoppableService.stop()
            print("[⏹️] Stopped service: \(key)")
        }
    }
    
    // MARK: - Optional Service Management
    
    func enableOpenSimSupport() {
        print("[🌐] Enabling OpenSim support...")
        
        // Initialize OpenSim services if dependencies are available
        guard let ecs = ecs else {
            print("[❌] Cannot enable OpenSim: ECS not available")
            return
        }
        
        // Initialize message router
        if messageRouter == nil {
            let router = OSMessageRouter()
            register(router, for: "messageRouter")
        }
        
        // Initialize connection manager
        if openSimConnection == nil {
            let connection = OSConnectManager(systemRegistry: self)
            register(connection, for: "openSimConnection")
        }
        
        // Initialize ECS bridge
        if openSimBridge == nil {
            let bridge = OpenSimECSBridge(ecs: ecs)
            register(bridge, for: "openSimBridge")
        }
        
        print("[✅] OpenSim support enabled")
    }
    
    func enableRenderer(_ rendererService: RendererService) {
        register(rendererService, for: "renderer")
        print("[🎨] Renderer service registered")
    }
    
    // MARK: - Service Status and Health
    
    func hasOpenSimSupport() -> Bool {
        return openSimBridge != nil && openSimConnection != nil && messageRouter != nil
    }
    
    func isServiceAvailable(_ key: String) -> Bool {
        return metadata[key] != nil
    }
    
    func checkServiceHealth() -> [String: ServiceHealth] {
        var healthStatus: [String: ServiceHealth] = [:]
        
        // Check core services
        healthStatus["ecs"] = checkECSHealth()
        healthStatus["ui"] = checkUIHealth()
        
        // Check optional services
        if renderer != nil {
            healthStatus["renderer"] = checkRendererHealth()
        }
        
        if hasOpenSimSupport() {
            healthStatus["openSimBridge"] = checkOpenSimBridgeHealth()
            healthStatus["openSimConnection"] = checkOpenSimConnectionHealth()
            healthStatus["messageRouter"] = checkMessageRouterHealth()
        }
        
        return healthStatus
    }
    
    private func checkECSHealth() -> ServiceHealth {
        guard let ecs = ecs else {
            return ServiceHealth(isHealthy: false, issues: ["ECS service not available"])
        }
        
        let entityCount = ecs.getEntityCount()
        var issues: [String] = []
        
        if entityCount > 10000 {
            issues.append("High entity count (\(entityCount))")
        }
        
        return ServiceHealth(isHealthy: issues.isEmpty, issues: issues)
    }
    
    private func checkUIHealth() -> ServiceHealth {
        guard let ui = ui else {
            return ServiceHealth(isHealthy: false, issues: ["UI service not available"])
        }
        
        // Basic UI health checks
        let activeSchemas = ui.getActiveSchemaNames()
        var issues: [String] = []
        
        if activeSchemas.isEmpty {
            issues.append("No active UI schemas")
        }
        
        return ServiceHealth(isHealthy: issues.isEmpty, issues: issues)
    }
    
    private func checkRendererHealth() -> ServiceHealth {
        guard let renderer = renderer else {
            return ServiceHealth(isHealthy: false, issues: ["Renderer service not available"])
        }
        
        // Basic renderer health checks would go here
        return ServiceHealth(isHealthy: true)
    }
    
    private func checkOpenSimBridgeHealth() -> ServiceHealth {
        guard let bridge = openSimBridge else {
            return ServiceHealth(isHealthy: false, issues: ["OpenSim bridge not available"])
        }
        
        let stats = bridge.getEntityStats()
        var issues: [String] = []
        
        if stats.activeEntities > 1000 {
            issues.append("High OpenSim entity count (\(stats.activeEntities))")
        }
        
        return ServiceHealth(isHealthy: issues.isEmpty, issues: issues)
    }
    
    private func checkOpenSimConnectionHealth() -> ServiceHealth {
        guard let connection = openSimConnection else {
            return ServiceHealth(isHealthy: false, issues: ["OpenSim connection not available"])
        }
        
        var issues: [String] = []
        
        if !connection.isConnected {
            issues.append("OpenSim not connected")
        }
        
        if connection.latency > 200 {
            issues.append("High latency (\(connection.latency)ms)")
        }
        
        return ServiceHealth(isHealthy: issues.isEmpty, issues: issues)
    }
    
    private func checkMessageRouterHealth() -> ServiceHealth {
        guard let router = messageRouter else {
            return ServiceHealth(isHealthy: false, issues: ["Message router not available"])
        }
        
        let avgTime = router.getAverageProcessingTime()
        var issues: [String] = []
        
        if avgTime > 0.1 {
            issues.append("Slow message processing (\(avgTime * 1000)ms)")
        }
        
        return ServiceHealth(isHealthy: issues.isEmpty, issues: issues)
    }
    
    // MARK: - Service Initialization and Dependencies
    
    func initializeServices() {
        print("[🔧] Initializing all registered services...")
        
        // Initialize services that have initialization methods
        for (key, service) in metadata {
            if let initializableService = service as? any ServiceInitializable {
                initializableService.initialize()
                print("[✅] Initialized service: \(key)")
            }
        }
        
        print("[✅] Service initialization complete")
    }
    
    // MARK: - Debug and Development
    
    func enableDebugMode(_ enabled: Bool) {
        isDebugMode = enabled
        
        // Enable debug mode on services that support it
        if let bridge = openSimBridge {
            bridge.enableDebugVisualization(enabled)
        }
        
        if let router = messageRouter {
            router.setDebugMode(enabled)
        }
        
        print("[🐛] Debug mode: \(enabled ? "Enabled" : "Disabled")")
    }
    
    func dumpServiceStatus() {
        print("=== SystemRegistry Service Status ===")
        print("Initialized: \(isInitialized)")
        print("Debug Mode: \(isDebugMode)")
        print("Total Services: \(metadata.count)")
        print("")
        
        print("Core Services:")
        print("  ECS: \(ecs != nil ? "✅" : "❌")")
        print("  UI: \(ui != nil ? "✅" : "❌")")
        print("")
        
        print("Optional Services:")
        print("  Renderer: \(renderer != nil ? "✅" : "❌")")
        print("  OpenSim Bridge: \(openSimBridge != nil ? "✅" : "❌")")
        print("  OpenSim Connection: \(openSimConnection != nil ? "✅" : "❌")")
        print("  Message Router: \(messageRouter != nil ? "✅" : "❌")")
        print("")
        
        print("All Registered Services:")
        for (key, service) in metadata {
            print("  \(key): \(type(of: service))")
        }
        
        print("")
        print("Service Health:")
        let healthStatus = checkServiceHealth()
        for (service, health) in healthStatus {
            let status = health.isHealthy ? "✅" : "❌"
            print("  \(status) \(service)")
            if !health.issues.isEmpty {
                for issue in health.issues {
                    print("    - \(issue)")
                }
            }
        }
        
        print("=====================================")
    }
    
    func reset() {
        metadata.removeAll()
        serviceMetadata.removeAll()
        initializationOrder.removeAll()
        
        ecs = nil
        ui = nil
        renderer = nil
        openSimBridge = nil
        openSimConnection = nil
        messageRouter = nil
        
        isInitialized = false
        isDebugMode = false
        print("[🔄] SystemRegistry reset")
    }
    
    // MARK: - Service Dependencies
    
    func getDependencies(for serviceKey: String) -> [String] {
        return serviceMetadata[serviceKey]?.dependencies ?? []
    }
    
    func validateDependencies() -> [String: [String]] {
        var missingDependencies: [String: [String]] = [:]
        
        for (serviceKey, metadata) in serviceMetadata {
            let missing = metadata.dependencies.filter { !isServiceAvailable($0) }
            if !missing.isEmpty {
                missingDependencies[serviceKey] = missing
            }
        }
        
        return missingDependencies
    }
    
    // MARK: - Service Access Convenience Methods
    
    func getECS() -> ECSCore? {
        return ecs
    }
    
    func getUI() -> UIComposer? {
        return ui
    }
    
    func getRenderer() -> RendererService? {
        return renderer
    }
    
    func getOpenSimBridge() -> OpenSimECSBridge? {
        return openSimBridge
    }
    
    func getOpenSimConnection() -> OSConnectManager? {
        return openSimConnection
    }
    
    func getMessageRouter() -> OSMessageRouter? {
        return messageRouter
    }
}

// MARK: - Service Lifecycle Protocols

/// Protocol for services that need explicit start/stop lifecycle management
protocol ServiceLifecycle {
    func start()
    func stop()
}

/// Protocol for services that need initialization after registration
protocol ServiceInitializable {
    func initialize()
}

// MARK: - Extensions

extension SystemRegistry {
    
    /// Get service by type (convenience method)
    func get<T>(_ type: T.Type) -> T? {
        return resolve(type)
    }
    
    /// Check if a service type is registered
    func has<T>(_ type: T.Type) -> Bool {
        return resolve(type) != nil
    }
    
    /// Get all services of a specific type
    func getAll<T>(_ type: T.Type) -> [T] {
        return metadata.values.compactMap { $0 as? T }
    }
    
    /// Get service count
    var serviceCount: Int {
        return metadata.count
    }
    
    /// Get all service keys
    var serviceKeys: [String] {
        return Array(metadata.keys)
    }
}

// MARK: - SystemRegistry Factory

extension SystemRegistry {
    
    /// Create a pre-configured SystemRegistry for testing
    static func createTestRegistry() -> SystemRegistry {
        let registry = SystemRegistry()
        
        // Initialize with mock services for testing
        let mockECS = ECSCore()
        registry.registerECS(mockECS)
        
        let mockUI = UIComposer(systemRegistry: registry)
        registry.register(mockUI, for: "ui")
        
        registry.initializeCore()
        
        print("[🧪] Test SystemRegistry created")
        return registry
    }
    
    /// Create a minimal SystemRegistry with only core services
    static func createMinimalRegistry() -> SystemRegistry {
        let registry = SystemRegistry()
        registry.initializeCore()
        print("[⚡] Minimal SystemRegistry created")
        return registry
    }
}
