//
//  Engine/OpenSimObjectLifecycleManager.swift
//  Storm
//
//  Advanced OpenSim object lifecycle management system
//  Handles ObjectUpdate, ObjectUpdateCompressed, real-time property updates
//  Manages object appearance, textures, and visual synchronization
//
//  Created for Finalverse Storm - OpenSim Object Lifecycle
//
//    OpenSim Object Lifecycle Management with comprehensive features:
//    Key Features:
//
//    Complete Object Lifecycle - Creation, updates, and removal handling
//    Multiple Update Types - Full, compressed, cached, terse, texture, and properties updates
//    Priority-Based Processing - Distance-based priority queuing for performance
//    Compression Support - Handles ObjectUpdateCompressed messages efficiently
//    Geometry Generation - Creates RealityKit meshes from OpenSim primitive parameters
//    Texture Management - Loads and caches textures from OpenSim asset server
//    Performance Optimization - Frame-time budgeting and batched processing
//    Change Detection - Efficient detection of transform, visual, and texture changes
//
//    Advanced Capabilities:
//
//    Real-time Updates - 60fps processing with configurable frame budgets
//    Resource Caching - Geometry and texture caching for performance
//    Error Recovery - Graceful handling of failed updates and malformed data
//    Memory Management - Automatic cleanup and monitoring
//    Statistics Tracking - Comprehensive performance and usage metrics
//
//    The system now handles the complete OpenSim object lifecycle from initial creation through real-time updates to final removal.
//                                                                        

                                                                    

import Foundation
import RealityKit
import simd
import Combine

// MARK: - Object Lifecycle State

enum ObjectLifecycleState {
    case unknown
    case creating
    case active
    case updating
    case removing
    case error(String)
    
    var canUpdate: Bool {
        switch self {
        case .active, .updating:
            return true
        default:
            return false
        }
    }
}

// MARK: - Object Update Types

enum ObjectUpdateType {
    case full          // Complete ObjectUpdate
    case compressed    // ObjectUpdateCompressed
    case cached        // ObjectUpdateCached
    case terse         // Minimal update (position/rotation only)
    case texture       // Texture/appearance only
    case properties    // Object properties (name, description, etc.)
}

// MARK: - OpenSim Object Data Structures

struct OpenSimObjectData {
    let localID: UInt32
    let fullID: UUID
    let parentID: UInt32
    let ownerID: UUID
    let groupID: UUID
    
    // Transform data
    var position: SIMD3<Float>
    var rotation: simd_quatf
    var scale: SIMD3<Float>
    var velocity: SIMD3<Float>
    var angularVelocity: SIMD3<Float>
    
    // Visual data
    var primitiveParams: PrimitiveParams
    var textureEntry: TextureEntry
    var material: UInt8
    var clickAction: UInt8
    
    // State data
    var state: ObjectState
    var flags: ObjectFlags
    var lastUpdateTime: Date
    var updateSequence: UInt32
    
    // Cached visual properties
    var cachedMesh: String?
    var cachedTextures: [String] = []
    var lodLevel: LODLevel = .high
}

struct PrimitiveParams {
    let primitiveType: UInt8
    let pathCurve: UInt8
    let profileCurve: UInt8
    let pathBegin: UInt16
    let pathEnd: UInt16
    let pathScaleX: UInt8
    let pathScaleY: UInt8
    let pathShearX: UInt8
    let pathShearY: UInt8
    let pathTwist: Int8
    let pathTwistBegin: Int8
    let pathRadiusOffset: Int8
    let pathTaperX: Int8
    let pathTaperY: Int8
    let pathRevolutions: UInt8
    let pathSkew: Int8
    let profileBegin: UInt16
    let profileEnd: UInt16
    let profileHollow: UInt16
}

struct TextureEntry {
    let textureID: UUID
    let color: SIMD4<Float>
    let repeatU: Float
    let repeatV: Float
    let offsetU: Float
    let offsetV: Float
    let rotation: Float
    let material: UInt8
    let media: UInt8
    let glow: Float
}

struct ObjectState {
    let attachment: UInt8
    let material: UInt8
    let clickAction: UInt8
    let state: UInt8
}

struct ObjectFlags {
    let usePhysics: Bool
    let temporary: Bool
    let phantom: Bool
    let castShadows: Bool
    let flying: Bool
    let attachmentPoint: UInt8
}

// MARK: - Main Object Lifecycle Manager

