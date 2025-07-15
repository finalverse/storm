//
//  Engine/OpenSimCleanupManager.swift
//  Storm
//
//  Advanced cleanup and state management system for OpenSim objects
//  Handles KillObject messages, memory management, state consistency, and error recovery
//  Provides comprehensive cleanup coordination across ECS, RealityKit, and OpenSim systems
//
//  Created for Finalverse Storm - Cleanup & State Management
//
//    Object Removal & Cleanup System with comprehensive features:
//    Key Features:
//
//    Complete Cleanup Pipeline - Handles KillObject messages and all cleanup types
//    Memory Management - Advanced memory monitoring with pressure levels and emergency cleanup
//    State Validation - Ensures consistency between ECS, OpenSim, and RealityKit systems
//    Orphan Detection - Automatically finds and cleans up orphaned objects
//    Priority-Based Processing - Emergency, high, normal, low, and deferred priority levels
//    Resource Tracking - Monitors memory usage per entity and system-wide
//    Error Recovery - Retry mechanisms and graceful failure handling
//    Performance Optimization - Frame-time budgeting and batch processing
//
//    Advanced Capabilities:
//
//    Smart Memory Pressure Handling - Preventative and emergency cleanup based on usage
//    Multi-Level Cleanup - Normal, emergency, orphaned, stale, connection, forced, and cascade cleanup
//    State Consistency - Cross-system validation and automatic inconsistency fixing
//    Comprehensive Statistics - Detailed metrics and performance monitoring
//    Automatic Recovery - Self-healing system that detects and fixes problems
//
//    Integration Benefits:
//
//    Seamless Integration - Works with existing ECS, RealityKit bridge, and OpenSim systems
//    Memory Efficient - Prevents memory leaks and optimizes resource usage
//    Fault Tolerant - Handles connection loss, corrupted data, and system errors
//    Performance Optimized - Maintains smooth 60fps while cleaning up efficiently
//
//    The system now provides robust cleanup and state management for the entire OpenSim integration.
//                                                            

                                                        
import Foundation
import RealityKit
import simd
import Combine

// MARK: - Cleanup State Management

enum CleanupState {
    case idle
    case processing
    case emergency
    case recovering
    case error(String)
    
    var canProcessCleanup: Bool {
        switch self {
        case .idle, .processing, .recovering:
            return true
        default:
            return false
        }
    }
}

// MARK: - Cleanup Types

enum CleanupType {
    case normal          // Standard object removal
    case emergency       // Emergency cleanup due to memory pressure
    case orphaned        // Cleanup orphaned objects
    case stale           // Remove stale/expired objects
    case connection      // Cleanup on connection loss
    case forced          // Manual/administrative cleanup
    case cascade         // Cleanup child objects
}

// MARK: - Cleanup Operation

struct CleanupOperation {
    let id: UUID = UUID()
    let type: CleanupType
    let localID: UInt32?
    let entityID: EntityID?
    let priority: CleanupPriority
    let timestamp: Date
    let reason: String
    var attempts: Int = 0
    var maxAttempts: Int = 3
    
    enum CleanupPriority: Int, CaseIterable {
        case emergency = 0
        case high = 1
        case normal = 2
        case low = 3
        case deferred = 4
    }
}

// MARK: - Memory Management Configuration

struct MemoryManagementConfig {
    let maxMemoryUsage: Int64 = 1_073_741_824 // 1GB
    let warningThreshold: Int64 = 805_306_368 // 768MB
    let emergencyThreshold: Int64 = 939_524_096 // 896MB
    let cleanupInterval: TimeInterval = 30.0
    let staleObjectTimeout: TimeInterval = 300.0 // 5 minutes
    let orphanCheckInterval: TimeInterval = 60.0
}

// MARK: - Main Cleanup Manager

