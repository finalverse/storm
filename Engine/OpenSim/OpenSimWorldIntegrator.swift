//
//  Engine/OpenSimWorldIntegrator.swift
//  Storm
//
//  Complete world integration system that handles real-time OpenSim updates
//  Bridges incoming server data with ECS entities and RealityKit visualization
//  Manages object lifecycle, terrain, and scene synchronization
//
//  Created for Finalverse Storm - World Integration System

import Foundation
import RealityKit
import simd
import Combine

// MARK: - World Integration State

enum WorldIntegrationState {
    case disconnected
    case initializing
    case receiving
    case synchronized
    case error(String)
    
    var canProcessUpdates: Bool {
        switch self {
        case .receiving, .synchronized:
            return true
        default:
            return false
        }
    }
}

// MARK: - World Update Types

enum WorldUpdateType {
    case objectCreate
    case objectUpdate
    case objectRemove
    case terrainUpdate
    case regionInfo
    case avatarUpdate
}

struct WorldUpdate {
    let type: WorldUpdateType
    let timestamp: Date
    let data: Any
    let localID: UInt32?
    let priority: UpdatePriority
}

enum UpdatePriority: Int {
    case critical = 0    // Avatar, immediate safety
    case high = 1        // Nearby objects, interactions
    case normal = 2      // Visible objects
    case low = 3         // Background, distant objects
    case deferred = 4    // Non-essential updates
}

// MARK: - Main World Integrator

@MainActor
class OpenSimWorldIntegrator: ObservableObject {
    
    // MARK: - Published Properties
    @Published var integrationState: WorldIntegrationState = .disconnected
    @Published var objectCount: Int = 0
    @Published var updateRate: Double = 0 // Updates per second
    @Published var latency: TimeInterval = 0
    @Published var memoryUsage: Int64 = 0
    
    // MARK: - Service References
    private weak var ecs: ECSCore?
    private weak var renderer: RendererService?
    private weak var connectManager: OSConnectManager?
    private weak var registry: SystemRegistry?
    
    // MARK: - Integration Components
    private var updateProcessor: WorldUpdateProcessor!
    private var objectManager: OpenSimObjectManager!
    private var terrainManager: OpenSimTerrainManager!
    private var avatarSynchronizer: OpenSimAvatarSynchronizer!
    private var performanceMonitor: WorldPerformanceMonitor!
    
    // MARK: - Update Management
    private var updateQueue: PriorityQueue<WorldUpdate> = PriorityQueue()
    private var pendingUpdates: [UInt32: WorldUpdate] = [:]
    private var processingQueue = DispatchQueue(label: "WorldIntegration", qos: .userInitiated)
    