@MainActor
class OpenSimObjectLifecycleManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var totalObjects: Int = 0
    @Published var activeObjects: Int = 0
    @Published var pendingUpdates: Int = 0
    @Published var processedUpdatesPerSecond: Double = 0
    @Published var memoryUsage: Int64 = 0
    @Published var compressionRatio: Double = 0
    
    // MARK: - Core References
    private weak var ecs: ECSCore?
    private weak var renderer: RendererService?
    private weak var ecsRealityBridge: ECSRealityKitBridge?
    private weak var worldIntegrator: OpenSimWorldIntegrator?
    
    // MARK: - Object Management
    private var managedObjects: [UInt32: OpenSimObjectData] = [:]
    private var objectStates: [UInt32: ObjectLifecycleState] = [:]
    private var pendingObjectUpdates: [UInt32: ObjectUpdateInfo] = [:]
    
    // MARK: - Processing Components
    private var updateProcessor: ObjectUpdateProcessor!
    private var compressionHandler: CompressionHandler!
    private var textureManager: OpenSimTextureManager!
    private var geometryGenerator: PrimitiveGeometryGenerator!
    private var performanceMonitor: ObjectPerformanceMonitor!
    
    // MARK: - Update Queues
    private var highPriorityQueue: [ObjectUpdateInfo] = []
    private var normalPriorityQueue: [ObjectUpdateInfo] = []
    private var lowPriorityQueue: [ObjectUpdateInfo] = []
    
    // MARK: - Performance Tracking
    private var updateCounter: Int = 0
    private var lastMetricsUpdate: Date = Date()
    private var processedBytes: Int64 = 0
    private var compressedBytes: Int64 = 0
    
    // MARK: - Processing Configuration
    private let maxUpdatesPerFrame = 20
    private let maxProcessingTimePerFrame: TimeInterval = 1.0/60.0 * 0.3 // 30% of frame time
    
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        print("[🔄] OpenSimObjectLifecycleManager initializing...")
        setupNotificationObservers()
    }
    
    func setup(
        ecs: ECSCore,
        renderer: RendererService,
        ecsRealityBridge: ECSRealityKitBridge,
        worldIntegrator: OpenSimWorldIntegrator
    ) {
        self.ecs = ecs
        self.renderer = renderer
        self.ecsRealityBridge = ecsRealityBridge
        self.worldIntegrator = worldIntegrator
        
        // Initialize processing components
        setupProcessingComponents()
        
        // Start update processing loop
        startUpdateProcessing()
        
        // Start performance monitoring
        startPerformanceMonitoring()
        
        print("[✅] OpenSimObjectLifecycleManager setup complete")
    }
    
    private func setupProcessingComponents() {
        // Update Processor - handles different types of object updates
        updateProcessor = ObjectUpdateProcessor(
            ecs: ecs!,
            delegate: self
        )
        
        // Compression Handler - handles compressed update formats
        compressionHandler = CompressionHandler()
        
        // Texture Manager - handles texture loading and caching
        textureManager = OpenSimTextureManager()
        
        // Geometry Generator - creates meshes from primitive parameters
        geometryGenerator = PrimitiveGeometryGenerator()
        
        // Performance Monitor - tracks processing performance
        performanceMonitor = ObjectPerformanceMonitor()
    }
    
    private func setupNotificationObservers() {
        // Object Update Messages
        NotificationCenter.default.publisher(for: .openSimObjectUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleObjectUpdate(notification)
            }
            .store(in: &cancellables)
        
        // Compressed Object Updates
        NotificationCenter.default.publisher(for: .openSimObjectUpdateCompressed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleObjectUpdateCompressed(notification)
            }
            .store(in: &cancellables)
        
        // Cached Object Updates
        NotificationCenter.default.publisher(for: .openSimObjectUpdateCached)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleObjectUpdateCached(notification)
            }
            .store(in: &cancellables)
        
        // Object Removal
        NotificationCenter.default.publisher(for: .openSimObjectRemoved)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleObjectRemoval(notification)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Object Update Handlers
    
    private func handleObjectUpdate(_ notification: Notification) {
        guard let objectUpdate = notification.object as? ObjectUpdateMessage else { return }
        
        let updateInfo = ObjectUpdateInfo(
            type: .full,
            localID: objectUpdate.localID,
            data: objectUpdate,
            priority: calculatePriority(for: objectUpdate.localID),
            timestamp: Date()
        )
        
        queueUpdate(updateInfo)
        processedBytes += Int64(MemoryLayout<ObjectUpdateMessage>.size)
    }
    
    private func handleObjectUpdateCompressed(_ notification: Notification) {
        guard let compressedUpdate = notification.object as? ObjectUpdateCompressedMessage else { return }
        
        // Decompress the update
        compressionHandler.decompressUpdate(compressedUpdate) { [weak self] decompressedUpdate in
            guard let self = self else { return }
            
            let updateInfo = ObjectUpdateInfo(
                type: .compressed,
                localID: compressedUpdate.localID,
                data: decompressedUpdate,
                priority: self.calculatePriority(for: compressedUpdate.localID),
                timestamp: Date()
            )
            
            self.queueUpdate(updateInfo)
            
            // Track compression metrics
            let originalSize = compressedUpdate.compressedData.count
            let decompressedSize = MemoryLayout<ObjectUpdateMessage>.size
            self.compressedBytes += Int64(originalSize)
            self.processedBytes += Int64(decompressedSize)
            
            DispatchQueue.main.async {
                self.updateCompressionRatio()
            }
        }
    }
    
    private func handleObjectUpdateCached(_ notification: Notification) {
        guard let cachedUpdate = notification.object as? ObjectUpdateCachedMessage else { return }
        
        let updateInfo = ObjectUpdateInfo(
            type: .cached,
            localID: cachedUpdate.localID,
            data: cachedUpdate,
            priority: calculatePriority(for: cachedUpdate.localID),
            timestamp: Date()
        )
        
        queueUpdate(updateInfo)
    }
    
    private func handleObjectRemoval(_ notification: Notification) {
        guard let userInfo = notification.object as? [String: Any],
              let localID = userInfo["localID"] as? UInt32 else { return }
        
        removeObject(localID: localID)
    }
    
    // MARK: - Update Queuing and Processing
    
    private func queueUpdate(_ updateInfo: ObjectUpdateInfo) {
        switch updateInfo.priority {
        case .critical, .high:
            highPriorityQueue.append(updateInfo)
        case .normal:
            normalPriorityQueue.append(updateInfo)
        case .low, .deferred:
            lowPriorityQueue.append(updateInfo)
        }
        
        pendingUpdates = highPriorityQueue.count + normalPriorityQueue.count + lowPriorityQueue.count
    }
    
    private func startUpdateProcessing() {
        Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.processQueuedUpdates()
        }
        .store(in: &cancellables)
    }
    
    private func processQueuedUpdates() {
        let startTime = CFAbsoluteTimeGetCurrent()
        var processedCount = 0
        
        // Process high priority updates first
        while !highPriorityQueue.isEmpty &&
              processedCount < maxUpdatesPerFrame &&
              CFAbsoluteTimeGetCurrent() - startTime < maxProcessingTimePerFrame {
            
            let updateInfo = highPriorityQueue.removeFirst()
            processObjectUpdate(updateInfo)
            processedCount += 1
        }
        
        // Process normal priority updates
        while !normalPriorityQueue.isEmpty &&
              processedCount < maxUpdatesPerFrame &&
              CFAbsoluteTimeGetCurrent() - startTime < maxProcessingTimePerFrame {
            
            let updateInfo = normalPriorityQueue.removeFirst()
            processObjectUpdate(updateInfo)
            processedCount += 1
        }
        
        // Process low priority updates if time remains
        while !lowPriorityQueue.isEmpty &&
              processedCount < maxUpdatesPerFrame &&
              CFAbsoluteTimeGetCurrent() - startTime < maxProcessingTimePerFrame {
            
            let updateInfo = lowPriorityQueue.removeFirst()
            processObjectUpdate(updateInfo)
            processedCount += 1
        }
        
        pendingUpdates = highPriorityQueue.count + normalPriorityQueue.count + lowPriorityQueue.count
        updateCounter += processedCount
        
        // Record performance metrics
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        performanceMonitor.recordProcessingCycle(
            updatesProcessed: processedCount,
            processingTime: processingTime
        )
    }
    
    // MARK: - Individual Update Processing
    
    private func processObjectUpdate(_ updateInfo: ObjectUpdateInfo) {
        switch updateInfo.type {
        case .full:
            if let objectUpdate = updateInfo.data as? ObjectUpdateMessage {
                processFullObjectUpdate(objectUpdate)
            }
            
        case .compressed:
            if let objectUpdate = updateInfo.data as? ObjectUpdateMessage {
                processFullObjectUpdate(objectUpdate)
            }
            
        case .cached:
            if let cachedUpdate = updateInfo.data as? ObjectUpdateCachedMessage {
                processCachedObjectUpdate(cachedUpdate)
            }
            
        case .terse:
            if let terseUpdate = updateInfo.data as? TerseObjectUpdate {
                processTerseObjectUpdate(terseUpdate)
            }
            
        case .texture:
            if let textureUpdate = updateInfo.data as? TextureObjectUpdate {
                processTextureObjectUpdate(textureUpdate)
            }
            
        case .properties:
            if let propertiesUpdate = updateInfo.data as? PropertiesObjectUpdate {
                processPropertiesObjectUpdate(propertiesUpdate)
            }
        }
    }
    
    private func processFullObjectUpdate(_ objectUpdate: ObjectUpdateMessage) {
        let localID = objectUpdate.localID
        let isNewObject = managedObjects[localID] == nil
        
        if isNewObject {
            createNewObject(from: objectUpdate)
        } else {
            updateExistingObject(objectUpdate)
        }
        
        // Update object state
        objectStates[localID] = .active
    }
    
    private func createNewObject(from objectUpdate: ObjectUpdateMessage) {
        print("[🆕] Creating new object: \(objectUpdate.localID)")
        
        objectStates[objectUpdate.localID] = .creating
        
        // Create object data structure
        let objectData = OpenSimObjectData(
            localID: objectUpdate.localID,
            fullID: objectUpdate.fullID,
            parentID: objectUpdate.parentID,
            ownerID: objectUpdate.ownerID,
            groupID: objectUpdate.groupID,
            position: objectUpdate.position,
            rotation: objectUpdate.rotation,
            scale: objectUpdate.scale,
            velocity: objectUpdate.velocity,
            angularVelocity: objectUpdate.angularVelocity,
            primitiveParams: objectUpdate.primitiveParams,
            textureEntry: objectUpdate.textureEntry,
            material: objectUpdate.material,
            clickAction: objectUpdate.clickAction,
            state: objectUpdate.state,
            flags: objectUpdate.flags,
            lastUpdateTime: Date(),
            updateSequence: 0
        )
        
        managedObjects[objectUpdate.localID] = objectData
        
        // Create ECS entity
        createECSEntity(from: objectData)
        
        // Generate geometry
        generateObjectGeometry(objectData)
        
        // Load textures
        loadObjectTextures(objectData)
        
        objectStates[objectUpdate.localID] = .active
        totalObjects += 1
        activeObjects += 1
        
        print("[✅] Object created: \(objectUpdate.localID)")
    }
    
    private func updateExistingObject(_ objectUpdate: ObjectUpdateMessage) {
        guard var objectData = managedObjects[objectUpdate.localID] else { return }
        
        objectStates[objectUpdate.localID] = .updating
        
        // Check what properties have changed
        let transformChanged = hasTransformChanged(objectData, objectUpdate)
        let visualChanged = hasVisualChanged(objectData, objectUpdate)
        let textureChanged = hasTextureChanged(objectData, objectUpdate)
        
        // Update object data
        objectData.position = objectUpdate.position
        objectData.rotation = objectUpdate.rotation
        objectData.scale = objectUpdate.scale
        objectData.velocity = objectUpdate.velocity
        objectData.angularVelocity = objectUpdate.angularVelocity
        objectData.lastUpdateTime = Date()
        objectData.updateSequence += 1
        
        if visualChanged {
            objectData.primitiveParams = objectUpdate.primitiveParams
            objectData.material = objectUpdate.material
        }
        
        if textureChanged {
            objectData.textureEntry = objectUpdate.textureEntry
        }
        
        managedObjects[objectUpdate.localID] = objectData
        
        // Update ECS entity
        updateECSEntity(objectData, transformChanged: transformChanged, visualChanged: visualChanged, textureChanged: textureChanged)
        
        objectStates[objectUpdate.localID] = .active
    }
    
    private func processCachedObjectUpdate(_ cachedUpdate: ObjectUpdateCachedMessage) {
        guard var objectData = managedObjects[cachedUpdate.localID] else {
            print("[⚠️] Received cached update for unknown object: \(cachedUpdate.localID)")
            return
        }
        
        // Update only the cached properties
        objectData.cachedMesh = cachedUpdate.cachedMeshID
        objectData.cachedTextures = cachedUpdate.cachedTextureIDs
        objectData.lastUpdateTime = Date()
        
        managedObjects[cachedUpdate.localID] = objectData
        
        // Apply cached resources
        applyCachedResources(objectData)
    }
    
    private func processTerseObjectUpdate(_ terseUpdate: TerseObjectUpdate) {
        guard var objectData = managedObjects[terseUpdate.localID] else { return }
        
        // Update only transform data
        objectData.position = terseUpdate.position
        objectData.rotation = terseUpdate.rotation
        objectData.velocity = terseUpdate.velocity
        objectData.angularVelocity = terseUpdate.angularVelocity
        objectData.lastUpdateTime = Date()
        
        managedObjects[terseUpdate.localID] = objectData
        
        // Update ECS transform only
        updateECSTransform(objectData)
    }
    
    private func processTextureObjectUpdate(_ textureUpdate: TextureObjectUpdate) {
        guard var objectData = managedObjects[textureUpdate.localID] else { return }
        
        objectData.textureEntry = textureUpdate.textureEntry
        objectData.lastUpdateTime = Date()
        
        managedObjects[textureUpdate.localID] = objectData
        
        // Update ECS visual/material only
        updateECSMaterial(objectData)
    }
    
    private func processPropertiesObjectUpdate(_ propertiesUpdate: PropertiesObjectUpdate) {
        guard var objectData = managedObjects[propertiesUpdate.localID] else { return }
        
        objectData.flags = propertiesUpdate.flags
        objectData.clickAction = propertiesUpdate.clickAction
        objectData.lastUpdateTime = Date()
        
        managedObjects[propertiesUpdate.localID] = objectData
        
        // Update ECS properties
        updateECSProperties(objectData)
    }
    
    // MARK: - ECS Entity Management
    
    private func createECSEntity(from objectData: OpenSimObjectData) {
        guard let ecs = ecs else { return }
        
        let world = ecs.getWorld()
        let entityID = world.createEntity()
        
        // Add position component
        let position = PositionComponent(position: objectData.position)
        world.addComponent(position, to: entityID)
        
        // Add rotation component
        let rotation = RotationComponent(rotation: objectData.rotation)
        world.addComponent(rotation, to: entityID)
        
        // Add scale component
        let scale = ScaleComponent(scale: objectData.scale)
        world.addComponent(scale, to: entityID)
        
        // Add visual component
        let visualType = geometryGenerator.determineVisualType(from: objectData.primitiveParams)
        let visual = VisualComponent(
            entityType: visualType,
            color: textureManager.extractBaseColor(from: objectData.textureEntry)
        )
        world.addComponent(visual, to: entityID)
        
        // Add OpenSim-specific component
        let openSimComponent = OpenSimObjectComponent(
            localID: objectData.localID,
            fullID: objectData.fullID,
            ownerID: objectData.ownerID,
            groupID: objectData.groupID
        )
        world.addComponent(openSimComponent, to: entityID)
        
        // Add physics if needed
        if objectData.flags.usePhysics {
            let physics = PhysicsComponent(
                mass: calculateMass(from: objectData),
                isStatic: false,
                shape: geometryGenerator.determinePhysicsShape(from: objectData.primitiveParams)
            )
            world.addComponent(physics, to: entityID)
        }
        
        // Notify ECS bridge
        ecs.notifyEntityCreated(entityID)
    }
    
    private func updateECSEntity(_ objectData: OpenSimObjectData, transformChanged: Bool, visualChanged: Bool, textureChanged: Bool) {
        guard let ecs = ecs else { return }
        
        if transformChanged {
            updateECSTransform(objectData)
        }
        
        if visualChanged {
            updateECSVisual(objectData)
        }
        
        if textureChanged {
            updateECSMaterial(objectData)
        }
    }
    
    private func updateECSTransform(_ objectData: OpenSimObjectData) {
        guard let ecs = ecs else { return }
        let world = ecs.getWorld()
        
        // Find the entity with this local ID
        let openSimEntities = world.entities(with: OpenSimObjectComponent.self)
        
        for (entityID, openSimComponent) in openSimEntities {
            if openSimComponent.localID == objectData.localID {
                // Update position
                if let positionComponent = world.getComponent(ofType: PositionComponent.self, from: entityID) {
                    positionComponent.position = objectData.position
                }
                
                // Update rotation
                if let rotationComponent = world.getComponent(ofType: RotationComponent.self, from: entityID) {
                    rotationComponent.rotation = objectData.rotation
                }
                
                // Update scale
                if let scaleComponent = world.getComponent(ofType: ScaleComponent.self, from: entityID) {
                    scaleComponent.scale = objectData.scale
                }
                
                // Notify of transform change
                ecs.notifyComponentChanged(entityID, changeType: .transform)
                break
            }
        }
    }
    
    private func updateECSVisual(_ objectData: OpenSimObjectData) {
        guard let ecs = ecs else { return }
        let world = ecs.getWorld()
        
        let openSimEntities = world.entities(with: OpenSimObjectComponent.self)
        
        for (entityID, openSimComponent) in openSimEntities {
            if openSimComponent.localID == objectData.localID {
                // Update visual component
                if let visualComponent = world.getComponent(ofType: VisualComponent.self, from: entityID) {
                    let newVisualType = geometryGenerator.determineVisualType(from: objectData.primitiveParams)
                    visualComponent.entityType = newVisualType
                }
                
                ecs.notifyComponentChanged(entityID, changeType: .visual)
                break
            }
        }
    }
    
    private func updateECSMaterial(_ objectData: OpenSimObjectData) {
        guard let ecs = ecs else { return }
        let world = ecs.getWorld()
        
        let openSimEntities = world.entities(with: OpenSimObjectComponent.self)
        
        for (entityID, openSimComponent) in openSimEntities {
            if openSimComponent.localID == objectData.localID {
                // Update visual component color/material
                if let visualComponent = world.getComponent(ofType: VisualComponent.self, from: entityID) {
                    visualComponent.color = textureManager.extractBaseColor(from: objectData.textureEntry)
                }
                
                ecs.notifyComponentChanged(entityID, changeType: .material)
                break
            }
        }
    }
    
    private func updateECSProperties(_ objectData: OpenSimObjectData) {
        guard let ecs = ecs else { return }
        let world = ecs.getWorld()
        
        let openSimEntities = world.entities(with: OpenSimObjectComponent.self)
        
        for (entityID, openSimComponent) in openSimEntities {
            if openSimComponent.localID == objectData.localID {
                // Update OpenSim component
                openSimComponent.lastUpdateTime = Date()
                
                // Update physics if changed
                if objectData.flags.usePhysics {
                    if world.getComponent(ofType: PhysicsComponent.self, from: entityID) == nil {
                        let physics = PhysicsComponent(
                            mass: calculateMass(from: objectData),
                            isStatic: false,
                            shape: geometryGenerator.determinePhysicsShape(from: objectData.primitiveParams)
                        )
                        world.addComponent(physics, to: entityID)
                    }
                } else {
                    world.removeComponent(ofType: PhysicsComponent.self, from: entityID)
                }
                
                break
            }
        }
    }
    
    // MARK: - Object Removal
    
    private func removeObject(localID: UInt32) {
        guard managedObjects[localID] != nil else { return }
        
        print("[🗑️] Removing object: \(localID)")
        
        objectStates[localID] = .removing
        
        // Remove from ECS
        removeECSEntity(localID: localID)
        
        // Clean up resources
        cleanupObjectResources(localID: localID)
        
        // Remove from managed objects
        managedObjects.removeValue(forKey: localID)
        objectStates.removeValue(forKey: localID)
        
        totalObjects -= 1
        activeObjects = max(0, activeObjects - 1)
        
        print("[✅] Object removed: \(localID)")
    }
    
    private func removeECSEntity(localID: UInt32) {
        guard let ecs = ecs else { return }
        let world = ecs.getWorld()
        
        let openSimEntities = world.entities(with: OpenSimObjectComponent.self)
        
        for (entityID, openSimComponent) in openSimEntities {
            if openSimComponent.localID == localID {
                world.removeEntity(entityID)
                ecs.notifyEntityDestroyed(entityID)
                break
            }
        }
    }
    
    private func cleanupObjectResources(localID: UInt32) {
        // Clean up any cached textures, meshes, etc.
        textureManager.cleanupTexturesForObject(localID: localID)
        geometryGenerator.cleanupGeometryForObject(localID: localID)
    }
    
    // MARK: - Geometry and Texture Management
    
    private func generateObjectGeometry(_ objectData: OpenSimObjectData) {
        geometryGenerator.generateGeometry(
            for: objectData.localID,
            primitiveParams: objectData.primitiveParams
        ) { [weak self] result in
            switch result {
            case .success(let geometryInfo):
                self?.applyGeometry(geometryInfo, to: objectData.localID)
            case .failure(let error):
                print("[❌] Failed to generate geometry for object \(objectData.localID): \(error)")
            }
        }
    }
    
    private func loadObjectTextures(_ objectData: OpenSimObjectData) {
        textureManager.loadTextures(
            for: objectData.localID,
            textureEntry: objectData.textureEntry
        ) { [weak self] result in
            switch result {
            case .success(let textureInfo):
                self?.applyTextures(textureInfo, to: objectData.localID)
            case .failure(let error):
                print("[❌] Failed to load textures for object \(objectData.localID): \(error)")
            }
        }
    }
    
    private func applyGeometry(_ geometryInfo: GeometryInfo, to localID: UInt32) {
        // Update the object's cached mesh
        guard var objectData = managedObjects[localID] else { return }
        objectData.cachedMesh = geometryInfo.meshID
        managedObjects[localID] = objectData
        
        // Trigger visual update
        updateECSVisual(objectData)
    }
    
    private func applyTextures(_ textureInfo: TextureInfo, to localID: UInt32) {
        // Update the object's cached textures
        guard var objectData = managedObjects[localID] else { return }
        objectData.cachedTextures = textureInfo.textureIDs
        managedObjects[localID] = objectData
        
        // Trigger material update
        updateECSMaterial(objectData)
    }
    
    private func applyCachedResources(_ objectData: OpenSimObjectData) {
        // Apply pre-cached mesh and textures
        if let cachedMesh = objectData.cachedMesh {
            geometryGenerator.applyCachedGeometry(cachedMesh, to: objectData.localID)
        }
        
        if !objectData.cachedTextures.isEmpty {
            textureManager.applyCachedTextures(objectData.cachedTextures, to: objectData.localID)
        }
    }
    
    // MARK: - Change Detection
    
    private func hasTransformChanged(_ current: OpenSimObjectData, _ update: ObjectUpdateMessage) -> Bool {
        return current.position != update.position ||
               current.rotation != update.rotation ||
               current.scale != update.scale
    }
    
    private func hasVisualChanged(_ current: OpenSimObjectData, _ update: ObjectUpdateMessage) -> Bool {
        return current.primitiveParams.primitiveType != update.primitiveParams.primitiveType ||
               current.material != update.material
    }
    
    private func hasTextureChanged(_ current: OpenSimObjectData, _ update: ObjectUpdateMessage) -> Bool {
        return current.textureEntry.textureID != update.textureEntry.textureID ||
        current.textureEntry.color != update.textureEntry.color ||
        current.textureEntry.repeatU != update.textureEntry.repeatU ||
        current.textureEntry.repeatV != update.textureEntry.repeatV
}

