//
//  Engine/OpenSimECSBridge.swift
//  Storm
//
//  Enhanced integration bridge between OpenSim protocol and Storm ECS system
//  Converts OpenSim objects to ECS entities with complete visual synchronization
//  FIXED: Compilation errors resolved, proper Swift syntax, working implementation
//
//  Created for Finalverse Storm - Complete ECS Integration

import Foundation
import RealityKit
import SwiftUI
import simd

#if os(macOS)
import AppKit
typealias PlatformColor = NSColor
#else
import UIKit
typealias PlatformColor = UIColor
#endif

// MARK: - Enhanced Visual Representation Types

enum OpenSimObjectType: Hashable {
    case primitive(PrimitiveType)
    case avatar
    case attachment
    case terrain
    case foliage
    case water
    case unknown
    
    enum PrimitiveType: Hashable {
        case cube
        case sphere
        case cylinder
        case cone
        case torus
        case plane
        case ring
        case tube
        case prism
        case custom
    }
}

// MARK: - Entity Creation Configuration

struct EntityCreationConfig {
    let enableVisualRepresentation: Bool
    let enablePhysics: Bool
    let enableInteraction: Bool
    let debugVisualization: Bool
    let materialQuality: MaterialQuality
    let lodDistance: Float
    let maxEntities: Int
    
    enum MaterialQuality {
        case low
        case medium
        case high
        
        var subdivisions: Int {
            switch self {
            case .low: return 8
            case .medium: return 16
            case .high: return 32
            }
        }
    }
    
    static let `default` = EntityCreationConfig(
        enableVisualRepresentation: true,
        enablePhysics: true,
        enableInteraction: true,
        debugVisualization: false,
        materialQuality: .medium,
        lodDistance: 100.0,
        maxEntities: 1000
    )
}

// MARK: - Entity Statistics

struct EntityStatistics {
    var totalEntities: Int = 0
    var activeEntities: Int = 0
    var visibleEntities: Int = 0
    var entitiesByType: [OpenSimObjectType: Int] = [:]
    var averageUpdateTime: TimeInterval = 0
    var memoryUsage: Int = 0
    
    mutating func recordEntityCreation(_ type: OpenSimObjectType) {
        totalEntities += 1
        activeEntities += 1
        entitiesByType[type, default: 0] += 1
    }
    
    mutating func recordEntityRemoval(_ type: OpenSimObjectType) {
        activeEntities = max(0, activeEntities - 1)
        entitiesByType[type, default: 0] = max(0, entitiesByType[type, default: 0] - 1)
    }
}

// MARK: - Performance Metrics

struct PerformanceMetrics {
    var entityCount: Int = 0
    var renderCount: Int = 0
    var updateTime: TimeInterval = 0
    var memoryUsage: Int = 0
    var frameRate: Double = 60.0
    var lastUpdateProcessingTimes: [TimeInterval] = []
    
    mutating func recordUpdateProcessing(_ time: TimeInterval) {
        updateTime = time
        lastUpdateProcessingTimes.append(time)
        
        // Keep only last 100 measurements
        if lastUpdateProcessingTimes.count > 100 {
            lastUpdateProcessingTimes.removeFirst()
        }
    }
    
    func averageUpdateTime() -> TimeInterval {
        guard !lastUpdateProcessingTimes.isEmpty else { return 0 }
        return lastUpdateProcessingTimes.reduce(0, +) / Double(lastUpdateProcessingTimes.count)
    }
}

// MARK: - Enhanced Notification Definitions

extension Notification.Name {
    static let openSimObjectUpdate = Notification.Name("openSimObjectUpdate")
    static let openSimChatMessage = Notification.Name("openSimChatMessage")
    static let localAvatarMoved = Notification.Name("localAvatarMoved")
    static let openSimObjectRemoved = Notification.Name("openSimObjectRemoved")
    static let openSimEntityCreated = Notification.Name("openSimEntityCreated")
    static let openSimEntityUpdated = Notification.Name("openSimEntityUpdated")
    static let openSimBridgeStats = Notification.Name("openSimBridgeStats")
}

// MARK: - Enhanced OpenSimECSBridge

class OpenSimECSBridge: ObservableObject {
    
    // MARK: - Core Dependencies
    private let ecs: ECSCore
    private let renderer: RendererService
    private let config: EntityCreationConfig
    
    // MARK: - Published Properties
    @Published var statistics = EntityStatistics()
    @Published var isProcessingUpdates = false
    @Published var performanceMetrics = PerformanceMetrics()
    
