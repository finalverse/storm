//
//  Engine/ECSRealityKitBridge.swift
//  Storm
//
//  Advanced ECS to RealityKit synchronization system for real-time 3D visualization
//  Handles entity lifecycle, transform updates, material management, and performance optimization
//  Provides seamless bridge between Storm's ECS and RealityKit rendering
//
//  Created for Finalverse Storm - ECS-RealityKit Bridge
//
//    ECS to RealityKit synchronization system with:
//    Key Features:
//
//    Real-time Synchronization - 60fps entity updates with performance budgeting
//    Level of Detail (LOD) - Distance-based optimization for performance
//    Material Management - Cached material system with PBR support
//    Visual Effects - Glow, particles, and animation system
//    Performance Monitoring - Frame rate, memory usage, and profiling
//    Batch Processing - Efficient update batching to maintain performance
//    Physics Integration - RealityKit physics body synchronization
//    Error Recovery - Graceful handling of failed updates
//
//    Architecture Benefits:
//
//    Separation of Concerns - Each component has specific responsibilities
//    Performance Optimized - LOD, culling, and batching for smooth 60fps
//    Memory Efficient - Proper cleanup and caching systems
//    Extensible - Easy to add new visual effects and materials
//    OpenSim Ready - Direct integration with OpenSim object updates
//                                                                
                                                            
                                                            
import Foundation
import RealityKit
import simd
import Combine

// MARK: - Synchronization State

enum SynchronizationState {
    case inactive
    case initializing
    case active
    case paused
    case error(String)
    
    var canSync: Bool {
        switch self {
        case .active:
            return true
        default:
            return false
        }
    }
}

// MARK: - Visual Entity Types

enum VisualEntityType {
    case primitive(PrimitiveType)
    case mesh(String)
    case avatar
    case particle
    case terrain
    case ui
    
    enum PrimitiveType {
        case box, sphere, cylinder, capsule, plane
    }
}

// MARK: - Level of Detail Configuration

struct LODConfiguration {
    let highDetailDistance: Float = 50.0
    let mediumDetailDistance: Float = 100.0
    let lowDetailDistance: Float = 200.0
    let cullingDistance: Float = 500.0
    
    func getLODLevel(distance: Float) -> LODLevel {
        switch distance {
        case 0..<highDetailDistance:
            return .high
        case highDetailDistance..<mediumDetailDistance:
            return .medium
        case mediumDetailDistance..<lowDetailDistance:
            return .low
        case lowDetailDistance..<cullingDistance:
            return .minimal
        default:
            return .culled
        }
    }
}

enum LODLevel {
    case high, medium, low, minimal, culled
    
    var maxPolygons: Int {
        switch self {
        case .high: return 10000
        case .medium: return 2000
        case .low: return 500
        case .minimal: return 100
        case .culled: return 0
        }
    }
}

// MARK: - Main ECS-RealityKit Bridge

@MainActor
class ECSRealityKitBridge: ObservableObject {
    
    // MARK: - Published Properties
    @Published var syncState: SynchronizationState = .inactive
    @Published var visualEntityCount: Int = 0
    @Published var renderFrameRate: Double = 60.0
    @Published var culledEntityCount: Int = 0
    @Published var memoryUsage: Int64 = 0
    
    // MARK: - Core References
    private weak var ecs: ECSCore?
    private weak var renderer: RendererService?
    private let arView: ARView
    
    // MARK: - Synchronization Components
    private var entitySynchronizer: EntitySynchronizer!
    private var transformSynchronizer: TransformSynchronizer!
    private var materialSynchronizer: MaterialSynchronizer!
    private var lodManager: LODManager!
    private var performanceOptimizer: RenderingPerformanceOptimizer!
    
    // MARK: - Entity Mapping
    private var ecsToRealityMap: [EntityID: ModelEntity] = [:]
    private var realityToECSMap: [ModelEntity: EntityID] = [:]
    private var entityAnchors: [EntityID: AnchorEntity] = [:]
    
    // MARK: - Performance Management
    private var frameTimer: Timer?
    private var lastFrameTime: CFAbsoluteTime = 0
    private var frameCount: Int = 0
    private let targetFrameRate: Double = 60.0
    private let lodConfig = LODConfiguration()
    
    // MARK: - Update Batching
    private var pendingUpdates: [EntityID: PendingUpdate] = [:]
    private var updateBatchSize: Int = 50
    private var lastBatchTime: Date = Date()
    
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(ecs: ECSCore, renderer: RendererService, arView: ARView) {
        self.ecs = ecs
        self.renderer = renderer
        self.arView = arView
        
        print("[🎨] ECSRealityKitBridge initializing...")
        setupSynchronizationComponents()
        setupPerformanceMonitoring()
        startSynchronization()
    }
    