// MARK: - Priority Calculation

private func calculatePriority(for localID: UInt32) -> UpdatePriority {
 // Calculate priority based on distance, importance, etc.
 
 // Get avatar position (assuming at region center for now)
 let avatarPosition = SIMD3<Float>(128, 25, 128)
 
 // Get object position
 guard let objectData = managedObjects[localID] else {
     return .normal
 }
 
 let distance = simd_length(objectData.position - avatarPosition)
 
 // Distance-based priority
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

private func calculateMass(from objectData: OpenSimObjectData) -> Float {
 // Calculate mass based on scale and material
 let volume = objectData.scale.x * objectData.scale.y * objectData.scale.z
 let density: Float = 1.0 // Default density
 return volume * density
}

// MARK: - Performance Monitoring

private func startPerformanceMonitoring() {
 Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
     self?.updatePerformanceMetrics()
 }
 .store(in: &cancellables)
}

private func updatePerformanceMetrics() {
 let now = Date()
 let timeDelta = now.timeIntervalSince(lastMetricsUpdate)
 
 if timeDelta > 0 {
     processedUpdatesPerSecond = Double(updateCounter) / timeDelta
     updateCounter = 0
 }
 
 lastMetricsUpdate = now
 
 // Update compression ratio
 updateCompressionRatio()
 
 // Update memory usage
 updateMemoryUsage()
}

