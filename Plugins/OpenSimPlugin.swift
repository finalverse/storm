//
//  Plugins/OpenSimPlugin.swift
//  Storm
//
//  Complete OpenSim integration plugin with enhanced architecture
//  Combines connection management, scene coordination, and UI integration
//  Follows Storm's clean plugin pattern with proper service separation
//
//  Created for Finalverse Storm - Unified OpenSim Architecture

import Foundation
import simd
import RealityKit

// MARK: - Enhanced OpenSim Plugin (Consolidated)

final class OpenSimPlugin: StormPlugin {
    
    // MARK: - Service Components (Separated by Concern)
    private weak var registry: SystemRegistry?
    private var connectManager: OSConnectManager?
    private var sceneManager: LocalSceneManager?
    private var ecsBridge: OpenSimECSBridge?
    
    // MARK: - Sub-Services (Clean Separation)
    private var connectionService: OpenSimConnectionService!
    private var sceneService: OpenSimSceneService!
    private var uiService: OpenSimUIService!
    private var healthService: OpenSimHealthService!
    
    // MARK: - Plugin State
    private var isSetupComplete = false
    private var lastUpdateTime: Date = Date()
    
    // MARK: - Configuration
    private let defaultServer = "127.0.0.1"
    private let defaultPort: UInt16 = 9000
    
    // MARK: - StormPlugin Implementation
    
    func setup(registry: SystemRegistry) {
        print("[🌐] OpenSimPlugin (Enhanced) setting up...")
        self.registry = registry
        
        // Phase 1: Initialize core services with clean separation
        setupCoreServices(registry)
        
        // Phase 2: Initialize specialized sub-services
        setupSubServices(registry)
        
        // Phase 3: Register UI command handlers
        setupUIIntegration(registry)
        
        // Phase 4: Validate complete integration
        validateIntegration()
        
        isSetupComplete = true
        print("[✅] OpenSimPlugin (Enhanced) setup complete")
    }
    
    func update(deltaTime: TimeInterval) {
        guard isSetupComplete else { return }
        
        // Update all sub-services
        connectionService.update(deltaTime)
        sceneService.update(deltaTime)
        uiService.update(deltaTime)
        healthService.update(deltaTime)
        
        lastUpdateTime = Date()
    }
    
    // MARK: - Core Service Setup (Streamlined)
    
    private func setupCoreServices(_ registry: SystemRegistry) {
        print("[🔧] Setting up core OpenSim services...")
        
        // 1. Initialize OSConnectManager
        connectManager = OSConnectManager(systemRegistry: registry)
        connectManager?.setSystemRegistry(registry)
        registry.register(connectManager!, for: "openSimConnection")
        
        // 2. Initialize LocalSceneManager
        sceneManager = LocalSceneManager()
        sceneManager?.setup(registry: registry)
        registry.register(sceneManager!, for: "localSceneManager")
        
        // 3. Setup ECS Bridge
        if let ecs = registry.ecs {
            ecsBridge = OpenSimECSBridge(ecs: ecs)
            registry.register(ecsBridge!, for: "openSimBridge")
            connectManager?.registerECSBridge(ecsBridge!)
        }
        
        // 4. Register self as main OpenSim service
        registry.register(self, for: "openSimPlugin")
        
        print("[✅] Core OpenSim services initialized")
    }
    
    private func setupSubServices(_ registry: SystemRegistry) {
        print("[🔧] Setting up OpenSim sub-services...")
        
        // Connection Service - Handles all connection logic
        connectionService = OpenSimConnectionService(
            connectManager: connectManager,
            sceneManager: sceneManager
        )
        
        // Scene Service - Handles scene synchronization
        sceneService = OpenSimSceneService(
            sceneManager: sceneManager,
            connectManager: connectManager,
            ecsBridge: ecsBridge
        )
        
        // UI Service - Handles all UI interactions
        uiService = OpenSimUIService(
            connectionService: connectionService,
            sceneService: sceneService
        )
        
        // Health Service - Monitors all service health
        healthService = OpenSimHealthService(
            connectManager: connectManager,
            sceneManager: sceneManager,
            ecsBridge: ecsBridge
        )
        
        print("[✅] OpenSim sub-services initialized")
    }
    