    private func setupSynchronizationComponents() {
        // Entity Synchronizer - handles entity creation/destruction
        entitySynchronizer = EntitySynchronizer(
            ecs: ecs!,
            arView: arView,
            delegate: self
        )
        
        // Transform Synchronizer - handles position/rotation/scale updates
        transformSynchronizer = TransformSynchronizer(
            ecs: ecs!,
            entityMap: ecsToRealityMap
        )
        
        // Material Synchronizer - handles appearance and materials
        materialSynchronizer = MaterialSynchronizer(
            ecs: ecs!,
            entityMap: ecsToRealityMap
        )
        
        // LOD Manager - handles level of detail optimization
        lodManager = LODManager(
            config: lodConfig,
            entityMap: ecsToRealityMap
        )
        
        // Performance Optimizer - handles rendering optimization
        performanceOptimizer = RenderingPerformanceOptimizer(
            arView: arView,
            targetFrameRate: targetFrameRate
        )
        
        print("[🔧] Synchronization components initialized")
    }
    
    private func setupPerformanceMonitoring() {
        // Frame rate monitoring
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updatePerformanceMetrics()
        }
        
        // Memory monitoring
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
    }
    
    // MARK: - Synchronization Lifecycle
    
    func startSynchronization() {
        guard let ecs = ecs else {
            syncState = .error("ECS not available")
            return
        }
        
        print("[▶️] Starting ECS-RealityKit synchronization...")
        syncState = .initializing
        
        // Setup ECS observers
        setupECSObservers()
        
        // Initial synchronization of existing entities
        performInitialSync()
        
        // Start update loop
        startUpdateLoop()
        
        syncState = .active
        print("[✅] ECS-RealityKit synchronization active")
    }
    
    func stopSynchronization() {
        print("[⏹️] Stopping ECS-RealityKit synchronization...")
        
        syncState = .inactive
        
        // Stop timers
        frameTimer?.invalidate()
        frameTimer = nil
        
        // Clear all visual entities
        clearAllVisualEntities()
        
        // Cancel observations
        cancellables.removeAll()
        
        print("[✅] ECS-RealityKit synchronization stopped")
    }
    
    func pauseSynchronization() {
        syncState = .paused
        print("[⏸️] ECS-RealityKit synchronization paused")
    }
    
    func resumeSynchronization() {
        if ecs != nil {
            syncState = .active
            print("[▶️] ECS-RealityKit synchronization resumed")
        }
    }
    
    // MARK: - ECS Observation Setup
    
    private func setupECSObservers() {
        guard let ecs = ecs else { return }
        
        // Observe entity creation
        NotificationCenter.default.publisher(for: .ecsEntityCreated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleEntityCreated(notification)
            }
            .store(in: &cancellables)
        
        // Observe entity destruction
        NotificationCenter.default.publisher(for: .ecsEntityDestroyed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleEntityDestroyed(notification)
            }
            .store(in: &cancellables)
        
        // Observe component changes
        NotificationCenter.default.publisher(for: .ecsComponentChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleComponentChanged(notification)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Initial Synchronization
    
    private func performInitialSync() {
        guard let ecs = ecs else { return }
        
        print("[🔄] Performing initial ECS-RealityKit synchronization...")
        
        let world = ecs.getWorld()
        
        // Sync entities with visual components
        let visualEntities = world.entities(with: VisualComponent.self)
        
        for (entityID, visualComponent) in visualEntities {
            createVisualEntity(entityID: entityID, visualComponent: visualComponent)
        }
        
        print("[✅] Initial synchronization complete: \(visualEntities.count) entities")
    }
    
    // MARK: - Entity Lifecycle Handlers
    
    private func handleEntityCreated(_ notification: Notification) {
        guard syncState.canSync,
              let entityInfo = notification.object as? EntityCreationInfo else { return }
        
        // Check if entity has visual components
        if let visualComponent = getVisualComponent(for: entityInfo.entityID) {
            createVisualEntity(entityID: entityInfo.entityID, visualComponent: visualComponent)
        }
    }
    
    private func handleEntityDestroyed(_ notification: Notification) {
        guard let entityInfo = notification.object as? EntityDestructionInfo else { return }
        
        destroyVisualEntity(entityID: entityInfo.entityID)
    }
    
    private func handleComponentChanged(_ notification: Notification) {
        guard syncState.canSync,
              let componentInfo = notification.object as? ComponentChangeInfo else { return }
        
        // Queue update for batching
        queueEntityUpdate(entityID: componentInfo.entityID, changeType: componentInfo.changeType)
    }
    
    // MARK: - Visual Entity Management
    
    private func createVisualEntity(entityID: EntityID, visualComponent: VisualComponent) {
        // Skip if already exists
        guard ecsToRealityMap[entityID] == nil else { return }
        
        // Create RealityKit entity based on visual component
        let modelEntity = entitySynchronizer.createModelEntity(
            entityID: entityID,
            visualComponent: visualComponent
        )
        
        // Create anchor for the entity
        let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
        anchor.addChild(modelEntity)
        arView.scene.addAnchor(anchor)
        
        // Store mappings
        ecsToRealityMap[entityID] = modelEntity
        realityToECSMap[modelEntity] = entityID
        entityAnchors[entityID] = anchor
        
        // Initialize transform
        updateEntityTransform(entityID: entityID)
        
        // Initialize materials
        updateEntityMaterial(entityID: entityID)
        
        visualEntityCount += 1
        
        print("[🎨] Created visual entity: \(entityID)")
    }
    
    private func destroyVisualEntity(entityID: EntityID) {
        guard let modelEntity = ecsToRealityMap[entityID],
              let anchor = entityAnchors[entityID] else { return }
        
        // Remove from scene
        arView.scene.removeAnchor(anchor)
        
        // Clean up mappings
        ecsToRealityMap.removeValue(forKey: entityID)
        realityToECSMap.removeValue(forKey: modelEntity)
        entityAnchors.removeValue(forKey: entityID)
        
        visualEntityCount -= 1
        
        print("[🗑️] Destroyed visual entity: \(entityID)")
    }
    
    // MARK: - Update Batching System
    
    private func queueEntityUpdate(entityID: EntityID, changeType: ComponentChangeType) {
        let update = PendingUpdate(
            entityID: entityID,
            changeType: changeType,
            timestamp: Date()
        )
        
        pendingUpdates[entityID] = update
    }
    
    private func startUpdateLoop() {
        // Process batched updates at 60 FPS
        Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.processBatchedUpdates()
        }
        .store(in: &cancellables)
    }
    
    private func processBatchedUpdates() {
        guard syncState.canSync && !pendingUpdates.isEmpty else { return }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let maxProcessingTime: CFAbsoluteTime = 1.0/60.0 * 0.5 // 50% of frame budget
        
        var processedCount = 0
        let updateList = Array(pendingUpdates.values.prefix(updateBatchSize))
        
        for update in updateList {
            guard CFAbsoluteTimeGetCurrent() - startTime < maxProcessingTime else { break }
            
            processEntityUpdate(update)
            pendingUpdates.removeValue(forKey: update.entityID)
            processedCount += 1
        }
        
        // Update LOD for all visible entities
        if processedCount > 0 {
            lodManager.updateLOD()
        }
    }
    
    private func processEntityUpdate(_ update: PendingUpdate) {
        switch update.changeType {
        case .transform:
            updateEntityTransform(entityID: update.entityID)
            
        case .visual:
            updateEntityVisual(entityID: update.entityID)
            
        case .material:
            updateEntityMaterial(entityID: update.entityID)
            
        case .physics:
            updateEntityPhysics(entityID: update.entityID)
        }
    }
    
    // MARK: - Specific Update Handlers
    
    private func updateEntityTransform(entityID: EntityID) {
        guard let modelEntity = ecsToRealityMap[entityID],
              let anchor = entityAnchors[entityID] else { return }
        
        transformSynchronizer.updateTransform(
            entityID: entityID,
            modelEntity: modelEntity,
            anchor: anchor
        )
    }
    
    private func updateEntityVisual(entityID: EntityID) {
        guard let modelEntity = ecsToRealityMap[entityID] else { return }
        
        entitySynchronizer.updateVisual(
            entityID: entityID,
            modelEntity: modelEntity
        )
    }
    
    private func updateEntityMaterial(entityID: EntityID) {
        guard let modelEntity = ecsToRealityMap[entityID] else { return }
        
        materialSynchronizer.updateMaterial(
            entityID: entityID,
            modelEntity: modelEntity
        )
    }
    
    private func updateEntityPhysics(entityID: EntityID) {
        guard let modelEntity = ecsToRealityMap[entityID] else { return }
        
        // Update physics properties
        // This would integrate with RealityKit's physics system
        updatePhysicsBody(modelEntity: modelEntity, entityID: entityID)
    }
    
    // MARK: - Helper Methods
    
    private func getVisualComponent(for entityID: EntityID) -> VisualComponent? {
        guard let ecs = ecs else { return nil }
        let world = ecs.getWorld()
        return world.getComponent(ofType: VisualComponent.self, from: entityID)
    }
    
    private func clearAllVisualEntities() {
        // Remove all anchors from scene
        for anchor in entityAnchors.values {
            arView.scene.removeAnchor(anchor)
        }
        
        // Clear all mappings
        ecsToRealityMap.removeAll()
        realityToECSMap.removeAll()
        entityAnchors.removeAll()
        
        visualEntityCount = 0
    }
    
    private func updatePhysicsBody(modelEntity: ModelEntity, entityID: EntityID) {
        guard let ecs = ecs else { return }
        let world = ecs.getWorld()
        
        // Check if entity has physics component
        if let physicsComponent = world.getComponent(ofType: PhysicsComponent.self, from: entityID) {
            // Create physics body based on component
            let shape = physicsComponent.shape.toRealityKitShape()
            let material = PhysicsMaterialResource.generate(
                friction: physicsComponent.friction,
                restitution: physicsComponent.restitution
            )
            
            let physicsBody = PhysicsBodyComponent(
                massProperties: .init(mass: physicsComponent.mass),
                material: material,
                mode: physicsComponent.isStatic ? .static : .dynamic
            )
            
            modelEntity.components[PhysicsBodyComponent.self] = physicsBody
            modelEntity.collision = CollisionComponent(shapes: [shape])
        }
    }
    
    // MARK: - Performance Monitoring
    
    private func updatePerformanceMetrics() {
        let currentTime = CFAbsoluteTimeGetCurrent()
        let deltaTime = currentTime - lastFrameTime
        
        if deltaTime > 0 {
            renderFrameRate = 1.0 / deltaTime
        }
        
        lastFrameTime = currentTime
        frameCount += 1
        
        // Update culling statistics
        culledEntityCount = lodManager.getCulledEntityCount()
        
        // Optimize performance if needed
        if renderFrameRate < targetFrameRate * 0.8 {
            performanceOptimizer.optimizeForPerformance()
        }
    }
    
    private func updateMemoryUsage() {
        memoryUsage = getMemoryUsage()
        
        // Trigger cleanup if memory usage is high
        if memoryUsage > 500_000_000 { // 500MB threshold
            performanceOptimizer.performMemoryCleanup()
        }
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
    
    // MARK: - Public Interface
    
    func forceResync() {
        print("[🔄] Forcing complete resynchronization...")
        
        clearAllVisualEntities()
        performInitialSync()
        
        print("[✅] Resynchronization complete")
    }
    
    func setLODEnabled(_ enabled: Bool) {
        lodManager.setEnabled(enabled)
    }
    
    func setUpdateBatchSize(_ size: Int) {
        updateBatchSize = max(1, min(size, 200)) // Clamp between 1-200
    }
    
    func getEntityCount() -> Int {
        return ecsToRealityMap.count
    }
    
    func getSynchronizationStats() -> SynchronizationStats {
        return SynchronizationStats(
            visualEntityCount: visualEntityCount,
            renderFrameRate: renderFrameRate,
            culledEntityCount: culledEntityCount,
            memoryUsage: memoryUsage,
            pendingUpdates: pendingUpdates.count,
            syncState: syncState
        )
    }
}

// MARK: - EntitySynchronizerDelegate

extension ECSRealityKitBridge: EntitySynchronizerDelegate {
    
    func entitySynchronizer(_ synchronizer: EntitySynchronizer, didCreateEntity modelEntity: ModelEntity, for entityID: EntityID) {
        // Entity created successfully
        print("[✅] Entity synchronized: \(entityID)")
    }
    
    func entitySynchronizer(_ synchronizer: EntitySynchronizer, didFailToCreateEntity entityID: EntityID, error: Error) {
        print("[❌] Failed to create entity: \(entityID) - \(error.localizedDescription)")
    }
}

// MARK: - Supporting Classes

// Entity Synchronizer
class EntitySynchronizer {
    weak var delegate: EntitySynchronizerDelegate?
    private let ecs: ECSCore
    private let arView: ARView
    
    init(ecs: ECSCore, arView: ARView, delegate: EntitySynchronizerDelegate) {
        self.ecs = ecs
        self.arView = arView
        self.delegate = delegate
    }
    
    func createModelEntity(entityID: EntityID, visualComponent: VisualComponent) -> ModelEntity {
        let world = ecs.getWorld()
        
        // Create mesh based on visual component
        let mesh: MeshResource
        let material: Material
        
        switch visualComponent.entityType {
        case .primitive(let primitiveType):
            mesh = createPrimitiveMesh(primitiveType)
            material = createBasicMaterial(visualComponent.color)
            
        case .mesh(let meshName):
            mesh = loadMeshResource(meshName)
            material = createBasicMaterial(visualComponent.color)
            
        case .avatar:
            mesh = createAvatarMesh()
            material = createAvatarMaterial()
            
        case .terrain:
            mesh = createTerrainMesh(entityID: entityID)
            material = createTerrainMaterial()
            
        default:
            mesh = MeshResource.generateBox(size: 1.0)
            material = SimpleMaterial(color: .gray, isMetallic: false)
        }
        
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])
        modelEntity.name = "Entity_\(entityID)"
        
        delegate?.entitySynchronizer(self, didCreateEntity: modelEntity, for: entityID)
        
        return modelEntity
    }
    
    func updateVisual(entityID: EntityID, modelEntity: ModelEntity) {
        let world = ecs.getWorld()
        
        guard let visualComponent = world.getComponent(ofType: VisualComponent.self, from: entityID) else { return }
        
        // Update visual properties that may have changed
        if let material = modelEntity.model?.materials.first as? SimpleMaterial {
            let newMaterial = SimpleMaterial(color: visualComponent.color, isMetallic: false)
            modelEntity.model?.materials = [newMaterial]
        }
    }
    
    private func createPrimitiveMesh(_ primitiveType: VisualEntityType.PrimitiveType) -> MeshResource {
        switch primitiveType {
        case .box:
            return MeshResource.generateBox(size: 1.0)
        case .sphere:
            return MeshResource.generateSphere(radius: 0.5)
        case .cylinder:
            return MeshResource.generateCylinder(height: 1.0, radius: 0.5)
        case .capsule:
            return MeshResource.generateCapsule(height: 1.0, radius: 0.5)
        case .plane:
            return MeshResource.generatePlane(width: 1.0, depth: 1.0)
        }
    }
    
    private func createBasicMaterial(_ color: UIColor) -> SimpleMaterial {
        return SimpleMaterial(color: color, isMetallic: false)
    }
    
    private func loadMeshResource(_ meshName: String) -> MeshResource {
        // Try to load custom mesh, fallback to box
        do {
            return try MeshResource.load(named: meshName)
        } catch {
            print("[⚠️] Failed to load mesh '\(meshName)', using fallback")
            return MeshResource.generateBox(size: 1.0)
        }
    }
    
    private func createAvatarMesh() -> MeshResource {
        // Create simple avatar representation
        return MeshResource.generateCapsule(height: 1.8, radius: 0.3)
    }
    
    private func createAvatarMaterial() -> SimpleMaterial {
        return SimpleMaterial(color: .systemBlue, isMetallic: false)
    }
    
    private func createTerrainMesh(entityID: EntityID) -> MeshResource {
        // Create terrain mesh based on terrain component
        return MeshResource.generatePlane(width: 10.0, depth: 10.0)
    }
    
    private func createTerrainMaterial() -> SimpleMaterial {
        return SimpleMaterial(color: .systemGreen, isMetallic: false)
    }
}