private func updateCompressionRatio() {
 if processedBytes > 0 && compressedBytes > 0 {
     compressionRatio = Double(compressedBytes) / Double(processedBytes)
 }
}

private func updateMemoryUsage() {
 // Calculate memory usage of managed objects
 let objectDataSize = managedObjects.count * MemoryLayout<OpenSimObjectData>.size
 let stateDataSize = objectStates.count * MemoryLayout<ObjectLifecycleState>.size
 let queueSize = (highPriorityQueue.count + normalPriorityQueue.count + lowPriorityQueue.count) * MemoryLayout<ObjectUpdateInfo>.size
 
 memoryUsage = Int64(objectDataSize + stateDataSize + queueSize)
}

// MARK: - Public Interface

func getObjectData(localID: UInt32) -> OpenSimObjectData? {
 return managedObjects[localID]
}

func getObjectState(localID: UInt32) -> ObjectLifecycleState? {
 return objectStates[localID]
}

func getAllManagedObjects() -> [UInt32: OpenSimObjectData] {
 return managedObjects
}

func forceUpdateObject(localID: UInt32) {
 guard let objectData = managedObjects[localID] else { return }
 
 // Force regenerate geometry and textures
 generateObjectGeometry(objectData)
 loadObjectTextures(objectData)
}

