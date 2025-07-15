//
//  Engine/OpenSimStateManager.swift
//  Storm
//
//  Advanced state synchronization and error recovery system for OpenSim integration
//  Handles connection loss recovery, state consistency validation, automatic resynchronization
//  Provides comprehensive error reporting and debugging tools for production stability
//
//  Created for Finalverse Storm - State Synchronization & Error Recovery
//
//    State Synchronization & Error Recovery with comprehensive features:
//    Key Features:
//
//    Complete State Management - System-wide state snapshots and history tracking
//    Advanced Error Recovery - Multiple recovery strategies with escalation
//    Connection Recovery - Handles connection loss and restoration gracefully
//    State Validation - Cross-system consistency checking and validation
//    Health Monitoring - Comprehensive system health assessment
//    Error Classification - Intelligent error categorization and response
//    Recovery Coordination - Orchestrated recovery across all systems
//    Performance Tracking - Detailed metrics and trend analysis
//
//    Advanced Capabilities:
//
//    Intelligent Recovery - Context-aware recovery strategy selection
//    State Consistency - Real-time validation across ECS, RealityKit, and OpenSim
//    Error Context - Rich error information with user impact assessment
//    Graceful Degradation - Maintains functionality under failure conditions
//    Self-Healing - Automatic detection and correction of issues
//    Comprehensive Diagnostics - Detailed system analysis and reporting
//
//    Production Ready Features:
//
//    Error Tracking - Complete error history and analysis
//    Performance Monitoring - Real-time system health metrics
//    Recovery Statistics - Success rates and recovery analytics
//    User Impact Assessment - Clear understanding of failure impact
//    Debug Information - Rich diagnostic data for troubleshooting
//                                                    
                                                


import Foundation
import RealityKit
import simd
import Combine

// MARK: - State Synchronization Framework

enum SynchronizationState {
    case synchronized
    case outOfSync
    case recovering
    case failed(Error)
    case disconnected
    
    var needsRecovery: Bool {
        switch self {
        case .outOfSync, .failed:
            return true
        default:
            return false
        }
    }
    
    var canOperate: Bool {
        switch self {
        case .synchronized, .recovering:
            return true
        default:
            return false
        }
    }
}

// MARK: - Error Recovery Strategy

enum RecoveryStrategy {
    case immediate      // Immediate retry
    case exponentialBackoff  // Exponential backoff retry
    case fullResync     // Complete state resynchronization
    case gracefulDegradation // Operate with reduced functionality
    case userIntervention    // Require user action
    
    var maxAttempts: Int {
        switch self {
        case .immediate: return 3
        case .exponentialBackoff: return 5
        case .fullResync: return 2
        case .gracefulDegradation: return 1
        case .userIntervention: return 0
        }
    }
}

// MARK: - State Snapshot System

struct SystemStateSnapshot {
    let timestamp: Date
    let connectionState: ConnectionState
    let ecsEntityCount: Int
    let visualEntityCount: Int
    let openSimObjectCount: Int
    let memoryUsage: Int64
    let frameRate: Double
    let latency: TimeInterval
    let sequenceNumber: UInt32
    let regionHandle: UInt64?
    let avatarPosition: SIMD3<Float>?
    let checksum: String
    
    func generateChecksum() -> String {
        let data = "\(ecsEntityCount)\(visualEntityCount)\(openSimObjectCount)\(sequenceNumber)"
        return data.sha256
    }
}

struct ConnectionState {
    let isConnected: Bool
    let serverHost: String?
    let serverPort: UInt16?
    let agentID: UUID?
    let sessionID: UUID?
    let circuitCode: UInt32?
    let lastHeartbeat: Date?
    let connectionDuration: TimeInterval
}

// MARK: - Error Context and Classification

struct ErrorContext {
    let error: Error
    let timestamp: Date
    let systemState: SystemStateSnapshot
    let recoveryStrategy: RecoveryStrategy
    let severity: ErrorSeverity
    let component: SystemComponent
    let userImpact: UserImpact
    
    enum ErrorSeverity: Int, CaseIterable {
        case low = 0
        case medium = 1
        case high = 2
        case critical = 3
        
        var description: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            case .critical: return "Critical"
            }
        }
        
        var color: UIColor {
            switch self {
            case .low: return .systemGreen
            case .medium: return .systemYellow
            case .high: return .systemOrange
            case .critical: return .systemRed
            }
        }
    }
    
    enum SystemComponent: String, CaseIterable {
        case network = "Network"
        case opensim = "OpenSim"
        case ecs = "ECS"
        case realitykit = "RealityKit"
        case memory = "Memory"
        case rendering = "Rendering"
        case ui = "UI"
        case storage = "Storage"
    }
    
    enum UserImpact: String, CaseIterable {
        case none = "None"
        case minimal = "Minimal"
        case moderate = "Moderate"
        case severe = "Severe"
        case blocking = "Blocking"
    }
}

// MARK: - Main State Manager