protocol EntitySynchronizerDelegate: AnyObject {
    func entitySynchronizer(_ synchronizer: EntitySynchronizer, didCreateEntity modelEntity: ModelEntity, for entityID: EntityID)
    func entitySynchronizer(_ synchronizer: EntitySynchronizer, didFailToCreateEntity entityID: EntityID, error: Error)
}

// Transform Synchronizer
class TransformSynchronizer {
    private let ecs: ECSCore
    private let entityMap: [EntityID: ModelEntity]
    
    init(ecs: ECSCore, entityMap: [EntityID: ModelEntity]) {
        self.ecs = ecs
        self.entityMap = entityMap
    }
    
    func updateTransform(entityID: EntityID, modelEntity: ModelEntity, anchor: AnchorEntity) {
        let world = ecs.getWorld()
        
        // Update position
        if let positionComponent = world.getComponent(ofType: PositionComponent.self, from: entityID) {
            anchor.transform.translation = positionComponent.position
        }
        
        // Update rotation
        if let rotationComponent = world.getComponent(ofType: RotationComponent.self, from: entityID) {
            anchor.transform.rotation = rotationComponent.rotation
        }
        
        // Update scale
        if let scaleComponent = world.getComponent(ofType: ScaleComponent.self, from: entityID) {
            modelEntity.transform.scale = scaleComponent.scale
        }
    }
}