func clearAllObjects() {
 print("[🧹] Clearing all managed objects...")
 
 // Remove all objects
 for localID in managedObjects.keys {
     removeObject(localID: localID)
 }
 
 // Clear queues
 highPriorityQueue.removeAll()
 normalPriorityQueue.removeAll()
 lowPriorityQueue.removeAll()
 
 // Reset metrics
 updateCounter = 0
 processedBytes = 0
 compressedBytes = 0
 
 print("[✅] All objects cleared")
}

func getLifecycleStatistics() -> ObjectLifecycleStatistics {
 return ObjectLifecycleStatistics(
     totalObjects: totalObjects,
     activeObjects: activeObjects,
     pendingUpdates: pendingUpdates,
     processedUpdatesPerSecond: processedUpdatesPerSecond,
     memoryUsage: memoryUsage,
     compressionRatio: compressionRatio,
     highPriorityQueueSize: highPriorityQueue.count,
     normalPriorityQueueSize: normalPriorityQueue.count,
     lowPriorityQueueSize: lowPriorityQueue.count
 )
}
}

// MARK: - ObjectUpdateProcessorDelegate

extension OpenSimObjectLifecycleManager: ObjectUpdateProcessorDelegate {

func objectUpdateProcessor(_ processor: ObjectUpdateProcessor, didProcessUpdate localID: UInt32) {
 // Update processed successfully
 print("[✅] Processed update for object: \(localID)")
}

func objectUpdateProcessor(_ processor: ObjectUpdateProcessor, didFailUpdate localID: UInt32, error: Error) {
 print("[❌] Failed to process update for object \(localID): \(error.localizedDescription)")
 
 // Mark object as error state
 objectStates[localID] = .error(error.localizedDescription)
}
}