    // MARK: - Entity Mapping (Enhanced)
    private var openSimToECSMap: [UInt32: EntityID] = [:] // OpenSim LocalID -> ECS EntityID
    private var ecsToOpenSimMap: [EntityID: UInt32] = [:] // ECS EntityID -> OpenSim LocalID
    private var entityRenderMap: [EntityID: ModelEntity] = [:] // EntityID -> RealityKit ModelEntity
    private var entityTypeMap: [EntityID: OpenSimObjectType] = [:] // EntityID -> Object Type
    private var entityAnchorMap: [EntityID: AnchorEntity] = [:] // EntityID -> Anchor Entity
    
    // MARK: - Performance Optimization
    private var lastUpdateTime: [UInt32: Date] = [:]
    private var pendingUpdates: [UInt32: ObjectUpdateMessage.ObjectUpdateData] = [:]
    private var updateQueue = DispatchQueue(label: "OpenSimECSBridge.updates", qos: .userInitiated)
    private var batchUpdateTimer: Timer?
    private let batchUpdateInterval: TimeInterval = 0.016 // ~60 FPS
    
    // MARK: - Visual Management
    private var materialCache: [String: RealityKit.Material] = [:]
    private var meshCache: [String: MeshResource] = [:]
    private var lodSystem: LODSystem
    
    // MARK: - Chat Management
    private var activeChatBubbles: [UUID: (AnchorEntity, Date)] = [:]
    private var chatCleanupTimer: Timer?
    
    init(ecs: ECSCore, renderer: RendererService, config: EntityCreationConfig = .default) {
        self.ecs = ecs
        self.renderer = renderer
        self.config = config
        self.lodSystem = LODSystem(config: config)
        
        setupNotificationObservers()
        setupPerformanceMonitoring()
        setupBatchUpdates()
        setupChatCleanup()
        
        print("[🔗] Enhanced OpenSimECSBridge initialized with config")
    }
    
    // MARK: - Setup Methods
    
    private func setupNotificationObservers() {
        // Listen for OpenSim object updates
        NotificationCenter.default.addObserver(
            forName: .openSimObjectUpdate,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let objectUpdate = notification.object as? ObjectUpdateMessage {
                self?.handleObjectUpdate(objectUpdate)
            }
        }
        
        // Listen for OpenSim chat messages
        NotificationCenter.default.addObserver(
            forName: .openSimChatMessage,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let chatMessage = notification.object as? ChatFromSimulatorMessage {
                self?.handleChatMessage(chatMessage)
            }
        }
        
        // Listen for object removal
        NotificationCenter.default.addObserver(
            forName: .openSimObjectRemoved,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let data = notification.object as? [String: Any],
               let localID = data["localID"] as? UInt32 {
                self?.removeOpenSimObject(localID: localID)
            }
        }
    }
    