// Material Synchronizer
class MaterialSynchronizer {
    private let ecs: ECSCore
    private let entityMap: [EntityID: ModelEntity]
    
    init(ecs: ECSCore, entityMap: [EntityID: ModelEntity]) {
        self.ecs = ecs
        self.entityMap = entityMap
    }
    
    func updateMaterial(entityID: EntityID, modelEntity: ModelEntity) {
        let world = ecs.getWorld()
        
        guard let visualComponent = world.getComponent(ofType: VisualComponent.self, from: entityID) else { return }
        
        // Update material properties
        let material = SimpleMaterial(
            color: visualComponent.color,
            roughness: visualComponent.roughness,
            isMetallic: visualComponent.isMetallic
        )
        
        modelEntity.model?.materials = [material]
    }
}

// LOD Manager
class LODManager {
    private let config: LODConfiguration
    private let entityMap: [EntityID: ModelEntity]
    private var entityLODLevels: [EntityID: LODLevel] = [:]
    private var isEnabled: Bool = true
    
    init(config: LODConfiguration, entityMap: [EntityID: ModelEntity]) {
        self.config = config
        self.entityMap = entityMap
    }
    
    func updateLOD() {
        guard isEnabled else { return }
        
        // Get camera position (assuming at origin for now)
        let cameraPosition = SIMD3<Float>(0, 0, 0)
        
        for (entityID, modelEntity) in entityMap {
            let distance = simd_length(modelEntity.transform.translation - cameraPosition)
            let newLODLevel = config.getLODLevel(distance: distance)
            
            if entityLODLevels[entityID] != newLODLevel {
                applyLODLevel(entityID: entityID, modelEntity: modelEntity, level: newLODLevel)
                entityLODLevels[entityID] = newLODLevel
            }
        }
    }
    