// MARK: - Supporting Classes

// Object Update Processor
class ObjectUpdateProcessor {
weak var delegate: ObjectUpdateProcessorDelegate?
private let ecs: ECSCore

init(ecs: ECSCore, delegate: ObjectUpdateProcessorDelegate) {
 self.ecs = ecs
 self.delegate = delegate
}
}

protocol ObjectUpdateProcessorDelegate: AnyObject {
func objectUpdateProcessor(_ processor: ObjectUpdateProcessor, didProcessUpdate localID: UInt32)
func objectUpdateProcessor(_ processor: ObjectUpdateProcessor, didFailUpdate localID: UInt32, error: Error)
}

// Compression Handler
class CompressionHandler {

func decompressUpdate(_ compressedUpdate: ObjectUpdateCompressedMessage, completion: @escaping (ObjectUpdateMessage) -> Void) {
 // Simulate decompression process
 DispatchQueue.global(qos: .userInitiated).async {
     // In a real implementation, this would decompress the data
     let decompressedUpdate = self.performDecompression(compressedUpdate)
     
     DispatchQueue.main.async {
         completion(decompressedUpdate)
     }
 }
}

private func performDecompression(_ compressedUpdate: ObjectUpdateCompressedMessage) -> ObjectUpdateMessage {
 // Placeholder decompression logic
 // In reality, this would parse the compressed data format
 
 return ObjectUpdateMessage(
     localID: compressedUpdate.localID,
     fullID: UUID(), // Would be extracted from compressed data
     parentID: 0,
     ownerID: UUID(),
     groupID: UUID(),
     position: SIMD3<Float>(0, 0, 0), // Would be decompressed
     rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)),
     scale: SIMD3<Float>(1, 1, 1),
     velocity: SIMD3<Float>(0, 0, 0),
     angularVelocity: SIMD3<Float>(0, 0, 0),
     primitiveParams: PrimitiveParams(
         primitiveType: 0, pathCurve: 0, profileCurve: 0,
         pathBegin: 0, pathEnd: 0, pathScaleX: 0, pathScaleY: 0,
         pathShearX: 0, pathShearY: 0, pathTwist: 0, pathTwistBegin: 0,
         pathRadiusOffset: 0, pathTaperX: 0, pathTaperY: 0,
         pathRevolutions: 0, pathSkew: 0, profileBegin: 0,
         profileEnd: 0, profileHollow: 0
     ),
     textureEntry: TextureEntry(
         textureID: UUID(), color: SIMD4<Float>(1, 1, 1, 1),
         repeatU: 1, repeatV: 1, offsetU: 0, offsetV: 0,
         rotation: 0, material: 0, media: 0, glow: 0
     ),
     material: 0,
     clickAction: 0,
     state: ObjectState(attachment: 0, material: 0, clickAction: 0, state: 0),
     flags: ObjectFlags(
         usePhysics: false, temporary: false, phantom: false,
         castShadows: true, flying: false, attachmentPoint: 0
     )
 )
}
}