    // MARK: - State Tracking
    private var knownObjects: [UInt32: ObjectState] = [:]
    private var regionInfo: RegionInfo?
    private var lastUpdateTime: Date = Date()
    private var updateCounter: Int = 0
    
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        print("[🌍] OpenSimWorldIntegrator initializing...")
        setupNotificationObservers()
    }
    
    func setup(registry: SystemRegistry) {
        self.registry = registry
        self.ecs = registry.ecs
        self.renderer = registry.resolve("renderer")
        self.connectManager = registry.resolve("openSimConnection")
        
        guard let ecs = ecs, let renderer = renderer else {
            integrationState = .error("Required services not available")
            return
        }
        
        // Initialize sub-components
        setupIntegrationComponents(ecs: ecs, renderer: renderer)
        
        // Setup update processing
        setupUpdateProcessing()
        
        // Start performance monitoring
        startPerformanceMonitoring()
        
        print("[✅] OpenSimWorldIntegrator setup complete")
    }
    
    private func setupIntegrationComponents(ecs: ECSCore, renderer: RendererService) {
        // Update Processor - handles incoming OpenSim messages
        updateProcessor = WorldUpdateProcessor(
            ecs: ecs,
            renderer: renderer,
            delegate: self
        )
        
        // Object Manager - handles 3D objects in the world
        objectManager = OpenSimObjectManager(
            ecs: ecs,
            renderer: renderer
        )
        
        // Terrain Manager - handles landscape and terrain
        terrainManager = OpenSimTerrainManager(
            ecs: ecs,
            renderer: renderer
        )
        
        // Avatar Synchronizer - handles avatar updates
        avatarSynchronizer = OpenSimAvatarSynchronizer(
            ecs: ecs,
            renderer: renderer
        )
        
        // Performance Monitor - tracks system performance
        performanceMonitor = WorldPerformanceMonitor()
    }
    
    private func setupNotificationObservers() {
        // Object Updates
        NotificationCenter.default.publisher(for: .openSimObjectUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleObjectUpdate(notification)
            }
            .store(in: &cancellables)
        
        // Object Removal
        NotificationCenter.default.publisher(for: .openSimObjectRemoved)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleObjectRemoval(notification)
            }
            .store(in: &cancellables)
        
        // Region Handshake
        NotificationCenter.default.publisher(for: .openSimRegionHandshake)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleRegionHandshake(notification)
            }
            .store(in: &cancellables)
        
        // Chat Messages
        NotificationCenter.default.publisher(for: .openSimChatMessage)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleChatMessage(notification)
            }
            .store(in: &cancellables)
        
        // Connection State Changes
        NotificationCenter.default.publisher(for: .openSimConnectionStateChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleConnectionStateChange(notification)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Update Processing Setup
    
    private func setupUpdateProcessing() {
        // Start update processing timer (60 FPS target)
        Timer.publish(every: 1.0/60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.processUpdates()
            }
            .store(in: &cancellables)
        
        // Start statistics update timer (1 Hz)
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateStatistics()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Real-time Update Handling
    
    private func handleObjectUpdate(_ notification: Notification) {
        guard integrationState.canProcessUpdates,
              let objectUpdate = notification.object as? ObjectUpdateMessage else { return }
        
        let update = WorldUpdate(
            type: .objectUpdate,
            timestamp: Date(),
            data: objectUpdate,
            localID: objectUpdate.localID,
            priority: calculateUpdatePriority(for: objectUpdate)
        )
        
        queueUpdate(update)
    }
    
    private func handleObjectRemoval(_ notification: Notification) {
        guard integrationState.canProcessUpdates,
              let userInfo = notification.object as? [String: Any],
              let localID = userInfo["localID"] as? UInt32 else { return }
        
        let update = WorldUpdate(
            type: .objectRemove,
            timestamp: Date(),
            data: localID,
            localID: localID,
            priority: .high
        )
        
        queueUpdate(update)
    }
    
    private func handleRegionHandshake(_ notification: Notification) {
        guard let regionHandshake = notification.object as? RegionHandshakeMessage else { return }
        
        // Initialize world with region information
        let regionInfo = RegionInfo(
            name: regionHandshake.simName,
            handle: regionHandshake.regionHandle,
            waterHeight: regionHandshake.waterHeight,
            regionFlags: regionHandshake.regionFlags,
            simAccess: regionHandshake.simAccess
        )
        
        initializeWorld(with: regionInfo)
    }
    
    private func handleChatMessage(_ notification: Notification) {
        guard let chatMessage = notification.object as? ChatFromSimulatorMessage else { return }
        
        let update = WorldUpdate(
            type: .avatarUpdate,
            timestamp: Date(),
            data: chatMessage,
            localID: nil,
            priority: .normal
        )
        
        queueUpdate(update)
    }
    
    private func handleConnectionStateChange(_ notification: Notification) {
        guard let connectManager = connectManager else { return }
        
        if connectManager.isConnected {
            if integrationState == .disconnected {
                integrationState = .initializing
            }
        } else {
            integrationState = .disconnected
            clearWorld()
        }
    }
    
    // MARK: - Update Processing
    
    private func queueUpdate(_ update: WorldUpdate) {
        updateQueue.enqueue(update, priority: update.priority.rawValue)
        updateCounter += 1
    }
    
    private func processUpdates() {
        guard integrationState.canProcessUpdates else { return }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var processedCount = 0
        let maxProcessingTime: CFAbsoluteTime = 1.0/60.0 * 0.8 // 80% of frame time
        
        // Process updates by priority until time budget exhausted
        while let update = updateQueue.dequeue(),
              CFAbsoluteTimeGetCurrent() - startTime < maxProcessingTime {
            
            processingQueue.async { [weak self] in
                self?.processWorldUpdate(update)
            }
            
            processedCount += 1
        }
        
        // Update performance metrics
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        performanceMonitor.recordFrameProcessing(
            updatesProcessed: processedCount,
            processingTime: processingTime
        )
    }
    
    private func processWorldUpdate(_ update: WorldUpdate) {
        switch update.type {
        case .objectCreate, .objectUpdate:
            if let objectUpdate = update.data as? ObjectUpdateMessage {
                processObjectUpdate(objectUpdate)
            }
            
        case .objectRemove:
            if let localID = update.data as? UInt32 {
                processObjectRemoval(localID)
            }
            
        case .terrainUpdate:
            if let terrainData = update.data as? TerrainUpdateData {
                processTerrainUpdate(terrainData)
            }
            
        case .avatarUpdate:
            if let chatMessage = update.data as? ChatFromSimulatorMessage {
                processChatMessage(chatMessage)
            }
            
        case .regionInfo:
            // Handle region-wide updates
            break
        }
    }
    
    // MARK: - Specific Update Processors
    
    private func processObjectUpdate(_ objectUpdate: ObjectUpdateMessage) {
        // Determine if this is a new object or update to existing
        let isNewObject = !knownObjects.keys.contains(objectUpdate.localID)
        
        if isNewObject {
            createNewObject(from: objectUpdate)
        } else {
            updateExistingObject(objectUpdate)
        }
        
        // Update object state tracking
        knownObjects[objectUpdate.localID] = ObjectState(
            localID: objectUpdate.localID,
            fullID: objectUpdate.fullID,
            lastUpdate: Date(),
            position: objectUpdate.position,
            rotation: objectUpdate.rotation,
            scale: objectUpdate.scale
        )
        
        DispatchQueue.main.async {
            self.objectCount = self.knownObjects.count
        }
    }
    
    private func createNewObject(from update: ObjectUpdateMessage) {
        // Create object through object manager
        objectManager.createObject(
            localID: update.localID,
            fullID: update.fullID,
            position: update.position,
            rotation: update.rotation,
            scale: update.scale,
            primitiveParams: update.primitiveParams,
            textureEntry: update.textureEntry,
            material: update.material
        )
        
        print("[🆕] Created new object: \(update.localID)")
    }
    
    private func updateExistingObject(_ update: ObjectUpdateMessage) {
        // Update object through object manager
        objectManager.updateObject(
            localID: update.localID,
            position: update.position,
            rotation: update.rotation,
            scale: update.scale
        )
    }
    
    private func processObjectRemoval(_ localID: UInt32) {
        // Remove object through object manager
        objectManager.removeObject(localID: localID)
        
        // Remove from tracking
        knownObjects.removeValue(forKey: localID)
        
        DispatchQueue.main.async {
            self.objectCount = self.knownObjects.count
        }
        
        print("[🗑️] Removed object: \(localID)")
    }
    
    private func processTerrainUpdate(_ terrainData: TerrainUpdateData) {
        // Update terrain through terrain manager
        terrainManager.updateTerrain(terrainData)
    }
    
    private func processChatMessage(_ chatMessage: ChatFromSimulatorMessage) {
        // Handle chat through avatar synchronizer
        avatarSynchronizer.displayChatBubble(
            message: chatMessage.message,
            position: chatMessage.position,
            sourceID: chatMessage.sourceID
        )
    }
    
    // MARK: - World Initialization & Management
    
    private func initializeWorld(with regionInfo: RegionInfo) {
        print("[🌍] Initializing world: \(regionInfo.name)")
        
        self.regionInfo = regionInfo
        integrationState = .receiving
        
        // Initialize terrain
        terrainManager.initializeRegion(regionInfo)
        
        // Setup world boundaries
        setupWorldBoundaries(regionInfo)
        
        // Clear any existing objects
        clearExistingObjects()
        
        print("[✅] World initialized and ready for updates")
        integrationState = .synchronized
    }
    
    private func setupWorldBoundaries(_ regionInfo: RegionInfo) {
        // Create region boundaries in ECS
        guard let ecs = ecs else { return }
        
        let world = ecs.getWorld()
        let boundaryEntity = world.createEntity()
        
        // Add boundary component
        let boundary = RegionBoundaryComponent(
            regionHandle: regionInfo.handle,
            size: SIMD2<Float>(256, 256), // Standard OpenSim region size
            waterHeight: regionInfo.waterHeight
        )
        world.addComponent(boundary, to: boundaryEntity)
        
        // Add position at region center
        let position = PositionComponent(position: SIMD3<Float>(128, regionInfo.waterHeight, 128))
        world.addComponent(position, to: boundaryEntity)
    }
    
    private func clearWorld() {
        print("[🧹] Clearing world state...")
        
        integrationState = .disconnected
        
        // Clear all objects
        clearExistingObjects()
        
        // Reset state
        regionInfo = nil
        updateQueue.clear()
        pendingUpdates.removeAll()
        
        DispatchQueue.main.async {
            self.objectCount = 0
            self.updateRate = 0
        }
    }
    
    private func clearExistingObjects() {
        // Remove all tracked objects
        for localID in knownObjects.keys {
            objectManager.removeObject(localID: localID)
        }
        knownObjects.removeAll()
        
        // Clear terrain
        terrainManager.clearTerrain()
    }
    
    // MARK: - Update Priority Calculation
    
    private func calculateUpdatePriority(for objectUpdate: ObjectUpdateMessage) -> UpdatePriority {
        // Distance-based priority (assuming avatar at 128,128)
        let avatarPosition = SIMD3<Float>(128, 25, 128) // Default avatar position
        let objectPosition = objectUpdate.position
        let distance = simd_length(objectPosition - avatarPosition)
        
        switch distance {
        case 0..<10:
            return .critical
        case 10..<50:
            return .high
        case 50..<100:
            return .normal
        case 100..<200:
            return .low
        default:
            return .deferred
        }
    }
    
    // MARK: - Performance Monitoring
    
    private func startPerformanceMonitoring() {
        performanceMonitor.startMonitoring()
    }
    
    private func updateStatistics() {
        let stats = performanceMonitor.getCurrentStats()
        
        updateRate = stats.updatesPerSecond
        latency = stats.averageLatency
        memoryUsage = stats.memoryUsage
        
        // Log performance if issues detected
        if stats.updatesPerSecond < 30 {
            print("[⚠️] Low update rate detected: \(stats.updatesPerSecond) ups")
        }
        
        if stats.averageLatency > 0.1 {
            print("[⚠️] High latency detected: \(stats.averageLatency)s")
        }
    }
    
    // MARK: - Public Interface
    
    func forceResynchronization() {
        print("[🔄] Forcing world resynchronization...")
        
        integrationState = .initializing
        clearExistingObjects()
        
        // Request fresh object data from server
        // This would typically involve sending a refresh request to OpenSim
        
        integrationState = .receiving
    }
    
    func pauseUpdates() {
        integrationState = .disconnected
        print("[⏸️] World updates paused")
    }
    
    func resumeUpdates() {
        if connectManager?.isConnected == true {
            integrationState = .synchronized
            print("[▶️] World updates resumed")
        }
    }
    
    func getWorldStatistics() -> WorldStatistics {
        return WorldStatistics(
            objectCount: objectCount,
            updateRate: updateRate,
            latency: latency,
            memoryUsage: memoryUsage,
            integrationState: integrationState,
            regionInfo: regionInfo
        )
    }
}

// MARK: - WorldUpdateProcessorDelegate

extension OpenSimWorldIntegrator: WorldUpdateProcessorDelegate {
    
    func updateProcessor(_ processor: WorldUpdateProcessor, didProcessUpdate update: WorldUpdate) {
        // Update was processed successfully
        lastUpdateTime = Date()
    }
    
    func updateProcessor(_ processor: WorldUpdateProcessor, didFailUpdate update: WorldUpdate, error: Error) {
        print("[❌] Update processing failed: \(error.localizedDescription)")
        
        // Re-queue update with lower priority if not critical
        if update.priority != .critical {
            var retryUpdate = update
            retryUpdate.priority = UpdatePriority(rawValue: min(update.priority.rawValue + 1, UpdatePriority.deferred.rawValue)) ?? .deferred
            queueUpdate(retryUpdate)
        }
    }
}

// MARK: - Supporting Classes

// World Update Processor
class WorldUpdateProcessor {
    weak var delegate: WorldUpdateProcessorDelegate?
    private let ecs: ECSCore
    private let renderer: RendererService
    
    init(ecs: ECSCore, renderer: RendererService, delegate: WorldUpdateProcessorDelegate) {
        self.ecs = ecs
        self.renderer = renderer
        self.delegate = delegate
    }
}

protocol WorldUpdateProcessorDelegate: AnyObject {
    func updateProcessor(_ processor: WorldUpdateProcessor, didProcessUpdate update: WorldUpdate)
    func updateProcessor(_ processor: WorldUpdateProcessor, didFailUpdate update: WorldUpdate, error: Error)
}

// Priority Queue Implementation
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

// MARK: - Supporting Types

struct ObjectState {
    let localID: UInt32
    let fullID: UUID
    let lastUpdate: Date
    let position: SIMD3<Float>
    let rotation: simd_quatf
    let scale: SIMD3<Float>
}

struct RegionInfo {
    let name: String
    let handle: UInt64
    let waterHeight: Float
    let regionFlags: UInt32
    let simAccess: UInt8
}

struct TerrainUpdateData {
    let patchX: Int
    let patchY: Int
    let heightData: [Float]
    let textureData: Data?
}

struct WorldStatistics {
    let objectCount: Int
    let updateRate: Double
    let latency: TimeInterval
    let memoryUsage: Int64
    let integrationState: WorldIntegrationState
    let regionInfo: RegionInfo?
}

// Performance Monitor
class WorldPerformanceMonitor {
    private var updateCounts: [Date] = []
    private var processingTimes: [TimeInterval] = []
    private var startTime: Date = Date()
    
    func startMonitoring() {
        startTime = Date()
    }
    
    func recordFrameProcessing(updatesProcessed: Int, processingTime: TimeInterval) {
        let now = Date()
        
        // Record updates
        for _ in 0..<updatesProcessed {
            updateCounts.append(now)
        }
        
        // Record processing time
        processingTimes.append(processingTime)
        
        // Keep only last 60 seconds of data
        let cutoffTime = now.addingTimeInterval(-60)
        updateCounts.removeAll { $0 < cutoffTime }
        
        // Keep only last 100 processing times
        if processingTimes.count > 100 {
            processingTimes.removeFirst(processingTimes.count - 100)
        }
    }
    
    func getCurrentStats() -> PerformanceStats {
        let now = Date()
        let recentUpdates = updateCounts.filter { now.timeIntervalSince($0) < 1.0 }
        let averageLatency = processingTimes.isEmpty ? 0 : processingTimes.reduce(0, +) / Double(processingTimes.count)
        let memoryUsage = getMemoryUsage()
        
        return PerformanceStats(
            updatesPerSecond: Double(recentUpdates.count),
            averageLatency: averageLatency,
            memoryUsage: memoryUsage
        )
    }
    
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
}

struct PerformanceStats {
    let updatesPerSecond: Double
    let averageLatency: TimeInterval
    let memoryUsage: Int64
}

// ECS Components
final class RegionBoundaryComponent: Component {
    let regionHandle: UInt64
    let size: SIMD2<Float>
    let waterHeight: Float
    
    init(regionHandle: UInt64, size: SIMD2<Float>, waterHeight: Float) {
        self.regionHandle = regionHandle
        self.size = size
        self.waterHeight = waterHeight
    }
}

// Notification Extensions
extension Notification.Name {
    static let openSimObjectUpdate = Notification.Name("OpenSimObjectUpdate")
    static let openSimObjectRemoved = Notification.Name("OpenSimObjectRemoved")
    static let openSimChatMessage = Notification.Name("OpenSimChatMessage")
}