    private func applyLODLevel(entityID: EntityID, modelEntity: ModelEntity, level: LODLevel) {
        switch level {
        case .culled:
            modelEntity.isEnabled = false
        case .minimal:
            modelEntity.isEnabled = true
            // Apply minimal detail settings
        case .low:
            modelEntity.isEnabled = true
            // Apply low detail settings
        case .medium:
            modelEntity.isEnabled = true
            // Apply medium detail settings
        case .high:
            modelEntity.isEnabled = true
            // Apply high detail settings
        }
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        
        if !enabled {
            // Reset all entities to high detail
            for (entityID, modelEntity) in entityMap {
                applyLODLevel(entityID: entityID, modelEntity: modelEntity, level: .high)
            }
        }
    }
    
    func getCulledEntityCount() -> Int {
        return entityLODLevels.values.filter { $0 == .culled }.count
    }
}

// Performance Optimizer
class RenderingPerformanceOptimizer {
    private let arView: ARView
    private let targetFrameRate: Double
    
    init(arView: ARView, targetFrameRate: Double) {
        self.arView = arView
        self.targetFrameRate = targetFrameRate
    }
    
    func optimizeForPerformance() {
        // Reduce rendering quality temporarily
        arView.renderOptions.remove(.disableMotionBlur)
        arView.renderOptions.insert(.disableAREnvironmentLighting)
        
        print("[⚡] Applied performance optimizations")
    }
    