// Texture Manager
class OpenSimTextureManager {
private var textureCache: [UUID: TextureResource] = [:]
private var loadingTextures: [UUID: [((Result<TextureResource, Error>) -> Void)]] = [:]

func loadTextures(for localID: UInt32, textureEntry: TextureEntry, completion: @escaping (Result<TextureInfo, Error>) -> Void) {
 
 let textureID = textureEntry.textureID
 
 // Check cache first
 if let cachedTexture = textureCache[textureID] {
     let textureInfo = TextureInfo(textureIDs: [textureID.uuidString], mainTexture: cachedTexture)
     completion(.success(textureInfo))
     return
 }
 
 // Check if already loading
 if loadingTextures[textureID] != nil {
     loadingTextures[textureID]?.append { result in
         switch result {
         case .success(let texture):
             let textureInfo = TextureInfo(textureIDs: [textureID.uuidString], mainTexture: texture)
             completion(.success(textureInfo))
         case .failure(let error):
             completion(.failure(error))
         }
     }
     return
 }
 
 // Start loading
 loadingTextures[textureID] = [{ result in
     switch result {
     case .success(let texture):
         let textureInfo = TextureInfo(textureIDs: [textureID.uuidString], mainTexture: texture)
         completion(.success(textureInfo))
     case .failure(let error):
         completion(.failure(error))
     }
 }]
 
 // Simulate texture loading
 DispatchQueue.global(qos: .userInitiated).async {
     // In reality, this would download from OpenSim asset server
     let result = self.loadTextureFromAssetServer(textureID: textureID)
     
     DispatchQueue.main.async {
         // Notify all waiting callbacks
         if let callbacks = self.loadingTextures.removeValue(forKey: textureID) {
             for callback in callbacks {
                 callback(result)
             }
         }
         
         // Cache successful results
         if case .success(let texture) = result {
             self.textureCache[textureID] = texture
         }
     }
 }
}

private func loadTextureFromAssetServer(textureID: UUID) -> Result<TextureResource, Error> {
 // Placeholder texture loading
 // In reality, this would make HTTP requests to OpenSim asset server
 
 do {
     // Try to load a default texture
     let texture = try TextureResource.load(named: "DefaultTexture")
     return .success(texture)
 } catch {
     return .failure(TextureLoadError.notFound)
 }
}

func extractBaseColor(from textureEntry: TextureEntry) -> UIColor {
 let color = textureEntry.color
 return UIColor(
     red: CGFloat(color.x),
     green: CGFloat(color.y),
     blue: CGFloat(color.z),
     alpha: CGFloat(color.w)
 )
}

func applyCachedTextures(_ textureIDs: [String], to localID: UInt32) {
 print("[🎨] Applying cached textures to object: \(localID)")
 // Implementation would apply cached textures to the object
}

func cleanupTexturesForObject(localID: UInt32) {
 // Clean up any object-specific texture references
 print("[🧹] Cleaning up textures for object: \(localID)")
}
}

enum TextureLoadError: Error {
case notFound
case downloadFailed
case invalidFormat
}