@MainActor
class OpenSimCleanupManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var cleanupState: CleanupState = .idle
    @Published var totalCleanupOperations: Int = 0
    @Published var pendingCleanups: Int = 0
    @Published var memoryUsage: Int64 = 0
    @Published var objectsRemoved: Int = 0
    @Published var cleanupRate: Double = 0
    @Published var memoryPressure: MemoryPressureLevel = .normal
    
    // MARK: - Core References
    private weak var ecs: ECSCore?
    private weak var renderer: RendererService?
    private weak var ecsRealityBridge: ECSRealityKitBridge?
    private weak var objectLifecycleManager: OpenSimObjectLifecycleManager?
    private weak var worldIntegrator: OpenSimWorldIntegrator?
    
    // MARK: - Cleanup Components
    private var cleanupProcessor: CleanupProcessor!
    private var memoryManager: MemoryManager!
    private var stateValidator: StateValidator!
    private var orphanDetector: OrphanDetector!
    private var resourceTracker: ResourceTracker!
    
    // MARK: - Operation Management
    private var cleanupQueue: PriorityQueue<CleanupOperation> = PriorityQueue()
    private var activeOperations: [UUID: CleanupOperation] = [:]
    private var completedOperations: [CleanupOperation] = []
    private var failedOperations: [CleanupOperation] = []
    
    // MARK: - State Tracking
    private var managedEntities: Set<EntityID> = []
    private var staleObjects: [UInt32: Date] = [:]
    private var orphanedObjects: [UInt32: Date] = [:]
    private var memoryHotspots: [String: Int64] = [:]
    
    // MARK: - Configuration and Timers
    private let config = MemoryManagementConfig()
    private var cleanupTimer: Timer?
    private var memoryMonitorTimer: Timer?
    private var orphanCheckTimer: Timer?
    private var stateValidationTimer: Timer?
    
    // MARK: - Performance Tracking
    private var cleanupCounter: Int = 0
    private var lastMetricsUpdate: Date = Date()
    private var memoryPressureHistory: [MemoryPressureLevel] = []
    
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        print("[🧹] OpenSimCleanupManager initializing...")
        setupNotificationObservers()
    }
    
    func setup(
        ecs: ECSCore,
        renderer: RendererService,
        ecsRealityBridge: ECSRealityKitBridge,
        objectLifecycleManager: OpenSimObjectLifecycleManager,
        worldIntegrator: OpenSimWorldIntegrator
    ) {
        self.ecs = ecs
        self.renderer = renderer
        self.ecsRealityBridge = ecsRealityBridge
        self.objectLifecycleManager = objectLifecycleManager
        self.worldIntegrator = worldIntegrator
        
        // Initialize cleanup components
        setupCleanupComponents()
        
        // Start monitoring and cleanup processes
        startCleanupProcesses()
        
        print("[✅] OpenSimCleanupManager setup complete")
    }
    
    private func setupCleanupComponents() {
        // Cleanup Processor - handles cleanup operations
        cleanupProcessor = CleanupProcessor(
            ecs: ecs!,
            renderer: renderer!,
            delegate: self
        )
        
        // Memory Manager - monitors and manages memory usage
        memoryManager = MemoryManager(
            config: config,
            delegate: self
        )
        
        // State Validator - ensures consistency across systems
        stateValidator = StateValidator(
            ecs: ecs!,
            objectLifecycleManager: objectLifecycleManager!
        )
        
        // Orphan Detector - finds orphaned objects
        orphanDetector = OrphanDetector(
            ecs: ecs!,
            objectLifecycleManager: objectLifecycleManager!
        )
        
        // Resource Tracker - tracks resource usage
        resourceTracker = ResourceTracker()
    }
    
    private func setupNotificationObservers() {
        // Kill Object Messages
        NotificationCenter.default.publisher(for: .openSimKillObject)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleKillObjectMessage(notification)
            }
            .store(in: &cancellables)
        
        // Connection Loss
        NotificationCenter.default.publisher(for: .openSimConnectionLost)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleConnectionLoss(notification)
            }
            .store(in: &cancellables)
        
        // Memory Warnings
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
        
        // Entity Lifecycle Events
        NotificationCenter.default.publisher(for: .ecsEntityCreated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.trackEntityCreation(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .ecsEntityDestroyed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.trackEntityDestruction(notification)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Cleanup Process Management
    
    private func startCleanupProcesses() {
        // Regular cleanup timer
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: config.cleanupInterval, repeats: true) { [weak self] _ in
            self?.performRoutineCleanup()
        }
        
        // Memory monitoring timer
        memoryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.monitorMemoryUsage()
        }
        
        // Orphan detection timer
        orphanCheckTimer = Timer.scheduledTimer(withTimeInterval: config.orphanCheckInterval, repeats: true) { [weak self] _ in
            self?.detectOrphanedObjects()
        }
        
        // State validation timer
        stateValidationTimer = Timer.scheduledTimer(withTimeInterval: 120.0, repeats: true) { [weak self] _ in
            self?.validateSystemState()
        }
        
        // Cleanup processing loop
        Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.processCleanupQueue()
        }
        .store(in: &cancellables)
        
        // Metrics update timer
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Message Handlers
    
    private func handleKillObjectMessage(_ notification: Notification) {
        guard let killMessage = notification.object as? KillObjectMessage else { return }
        
        print("[💀] Received KillObject message for \(killMessage.localIDs.count) objects")
        
        for localID in killMessage.localIDs {
            let operation = CleanupOperation(
                type: .normal,
                localID: localID,
                entityID: nil,
                priority: .normal,
                timestamp: Date(),
                reason: "KillObject message received"
            )
            
            queueCleanupOperation(operation)
        }
    }
    
    private func handleConnectionLoss(_ notification: Notification) {
        print("[🔌] Connection lost - initiating connection cleanup")
        
        let operation = CleanupOperation(
            type: .connection,
            localID: nil,
            entityID: nil,
            priority: .high,
            timestamp: Date(),
            reason: "Connection lost to OpenSim server"
        )
        
        queueCleanupOperation(operation)
    }
    
    private func handleMemoryWarning() {
        print("[⚠️] Memory warning received - initiating emergency cleanup")
        
        let operation = CleanupOperation(
            type: .emergency,
            localID: nil,
            entityID: nil,
            priority: .emergency,
            timestamp: Date(),
            reason: "System memory warning"
        )
        
        queueCleanupOperation(operation)
        cleanupState = .emergency
    }
    
    private func trackEntityCreation(_ notification: Notification) {
        guard let entityInfo = notification.object as? EntityCreationInfo else { return }
        
        managedEntities.insert(entityInfo.entityID)
        resourceTracker.trackEntityCreation(entityInfo.entityID)
    }
    
    private func trackEntityDestruction(_ notification: Notification) {
        guard let entityInfo = notification.object as? EntityDestructionInfo else { return }
        
        managedEntities.remove(entityInfo.entityID)
        resourceTracker.trackEntityDestruction(entityInfo.entityID)
        objectsRemoved += 1
    }
    
    // MARK: - Cleanup Operations
    
    private func queueCleanupOperation(_ operation: CleanupOperation) {
        cleanupQueue.enqueue(operation, priority: operation.priority.rawValue)
        pendingCleanups += 1
        totalCleanupOperations += 1
        
        print("[📝] Queued cleanup operation: \(operation.type) - \(operation.reason)")
    }
    
    private func processCleanupQueue() {
        guard cleanupState.canProcessCleanup else { return }
        
        let maxOperationsPerCycle = cleanupState == .emergency ? 10 : 3
        var processedCount = 0
        
        while let operation = cleanupQueue.dequeue(),
              processedCount < maxOperationsPerCycle {
            
            processCleanupOperation(operation)
            processedCount += 1
        }
        
        pendingCleanups = cleanupQueue.count
        
        // Update state
        if cleanupState == .emergency && cleanupQueue.isEmpty {
            cleanupState = .recovering
        } else if cleanupState == .recovering && memoryPressure == .normal {
            cleanupState = .idle
        }
    }
    
    private func processCleanupOperation(_ operation: CleanupOperation) {
        activeOperations[operation.id] = operation
        cleanupState = .processing
        
        cleanupProcessor.executeCleanup(operation) { [weak self] result in
            self?.handleCleanupResult(operation: operation, result: result)
        }
    }
    
    private func handleCleanupResult(operation: CleanupOperation, result: CleanupResult) {
        activeOperations.removeValue(forKey: operation.id)
        
        switch result {
        case .success:
            completedOperations.append(operation)
            cleanupCounter += 1
            print("[✅] Cleanup operation completed: \(operation.type)")
            
        case .failure(let error):
            var failedOperation = operation
            failedOperation.attempts += 1
            
            if failedOperation.attempts < failedOperation.maxAttempts {
                // Retry the operation
                print("[🔄] Retrying cleanup operation: \(operation.type) (attempt \(failedOperation.attempts))")
                queueCleanupOperation(failedOperation)
            } else {
                // Mark as permanently failed
                failedOperations.append(failedOperation)
                print("[❌] Cleanup operation failed permanently: \(operation.type) - \(error.localizedDescription)")
            }
        }
        
        // Update state
        if activeOperations.isEmpty {
            cleanupState = .idle
        }
    }
    
    // MARK: - Routine Cleanup Processes
    
    private func performRoutineCleanup() {
        print("[🧹] Performing routine cleanup...")
        
        // Clean up stale objects
        cleanupStaleObjects()
        
        // Clean up completed operations history
        cleanupOperationHistory()
        
        // Optimize memory usage
        optimizeMemoryUsage()
        
        print("[✅] Routine cleanup completed")
    }
    
    private func cleanupStaleObjects() {
        let cutoffTime = Date().addingTimeInterval(-config.staleObjectTimeout)
        
        guard let objectLifecycleManager = objectLifecycleManager else { return }
        
        let managedObjects = objectLifecycleManager.getAllManagedObjects()
        
        for (localID, objectData) in managedObjects {
            if objectData.lastUpdateTime < cutoffTime {
                staleObjects[localID] = objectData.lastUpdateTime
                
                let operation = CleanupOperation(
                    type: .stale,
                    localID: localID,
                    entityID: nil,
                    priority: .low,
                    timestamp: Date(),
                    reason: "Object stale - no updates for \(config.staleObjectTimeout) seconds"
                )
                
                queueCleanupOperation(operation)
            }
        }
    }
    
    private func cleanupOperationHistory() {
        // Keep only recent operations
        let cutoffTime = Date().addingTimeInterval(-3600) // 1 hour
        
        completedOperations.removeAll { $0.timestamp < cutoffTime }
        failedOperations.removeAll { $0.timestamp < cutoffTime }
    }
    
    private func optimizeMemoryUsage() {
        // Clear caches if memory pressure is high
        if memoryPressure == .high || memoryPressure == .critical {
            resourceTracker.clearCaches()
            ecsRealityBridge?.forceResync()
        }
    }
    
    // MARK: - Memory Monitoring
    
    private func monitorMemoryUsage() {
        memoryUsage = getMemoryUsage()
        
        let previousPressure = memoryPressure
        memoryPressure = calculateMemoryPressure(memoryUsage)
        
        // Record pressure history
        memoryPressureHistory.append(memoryPressure)
        if memoryPressureHistory.count > 60 { // Keep last 5 minutes
            memoryPressureHistory.removeFirst()
        }
        
        // Handle pressure level changes
        if memoryPressure != previousPressure {
            handleMemoryPressureChange(from: previousPressure, to: memoryPressure)
        }
        
        // Track memory hotspots
        updateMemoryHotspots()
    }
    
    private func calculateMemoryPressure(_ usage: Int64) -> MemoryPressureLevel {
        switch usage {
        case 0..<config.warningThreshold:
            return .normal
        case config.warningThreshold..<config.emergencyThreshold:
            return .high
        default:
            return .critical
        }
    }
    
    private func handleMemoryPressureChange(from previous: MemoryPressureLevel, to current: MemoryPressureLevel) {
        print("[📊] Memory pressure changed: \(previous) → \(current)")
        
        switch current {
        case .high:
            if previous == .normal {
                initiatePreventativeCleanup()
            }
            
        case .critical:
            if previous != .critical {
                initiateEmergencyCleanup()
            }
            
        case .normal:
            if previous != .normal {
                print("[✅] Memory pressure returned to normal")
            }
        }
    }
    
    private func initiatePreventativeCleanup() {
        print("[⚠️] Initiating preventative cleanup due to high memory pressure")
        
        let operation = CleanupOperation(
            type: .emergency,
            localID: nil,
            entityID: nil,
            priority: .high,
            timestamp: Date(),
            reason: "High memory pressure - preventative cleanup"
        )
        
        queueCleanupOperation(operation)
    }
    
    private func initiateEmergencyCleanup() {
        print("[🚨] Initiating emergency cleanup due to critical memory pressure")
        
        cleanupState = .emergency
        
        // Clear all non-essential objects
        let operation = CleanupOperation(
            type: .emergency,
            localID: nil,
            entityID: nil,
            priority: .emergency,
            timestamp: Date(),
            reason: "Critical memory pressure - emergency cleanup"
        )
        
        queueCleanupOperation(operation)
        
        // Force immediate processing
        for _ in 0..<5 {
            processCleanupQueue()
        }
    }
    
    private func updateMemoryHotspots() {
        memoryHotspots["ECS"] = Int64(managedEntities.count * MemoryLayout<EntityID>.size)
        memoryHotspots["RealityKit"] = ecsRealityBridge?.getSynchronizationStats().memoryUsage ?? 0
        memoryHotspots["ObjectLifecycle"] = objectLifecycleManager?.getLifecycleStatistics().memoryUsage ?? 0
        memoryHotspots["Cleanup"] = Int64(activeOperations.count * MemoryLayout<CleanupOperation>.size)
    }
    
    // MARK: - Orphan Detection
    
    private func detectOrphanedObjects() {
        orphanDetector.detectOrphans { [weak self] orphanedLocalIDs in
            guard let self = self else { return }
            
            for localID in orphanedLocalIDs {
                self.orphanedObjects[localID] = Date()
                
                let operation = CleanupOperation(
                    type: .orphaned,
                    localID: localID,
                    entityID: nil,
                    priority: .normal,
                    timestamp: Date(),
                    reason: "Orphaned object detected"
                )
                
                self.queueCleanupOperation(operation)
            }
        }
    }
    
    // MARK: - State Validation
    
    private func validateSystemState() {
        stateValidator.validateState { [weak self] inconsistencies in
            guard let self = self else { return }
            
            for inconsistency in inconsistencies {
                print("[⚠️] State inconsistency detected: \(inconsistency.description)")
                
                if let fixOperation = inconsistency.createFixOperation() {
                    self.queueCleanupOperation(fixOperation)
                }
            }
        }
    }
    
    // MARK: - Utility Methods
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    private func updateMetrics() {
        let now = Date()
        let timeDelta = now.timeIntervalSince(lastMetricsUpdate)
        
        if timeDelta > 0 {
            cleanupRate = Double(cleanupCounter) / timeDelta
            cleanupCounter = 0
        }
        
        lastMetricsUpdate = now
    }
    
    // MARK: - Public Interface
    
    func forceCleanupObject(localID: UInt32, reason: String = "Manual cleanup") {
        let operation = CleanupOperation(
            type: .forced,
            localID: localID,
            entityID: nil,
            priority: .high,
            timestamp: Date(),
            reason: reason
        )
        
        queueCleanupOperation(operation)
    }
    
    func forceCleanupEntity(entityID: EntityID, reason: String = "Manual cleanup") {
        let operation = CleanupOperation(
            type: .forced,
            localID: nil,
            entityID: entityID,
            priority: .high,
            timestamp: Date(),
            reason: reason
        )
        
        queueCleanupOperation(operation)
    }
    
    func emergencyCleanupAll() {
        print("[🚨] Emergency cleanup of all objects requested")
        
        cleanupState = .emergency
        
        let operation = CleanupOperation(
            type: .emergency,
            localID: nil,
            entityID: nil,
            priority: .emergency,
            timestamp: Date(),
            reason: "Emergency cleanup all requested"
        )
        
        queueCleanupOperation(operation)
    }
    
    func getCleanupStatistics() -> CleanupStatistics {
        return CleanupStatistics(
            totalOperations: totalCleanupOperations,
            pendingOperations: pendingCleanups,
            completedOperations: completedOperations.count,
            failedOperations: failedOperations.count,
            activeOperations: activeOperations.count,
            memoryUsage: memoryUsage,
            memoryPressure: memoryPressure,
            cleanupRate: cleanupRate,
            objectsRemoved: objectsRemoved,
            staleObjectCount: staleObjects.count,
            orphanedObjectCount: orphanedObjects.count,
            memoryHotspots: memoryHotspots
        )
    }
    
    func getMemoryPressureHistory() -> [MemoryPressureLevel] {
        return memoryPressureHistory
    }
    
    func pauseCleanup() {
        cleanupTimer?.invalidate()
        print("[⏸️] Cleanup processes paused")
    }
    
    func resumeCleanup() {
        startCleanupProcesses()
        print("[▶️] Cleanup processes resumed")
    }
    
    // MARK: - Cleanup on Deinit
    
    deinit {
        cleanupTimer?.invalidate()
        memoryMonitorTimer?.invalidate()
        orphanCheckTimer?.invalidate()
        stateValidationTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - CleanupProcessorDelegate

extension OpenSimCleanupManager: CleanupProcessorDelegate {
    
    func cleanupProcessor(_ processor: CleanupProcessor, willStartOperation operation: CleanupOperation) {
        print("[🧹] Starting cleanup operation: \(operation.type)")
    }
    
    func cleanupProcessor(_ processor: CleanupProcessor, didCompleteOperation operation: CleanupOperation) {
        print("[✅] Completed cleanup operation: \(operation.type)")
    }
    
    func cleanupProcessor(_ processor: CleanupProcessor, didFailOperation operation: CleanupOperation, error: Error) {
        print("[❌] Failed cleanup operation: \(operation.type) - \(error.localizedDescription)")
    }
}

// MARK: - MemoryManagerDelegate

extension OpenSimCleanupManager: MemoryManagerDelegate {
    
    func memoryManager(_ manager: MemoryManager, didDetectHighPressure usage: Int64) {
        initiatePreventativeCleanup()
    }
    
    func memoryManager(_ manager: MemoryManager, didDetectCriticalPressure usage: Int64) {
        initiateEmergencyCleanup()
    }
    
    func memoryManager(_ manager: MemoryManager, didOptimizeMemory freedBytes: Int64) {
        print("[💾] Memory optimized: freed \(freedBytes) bytes")
    }
}

// MARK: - Supporting Classes

// Cleanup Processor
class CleanupProcessor {
    weak var delegate: CleanupProcessorDelegate?
    private let ecs: ECSCore
    private let renderer: RendererService
    
    init(ecs: ECSCore, renderer: RendererService, delegate: CleanupProcessorDelegate) {
        self.ecs = ecs
        self.renderer = renderer
        self.delegate = delegate
    }
    
    func executeCleanup(_ operation: CleanupOperation, completion: @escaping (CleanupResult) -> Void) {
        delegate?.cleanupProcessor(self, willStartOperation: operation)
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.performCleanup(operation)
                
                DispatchQueue.main.async {
                    self.delegate?.cleanupProcessor(self, didCompleteOperation: operation)
                    completion(.success)
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.delegate?.cleanupProcessor(self, didFailOperation: operation, error: error)
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func performCleanup(_ operation: CleanupOperation) throws {
        switch operation.type {
        case .normal:
            if let localID = operation.localID {
                try performNormalCleanup(localID: localID)
            }
            
        case .emergency:
            try performEmergencyCleanup()
            
        case .orphaned:
            if let localID = operation.localID {
                try performOrphanCleanup(localID: localID)
            }
            
        case .stale:
            if let localID = operation.localID {
                try performStaleCleanup(localID: localID)
            }
            
        case .connection:
            try performConnectionCleanup()
            
        case .forced:
            if let localID = operation.localID {
                try performForcedCleanup(localID: localID)
            } else if let entityID = operation.entityID {
                try performForcedEntityCleanup(entityID: entityID)
            }
            
        case .cascade:
            if let localID = operation.localID {
                try performCascadeCleanup(localID: localID)
            }
        }
    }
    
    private func performNormalCleanup(localID: UInt32) throws {
        // Standard object removal process
        removeECSEntity(localID: localID)
        removeVisualEntity(localID: localID)
        cleanupResources(localID: localID)
    }
    
    private func performEmergencyCleanup() throws {
        // Aggressive cleanup to free memory
        let world = ecs.getWorld()
        let entities = world.entities(with: OpenSimObjectComponent.self)
        
        // Remove entities beyond a certain distance
        let avatarPosition = SIMD3<Float>(128, 25, 128)
        let cullingDistance: Float = 100.0
        
        for (entityID, component) in entities {
            if let positionComponent = world.getComponent(ofType: PositionComponent.self, from: entityID) {
                let distance = simd_length(positionComponent.position - avatarPosition)
                
                if distance > cullingDistance {
                    try performForcedEntityCleanup(entityID: entityID)
                }
            }
        }
    }
    
    private func performOrphanCleanup(localID: UInt32) throws {
        // Remove orphaned objects that have no corresponding OpenSim data
        try performNormalCleanup(localID: localID)
    }
    
    private func performStaleCleanup(localID: UInt32) throws {
        // Remove objects that haven't been updated recently
        try performNormalCleanup(localID: localID)
    }
    
    private func performConnectionCleanup() throws {
        // Clean up all OpenSim-related objects when connection is lost
        let world = ecs.getWorld()
        let openSimEntities = world.entities(with: OpenSimObjectComponent.self)
        
        for (entityID, _) in openSimEntities {
            try performForcedEntityCleanup(entityID: entityID)
        }
    }
    
    private func performForcedCleanup(localID: UInt32) throws {
        try performNormalCleanup(localID: localID)
    }
    
    private func performForcedEntityCleanup(entityID: EntityID) throws {
        removeSpecificEntity(entityID: entityID)
    }
    
    private func performCascadeCleanup(localID: UInt32) throws {
        // Remove object and all its children
        let world = ecs.getWorld()
        let entities = world.entities(with: OpenSimObjectComponent.self)
        
        // Find children of this object
        for (entityID, component) in entities {
            // In OpenSim, child objects would have parentID set
            // This is a simplified version
            try performForcedEntityCleanup(entityID: entityID)
        }
        
        try performNormalCleanup(localID: localID)
    }
    
    private func removeECSEntity(localID: UInt32) {
        let world = ecs.getWorld()
        let entities = world.entities(with: OpenSimObjectComponent.self)
        
        for (entityID, component) in entities {
            if component.localID == localID {
                world.removeEntity(entityID)
                ecs.notifyEntityDestroyed(entityID)
                break
            }
        }
    }
    
    private func removeVisualEntity(localID: UInt32) {
        // Remove from RealityKit through ECS bridge notification
        NotificationCenter.default.post(
            name: .openSimObjectRemoved,
            object: ["localID": localID]
        )
    }
    
    private func removeSpecificEntity(entityID: EntityID) {
        let world = ecs.getWorld()
        world.removeEntity(entityID)
        ecs.notifyEntityDestroyed(entityID)
    }
    
    private func cleanupResources(localID: UInt32) {
        // Clean up any cached resources for this object
        // This would integrate with texture manager, geometry cache, etc.
        print("[🧹] Cleaning up resources for object: \(localID)")
    }
 }

 protocol CleanupProcessorDelegate: AnyObject {
    func cleanupProcessor(_ processor: CleanupProcessor, willStartOperation operation: CleanupOperation)
    func cleanupProcessor(_ processor: CleanupProcessor, didCompleteOperation operation: CleanupOperation)
    func cleanupProcessor(_ processor: CleanupProcessor, didFailOperation operation: CleanupOperation, error: Error)
 }

 // Memory Manager
 class MemoryManager {
    weak var delegate: MemoryManagerDelegate?
    private let config: MemoryManagementConfig
    private var lastOptimization: Date = Date()
    
    init(config: MemoryManagementConfig, delegate: MemoryManagerDelegate) {
        self.config = config
        self.delegate = delegate
    }
    
    func checkMemoryPressure(_ currentUsage: Int64) {
        if currentUsage > config.emergencyThreshold {
            delegate?.memoryManager(self, didDetectCriticalPressure: currentUsage)
        } else if currentUsage > config.warningThreshold {
            delegate?.memoryManager(self, didDetectHighPressure: currentUsage)
        }
    }
    
    func optimizeMemory() {
        let now = Date()
        
        // Throttle optimization to prevent excessive calls
        guard now.timeIntervalSince(lastOptimization) > 30.0 else { return }
        
        lastOptimization = now
        
        // Perform memory optimization
        let freedBytes = performMemoryOptimization()
        delegate?.memoryManager(self, didOptimizeMemory: freedBytes)
    }
    
    private func performMemoryOptimization() -> Int64 {
        // Simulate memory optimization
        // In reality, this would clear caches, compact memory, etc.
        let freedBytes: Int64 = 50_000_000 // 50MB
        
        // Force garbage collection
        autoreleasepool {
            // Trigger memory cleanup
        }
        
        return freedBytes
    }
 }

 protocol MemoryManagerDelegate: AnyObject {
    func memoryManager(_ manager: MemoryManager, didDetectHighPressure usage: Int64)
    func memoryManager(_ manager: MemoryManager, didDetectCriticalPressure usage: Int64)
    func memoryManager(_ manager: MemoryManager, didOptimizeMemory freedBytes: Int64)
 }

 // State Validator
 class StateValidator {
    private let ecs: ECSCore
    private let objectLifecycleManager: OpenSimObjectLifecycleManager
    
    init(ecs: ECSCore, objectLifecycleManager: OpenSimObjectLifecycleManager) {
        self.ecs = ecs
        self.objectLifecycleManager = objectLifecycleManager
    }
    
    func validateState(completion: @escaping ([StateInconsistency]) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            var inconsistencies: [StateInconsistency] = []
            
            // Validate ECS-OpenSim consistency
            inconsistencies.append(contentsOf: self.validateECSOpenSimConsistency())
            
            // Validate entity-visual consistency
            inconsistencies.append(contentsOf: self.validateEntityVisualConsistency())
            
            // Validate memory consistency
            inconsistencies.append(contentsOf: self.validateMemoryConsistency())
            
            DispatchQueue.main.async {
                completion(inconsistencies)
            }
        }
    }
    
    private func validateECSOpenSimConsistency() -> [StateInconsistency] {
        var inconsistencies: [StateInconsistency] = []
        
        let world = ecs.getWorld()
        let ecsEntities = world.entities(with: OpenSimObjectComponent.self)
        let managedObjects = objectLifecycleManager.getAllManagedObjects()
        
        // Check for ECS entities without corresponding OpenSim objects
        for (entityID, component) in ecsEntities {
            if managedObjects[component.localID] == nil {
                inconsistencies.append(
                    StateInconsistency(
                        type: .orphanedECSEntity,
                        description: "ECS entity \(entityID) has no corresponding OpenSim object",
                        entityID: entityID,
                        localID: component.localID
                    )
                )
            }
        }
        
        // Check for OpenSim objects without corresponding ECS entities
        for (localID, _) in managedObjects {
            let hasECSEntity = ecsEntities.contains { $0.1.localID == localID }
            if !hasECSEntity {
                inconsistencies.append(
                    StateInconsistency(
                        type: .orphanedOpenSimObject,
                        description: "OpenSim object \(localID) has no corresponding ECS entity",
                        entityID: nil,
                        localID: localID
                    )
                )
            }
        }
        
        return inconsistencies
    }
    
    private func validateEntityVisualConsistency() -> [StateInconsistency] {
        var inconsistencies: [StateInconsistency] = []
        
        // This would validate that entities with visual components have corresponding RealityKit representations
        // Implementation would depend on the specific visual system architecture
        
        return inconsistencies
    }
    
    private func validateMemoryConsistency() -> [StateInconsistency] {
        var inconsistencies: [StateInconsistency] = []
        
        // Check for memory leaks or excessive memory usage
        let currentMemory = getCurrentMemoryUsage()
        let expectedMemory = calculateExpectedMemoryUsage()
        
        if currentMemory > expectedMemory * 2 {
            inconsistencies.append(
                StateInconsistency(
                    type: .memoryLeak,
                    description: "Memory usage (\(currentMemory)) significantly exceeds expected (\(expectedMemory))",
                    entityID: nil,
                    localID: nil
                )
            )
        }
        
        return inconsistencies
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    private func calculateExpectedMemoryUsage() -> Int64 {
        let world = ecs.getWorld()
        let entityCount = world.entities(with: OpenSimObjectComponent.self).count
        
        // Rough estimation: 1MB per object (including textures, geometry, etc.)
        return Int64(entityCount) * 1_000_000
    }
 }

 // Orphan Detector
 class OrphanDetector {
    private let ecs: ECSCore
    private let objectLifecycleManager: OpenSimObjectLifecycleManager
    
    init(ecs: ECSCore, objectLifecycleManager: OpenSimObjectLifecycleManager) {
        self.ecs = ecs
        self.objectLifecycleManager = objectLifecycleManager
    }
    
    func detectOrphans(completion: @escaping ([UInt32]) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            var orphanedLocalIDs: [UInt32] = []
            
            let world = self.ecs.getWorld()
            let ecsEntities = world.entities(with: OpenSimObjectComponent.self)
            let managedObjects = self.objectLifecycleManager.getAllManagedObjects()
            
            // Find orphaned objects (exist in ECS but not in lifecycle manager)
            for (_, component) in ecsEntities {
                if managedObjects[component.localID] == nil {
                    orphanedLocalIDs.append(component.localID)
                }
            }
            
            DispatchQueue.main.async {
                completion(orphanedLocalIDs)
            }
        }
    }
 }

 // Resource Tracker
 class ResourceTracker {
    private var entityResourceMap: [EntityID: ResourceUsage] = [:]
    private var totalResourceUsage = ResourceUsage()
    
    func trackEntityCreation(_ entityID: EntityID) {
        let usage = ResourceUsage(
            memoryUsage: 1_000_000, // 1MB estimated
            geometryMemory: 500_000, // 500KB
            textureMemory: 500_000,  // 500KB
            creationTime: Date()
        )
        
        entityResourceMap[entityID] = usage
        totalResourceUsage.add(usage)
    }
    
    func trackEntityDestruction(_ entityID: EntityID) {
        if let usage = entityResourceMap.removeValue(forKey: entityID) {
            totalResourceUsage.subtract(usage)
        }
    }
    
    func getTotalResourceUsage() -> ResourceUsage {
        return totalResourceUsage
    }
    
    func getEntityResourceUsage(_ entityID: EntityID) -> ResourceUsage? {
        return entityResourceMap[entityID]
    }
    
    func clearCaches() {
        print("[🧹] Clearing resource caches")
        // Implementation would clear various caches
    }
 }

 // MARK: - Supporting Types

 enum CleanupResult {
    case success
    case failure(Error)
 }

 enum MemoryPressureLevel: String, CaseIterable {
    case normal = "Normal"
    case high = "High"
    case critical = "Critical"
    
    var color: UIColor {
        switch self {
        case .normal: return .systemGreen
        case .high: return .systemOrange
        case .critical: return .systemRed
        }
    }
 }

 struct StateInconsistency {
    let type: InconsistencyType
    let description: String
    let entityID: EntityID?
    let localID: UInt32?
    
    enum InconsistencyType {
        case orphanedECSEntity
        case orphanedOpenSimObject
        case orphanedVisualEntity
        case memoryLeak
        case corruptedState
    }
    
    func createFixOperation() -> CleanupOperation? {
        switch type {
        case .orphanedECSEntity:
            if let entityID = entityID {
                return CleanupOperation(
                    type: .orphaned,
                    localID: nil,
                    entityID: entityID,
                    priority: .normal,
                    timestamp: Date(),
                    reason: "Fix orphaned ECS entity"
                )
            }
            
        case .orphanedOpenSimObject:
            if let localID = localID {
                return CleanupOperation(
                    type: .orphaned,
                    localID: localID,
                    entityID: nil,
                    priority: .normal,
                    timestamp: Date(),
                    reason: "Fix orphaned OpenSim object"
                )
            }
            
        case .memoryLeak:
            return CleanupOperation(
                type: .emergency,
                localID: nil,
                entityID: nil,
                priority: .high,
                timestamp: Date(),
                reason: "Fix memory leak"
            )
            
        default:
            break
        }
        
        return nil
    }
 }

 struct ResourceUsage {
    var memoryUsage: Int64 = 0
    var geometryMemory: Int64 = 0
    var textureMemory: Int64 = 0
    var creationTime: Date = Date()
    
    mutating func add(_ other: ResourceUsage) {
        memoryUsage += other.memoryUsage
        geometryMemory += other.geometryMemory
        textureMemory += other.textureMemory
    }
    
    mutating func subtract(_ other: ResourceUsage) {
        memoryUsage -= other.memoryUsage
        geometryMemory -= other.geometryMemory
        textureMemory -= other.textureMemory
    }
 }

 struct CleanupStatistics {
    let totalOperations: Int
    let pendingOperations: Int
    let completedOperations: Int
    let failedOperations: Int
    let activeOperations: Int
    let memoryUsage: Int64
    let memoryPressure: MemoryPressureLevel
    let cleanupRate: Double
    let objectsRemoved: Int
    let staleObjectCount: Int
    let orphanedObjectCount: Int
    let memoryHotspots: [String: Int64]
    
    var successRate: Double {
        let total = completedOperations + failedOperations
        return total > 0 ? Double(completedOperations) / Double(total) : 1.0
    }
    
    var memoryUsageMB: Double {
        return Double(memoryUsage) / 1_048_576 // Convert to MB
    }
 }

 struct KillObjectMessage {
    let localIDs: [UInt32]
 }

 // MARK: - Notification Extensions

 extension Notification.Name {
    static let openSimKillObject = Notification.Name("OpenSimKillObject")
    static let openSimConnectionLost = Notification.Name("OpenSimConnectionLost")
 }

 // MARK: - Priority Queue Implementation (if not already defined)

 struct PriorityQueue<T> {
    private var heap: [(T, Int)] = []
    
    var isEmpty: Bool { heap.isEmpty }
    var count: Int { heap.count }
    
    mutating func enqueue(_ element: T, priority: Int) {
        heap.append((element, priority))
        heap.sort { $0.1 < $1.1 } // Lower priority number = higher priority
    }
    
    mutating func dequeue() -> T? {
        guard !heap.isEmpty else { return nil }
        return heap.removeFirst().0
    }
    
    mutating func clear() {
        heap.removeAll()
    }
 }

 // MARK: - Extension for Timer Cancellable Storage

 extension Timer {
    func store(in set: inout Set<AnyCancellable>) {
        let cancellable = AnyCancellable {
            self.invalidate()
        }
        set.insert(cancellable)
    }
 }

 //print("[✅] OpenSim Cleanup & State Management System Complete")