    private func setupUIIntegration(_ registry: SystemRegistry) {
        guard let composer = registry.getUI() else {
            print("[⚠️] UIComposer not available")
            return
        }
        
        // Register command namespaces with proper routing
        composer.registerActionHandler(namespace: "opensim") { [weak self] command, args in
            self?.uiService.handleOpenSimCommand(command: command, args: args)
        }
        
        composer.registerActionHandler(namespace: "scene") { [weak self] command, args in
            self?.uiService.handleSceneCommand(command: command, args: args)
        }
        
        composer.registerActionHandler(namespace: "avatar") { [weak self] command, args in
            self?.uiService.handleAvatarCommand(command: command, args: args)
        }
        
        print("[🎯] OpenSim UI commands registered")
    }
    
    private func validateIntegration() {
        let services = [
            ("ConnectionService", connectionService != nil),
            ("SceneService", sceneService != nil),
            ("UIService", uiService != nil),
            ("HealthService", healthService != nil),
            ("ConnectManager", connectManager != nil),
            ("SceneManager", sceneManager != nil),
            ("ECSBridge", ecsBridge != nil)
        ]
        
        let allValid = services.allSatisfy { $0.1 }
        
        for (name, isValid) in services {
            print("[🔍] \(name): \(isValid ? "✅" : "❌")")
        }
        
        if allValid {
            print("[✅] OpenSim integration validation successful")
        } else {
            print("[❌] OpenSim integration validation failed")
        }
    }
    
    // MARK: - Public Interface (Simplified)
    
    func connectToServer(hostname: String = "127.0.0.1", port: UInt16 = 9000) {
        connectionService.connectToServer(hostname: hostname, port: port)
    }
    
    func disconnectFromServer() {
        connectionService.disconnectFromServer()
    }
    
    func performLogin(firstName: String, lastName: String, password: String = "") {
        connectionService.performLogin(firstName: firstName, lastName: lastName, password: password)
    }
    
    func getConnectionStatus() -> OpenSimLoginState {
        return connectionService.getLoginState()
    }
    
    func getServerInfo() -> OpenSimServerInfo? {
        return connectionService.getServerInfo()
    }
    
    func isReadyForAvatarControl() -> Bool {
        return connectionService.isReadyForAvatarControl()
    }
    
    func teleportAvatar(to position: SIMD3<Float>) {
        sceneService.teleportAvatar(to: position)
    }
    
    func getServiceHealth() -> [String: Bool] {
        return healthService.getHealthReport()
    }
}

// MARK: - Connection Service (Separated Concern)

class OpenSimConnectionService {
    private weak var connectManager: OSConnectManager?
    private weak var sceneManager: LocalSceneManager?
    
    private var loginState: OpenSimLoginState = .disconnected
    private var serverInfo: OpenSimServerInfo?
    
    init(connectManager: OSConnectManager?, sceneManager: LocalSceneManager?) {
        self.connectManager = connectManager
        self.sceneManager = sceneManager
    }
    
    func update(_ deltaTime: TimeInterval) {
        updateConnectionMonitoring()
        updateServerInfo()
    }
    
    func connectToServer(hostname: String, port: UInt16) {
        guard let connectManager = connectManager else {
            print("[❌] OSConnectManager not available")
            return
        }
        
        print("[🔌] Connecting to OpenSim server: \(hostname):\(port)")
        loginState = .connecting
        
        connectManager.connect(to: hostname, port: port)
        sceneManager?.prepareForOpenSimConnection()
    }
    
    func disconnectFromServer() {
        connectManager?.disconnect()
        loginState = .disconnected
        serverInfo = nil
        sceneManager?.disconnectFromOpenSim()
    }
    