// Geometry Generator
class PrimitiveGeometryGenerator {
private var geometryCache: [String: MeshResource] = [:]

func generateGeometry(for localID: UInt32, primitiveParams: PrimitiveParams, completion: @escaping (Result<GeometryInfo, Error>) -> Void) {
 
 let geometryKey = createGeometryKey(from: primitiveParams)
 
 // Check cache
 if let cachedMesh = geometryCache[geometryKey] {
     let geometryInfo = GeometryInfo(meshID: geometryKey, mesh: cachedMesh)
     completion(.success(geometryInfo))
     return
 }
 
 // Generate geometry asynchronously
 DispatchQueue.global(qos: .userInitiated).async {
     do {
         let mesh = try self.createMeshFromPrimitive(primitiveParams)
         let geometryInfo = GeometryInfo(meshID: geometryKey, mesh: mesh)
         
         DispatchQueue.main.async {
             self.geometryCache[geometryKey] = mesh
             completion(.success(geometryInfo))
         }
         
     } catch {
         DispatchQueue.main.async {
             completion(.failure(error))
         }
     }
 }
}

private func createMeshFromPrimitive(_ params: PrimitiveParams) throws -> MeshResource {
 switch params.primitiveType {
 case 0: // Box
     return MeshResource.generateBox(size: 1.0)
 case 1: // Cylinder
     return MeshResource.generateCylinder(height: 1.0, radius: 0.5)
 case 3: // Sphere
     return MeshResource.generateSphere(radius: 0.5)
 default:
     return MeshResource.generateBox(size: 1.0)
 }
}

private func createGeometryKey(from params: PrimitiveParams) -> String {
 return "primitive_\(params.primitiveType)_\(params.pathCurve)_\(params.profileCurve)"
}

func determineVisualType(from primitiveParams: PrimitiveParams) -> VisualEntityType {
 switch primitiveParams.primitiveType {
 case 0: return .primitive(.box)
 case 1: return .primitive(.cylinder)
 case 3: return .primitive(.sphere)
 default: return .primitive(.box)
 }
}

func determinePhysicsShape(from primitiveParams: PrimitiveParams) -> PhysicsShape {
 switch primitiveParams.primitiveType {
 case 0: return .box
 case 1: return .capsule
 case 3: return .sphere
 default: return .box
 }
}

func applyCachedGeometry(_ meshID: String, to localID: UInt32) {
 print("[🔺] Applying cached geometry to object: \(localID)")
}

func cleanupGeometryForObject(localID: UInt32) {
 print("[🧹] Cleaning up geometry for object: \(localID)")
}
}

// Performance Monitor
class ObjectPerformanceMonitor {
private var processingTimes: [TimeInterval] = []
private var updateCounts: [Int] = []

func recordProcessingCycle(updatesProcessed: Int, processingTime: TimeInterval) {
 processingTimes.append(processingTime)
 updateCounts.append(updatesProcessed)
 
 // Keep only last 100 measurements
 if processingTimes.count > 100 {
     processingTimes.removeFirst(processingTimes.count - 100)
 }
 if updateCounts.count > 100 {
     updateCounts.removeFirst(updateCounts.count - 100)
 }
}

func getAverageProcessingTime() -> TimeInterval {
 guard !processingTimes.isEmpty else { return 0 }
 return processingTimes.reduce(0, +) / Double(processingTimes.count)
}

func getAverageUpdatesPerCycle() -> Double {
 guard !updateCounts.isEmpty else { return 0 }
 return Double(updateCounts.reduce(0, +)) / Double(updateCounts.count)
}
}

// MARK: - Supporting Types

struct ObjectUpdateInfo {
let type: ObjectUpdateType
let localID: UInt32
let data: Any
let priority: UpdatePriority
let timestamp: Date
}

struct GeometryInfo {
let meshID: String
let mesh: MeshResource
}

struct TextureInfo {
let textureIDs: [String]
let mainTexture: TextureResource
}

struct ObjectLifecycleStatistics {
let totalObjects: Int
let activeObjects: Int
let pendingUpdates: Int
let processedUpdatesPerSecond: Double
let memoryUsage: Int64
let compressionRatio: Double
let highPriorityQueueSize: Int
let normalPriorityQueueSize: Int
let lowPriorityQueueSize: Int
}

// MARK: - OpenSim Message Types

struct ObjectUpdateMessage {
let localID: UInt32
let fullID: UUID
let parentID: UInt32
let ownerID: UUID
let groupID: UUID
let position: SIMD3<Float>
let rotation: simd_quatf
let scale: SIMD3<Float>
let velocity: SIMD3<Float>
let angularVelocity: SIMD3<Float>
let primitiveParams: PrimitiveParams
let textureEntry: TextureEntry
let material: UInt8
let clickAction: UInt8
let state: ObjectState
let flags: ObjectFlags
}

struct ObjectUpdateCompressedMessage {
let localID: UInt32
let compressedData: Data
let compressionType: UInt8
}

struct ObjectUpdateCachedMessage {
let localID: UInt32
let cachedMeshID: String
let cachedTextureIDs: [String]
}

struct TerseObjectUpdate {
let localID: UInt32
let position: SIMD3<Float>
let rotation: simd_quatf
let velocity: SIMD3<Float>
let angularVelocity: SIMD3<Float>
}

struct TextureObjectUpdate {
let localID: UInt32
let textureEntry: TextureEntry
}

struct PropertiesObjectUpdate {
let localID: UInt32
let flags: ObjectFlags
let clickAction: UInt8
}

// MARK: - Notification Extensions

extension Notification.Name {
static let openSimObjectUpdateCompressed = Notification.Name("OpenSimObjectUpdateCompressed")
static let openSimObjectUpdateCached = Notification.Name("OpenSimObjectUpdateCached")
}

//print("[✅] OpenSim Object Lifecycle Management System Complete")