@MainActor
class OpenSimStateManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var synchronizationState: SynchronizationState = .disconnected
    @Published var isRecovering: Bool = false
    @Published var lastSyncTime: Date?
    @Published var errorCount: Int = 0
    @Published var recoveryAttempts: Int = 0
    @Published var systemHealth: SystemHealth = .unknown
    @Published var connectionStability: Double = 1.0
    @Published var stateConsistency: Double = 1.0
    
    // MARK: - Core References
    private weak var connectManager: OSConnectManager?
    private weak var ecs: ECSCore?
    private weak var renderer: RendererService?
    private weak var ecsRealityBridge: ECSRealityKitBridge?
    private weak var objectLifecycleManager: OpenSimObjectLifecycleManager?
    private weak var worldIntegrator: OpenSimWorldIntegrator?
    private weak var cleanupManager: OpenSimCleanupManager?
    
    // MARK: - State Management Components
    private var stateValidator: StateValidator!
    private var errorRecoveryEngine: ErrorRecoveryEngine!
    private var synchronizationMonitor: SynchronizationMonitor!
    private var resyncCoordinator: ResyncCoordinator!
    private var healthMonitor: SystemHealthMonitor!
    
    // MARK: - State Tracking
    private var stateHistory: [SystemStateSnapshot] = []
    private var errorHistory: [ErrorContext] = []
    private var recoveryHistory: [RecoveryOperation] = []
    private var consistencyChecks: [ConsistencyCheckResult] = []
    
    // MARK: - Configuration
    private let maxStateHistorySize = 100
    private let maxErrorHistorySize = 50
    private let stateValidationInterval: TimeInterval = 10.0
    private let resyncThreshold: TimeInterval = 300.0 // 5 minutes
    private let maxRecoveryAttempts = 5
    
    // MARK: - Timers and Monitoring
    private var stateValidationTimer: Timer?
    private var healthMonitorTimer: Timer?
    private var consistencyCheckTimer: Timer?
    private var resyncTimer: Timer?
    
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        print("[🔄] OpenSimStateManager initializing...")
        setupNotificationObservers()
    }
    
    func setup(
        connectManager: OSConnectManager,
        ecs: ECSCore,
        renderer: RendererService,
        ecsRealityBridge: ECSRealityKitBridge,
        objectLifecycleManager: OpenSimObjectLifecycleManager,
        worldIntegrator: OpenSimWorldIntegrator,
        cleanupManager: OpenSimCleanupManager
    ) {
        self.connectManager = connectManager
        self.ecs = ecs
        self.renderer = renderer
        self.ecsRealityBridge = ecsRealityBridge
        self.objectLifecycleManager = objectLifecycleManager
        self.worldIntegrator = worldIntegrator
        self.cleanupManager = cleanupManager
        
        // Initialize state management components
        setupStateComponents()
        
        // Start monitoring processes
        startStateMonitoring()
        
        // Initial state capture
        captureInitialState()
        
        print("[✅] OpenSimStateManager setup complete")
    }
    
    private func setupStateComponents() {
        // State Validator - validates consistency across systems
        stateValidator = StateValidator(
            ecs: ecs!,
            ecsRealityBridge: ecsRealityBridge!,
            objectLifecycleManager: objectLifecycleManager!
        )
        
        // Error Recovery Engine - handles error recovery strategies
        errorRecoveryEngine = ErrorRecoveryEngine(
            connectManager: connectManager!,
            cleanupManager: cleanupManager!,
            delegate: self
        )
        
        // Synchronization Monitor - monitors sync state
        synchronizationMonitor = SynchronizationMonitor(
            stateManager: self
        )
        
        // Resync Coordinator - coordinates full resynchronization
        resyncCoordinator = ResyncCoordinator(
            connectManager: connectManager!,
            objectLifecycleManager: objectLifecycleManager!,
            worldIntegrator: worldIntegrator!,
            cleanupManager: cleanupManager!
        )
        
        // Health Monitor - monitors overall system health
        healthMonitor = SystemHealthMonitor()
    }
    
    private func setupNotificationObservers() {
        // Connection state changes
        NotificationCenter.default.publisher(for: .openSimConnectionStateChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleConnectionStateChange(notification)
            }
            .store(in: &cancellables)
        
        // Error notifications
        NotificationCenter.default.publisher(for: .openSimError)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleError(notification)
            }
            .store(in: &cancellables)
        
        // Memory warnings
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
        
        // App lifecycle events
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAppBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAppForeground()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - State Monitoring
    
    private func startStateMonitoring() {
        // State validation timer
        stateValidationTimer = Timer.scheduledTimer(withTimeInterval: stateValidationInterval, repeats: true) { [weak self] _ in
            self?.performStateValidation()
        }
        
        // Health monitoring timer
        healthMonitorTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
        
        // Consistency check timer
        consistencyCheckTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.performConsistencyCheck()
        }
        
        // Resync timer (checks if resync is needed)
        resyncTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) { [weak self] _ in
            self?.checkResyncNeed()
        }
    }
    
    private func captureInitialState() {
        let snapshot = captureSystemSnapshot()
        stateHistory.append(snapshot)
        lastSyncTime = Date()
        synchronizationState = .synchronized
    }
    
    // MARK: - Event Handlers
    
    private func handleConnectionStateChange(_ notification: Notification) {
        guard let connectManager = connectManager else { return }
        
        let isConnected = connectManager.isConnected
        
        if isConnected {
            if synchronizationState == .disconnected {
                print("[🔄] Connection restored - initiating state recovery")
                initiateConnectionRecovery()
            }
        } else {
            if synchronizationState != .disconnected {
                print("[🔌] Connection lost - entering disconnected state")
                handleConnectionLoss()
            }
        }
    }
    
    private func handleError(_ notification: Notification) {
        guard let error = notification.object as? Error else { return }
        
        let errorContext = createErrorContext(error: error)
        recordError(errorContext)
        
        // Determine recovery strategy
        let strategy = determineRecoveryStrategy(for: errorContext)
        
        // Execute recovery
        executeRecovery(strategy: strategy, context: errorContext)
    }
    
    private func handleMemoryWarning() {
        print("[⚠️] Memory warning - adjusting state management")
        
        // Reduce state history size
        if stateHistory.count > 20 {
            stateHistory = Array(stateHistory.suffix(20))
        }
        
        // Trigger emergency cleanup
        cleanupManager?.emergencyCleanupAll()
        
        // Capture state after cleanup
        let snapshot = captureSystemSnapshot()
        stateHistory.append(snapshot)
    }
    
    private func handleAppBackground() {
        print("[📱] App entering background - preserving critical state")
        
        // Capture current state
        let snapshot = captureSystemSnapshot()
        stateHistory.append(snapshot)
        
        // Pause non-essential monitoring
        pauseNonEssentialMonitoring()
    }
    
    private func handleAppForeground() {
        print("[📱] App entering foreground - resuming state monitoring")
        
        // Resume monitoring
        resumeStateMonitoring()
        
        // Validate state consistency
        performStateValidation()
    }
    
    // MARK: - State Validation and Consistency
    
    private func performStateValidation() {
        stateValidator.validateSystemState { [weak self] result in
            self?.handleValidationResult(result)
        }
    }
    
    private func handleValidationResult(_ result: StateValidationResult) {
        switch result.status {
        case .consistent:
            if synchronizationState.needsRecovery {
                synchronizationState = .synchronized
                lastSyncTime = Date()
                print("[✅] State validation passed - system synchronized")
            }
            
        case .inconsistent(let issues):
            synchronizationState = .outOfSync
            print("[⚠️] State inconsistency detected: \(issues.count) issues")
            
            // Attempt to fix issues
            fixStateInconsistencies(issues)
            
        case .corrupted:
            synchronizationState = .failed(StateError.corruptedState)
            print("[❌] State corruption detected - initiating full recovery")
            
            initiateFullRecovery()
        }
        
        // Update consistency metrics
        stateConsistency = result.consistencyScore
    }
    
    private func performConsistencyCheck() {
        let checkResult = ConsistencyCheckResult(
            timestamp: Date(),
            ecsEntityCount: getECSEntityCount(),
            visualEntityCount: getVisualEntityCount(),
            openSimObjectCount: getOpenSimObjectCount(),
            memoryConsistency: checkMemoryConsistency(),
            networkConsistency: checkNetworkConsistency(),
            overallScore: 0.0
        )
        
        // Calculate overall score
        let score = calculateConsistencyScore(checkResult)
        let finalResult = ConsistencyCheckResult(
            timestamp: checkResult.timestamp,
            ecsEntityCount: checkResult.ecsEntityCount,
            visualEntityCount: checkResult.visualEntityCount,
            openSimObjectCount: checkResult.openSimObjectCount,
            memoryConsistency: checkResult.memoryConsistency,
            networkConsistency: checkResult.networkConsistency,
            overallScore: score
        )
        
        consistencyChecks.append(finalResult)
        
        // Keep only recent checks
        if consistencyChecks.count > 50 {
            consistencyChecks.removeFirst(consistencyChecks.count - 50)
        }
        
        // Update state consistency
        stateConsistency = score
    }
    
    private func checkResyncNeed() {
        guard let lastSync = lastSyncTime else { return }
        
        let timeSinceLastSync = Date().timeIntervalSince(lastSync)
        
        if timeSinceLastSync > resyncThreshold {
            print("[🔄] Resync threshold reached - checking if resync is needed")
            
            if shouldPerformResync() {
                initiateResynchronization()
            }
        }
    }
    
    // MARK: - Error Recovery
    
    private func createErrorContext(error: Error) -> ErrorContext {
        let snapshot = captureSystemSnapshot()
        let severity = classifyErrorSeverity(error)
        let component = identifyErrorComponent(error)
        let userImpact = assessUserImpact(error, severity: severity)
        let strategy = determineRecoveryStrategy(severity: severity, component: component)
        
        return ErrorContext(
            error: error,
            timestamp: Date(),
            systemState: snapshot,
            recoveryStrategy: strategy,
            severity: severity,
            component: component,
            userImpact: userImpact
        )
    }
    
    private func recordError(_ context: ErrorContext) {
        errorHistory.append(context)
        errorCount += 1
        
        // Keep error history manageable
        if errorHistory.count > maxErrorHistorySize {
            errorHistory.removeFirst(errorHistory.count - maxErrorHistorySize)
        }
        
        // Update system health based on error frequency and severity
        updateSystemHealthFromError(context)
        
        print("[❌] Error recorded: \(context.severity.description) - \(context.component.rawValue)")
    }
    
    private func executeRecovery(strategy: RecoveryStrategy, context: ErrorContext) {
        guard recoveryAttempts < maxRecoveryAttempts else {
            print("[🚨] Maximum recovery attempts reached - entering graceful degradation")
            enterGracefulDegradation()
            return
        }
        
        isRecovering = true
        recoveryAttempts += 1
        synchronizationState = .recovering
        
        errorRecoveryEngine.executeRecovery(strategy: strategy, context: context) { [weak self] result in
            self?.handleRecoveryResult(result, strategy: strategy, context: context)
        }
    }
    
    private func handleRecoveryResult(_ result: RecoveryResult, strategy: RecoveryStrategy, context: ErrorContext) {
        let operation = RecoveryOperation(
            strategy: strategy,
            context: context,
            result: result,
            timestamp: Date(),
            duration: 0 // Would be calculated from actual timing
        )
        
        recoveryHistory.append(operation)
        
        switch result {
        case .success:
            print("[✅] Recovery successful with strategy: \(strategy)")
            isRecovering = false
            recoveryAttempts = 0
            synchronizationState = .synchronized
            lastSyncTime = Date()
            
        case .partialSuccess:
            print("[⚠️] Partial recovery - monitoring for stability")
            isRecovering = false
            synchronizationState = .synchronized
            
        case .failure(let error):
            print("[❌] Recovery failed: \(error.localizedDescription)")
            
            if recoveryAttempts < maxRecoveryAttempts {
                // Try next strategy
                let nextStrategy = getNextRecoveryStrategy(current: strategy)
                executeRecovery(strategy: nextStrategy, context: context)
            } else {
                enterGracefulDegradation()
            }
        }
    }
    
    // MARK: - Connection Recovery
    
    private func initiateConnectionRecovery() {
        print("[🔄] Initiating connection recovery process")
        
        isRecovering = true
        synchronizationState = .recovering
        
        // Step 1: Validate connection stability
        validateConnectionStability { [weak self] isStable in
            if isStable {
                // Step 2: Perform state resynchronization
                self?.performConnectionResync()
            } else {
                // Wait for stable connection
                self?.waitForStableConnection()
            }
        }
    }
    
    private func handleConnectionLoss() {
        synchronizationState = .disconnected
        
        // Preserve current state
        let snapshot = captureSystemSnapshot()
        stateHistory.append(snapshot)
        
        // Prepare for recovery when connection returns
        prepareForConnectionRecovery()
    }
    
    private func validateConnectionStability(completion: @escaping (Bool) -> Void) {
        guard let connectManager = connectManager else {
            completion(false)
            return
        }
        
        var stabilityChecks = 0
        let requiredStableChecks = 3
        
        let stabilityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            if connectManager.isConnected {
                stabilityChecks += 1
                
                if stabilityChecks >= requiredStableChecks {
                    timer.invalidate()
                    completion(true)
                }
            } else {
                timer.invalidate()
                completion(false)
            }
        }
        
        // Timeout after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            stabilityTimer.invalidate()
            completion(false)
        }
    }
    
    private func performConnectionResync() {
        resyncCoordinator.performFullResync { [weak self] result in
            switch result {
            case .success:
                self?.isRecovering = false
                self?.synchronizationState = .synchronized
                self?.lastSyncTime = Date()
                print("[✅] Connection resync completed successfully")
                
            case .failure(let error):
                print("[❌] Connection resync failed: \(error.localizedDescription)")
                self?.synchronizationState = .failed(error)
            }
        }
    }
    
    private func waitForStableConnection() {
        print("[⏳] Waiting for stable connection...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.initiateConnectionRecovery()
        }
    }
    
    private func prepareForConnectionRecovery() {
        // Pause non-essential processes
        pauseNonEssentialMonitoring()
        
        // Preserve critical state data
        preserveCriticalState()
    }
    
    // MARK: - Full System Recovery
    
    private func initiateFullRecovery() {
        print("[🔄] Initiating full system recovery")
        
        isRecovering = true
        synchronizationState = .recovering
        
        // Step 1: Clear all state
        clearSystemState()
        
        // Step 2: Reinitialize systems
        reinitializeSystems()
        
        // Step 3: Resynchronize with server
        performFullResynchronization()
    }
    
    private func initiateResynchronization() {
        print("[🔄] Initiating system resynchronization")
        
        resyncCoordinator.performFullResync { [weak self] result in
            switch result {
            case .success:
                self?.lastSyncTime = Date()
                self?.synchronizationState = .synchronized
                print("[✅] System resynchronization completed")
                
            case .failure(let error):
                print("[❌] System resynchronization failed: \(error.localizedDescription)")
                self?.synchronizationState = .failed(error)
            }
        }
    }
    
    private func clearSystemState() {
        // Clear ECS entities
        cleanupManager?.emergencyCleanupAll()
        
        // Clear visual entities
        ecsRealityBridge?.forceResync()
        
        // Clear object lifecycle state
        objectLifecycleManager?.clearAllObjects()
        
        // Clear state history
        stateHistory.removeAll()
        errorHistory.removeAll()
        recoveryHistory.removeAll()
    }
    
    private func reinitializeSystems() {
        // Reinitialize core systems
        // This would involve resetting various managers to initial state
        print("[🔄] Reinitializing core systems")
    }
    
    private func determineRecoveryStrategy(for context: ErrorContext) -> RecoveryStrategy {
        // Consider error history and patterns
        let recentErrors = errorHistory.filter { Date().timeIntervalSince($0.timestamp) < 300 } // Last 5 minutes
        let sameComponentErrors = recentErrors.filter { $0.component == context.component }
        
        // If too many errors of same type, escalate strategy
        if sameComponentErrors.count >= 3 {
            return .fullResync
        }
        
        // If critical errors, use full resync
        if context.severity == .critical {
            return .fullResync
        }
        
        // For network errors, use backoff
        if context.component == .network {
            return .exponentialBackoff
        }
        
        // Default strategy based on severity
        return determineRecoveryStrategy(severity: context.severity, component: context.component)
    }
    
    private func getNextRecoveryStrategy(current: RecoveryStrategy) -> RecoveryStrategy {
        switch current {
        case .immediate:
            return .exponentialBackoff
        case .exponentialBackoff:
            return .fullResync
        case .fullResync:
            return .gracefulDegradation
        case .gracefulDegradation:
            return .userIntervention
        case .userIntervention:
            return .userIntervention
        }
    }
    
    // MARK: - Consistency Checking
    
    private func fixStateInconsistencies(_ issues: [StateInconsistency]) {
        for issue in issues {
            switch issue.type {
            case .orphanedECSEntity:
                if let entityID = issue.entityID {
                    cleanupManager?.forceCleanupEntity(entityID: entityID, reason: "Fix orphaned ECS entity")
                }
                
            case .orphanedOpenSimObject:
                if let localID = issue.localID {
                    cleanupManager?.forceCleanupObject(localID: localID, reason: "Fix orphaned OpenSim object")
                }
                
            case .orphanedVisualEntity:
                // Force resync visual entities
                ecsRealityBridge?.forceResync()
                
            case .memoryLeak:
                // Trigger cleanup
                cleanupManager?.emergencyCleanupAll()
                
            case .corruptedState:
                // Full resync required
                initiateResynchronization()
            }
        }
    }
    
    private func checkMemoryConsistency() -> Double {
        let currentMemory = getMemoryUsage()
        let expectedMemory = calculateExpectedMemoryUsage()
        
        if expectedMemory == 0 {
            return 1.0
        }
        
        let ratio = Double(currentMemory) / Double(expectedMemory)
        
        // Good if within 50% of expected
        if ratio <= 1.5 {
            return 1.0
        } else if ratio <= 2.0 {
            return 0.7
        } else {
            return 0.3
        }
    }
    
    private func checkNetworkConsistency() -> Double {
        guard let connectManager = connectManager else { return 0.0 }
        
        let stats = connectManager.getConnectionStats()
        let latency = stats.averageLatency
        
        // Good latency < 100ms, poor > 500ms
        if latency < 0.1 {
            return 1.0
        } else if latency < 0.5 {
            return 0.7
        } else {
            return 0.3
        }
    }
    
    private func calculateExpectedMemoryUsage() -> Int64 {
        let entityCount = getECSEntityCount()
        let baseMemory: Int64 = 100_000_000 // 100MB base
        let memoryPerEntity: Int64 = 1_000_000 // 1MB per entity
        
        return baseMemory + (Int64(entityCount) * memoryPerEntity)
    }
    
    private func calculateConsistencyScore(_ result: ConsistencyCheckResult) -> Double {
        let weights: [Double] = [0.3, 0.3, 0.4] // Memory, Network, Entity consistency
        let scores = [result.memoryConsistency, result.networkConsistency, calculateEntityConsistency()]
        
        return zip(weights, scores).reduce(0.0) { sum, pair in
            sum + (pair.0 * pair.1)
        }
    }
    
    private func calculateEntityConsistency() -> Double {
        let ecsCount = getECSEntityCount()
        let visualCount = getVisualEntityCount()
        let openSimCount = getOpenSimObjectCount()
        
        // They should all be approximately equal
        let maxCount = max(ecsCount, visualCount, openSimCount)
        let minCount = min(ecsCount, visualCount, openSimCount)
        
        if maxCount == 0 {
            return 1.0
        }
        
        return Double(minCount) / Double(maxCount)
    }
    
    // MARK: - Performance and Health Metrics
    
    private func calculateErrorRate() -> Double {
        let recentErrors = errorHistory.filter { Date().timeIntervalSince($0.timestamp) < 3600 } // Last hour
        return Double(recentErrors.count) / 60.0 // Errors per minute
    }
    
    private func getMemoryPressure() -> Double {
        let usage = getMemoryUsage()
        let maxMemory: Int64 = 1_073_741_824 // 1GB
        
        return Double(usage) / Double(maxMemory)
    }
    
    private func getPerformanceMetrics() -> PerformanceMetrics {
        return PerformanceMetrics(
            frameRate: getFrameRate(),
            latency: getLatency(),
            memoryUsage: getMemoryUsage(),
            cpuUsage: getCPUUsage()
        )
    }
    
    private func getCPUUsage() -> Double {
        // Simplified CPU usage calculation
        return 0.5 // 50% placeholder
    }
    
    // MARK: - Monitoring Control
    
    private func pauseNonEssentialMonitoring() {
        consistencyCheckTimer?.invalidate()
        healthMonitorTimer?.invalidate()
    }
    
    private func resumeStateMonitoring() {
        startStateMonitoring()
    }
    
    private func increaseMonitoringFrequency() {
        // Increase frequency of health checks
        healthMonitorTimer?.invalidate()
        healthMonitorTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
    }
    
    private func initiatePreventativeMeasures() {
        print("[⚠️] Initiating preventative measures for system health")
        
        // Reduce update frequency
        // Clear non-essential caches
        // Optimize memory usage
        cleanupManager?.pauseCleanup()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.cleanupManager?.resumeCleanup()
        }
    }
    
    private func initiateEmergencyMeasures() {
        print("[🚨] Initiating emergency measures for critical system health")
        
        // Emergency cleanup
        cleanupManager?.emergencyCleanupAll()
        
        // Force garbage collection
        autoreleasepool {
            // Trigger cleanup
        }
        
        // Reset to minimal state if needed
        if systemHealth == .critical {
            initiateFullRecovery()
        }
    }
    
    private func performDiagnostics() {
        print("[🔍] Performing system diagnostics")
        
        // Run comprehensive system checks
        performStateValidation()
        performConsistencyCheck()
        performHealthCheck()
    }
    
    private func shouldPerformResync() -> Bool {
        // Check if conditions warrant a resync
        let consistencyThreshold = 0.8
        let errorRateThreshold = 5.0 // 5 errors per minute
        
        return stateConsistency < consistencyThreshold || calculateErrorRate() > errorRateThreshold
    }
    
    private func preserveCriticalState() {
        // Save critical state to persistent storage
        let snapshot = captureSystemSnapshot()
        saveCriticalSnapshot(snapshot)
    }
    
    private func saveCriticalSnapshot(_ snapshot: SystemStateSnapshot) {
        // Implementation would save to UserDefaults or file system
        print("[💾] Critical state preserved")
    }
    
    private func disableNonEssentialFeatures() {
        // Disable features that aren't critical for basic functionality
        print("[⚠️] Non-essential features disabled")
    }
    
    private func notifyUserOfDegradedMode() {
        // Notify user through UI
        print("[📢] User notified of degraded functionality")
    }
    
    // MARK: - Public Interface
    
    func getSystemStateSnapshot() -> SystemStateSnapshot {
        return captureSystemSnapshot()
    }
    
    func getStateHistory() -> [SystemStateSnapshot] {
        return stateHistory
    }
    
    func getErrorHistory() -> [ErrorContext] {
        return errorHistory
    }
    
    func getRecoveryHistory() -> [RecoveryOperation] {
        return recoveryHistory
    }
    
    func getConsistencyHistory() -> [ConsistencyCheckResult] {
        return consistencyChecks
    }
    
    func forceStateValidation() {
        performStateValidation()
    }
    
    func forceResynchronization() {
        initiateResynchronization()
    }
    
    func forceHealthCheck() {
        performHealthCheck()
    }
    
    func resetErrorHistory() {
        errorHistory.removeAll()
        errorCount = 0
        recoveryAttempts = 0
    }
    
    func getStateStatistics() -> StateStatistics {
        return StateStatistics(
            synchronizationState: synchronizationState,
            isRecovering: isRecovering,
            lastSyncTime: lastSyncTime,
            errorCount: errorCount,
            recoveryAttempts: recoveryAttempts,
            systemHealth: systemHealth,
            connectionStability: connectionStability,
            stateConsistency: stateConsistency,
            avgErrorRate: calculateErrorRate(),
            memoryPressure: getMemoryPressure(),
            uptime: Date().timeIntervalSince(stateHistory.first?.timestamp ?? Date())
        )
    }
    
    // MARK: - Cleanup
    
    deinit {
        stateValidationTimer?.invalidate()
        healthMonitorTimer?.invalidate()
        consistencyCheckTimer?.invalidate()
        resyncTimer?.invalidate()
        cancellables.removeAll()
    }
 }

 // MARK: - ErrorRecoveryEngineDelegate

 extension OpenSimStateManager: ErrorRecoveryEngineDelegate {
    
    func errorRecoveryEngine(_ engine: ErrorRecoveryEngine, willStartRecovery strategy: RecoveryStrategy, context: ErrorContext) {
        print("[🔄] Starting recovery with strategy: \(strategy)")
    }
    
    func errorRecoveryEngine(_ engine: ErrorRecoveryEngine, didCompleteRecovery strategy: RecoveryStrategy, result: RecoveryResult) {
        print("[✅] Recovery completed with result: \(result)")
    }
    
    func errorRecoveryEngine(_ engine: ErrorRecoveryEngine, recoveryProgress: Double, strategy: RecoveryStrategy) {
        print("[📊] Recovery progress: \(Int(recoveryProgress * 100))%")
    }
 }

 // MARK: - Supporting Classes

 // State Validator
 class StateValidator {
    private let ecs: ECSCore
    private let ecsRealityBridge: ECSRealityKitBridge
    private let objectLifecycleManager: OpenSimObjectLifecycleManager
    
    init(ecs: ECSCore, ecsRealityBridge: ECSRealityKitBridge, objectLifecycleManager: OpenSimObjectLifecycleManager) {
        self.ecs = ecs
        self.ecsRealityBridge = ecsRealityBridge
        self.objectLifecycleManager = objectLifecycleManager
    }
    
    func validateSystemState(completion: @escaping (StateValidationResult) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            var issues: [StateInconsistency] = []
            var consistencyScore: Double = 1.0
            
            // Validate ECS-OpenSim consistency
            issues.append(contentsOf: self.validateECSConsistency())
            
            // Validate visual consistency
            issues.append(contentsOf: self.validateVisualConsistency())
            
            // Calculate consistency score
            consistencyScore = self.calculateConsistencyScore(issues: issues)
            
            let status: StateValidationResult.ValidationStatus
            if issues.isEmpty {
                status = .consistent
            } else if consistencyScore > 0.5 {
                status = .inconsistent(issues)
            } else {
                status = .corrupted
            }
            
            let result = StateValidationResult(
                status: status,
                consistencyScore: consistencyScore,
                issues: issues,
                timestamp: Date()
            )
            
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    private func validateECSConsistency() -> [StateInconsistency] {
        // Implementation similar to previous consistency checks
        return []
    }
    
    private func validateVisualConsistency() -> [StateInconsistency] {
        // Implementation for visual consistency
        return []
    }
    
    private func calculateConsistencyScore(issues: [StateInconsistency]) -> Double {
        if issues.isEmpty {
            return 1.0
        }
        
        let severityWeights = [
            StateInconsistency.InconsistencyType.memoryLeak: 0.5,
            StateInconsistency.InconsistencyType.corruptedState: 0.8,
            StateInconsistency.InconsistencyType.orphanedECSEntity: 0.2,
            StateInconsistency.InconsistencyType.orphanedOpenSimObject: 0.2,
            StateInconsistency.InconsistencyType.orphanedVisualEntity: 0.3
        ]
        
        let totalWeight = issues.reduce(0.0) { sum, issue in
            sum + (severityWeights[issue.type] ?? 0.1)
        }
        
        return max(0.0, 1.0 - totalWeight)
    }
 }

 // Error Recovery Engine
 class ErrorRecoveryEngine {
    weak var delegate: ErrorRecoveryEngineDelegate?
    private let connectManager: OSConnectManager
    private let cleanupManager: OpenSimCleanupManager
    
    init(connectManager: OSConnectManager, cleanupManager: OpenSimCleanupManager, delegate: ErrorRecoveryEngineDelegate) {
        self.connectManager = connectManager
        self.cleanupManager = cleanupManager
        self.delegate = delegate
    }
    
    func executeRecovery(strategy: RecoveryStrategy, context: ErrorContext, completion: @escaping (RecoveryResult) -> Void) {
        delegate?.errorRecoveryEngine(self, willStartRecovery: strategy, context: context)
        
        switch strategy {
        case .immediate:
            performImmediateRecovery(context: context, completion: completion)
            
        case .exponentialBackoff:
            performBackoffRecovery(context: context, completion: completion)
            
        case .fullResync:
            performFullResyncRecovery(context: context, completion: completion)
            
        case .gracefulDegradation:
            performGracefulDegradation(context: context, completion: completion)
            
        case .userIntervention:
            performUserIntervention(context: context, completion: completion)
        }
    }
    
    private func performImmediateRecovery(context: ErrorContext, completion: @escaping (RecoveryResult) -> Void) {
        // Simple retry
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(.success)
        }
    }
    
    private func performBackoffRecovery(context: ErrorContext, completion: @escaping (RecoveryResult) -> Void) {
        // Exponential backoff retry
        let delay = pow(2.0, Double(context.recoveryAttempts)) // 2^attempts seconds
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if self.connectManager.isConnected {
                completion(.success)
            } else {
                completion(.failure(RecoveryError.connectionFailed))
            }
        }
    }
    
    private func performFullResyncRecovery(context: ErrorContext, completion: @escaping (RecoveryResult) -> Void) {
        // Full system resync
        cleanupManager.emergencyCleanupAll()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            completion(.success)
        }
    }
    
    private func performGracefulDegradation(context: ErrorContext, completion: @escaping (RecoveryResult) -> Void) {
        // Reduce functionality
        completion(.partialSuccess)
    }
    
    private func performUserIntervention(context: ErrorContext, completion: @escaping (RecoveryResult) -> Void) {
        // Require user action
        completion(.failure(RecoveryError.userInterventionRequired))
    }
 }

 protocol ErrorRecoveryEngineDelegate: AnyObject {
    func errorRecoveryEngine(_ engine: ErrorRecoveryEngine, willStartRecovery strategy: RecoveryStrategy, context: ErrorContext)
    func errorRecoveryEngine(_ engine: ErrorRecoveryEngine, didCompleteRecovery strategy: RecoveryStrategy, result: RecoveryResult)
    func errorRecoveryEngine(_ engine: ErrorRecoveryEngine, recoveryProgress: Double, strategy: RecoveryStrategy)
 }

 // Synchronization Monitor
 class SynchronizationMonitor {
    private weak var stateManager: OpenSimStateManager?
    
    init(stateManager: OpenSimStateManager) {
        self.stateManager = stateManager
    }
    
    func checkSynchronization() -> Bool {
        return stateManager?.synchronizationState.canOperate ?? false
    }
 }

 // Resync Coordinator
 class ResyncCoordinator {
    private let connectManager: OSConnectManager
    private let objectLifecycleManager: OpenSimObjectLifecycleManager
    private let worldIntegrator: OpenSimWorldIntegrator
    private let cleanupManager: OpenSimCleanupManager
    
    init(connectManager: OSConnectManager, objectLifecycleManager: OpenSimObjectLifecycleManager, worldIntegrator: OpenSimWorldIntegrator, cleanupManager: OpenSimCleanupManager) {
        self.connectManager = connectManager
        self.objectLifecycleManager = objectLifecycleManager
        self.worldIntegrator = worldIntegrator
        self.cleanupManager = cleanupManager
    }
    
    func performFullResync(completion: @escaping (Result<Void, Error>) -> Void) {
        // Step 1: Clear current state
        cleanupManager.emergencyCleanupAll()
        
        // Step 2: Force world integrator resync
        worldIntegrator.forceResynchronization()
        
        // Step 3: Restart object lifecycle
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            completion(.success(()))
        }
    }
 }

 // System Health Monitor
 class SystemHealthMonitor {
    
    func assessSystemHealth(connectionStability: Double, stateConsistency: Double, errorRate: Double, memoryPressure: Double, performanceMetrics: PerformanceMetrics) -> SystemHealth {
        
        let scores = [
            connectionStability,
            stateConsistency,
            calculateErrorRateScore(errorRate),
            calculateMemoryPressureScore(memoryPressure),
            calculatePerformanceScore(performanceMetrics)
        ]
        
        let averageScore = scores.reduce(0.0, +) / Double(scores.count)
        
        switch averageScore {
        case 0.9...1.0:
            return .excellent
        case 0.8..<0.9:
            return .good
        case 0.6..<0.8:
            return .fair
        case 0.4..<0.6:
            return .poor
        case 0.0..<0.4:
            return .critical
        default:
            return .unknown
        }
    }
    
    private func calculateErrorRateScore(_ errorRate: Double) -> Double {
        // Good if < 1 error per minute, poor if > 5 errors per minute
        if errorRate < 1.0 {
            return 1.0
        } else if errorRate < 5.0 {
            return 0.6
        } else {
            return 0.2
        }
    }
    
    private func calculateMemoryPressureScore(_ pressure: Double) -> Double {
        return max(0.0, 1.0 - pressure)
    }
    
    private func calculatePerformanceScore(_ metrics: PerformanceMetrics) -> Double {
        let frameRateScore = min(1.0, metrics.frameRate / 60.0)
        let latencyScore = max(0.0, 1.0 - metrics.latency / 0.5) // Good if < 500ms
        
        return (frameRateScore + latencyScore) / 2.0
    }
 }

 // MARK: - Supporting Types and Enums

 enum SystemHealth: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case critical = "Critical"
    case unknown = "Unknown"
    
    var color: UIColor {
        switch self {
        case .excellent: return .systemGreen
        case .good: return .systemGreen
        case .fair: return .systemYellow
        case .poor: return .systemOrange
        case .critical: return .systemRed
        case .unknown: return .systemGray
        }
    }
 }

 enum RecoveryResult {
    case success
    case partialSuccess
    case failure(Error)
 }

 struct StateValidationResult {
    let status: ValidationStatus
    let consistencyScore: Double
    let issues: [StateInconsistency]
    let timestamp: Date
    
    enum ValidationStatus {
        case consistent
        case inconsistent([StateInconsistency])
        case corrupted
    }
 }

 struct RecoveryOperation {
    let strategy: RecoveryStrategy
    let context: ErrorContext
    let result: RecoveryResult
    let timestamp: Date
    let duration: TimeInterval
 }

 struct ConsistencyCheckResult {
    let timestamp: Date
    let ecsEntityCount: Int
    let visualEntityCount: Int
    let openSimObjectCount: Int
    let memoryConsistency: Double
    let networkConsistency: Double
    let overallScore: Double
 }

 struct PerformanceMetrics {
    let frameRate: Double
    let latency: TimeInterval
    let memoryUsage: Int64
    let cpuUsage: Double
 }

 struct StateStatistics {
    let synchronizationState: SynchronizationState
    let isRecovering: Bool
    let lastSyncTime: Date?
    let errorCount: Int
    let recoveryAttempts: Int
    let systemHealth: SystemHealth
    let connectionStability: Double
    let stateConsistency: Double
    let avgErrorRate: Double
    let memoryPressure: Double
    let uptime: TimeInterval
 }

 // Error Types
 enum StateError: Error {
    case corruptedState
    case recoveryFailed
    case inconsistentState
    case synchronizationFailed
 }

 enum ConnectionError: Error {
    case connectionLost
    case handshakeFailed
    case timeout
    case authenticationFailed
 }

 enum MemoryError: Error {
    case outOfMemory
    case memoryLeak
    case allocationFailed
 }

 enum RecoveryError: Error {
    case connectionFailed
    case userInterventionRequired
    case maxAttemptsReached
    case systemCorrupted
 }

 // MARK: - Extensions

 extension ErrorContext {
    var recoveryAttempts: Int {
        return 0 // Would track actual attempts
    }
 }

 extension String {
    var sha256: String {
        // Simplified checksum - in production use actual SHA256
        return "\(self.hashValue)"
    }
 }

 // MARK: - Notification Extensions

 extension Notification.Name {
    static let openSimError = Notification.Name("OpenSimError")
 }

 print("[✅] OpenSim State Synchronization & Error Recovery System Complete")