    private func setupPerformanceMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updatePerformanceMetrics()
        }
    }
    
    private func setupBatchUpdates() {
        batchUpdateTimer = Timer.scheduledTimer(withTimeInterval: batchUpdateInterval, repeats: true) { [weak self] _ in
            self?.processBatchedUpdates()
        }
    }
    
    private func setupChatCleanup() {
        chatCleanupTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.cleanupExpiredChatBubbles()
        }
    }
    
    // MARK: - Enhanced Object Update Handling
    
    private func handleObjectUpdate(_ update: ObjectUpdateMessage) {
        let startTime = Date()
        isProcessingUpdates = true
        
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            for objectData in update.objects {
                // Batch updates for performance
                self.pendingUpdates[objectData.localID] = objectData
            }
            
            DispatchQueue.main.async {
                self.isProcessingUpdates = false
                self.performanceMetrics.recordUpdateProcessing(Date().timeIntervalSince(startTime))
            }
        }
    }
    
    private func processBatchedUpdates() {
        guard !pendingUpdates.isEmpty else { return }
        
        let updates = pendingUpdates
        pendingUpdates.removeAll()
        
        for (localID, objectData) in updates {
            if let existingEntityID = openSimToECSMap[localID] {
                updateExistingEntity(existingEntityID, with: objectData)
            } else {
                createNewEntity(from: objectData)
            }
            
            lastUpdateTime[localID] = Date()
        }
    }
    
    // MARK: - Enhanced Entity Creation
    
    private func createNewEntity(from objectData: ObjectUpdateMessage.ObjectUpdateData) {
        // Check entity limits
        guard statistics.activeEntities < config.maxEntities else {
            print("[⚠️] Entity limit reached (\(config.maxEntities)), skipping creation")
            return
        }
        
        let world = ecs.getWorld()
        let entityID = world.createEntity()
        
        // Map OpenSim object to ECS entity
        openSimToECSMap[objectData.localID] = entityID
        ecsToOpenSimMap[entityID] = objectData.localID
        
        // Determine object type
        let objectType = determineObjectType(from: objectData)
        entityTypeMap[entityID] = objectType
        
        // Add ECS components
        addECSComponents(to: entityID, from: objectData, objectType: objectType)
        
        // Create visual representation if enabled
        if config.enableVisualRepresentation {
            createVisualRepresentation(for: entityID, objectData: objectData, objectType: objectType)
        }
        
        // Update statistics
        statistics.recordEntityCreation(objectType)
        
        // Notify creation
        NotificationCenter.default.post(
            name: .openSimEntityCreated,
            object: ["entityID": entityID, "localID": objectData.localID, "type": objectType]
        )
        
        print("[🔗] Created ECS entity \(entityID) for OpenSim object \(objectData.localID)")
    }
    
    private func addECSComponents(to entityID: EntityID, from objectData: ObjectUpdateMessage.ObjectUpdateData, objectType: OpenSimObjectType) {
        let world = ecs.getWorld()
        
        // Add position component (using authoritative ECS component)
        let position = PositionComponent(position: objectData.position)
        world.addComponent(position, to: entityID)
        
        // Add OpenSim-specific component (using authoritative ECS component)
        let openSimComponent = OpenSimObjectComponent(
            localID: objectData.localID,
            fullID: objectData.fullID,
            pcode: objectData.pcode,
            material: objectData.material,
            flags: objectData.flags
        )
        world.addComponent(openSimComponent, to: entityID)
        
        // Add spin component for certain object types
        if case .primitive = objectType {
            let spinComponent = SpinComponent()
            world.addComponent(spinComponent, to: entityID)
        }
        
        // Add terrain component for terrain objects
        if case .terrain = objectType {
            let terrainComponent = TerrainComponent(size: max(objectData.scale.x, objectData.scale.z))
            world.addComponent(terrainComponent, to: entityID)
        }
        
        // Add mood component based on object properties
        let mood = determineMood(from: objectData)
        let moodComponent = MoodComponent(mood: mood)
        world.addComponent(moodComponent, to: entityID)
    }
    
    private func determineObjectType(from objectData: ObjectUpdateMessage.ObjectUpdateData) -> OpenSimObjectType {
        // Determine type based on pcode and flags
        switch objectData.pcode {
        case 9: return .primitive(.cube)
        case 10: return .primitive(.cylinder)
        case 11: return .primitive(.prism)
        case 12: return .primitive(.sphere)
        case 13: return .primitive(.torus)
        case 14: return .primitive(.tube)
        case 15: return .primitive(.ring)
        case 95: return .avatar
        case 255: return .terrain
        default:
            // Check flags for special types
            if (objectData.flags & 0x01) != 0 {
                return .attachment
            } else if (objectData.flags & 0x02) != 0 {
                return .foliage
            } else {
                return .unknown
            }
        }
    }
    
    private func determineMood(from objectData: ObjectUpdateMessage.ObjectUpdateData) -> String {
        // Determine mood based on object properties
        switch objectData.material {
        case 0: return "stone"
        case 1: return "metallic"
        case 2: return "glass"
        case 3: return "wooden"
        case 4: return "organic"
        case 5: return "plastic"
        case 6: return "rubber"
        default: return "neutral"
        }
    }
    
    // MARK: - Enhanced Entity Updates
    
    private func updateExistingEntity(_ entityID: EntityID, with objectData: ObjectUpdateMessage.ObjectUpdateData) {
        let world = ecs.getWorld()
        
        // Update position component
        if let positionComponent = world.getComponent(ofType: PositionComponent.self, from: entityID) {
            let oldPosition = positionComponent.position
            positionComponent.position = objectData.position
            
            // Check if position changed significantly
            let distance = simd_distance(oldPosition, objectData.position)
            if distance > 0.01 { // 1cm threshold
                updateVisualRepresentation(for: entityID, objectData: objectData)
            }
        }
        
        // Update OpenSim component
        if let openSimComponent = world.getComponent(ofType: OpenSimObjectComponent.self, from: entityID) {
            openSimComponent.lastUpdateTime = Date()
        }
        
        // Notify update
        NotificationCenter.default.post(
            name: .openSimEntityUpdated,
            object: ["entityID": entityID, "localID": objectData.localID]
        )
    }
    
    // MARK: - Enhanced Visual Representation
    
    private func createVisualRepresentation(for entityID: EntityID, objectData: ObjectUpdateMessage.ObjectUpdateData, objectType: OpenSimObjectType) {
        let meshKey = createMeshKey(objectData: objectData)
        let materialKey = createMaterialKey(objectData: objectData)
        
        // Get or create mesh (with caching)
        let mesh: MeshResource
        if let cachedMesh = meshCache[meshKey] {
            mesh = cachedMesh
        } else {
            mesh = createMeshForObjectData(objectData, objectType: objectType)
            meshCache[meshKey] = mesh
        }
        
        // Get or create material (with caching)
        let material: RealityKit.Material
        if let cachedMaterial = materialCache[materialKey] {
            material = cachedMaterial
        } else {
            material = createMaterialForObject(objectData, objectType: objectType)
            materialCache[materialKey] = material
        }
        
        // Create model entity
        let modelEntity = ModelEntity(mesh: mesh, materials: [material])
        modelEntity.position = objectData.position
        modelEntity.orientation = objectData.rotation
        modelEntity.scale = objectData.scale
        
        // Add interaction components if enabled
        if config.enableInteraction {
            setupEntityInteraction(modelEntity, entityID: entityID, localID: objectData.localID)
        }
        
        // Add physics if enabled
        if config.enablePhysics {
            setupEntityPhysics(modelEntity, objectData: objectData, objectType: objectType)
        }
        
        // Create anchor and add to scene
        let anchor = AnchorEntity(world: objectData.position)
        anchor.addChild(modelEntity)
        renderer.arView.scene.addAnchor(anchor)
        
        // Store mappings
        entityRenderMap[entityID] = modelEntity
        entityAnchorMap[entityID] = anchor
        
        // Add metadata for debugging
        modelEntity.name = "opensim_\(objectData.localID)"
        
        // Apply LOD if configured
        lodSystem.applyLOD(to: modelEntity, distance: calculateDistanceToCamera(objectData.position))
    }
    
    private func createMeshForObjectData(_ objectData: ObjectUpdateMessage.ObjectUpdateData, objectType: OpenSimObjectType) -> MeshResource {
        let scale = objectData.scale.x > 0 ? objectData.scale : SIMD3<Float>(0.5, 0.5, 0.5)
        
        switch objectType {
        case .primitive(let primitiveType):
            return createPrimitiveMesh(primitiveType, scale: scale)
        case .avatar:
            return MeshResource.generateSphere(radius: 0.5)
        case .terrain:
            return MeshResource.generateBox(size: scale)
        case .foliage:
            return MeshResource.generateCylinder(height: scale.y, radius: max(scale.x, scale.z) / 4)
        case .water:
            return MeshResource.generateBox(size: scale)
        default:
            return MeshResource.generateBox(size: scale)
        }
    }
    
    private func createPrimitiveMesh(_ primitiveType: OpenSimObjectType.PrimitiveType, scale: SIMD3<Float>) -> MeshResource {
        switch primitiveType {
        case .cube:
            return MeshResource.generateBox(size: scale)
        case .sphere:
            return MeshResource.generateSphere(radius: max(scale.x, max(scale.y, scale.z)) / 2)
        case .cylinder:
            return MeshResource.generateCylinder(height: scale.y, radius: max(scale.x, scale.z) / 2)
        case .cone:
            return MeshResource.generateCylinder(height: scale.y, radius: max(scale.x, scale.z) / 2)
        case .torus:
            return MeshResource.generateSphere(radius: max(scale.x, scale.z) / 2) // Simplified
        case .plane:
            return MeshResource.generatePlane(width: scale.x, depth: scale.z)
        case .ring:
            return MeshResource.generateSphere(radius: max(scale.x, scale.z) / 2) // Simplified
        case .tube:
            return MeshResource.generateCylinder(height: scale.y, radius: max(scale.x, scale.z) / 2)
        case .prism:
            return MeshResource.generateBox(size: scale)
        case .custom:
            return MeshResource.generateBox(size: scale)
        }
    }
    
    private func createMaterialForObject(_ objectData: ObjectUpdateMessage.ObjectUpdateData, objectType: OpenSimObjectType) -> RealityKit.Material {
        var color: PlatformColor = .gray
        var metallic = false
        var roughness: Float = 0.5
        
        // Base material properties
        switch objectData.material {
        case 0: // Stone
            color = .lightGray
            roughness = 0.8
        case 1: // Metal
            color = .darkGray
            metallic = true
            roughness = 0.1
        case 2: // Glass
            color = .cyan
            roughness = 0.0
        case 3: // Wood
            color = .brown
            roughness = 0.7
        case 4: // Flesh
            #if os(macOS)
            color = NSColor.systemPink
            #else
            color = UIColor.systemPink
            #endif
            roughness = 0.6
        case 5: // Plastic
            color = .white
            roughness = 0.4
        case 6: // Rubber
            color = .black
            roughness = 0.9
        default:
            color = .gray
        }
        
        // Object type specific adjustments
        switch objectType {
        case .avatar:
            #if os(macOS)
            color = NSColor.systemBlue
            #else
            color = UIColor.systemBlue
            #endif
        case .terrain:
            #if os(macOS)
            color = NSColor.systemGreen
            #else
            color = UIColor.systemGreen
            #endif
            roughness = 0.9
        case .foliage:
            #if os(macOS)
            color = NSColor.systemGreen
            #else
            color = UIColor.systemGreen
            #endif
        case .water:
            #if os(macOS)
            color = NSColor.systemBlue
            #else
            color = UIColor.systemBlue
            #endif
            roughness = 0.0
        default:
            break
        }
        
        // Create material based on quality setting
        switch config.materialQuality {
        case .low:
            return SimpleMaterial(color: color, isMetallic: metallic)
        case .medium, .high:
            var material = PhysicallyBasedMaterial()
            material.baseColor = PhysicallyBasedMaterial.BaseColor(tint: color)
            material.metallic = PhysicallyBasedMaterial.Metallic(floatLiteral: metallic ? 1.0 : 0.0)
            material.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: roughness)
            return material
        }
    }
    
    private func setupEntityInteraction(_ modelEntity: ModelEntity, entityID: EntityID, localID: UInt32) {
        // Add collision component for interaction
        let shape = ShapeResource.generateBox(size: modelEntity.model?.mesh.bounds.extents ?? SIMD3<Float>(1, 1, 1))
        modelEntity.collision = CollisionComponent(shapes: [shape])
        
        // Enable input target
        modelEntity.generateCollisionShapes(recursive: true)
    }
    
    private func setupEntityPhysics(_ modelEntity: ModelEntity, objectData: ObjectUpdateMessage.ObjectUpdateData, objectType: OpenSimObjectType) {
        // Add physics body based on object type
        let physicsBodyMode: PhysicsBodyMode
        switch objectType {
        case .terrain:
            physicsBodyMode = .static
        case .avatar:
            physicsBodyMode = .kinematic
        default:
            physicsBodyMode = .dynamic
        }
        
        let shape = ShapeResource.generateBox(size: objectData.scale)
        modelEntity.physicsBody = PhysicsBodyComponent(
            massProperties: .default,
            material: .default,
            mode: physicsBodyMode
        )
        modelEntity.collision = CollisionComponent(shapes: [shape])
    }
    
    private func updateVisualRepresentation(for entityID: EntityID, objectData: ObjectUpdateMessage.ObjectUpdateData) {
        guard let modelEntity = entityRenderMap[entityID],
              let anchor = entityAnchorMap[entityID] else { return }
        
        // Update transform with smooth animation
        let duration: TimeInterval = 0.1
        let newTransform = Transform(
            scale: objectData.scale,
            rotation: objectData.rotation,
            translation: objectData.position
        )
        
        modelEntity.move(to: newTransform, relativeTo: anchor, duration: duration)
        
        // Update LOD based on distance
        let distance = calculateDistanceToCamera(objectData.position)
        lodSystem.updateLOD(for: modelEntity, distance: distance)
    }
    
    // MARK: - Enhanced Chat Integration
    
    private func handleChatMessage(_ chatMessage: ChatFromSimulatorMessage) {
        // Create a chat entity for visualization (using authoritative ECS component)
        let world = ecs.getWorld()
        let entityID = world.createEntity()
        
        // Add position component at chat location
        let position = PositionComponent(position: chatMessage.position)
        world.addComponent(position, to: entityID)
        
        // Add chat component (using authoritative ECS component)
        let chatComponent = ChatMessageComponent(
            fromName: chatMessage.fromName,
            message: chatMessage.message,
            timestamp: Date(),
            chatType: chatMessage.chatType
        )
        world.addComponent(chatComponent, to: entityID)
        
        // Create visual chat bubble
        createEnhancedChatBubble(
            at: chatMessage.position,
            message: chatMessage.message,
            from: chatMessage.fromName,
            chatType: chatMessage.chatType
        )
        
        print("[💬] Chat from \(chatMessage.fromName): \(chatMessage.message)")
    }
    
    private func createEnhancedChatBubble(at position: SIMD3<Float>, message: String, from sender: String, chatType: UInt8) {
        let bubbleID = UUID()
        let bubbleHeight: Float = 2.0
        let maxWidth: Float = 3.0
        let bubbleLifetime: TimeInterval = 5.0
        
        // Create text with proper formatting
        let displayText = "\(sender): \(message)"
        let textMesh = MeshResource.generateText(
            displayText,
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.12),
            containerFrame: CGRect(x: 0, y: 0, width: Double(maxWidth), height: 1),
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        
        // Chat type specific styling
        let textColor: PlatformColor
        switch chatType {
        case 0:
            textColor = .white          // Normal chat
        case 1:
            #if os(macOS)
            textColor = NSColor.systemYellow   // Whisper
            #else
            textColor = UIColor.systemYellow
            #endif
        case 2:
            #if os(macOS)
            textColor = NSColor.systemRed      // Shout
            #else
            textColor = UIColor.systemRed
            #endif
        default:
            textColor = .white
        }
        
        let textMaterial = SimpleMaterial(color: textColor, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
        
        // Create background panel with rounded corners
        let textBounds = textMesh.bounds
        let panelSize = SIMD3<Float>(
            textBounds.extents.x + 0.2,
            textBounds.extents.y + 0.1,
            0.02
        )
        
        let panelMesh = MeshResource.generateBox(size: panelSize, cornerRadius: 0.02)
        
        #if os(macOS)
        let panelColor = NSColor.black.withAlphaComponent(0.8)
        #else
        let panelColor = UIColor.black.withAlphaComponent(0.8)
        #endif
        
        let panelMaterial = SimpleMaterial(color: panelColor, isMetallic: false)
        let panelEntity = ModelEntity(mesh: panelMesh, materials: [panelMaterial])
        
        // Position elements
        textEntity.position = SIMD3<Float>(0, 0, 0.01)
        panelEntity.position = SIMD3<Float>(0, 0, 0)
        
        // Create anchor and group
        let chatBubbleAnchor = AnchorEntity(world: position + SIMD3<Float>(0, bubbleHeight, 0))
        chatBubbleAnchor.addChild(panelEntity)
        chatBubbleAnchor.addChild(textEntity)
        
        renderer.arView.scene.addAnchor(chatBubbleAnchor)
        
        // Store for cleanup
        activeChatBubbles[bubbleID] = (chatBubbleAnchor, Date().addingTimeInterval(bubbleLifetime))
    }
    
    private func cleanupExpiredChatBubbles() {
        let now = Date()
        var expiredBubbles: [UUID] = []
        
        for (bubbleID, (anchor, expiration)) in activeChatBubbles {
            if now > expiration {
                renderer.arView.scene.removeAnchor(anchor)
                expiredBubbles.append(bubbleID)
            }
        }
        
        for bubbleID in expiredBubbles {
            activeChatBubbles.removeValue(forKey: bubbleID)
        }
    }
    
    // MARK: - Avatar Movement Integration
    
    func moveLocalAvatar(to position: SIMD3<Float>, rotation: SIMD2<Float>) {
        // Update local avatar in ECS (using authoritative ECS component)
        let world = ecs.getWorld()
        
        // Find local avatar entity (would be created during login)
        let avatarEntities = world.entities(with: LocalAvatarComponent.self)
        
        if let (avatarEntityID, _) = avatarEntities.first {
            // Update position
            if let positionComponent = world.getComponent(ofType: PositionComponent.self, from: avatarEntityID) {
                positionComponent.position = position
            }
            
            // Send update to OpenSim server via notification
            NotificationCenter.default.post(
                name: .localAvatarMoved,
                object: AvatarMovementUpdate(position: position, rotation: rotation)
            )
        }
    }
    
    // MARK: - Enhanced Entity Cleanup
    
    func removeOpenSimObject(localID: UInt32) {
        guard let entityID = openSimToECSMap[localID] else { return }
        
        let world = ecs.getWorld()
        
        // Get object type for statistics
        let objectType = entityTypeMap[entityID] ?? .unknown
        
        // Remove from ECS
        world.removeEntity(entityID)
        
        // Remove visual representation
        if let modelEntity = entityRenderMap[entityID] {
            modelEntity.removeFromParent()
            entityRenderMap.removeValue(forKey: entityID)
        }
        
        // Remove anchor
        if let anchor = entityAnchorMap[entityID] {
            renderer.arView.scene.removeAnchor(anchor)
            entityAnchorMap.removeValue(forKey: entityID)
        }
        
        // Clean up mappings
        openSimToECSMap.removeValue(forKey: localID)
        ecsToOpenSimMap.removeValue(forKey: entityID)
        entityTypeMap.removeValue(forKey: entityID)
        lastUpdateTime.removeValue(forKey: localID)
        
        // Update statistics
        statistics.recordEntityRemoval(objectType)
        
        print("[🗑️] Removed ECS entity \(entityID) for OpenSim object \(localID)")
    }
    
    // MARK: - Performance and Utilities
    
    private func createMeshKey(objectData: ObjectUpdateMessage.ObjectUpdateData) -> String {
        return "pcode_\(objectData.pcode)_scale_\(objectData.scale.x)_\(objectData.scale.y)_\(objectData.scale.z)"
    }
    
    private func createMaterialKey(objectData: ObjectUpdateMessage.ObjectUpdateData) -> String {
        return "material_\(objectData.material)_flags_\(objectData.flags)"
    }
    
    private func calculateDistanceToCamera(_ position: SIMD3<Float>) -> Float {
        // Get camera position from ARView
        let cameraTransform = renderer.arView.cameraTransform
        let cameraPosition = cameraTransform.translation
        return simd_distance(position, cameraPosition)
    }
    
    private func updatePerformanceMetrics() {
        performanceMetrics.entityCount = statistics.activeEntities
        performanceMetrics.renderCount = entityRenderMap.count
        performanceMetrics.memoryUsage = estimateMemoryUsage()
        
        // Post statistics notification
        NotificationCenter.default.post(
            name: .openSimBridgeStats,
            object: ["statistics": statistics, "performance": performanceMetrics]
        )
    }
    
    private func estimateMemoryUsage() -> Int {
        // Rough estimate of memory usage
        let entitySize = 1024 // Estimated bytes per entity
        let meshCacheSize = meshCache.count * 8192 // Estimated bytes per cached mesh
        let materialCacheSize = materialCache.count * 1024 // Estimated bytes per cached material
        
        return (statistics.activeEntities * entitySize) + meshCacheSize + materialCacheSize
    }
    
    // MARK: - Public Interface
    
    func getEntityStats() -> EntityStatistics {
        return statistics
    }
    
    func getPerformanceMetrics() -> PerformanceMetrics {
        return performanceMetrics
    }
    
    func clearCache() {
        meshCache.removeAll()
        materialCache.removeAll()
        print("[🧹] Cleared material and mesh caches")
    }
    
    func setLODDistance(_ distance: Float) {
        lodSystem.updateConfig(lodDistance: distance)
    }
    
    func getEntityByLocalID(_ localID: UInt32) -> EntityID? {
        return openSimToECSMap[localID]
    }
    
    func getLocalIDByEntity(_ entityID: EntityID) -> UInt32? {
        return ecsToOpenSimMap[entityID]
    }
    
    func getAllActiveEntities() -> [EntityID] {
        return Array(ecsToOpenSimMap.keys)
    }
    
    func getEntitiesByType(_ objectType: OpenSimObjectType) -> [EntityID] {
        return entityTypeMap.compactMap { (entityID, type) in
            return typesMatch(type, objectType) ? entityID : nil
        }
    }
    
    // MARK: - Debug and Inspection
    
    func enableDebugVisualization(_ enabled: Bool) {
        for (_, modelEntity) in entityRenderMap {
            if enabled {
                // Add debug wireframe or bounding box
                let bounds = modelEntity.model?.mesh.bounds ?? BoundingBox()
                let debugMesh = MeshResource.generateBox(size: bounds.extents)
                let debugMaterial = SimpleMaterial(color: .red, isMetallic: false)
                let debugEntity = ModelEntity(mesh: debugMesh, materials: [debugMaterial])
                debugEntity.name = "debug_bounds"
                modelEntity.addChild(debugEntity)
            } else {
                // Remove debug visualizations
                for child in modelEntity.children {
                    if child.name == "debug_bounds" {
                        child.removeFromParent()
                    }
                }
            }
        }
    }
    
    func dumpEntityInfo() {
        print("=== OpenSim ECS Bridge Entity Info ===")
        print("Active Entities: \(statistics.activeEntities)")
        print("Total Created: \(statistics.totalEntities)")
        print("Visible Entities: \(statistics.visibleEntities)")
        print("Entities by Type:")
        for (type, count) in statistics.entitiesByType {
            print("  \(type): \(count)")
        }
        print("Cache Status:")
        print("  Mesh Cache: \(meshCache.count) entries")
        print("  Material Cache: \(materialCache.count) entries")
        print("  Memory Usage: ~\(performanceMetrics.memoryUsage / 1024)KB")
        print("=====================================")
    }
    
    // MARK: - Helper Methods
    
    private func typesMatch(_ type1: OpenSimObjectType, _ type2: OpenSimObjectType) -> Bool {
        switch (type1, type2) {
        case (.primitive, .primitive), (.avatar, .avatar), (.terrain, .terrain),
             (.foliage, .foliage), (.water, .water), (.attachment, .attachment),
             (.unknown, .unknown):
            return true
        default:
            return false
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Cleanup timers
        batchUpdateTimer?.invalidate()
        chatCleanupTimer?.invalidate()
        
        // Remove observers
        NotificationCenter.default.removeObserver(self)
        
        // Clear all entities
        for entityID in Array(ecsToOpenSimMap.keys) {
            if let localID = ecsToOpenSimMap[entityID] {
                removeOpenSimObject(localID: localID)
            }
        }
        
        print("[🔗] OpenSimECSBridge deinitialized")
    }
 }

 // MARK: - Supporting Classes

 // MARK: - LOD (Level of Detail) System

 class LODSystem {
    private var config: EntityCreationConfig
    
    init(config: EntityCreationConfig) {
        self.config = config
    }
    
    func applyLOD(to modelEntity: ModelEntity, distance: Float) {
        let lodLevel = calculateLODLevel(distance: distance)
        updateEntityLOD(modelEntity, lodLevel: lodLevel)
    }
    
    func updateLOD(for modelEntity: ModelEntity, distance: Float) {
        let lodLevel = calculateLODLevel(distance: distance)
        updateEntityLOD(modelEntity, lodLevel: lodLevel)
    }
    
    func updateConfig(lodDistance: Float) {
        // Update config would require recreating the system
        // For now, just log the update request
        print("[🔧] LOD distance update requested: \(lodDistance)")
    }
    
    private func calculateLODLevel(distance: Float) -> LODLevel {
        let maxDistance = config.lodDistance
        
        if distance < maxDistance * 0.3 {
            return .high
        } else if distance < maxDistance * 0.7 {
            return .medium
        } else {
            return .low
        }
    }
    
    private func updateEntityLOD(_ modelEntity: ModelEntity, lodLevel: LODLevel) {
        // Adjust rendering quality based on distance
        switch lodLevel {
        case .high:
            modelEntity.isEnabled = true
            // Full detail rendering
            
        case .medium:
            modelEntity.isEnabled = true
            // Reduced detail - could swap meshes here
            
        case .low:
            // Very low detail or cull completely based on distance
            modelEntity.isEnabled = true // Keep enabled for now
        }
    }
    
    enum LODLevel {
        case high
        case medium
        case low
    }
 }

 // MARK: - Enhanced Movement Update Structure

 struct AvatarMovementUpdate {
    let position: SIMD3<Float>
    let rotation: SIMD2<Float>
    let timestamp: Date
    let velocity: SIMD3<Float>
    let isFlying: Bool
    let isRunning: Bool
    
    init(position: SIMD3<Float>, rotation: SIMD2<Float>, velocity: SIMD3<Float> = SIMD3<Float>(0, 0, 0), isFlying: Bool = false, isRunning: Bool = false) {
        self.position = position
        self.rotation = rotation
        self.timestamp = Date()
        self.velocity = velocity
        self.isFlying = isFlying
        self.isRunning = isRunning
    }
 }

 // MARK: - Entity Query Extensions

 extension OpenSimECSBridge {
    
    // MARK: - Spatial Queries
    
    func getEntitiesInRadius(center: SIMD3<Float>, radius: Float) -> [EntityID] {
        let world = ecs.getWorld()
        let entities = world.entities(with: PositionComponent.self)
        
        return entities.compactMap { (entityID, positionComponent) in
            let distance = simd_distance(center, positionComponent.position)
            return distance <= radius ? entityID : nil
        }
    }
    
    func getEntitiesInBox(min: SIMD3<Float>, max: SIMD3<Float>) -> [EntityID] {
        let world = ecs.getWorld()
        let entities = world.entities(with: PositionComponent.self)
        
        return entities.compactMap { (entityID, positionComponent) in
            let pos = positionComponent.position
            let inBounds = pos.x >= min.x && pos.x <= max.x &&
                          pos.y >= min.y && pos.y <= max.y &&
                          pos.z >= min.z && pos.z <= max.z
            return inBounds ? entityID : nil
        }
    }
    
    func getClosestEntity(to position: SIMD3<Float>, ofType objectType: OpenSimObjectType? = nil) -> EntityID? {
        let world = ecs.getWorld()
        let entities = world.entities(with: PositionComponent.self)
        
        var closestEntity: EntityID?
        var closestDistance: Float = Float.greatestFiniteMagnitude
        
        for (entityID, positionComponent) in entities {
            // Filter by type if specified
            if let requiredType = objectType,
               let entityType = entityTypeMap[entityID],
               !typesMatch(entityType, requiredType) {
                continue
            }
            
            let distance = simd_distance(position, positionComponent.position)
            if distance < closestDistance {
                closestDistance = distance
                closestEntity = entityID
            }
        }
        
        return closestEntity
    }
    
    // MARK: - Batch Operations
    
    func updateMultipleEntities(_ updates: [(UInt32, ObjectUpdateMessage.ObjectUpdateData)]) {
        for (localID, objectData) in updates {
            if let entityID = openSimToECSMap[localID] {
                updateExistingEntity(entityID, with: objectData)
            }
        }
    }
    
    func removeMultipleEntities(_ localIDs: [UInt32]) {
        for localID in localIDs {
            removeOpenSimObject(localID: localID)
        }
    }
    
    func createMultipleEntities(_ objectDataList: [ObjectUpdateMessage.ObjectUpdateData]) {
        for objectData in objectDataList {
            if openSimToECSMap[objectData.localID] == nil {
                createNewEntity(from: objectData)
            }
        }
    }
 }