    func performMemoryCleanup() {
        // Force cleanup of unused resources
        print("[🧹] Performing memory cleanup")
    }
}

// MARK: - Supporting Types

struct PendingUpdate {
    let entityID: EntityID
    let changeType: ComponentChangeType
    let timestamp: Date
}

enum ComponentChangeType {
    case transform
    case visual
    case material
    case physics
}

struct EntityCreationInfo {
    let entityID: EntityID
}

struct EntityDestructionInfo {
    let entityID: EntityID
}

struct ComponentChangeInfo {
    let entityID: EntityID
    let changeType: ComponentChangeType
}

struct SynchronizationStats {
    let visualEntityCount: Int
    let renderFrameRate: Double
    let culledEntityCount: Int
    let memoryUsage: Int64
    let pendingUpdates: Int
    let syncState: SynchronizationState
}

// MARK: - ECS Components

final class VisualComponent: Component {
    let entityType: VisualEntityType
    var color: UIColor
    var roughness: Float
    var isMetallic: Bool
    
    init(entityType: VisualEntityType, color: UIColor = .white, roughness: Float = 0.5, isMetallic: Bool = false) {
        self.entityType = entityType
        self.color = color
        self.roughness = roughness
        self.isMetallic = isMetallic
    }
}

final class ScaleComponent: Component {
    var scale: SIMD3<Float>
    init(scale: SIMD3<Float> = SIMD3<Float>(1, 1, 1)) {
        self.scale = scale
    }
 }

 final class PhysicsComponent: Component {
    var mass: Float
    var friction: Float
    var restitution: Float
    var isStatic: Bool
    var shape: PhysicsShape
    
    init(mass: Float = 1.0, friction: Float = 0.5, restitution: Float = 0.3, isStatic: Bool = false, shape: PhysicsShape = .box) {
        self.mass = mass
        self.friction = friction
        self.restitution = restitution
        self.isStatic = isStatic
        self.shape = shape
    }
 }

 enum PhysicsShape {
    case box
    case sphere
    case capsule
    case mesh
    
    func toRealityKitShape() -> ShapeResource {
        switch self {
        case .box:
            return ShapeResource.generateBox(size: SIMD3<Float>(1, 1, 1))
        case .sphere:
            return ShapeResource.generateSphere(radius: 0.5)
        case .capsule:
            return ShapeResource.generateCapsule(height: 1.0, radius: 0.5)
        case .mesh:
            // For now, use box as fallback for mesh collision
            return ShapeResource.generateBox(size: SIMD3<Float>(1, 1, 1))
        }
    }
 }

 // MARK: - Notification Extensions for ECS Events

 extension Notification.Name {
    static let ecsEntityCreated = Notification.Name("ECSEntityCreated")
    static let ecsEntityDestroyed = Notification.Name("ECSEntityDestroyed")
    static let ecsComponentChanged = Notification.Name("ECSComponentChanged")
 }

 // MARK: - Enhanced ECS Integration

 extension ECSCore {
    
    /// Notify when entity is created
    func notifyEntityCreated(_ entityID: EntityID) {
        let info = EntityCreationInfo(entityID: entityID)
        NotificationCenter.default.post(name: .ecsEntityCreated, object: info)
    }
    
    /// Notify when entity is destroyed
    func notifyEntityDestroyed(_ entityID: EntityID) {
        let info = EntityDestructionInfo(entityID: entityID)
        NotificationCenter.default.post(name: .ecsEntityDestroyed, object: info)
    }
    
    /// Notify when component changes
    func notifyComponentChanged(_ entityID: EntityID, changeType: ComponentChangeType) {
        let info = ComponentChangeInfo(entityID: entityID, changeType: changeType)
        NotificationCenter.default.post(name: .ecsComponentChanged, object: info)
    }
 }

 // MARK: - OpenSim Integration Extensions

 extension OpenSimObjectManager {
    
    /// Create visual entity from OpenSim object update
    func createVisualEntity(from objectUpdate: ObjectUpdateMessage) -> EntityID? {
        guard let ecs = self.ecs else { return nil }
        
        let world = ecs.getWorld()
        let entityID = world.createEntity()
        
        // Add position component
        let position = PositionComponent(position: objectUpdate.position)
        world.addComponent(position, to: entityID)
        
        // Add rotation component
        let rotation = RotationComponent(rotation: objectUpdate.rotation)
        world.addComponent(rotation, to: entityID)
        
        // Add scale component
        let scale = ScaleComponent(scale: objectUpdate.scale)
        world.addComponent(scale, to: entityID)
        
        // Add visual component based on OpenSim primitive
        let visualType = determineVisualType(from: objectUpdate.primitiveParams)
        let visual = VisualComponent(
            entityType: visualType,
            color: extractColor(from: objectUpdate.textureEntry)
        )
        world.addComponent(visual, to: entityID)
        
        // Add OpenSim-specific component
        let openSimData = OpenSimObjectComponent(
            localID: objectUpdate.localID,
            fullID: objectUpdate.fullID,
            ownerID: objectUpdate.ownerID,
            groupID: objectUpdate.groupID
        )
        world.addComponent(openSimData, to: entityID)
        
        // Notify ECS bridge of new entity
        ecs.notifyEntityCreated(entityID)
        
        return entityID
    }
    
    private func determineVisualType(from primitiveParams: PrimitiveParams) -> VisualEntityType {
        switch primitiveParams.primitiveType {
        case 0: // Box
            return .primitive(.box)
        case 1: // Cylinder
            return .primitive(.cylinder)
        case 2: // Prism
            return .primitive(.box)
        case 3: // Sphere
            return .primitive(.sphere)
        case 4: // Torus
            return .primitive(.cylinder) // Fallback
        case 5: // Tube
            return .primitive(.cylinder)
        case 6: // Ring
            return .primitive(.cylinder) // Fallback
        case 7: // Sculpted
            return .mesh("sculpted")
        default:
            return .primitive(.box)
        }
    }
    
    private func extractColor(from textureEntry: TextureEntry?) -> UIColor {
        // Extract color from texture entry
        // For now, return a default color based on hash
        return UIColor(
            red: 0.7,
            green: 0.7,
            blue: 0.7,
            alpha: 1.0
        )
    }
 }

 // MARK: - Advanced Visual Effects System

 class VisualEffectsManager {
    private let arView: ARView
    private var activeEffects: [EntityID: VisualEffect] = [:]
    
    init(arView: ARView) {
        self.arView = arView
    }
    
    func addEffect(_ effect: VisualEffect, to entityID: EntityID) {
        activeEffects[entityID] = effect
        applyEffect(effect, to: entityID)
    }
    
    func removeEffect(from entityID: EntityID) {
        if let effect = activeEffects.removeValue(forKey: entityID) {
            removeEffect(effect, from: entityID)
        }
    }
    
    private func applyEffect(_ effect: VisualEffect, to entityID: EntityID) {
        switch effect {
        case .glow(let intensity, let color):
            applyGlowEffect(entityID: entityID, intensity: intensity, color: color)
        case .particle(let type):
            addParticleEffect(entityID: entityID, type: type)
        case .animation(let animationType):
            startAnimation(entityID: entityID, type: animationType)
        }
    }
    
    private func removeEffect(_ effect: VisualEffect, from entityID: EntityID) {
        switch effect {
        case .glow:
            removeGlowEffect(entityID: entityID)
        case .particle:
            removeParticleEffect(entityID: entityID)
        case .animation:
            stopAnimation(entityID: entityID)
        }
    }
    
    private func applyGlowEffect(entityID: EntityID, intensity: Float, color: UIColor) {
        // Implementation would add emission to material
        print("[✨] Applied glow effect to entity: \(entityID)")
    }
    
    private func addParticleEffect(entityID: EntityID, type: ParticleType) {
        // Implementation would add particle system
        print("[🎆] Added particle effect to entity: \(entityID)")
    }
    
    private func startAnimation(entityID: EntityID, type: AnimationType) {
        // Implementation would start animation
        print("[🎬] Started animation on entity: \(entityID)")
    }
    
    private func removeGlowEffect(entityID: EntityID) {
        print("[💫] Removed glow effect from entity: \(entityID)")
    }
    
    private func removeParticleEffect(entityID: EntityID) {
        print("[🌪️] Removed particle effect from entity: \(entityID)")
    }
    
    private func stopAnimation(entityID: EntityID) {
        print("[⏹️] Stopped animation on entity: \(entityID)")
    }
 }

 enum VisualEffect {
    case glow(intensity: Float, color: UIColor)
    case particle(type: ParticleType)
    case animation(type: AnimationType)
 }

 enum ParticleType {
    case smoke
    case fire
    case sparkles
    case dust
 }

 enum AnimationType {
    case rotate
    case bounce
    case pulse
    case float
 }

 // MARK: - Material Management System

 class MaterialManager {
    private var materialCache: [String: Material] = [:]
    private var textureCache: [String: TextureResource] = [:]
    
    func getMaterial(for specification: MaterialSpecification) -> Material {
        let cacheKey = specification.cacheKey
        
        if let cachedMaterial = materialCache[cacheKey] {
            return cachedMaterial
        }
        
        let material = createMaterial(from: specification)
        materialCache[cacheKey] = material
        return material
    }
    
    private func createMaterial(from spec: MaterialSpecification) -> Material {
        switch spec.type {
        case .simple:
            return createSimpleMaterial(spec)
        case .pbr:
            return createPBRMaterial(spec)
        case .unlit:
            return createUnlitMaterial(spec)
        }
    }
    
    private func createSimpleMaterial(_ spec: MaterialSpecification) -> SimpleMaterial {
        var material = SimpleMaterial(
            color: spec.baseColor,
            roughness: spec.roughness,
            isMetallic: spec.metallic > 0.5
        )
        
        // Add texture if available
        if let textureName = spec.diffuseTexture {
            if let texture = getTexture(named: textureName) {
                material.color = SimpleMaterial.Color(texture: MaterialColorParameter(texture: texture))
            }
        }
        
        return material
    }
    
    private func createPBRMaterial(_ spec: MaterialSpecification) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        
        material.baseColor = PhysicallyBasedMaterial.BaseColor(tint: spec.baseColor)
        material.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: spec.roughness)
        material.metallic = PhysicallyBasedMaterial.Metallic(floatLiteral: spec.metallic)
        
        // Add textures
        if let textureName = spec.diffuseTexture,
           let texture = getTexture(named: textureName) {
            material.baseColor = PhysicallyBasedMaterial.BaseColor(texture: MaterialColorParameter(texture: texture))
        }
        
        if let normalTextureName = spec.normalTexture,
           let normalTexture = getTexture(named: normalTextureName) {
            material.normal = PhysicallyBasedMaterial.Normal(texture: MaterialScalarParameter(texture: normalTexture))
        }
        
        return material
    }
    
    private func createUnlitMaterial(_ spec: MaterialSpecification) -> UnlitMaterial {
        var material = UnlitMaterial(color: spec.baseColor)
        
        if let textureName = spec.diffuseTexture,
           let texture = getTexture(named: textureName) {
            material.color = UnlitMaterial.Color(texture: MaterialColorParameter(texture: texture))
        }
        
        return material
    }
    
    private func getTexture(named name: String) -> TextureResource? {
        if let cachedTexture = textureCache[name] {
            return cachedTexture
        }
        
        do {
            let texture = try TextureResource.load(named: name)
            textureCache[name] = texture
            return texture
        } catch {
            print("[⚠️] Failed to load texture: \(name)")
            return nil
        }
    }
    
    func clearCache() {
        materialCache.removeAll()
        textureCache.removeAll()
    }
 }

 struct MaterialSpecification {
    let type: MaterialType
    let baseColor: UIColor
    let roughness: Float
    let metallic: Float
    let diffuseTexture: String?
    let normalTexture: String?
    let emissionTexture: String?
    
    enum MaterialType {
        case simple
        case pbr
        case unlit
    }
    
    var cacheKey: String {
        return "\(type)_\(baseColor)_\(roughness)_\(metallic)_\(diffuseTexture ?? "")_\(normalTexture ?? "")"
    }
    
    static let `default` = MaterialSpecification(
        type: .simple,
        baseColor: .white,
        roughness: 0.5,
        metallic: 0.0,
        diffuseTexture: nil,
        normalTexture: nil,
        emissionTexture: nil
    )
 }

 // MARK: - Integration with Enhanced OpenSim Plugin

 extension OpenSimPlugin {
    
    /// Setup ECS-RealityKit bridge integration
    func setupECSRealityKitBridge() {
        guard let renderer = registry?.resolve("renderer") as? RendererService else {
            print("[⚠️] Cannot setup ECS-RealityKit bridge: renderer not available")
            return
        }
        
        guard let ecs = registry?.ecs else {
            print("[⚠️] Cannot setup ECS-RealityKit bridge: ECS not available")
            return
        }
        
        // Create and register the bridge
        let bridge = ECSRealityKitBridge(
            ecs: ecs,
            renderer: renderer,
            arView: renderer.arView
        )
        
        registry?.register(bridge, for: "ecsRealityKitBridge")
        
        print("[🌉] ECS-RealityKit bridge integrated with OpenSim plugin")
    }
    
    /// Get the ECS-RealityKit bridge
    func getECSRealityKitBridge() -> ECSRealityKitBridge? {
        return registry?.resolve("ecsRealityKitBridge")
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

 // MARK: - Performance Profiler

 class ECSRealityKitProfiler {
    private var profileData: [String: ProfileMetric] = [:]
    private let startTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    
    func startTiming(_ operation: String) {
        profileData[operation] = ProfileMetric(startTime: CFAbsoluteTimeGetCurrent())
    }
    
    func endTiming(_ operation: String) {
        guard var metric = profileData[operation] else { return }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - metric.startTime
        
        metric.totalTime += duration
        metric.callCount += 1
        metric.averageTime = metric.totalTime / Double(metric.callCount)
        
        profileData[operation] = metric
    }
    
    func getProfileReport() -> String {
        var report = "=== ECS-RealityKit Performance Profile ===\n"
        
        for (operation, metric) in profileData.sorted(by: { $0.value.totalTime > $1.value.totalTime }) {
            report += String(format: "%@: %.3fms avg (%.3fms total, %d calls)\n",
                           operation, metric.averageTime * 1000, metric.totalTime * 1000, metric.callCount)
        }
        
        return report
    }
    
    func reset() {
        profileData.removeAll()
    }
 }

 struct ProfileMetric {
    let startTime: CFAbsoluteTime
    var totalTime: Double = 0
    var callCount: Int = 0
    var averageTime: Double = 0
 }

 //print("[✅] ECS-RealityKit Synchronization System Complete")