    func performLogin(firstName: String, lastName: String, password: String) {
        guard loginState == .connected else {
            print("[⚠️] Cannot login: not connected to server")
            return
        }
        
        print("[👤] Performing login for \(firstName) \(lastName)")
        loginState = .authenticating
        
        // OpenSim handshake is handled by OSConnectManager
        // We track state and create local representation
        createLocalAvatarRepresentation(firstName: firstName, lastName: lastName)
    }
    
    private func createLocalAvatarRepresentation(firstName: String, lastName: String) {
        // Delegate to scene service for avatar creation
        // This ensures proper separation of concerns
    }
    
    private func updateConnectionMonitoring() {
        guard let connectManager = connectManager else { return }
        
        let currentlyConnected = connectManager.isConnected
        
        switch (loginState, currentlyConnected) {
        case (.connecting, true):
            loginState = .connected
            
        case (.connected, false), (.authenticating, false), (.loggedIn, false):
            loginState = .disconnected
            
        case (.authenticating, true):
            if connectManager.validateServiceDependencies() {
                loginState = .loggedIn
                completeLoginProcess()
            }
            
        default:
            break
        }
    }
    
    private func completeLoginProcess() {
        // Sync with scene manager
        if let connectManager = connectManager, let sceneManager = sceneManager {
            let sessionInfo = connectManager.getSessionInfo()
            let spawnPosition = SIMD3<Float>(128, 25, 128)
            
            sceneManager.synchronizeWithOpenSim(
                agentID: sessionInfo.agentID,
                sessionID: sessionInfo.sessionID,
                serverPosition: spawnPosition
            )
        }
    }
    
    private func updateServerInfo() {
        if loginState == .loggedIn, let connectManager = connectManager {
            let stats = connectManager.getConnectionStats()
            let sessionInfo = connectManager.getSessionInfo()
            
            serverInfo = OpenSimServerInfo(
                agentID: sessionInfo.agentID,
                sessionID: sessionInfo.sessionID,
                circuitCode: sessionInfo.circuitCode,
                connectionStats: stats,
                isConnected: connectManager.isConnected
            )
        }
    }
    
    func getLoginState() -> OpenSimLoginState { return loginState }
    func getServerInfo() -> OpenSimServerInfo? { return serverInfo }
    func isReadyForAvatarControl() -> Bool {
        return loginState == .loggedIn && connectManager?.isConnected == true
    }
}

// MARK: - Scene Service (Separated Concern)

class OpenSimSceneService {
    private weak var sceneManager: LocalSceneManager?
    private weak var connectManager: OSConnectManager?
    private weak var ecsBridge: OpenSimECSBridge?
    
    init(sceneManager: LocalSceneManager?, connectManager: OSConnectManager?, ecsBridge: OpenSimECSBridge?) {
        self.sceneManager = sceneManager
        self.connectManager = connectManager
        self.ecsBridge = ecsBridge
    }
    
    func update(_ deltaTime: TimeInterval) {
        synchronizeSceneState()
    }
    
    func teleportAvatar(to position: SIMD3<Float>) {
        // Update both local scene and OpenSim
        sceneManager?.teleportAvatar(to: position)
        connectManager?.teleportAvatar(to: position)
    }
    
    func setCameraMode(_ mode: CameraMode) {
        sceneManager?.setCameraMode(mode)
    }
    
    func setEnvironmentLighting(_ lighting: EnvironmentLighting) {
        sceneManager?.setEnvironmentLighting(lighting)
    }
    
    private func synchronizeSceneState() {
        guard let sceneManager = sceneManager, let connectManager = connectManager else { return }
        
        let isConnected = connectManager.isConnected
        let currentSceneState = sceneManager.sceneState
        
        switch (isConnected, currentSceneState) {
        case (true, .localOnly):
            sceneManager.prepareForOpenSimConnection()
        case (false, .synchronized):
            sceneManager.disconnectFromOpenSim()
        default:
            break
        }
    }
}

// MARK: - UI Service (Separated Concern)

class OpenSimUIService {
    private weak var connectionService: OpenSimConnectionService?
    private weak var sceneService: OpenSimSceneService?
    
    init(connectionService: OpenSimConnectionService?, sceneService: OpenSimSceneService?) {
        self.connectionService = connectionService
        self.sceneService = sceneService
    }
    
    func update(_ deltaTime: TimeInterval) {
        // Update UI state based on services
    }
    
    func handleOpenSimCommand(command: String, args: [String]) {
        switch command {
        case "connect":
            let hostname = args.first ?? "127.0.0.1"
            let port = UInt16(args.count > 1 ? args[1] : "9000") ?? 9000
            connectionService?.connectToServer(hostname: hostname, port: port)
            
        case "disconnect":
            connectionService?.disconnectFromServer()
            
        case "login":
            if args.count >= 2 {
                connectionService?.performLogin(firstName: args[0], lastName: args[1], password: args.count > 2 ? args[2] : "")
            }
            
        case "status":
            logConnectionStatus()
            
        default:
            print("[❌] Unknown OpenSim command: \(command)")
        }
    }
    
    func handleSceneCommand(command: String, args: [String]) {
        switch command {
        case "camera":
            if let modeString = args.first, let mode = CameraMode(rawValue: modeString) {
                sceneService?.setCameraMode(mode)
            }
            
        case "lighting":
            if let lightingString = args.first, let lighting = EnvironmentLighting(rawValue: lightingString) {
                sceneService?.setEnvironmentLighting(lighting)
            }
            
        default:
            print("[❌] Unknown scene command: \(command)")
        }
    }
    
    func handleAvatarCommand(command: String, args: [String]) {
        switch command {
        case "teleport":
            if args.count >= 3,
               let x = Float(args[0]),
               let y = Float(args[1]),
               let z = Float(args[2]) {
                sceneService?.teleportAvatar(to: SIMD3<Float>(x, y, z))
            }
            
        default:
            print("[❌] Unknown avatar command: \(command)")
        }
    }
    
    private func logConnectionStatus() {
        if let connectionService = connectionService {
            let state = connectionService.getLoginState()
            let isReady = connectionService.isReadyForAvatarControl()
            
            print("[📊] === OpenSim Status ===")
            print("[🔗] Login State: \(state.rawValue)")
            print("[✅] Ready for Avatar Control: \(isReady)")
            print("[==========================]")
        }
    }
}

// MARK: - Health Service (Separated Concern)

class OpenSimHealthService {
    private weak var connectManager: OSConnectManager?
    private weak var sceneManager: LocalSceneManager?
    private weak var ecsBridge: OpenSimECSBridge?
    
    private var lastHealthCheck: Date = Date()
    private let healthCheckInterval: TimeInterval = 5.0
    
    init(connectManager: OSConnectManager?, sceneManager: LocalSceneManager?, ecsBridge: OpenSimECSBridge?) {
        self.connectManager = connectManager
        self.sceneManager = sceneManager
        self.ecsBridge = ecsBridge
    }
    
    func update(_ deltaTime: TimeInterval) {
        let now = Date()
        if now.timeIntervalSince(lastHealthCheck) >= healthCheckInterval {
            performHealthCheck()
            lastHealthCheck = now
        }
    }
    
    private func performHealthCheck() {
        let report = getHealthReport()
        let unhealthyServices = report.filter { !$0.value }
        
        if !unhealthyServices.isEmpty {
            print("[⚠️] Health issues detected: \(unhealthyServices.keys.joined(separator: ", "))")
        }
    }
    
    func getHealthReport() -> [String: Bool] {
        return [
            "connectManager": connectManager != nil,
            "sceneManager": sceneManager != nil && sceneManager?.sceneState != .error,
            "ecsBridge": ecsBridge != nil,
            "connection": connectManager?.isConnected ?? false
        ]
    }
}
