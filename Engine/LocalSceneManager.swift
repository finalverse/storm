//
//  Engine/LocalSceneManager.swift
//  Storm
//
//  Manages local 3D scene representation before and during OpenSim connection
//  Handles avatar creation, camera control, environment setup, and ECS integration
//  Provides seamless transition from local scene to OpenSim world
//
//  Created for Finalverse Storm - Local Scene & Avatar Management
//
//    LocalSceneManager provides:
//
//    Pre-login local scene - Functional 3D environment before OpenSim connection
//    Avatar creation & customization - Local avatar with appearance options
//    Camera control system - Multiple camera modes (first/third person, free, cinematic)
//    Input handling - WASD movement, mouse camera control
//    Environment management - Ground plane, objects, lighting
//    Seamless OpenSim integration - Smooth transition from local to networked
//    ECS integration - Full integration with your existing ECS system
//    RealityKit rendering - Proper 3D visualization
//

import Foundation
import RealityKit
import simd
import Combine

// MARK: - Scene State Management

enum LocalSceneState: String, CaseIterable {
    case initializing = "Initializing"
    case localOnly = "Local Scene"
    case connecting = "Connecting to World"
    case synchronized = "Synchronized"
    case error = "Error"
    
    var allowsAvatarControl: Bool {
        switch self {
        case .localOnly, .synchronized:
            return true
        default:
            return false
        }
    }
}

// MARK: - Avatar Appearance Configuration

struct AvatarAppearance {
    let bodyType: AvatarBodyType
    let skinTone: SkinTone
    let hairStyle: HairStyle
    let hairColor: HairColor
    let eyeColor: EyeColor
    let clothing: ClothingSet
    
    static let `default` = AvatarAppearance(
        bodyType: .humanoid,
        skinTone: .medium,
        hairStyle: .short,
        hairColor: .brown,
        eyeColor: .brown,
        clothing: .casual
    )
}

enum AvatarBodyType: String, CaseIterable {
    case humanoid = "Humanoid"
    case stylized = "Stylized"
    case robot = "Robot"
}

enum SkinTone: String, CaseIterable {
    case light = "Light"
    case medium = "Medium"
    case dark = "Dark"
    case fantasy = "Fantasy"
}

enum HairStyle: String, CaseIterable {
    case short = "Short"
    case long = "Long"
    case curly = "Curly"
    case none = "Bald"
}

enum HairColor: String, CaseIterable {
    case black = "Black"
    case brown = "Brown"
    case blonde = "Blonde"
    case red = "Red"
    case fantasy = "Fantasy"
}

enum EyeColor: String, CaseIterable {
    case brown = "Brown"
    case blue = "Blue"
    case green = "Green"
    case hazel = "Hazel"
    case fantasy = "Fantasy"
}

enum ClothingSet: String, CaseIterable {
    case casual = "Casual"
    case formal = "Formal"
    case fantasy = "Fantasy"
    case scifi = "Sci-Fi"
}

// MARK: - Local Scene Manager

@MainActor
class LocalSceneManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var sceneState: LocalSceneState = .initializing
    @Published var avatarPosition: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    @Published var avatarRotation: simd_quatf = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    @Published var cameraMode: CameraMode = .thirdPerson
    @Published var avatarAppearance: AvatarAppearance = .default
    @Published var isAvatarVisible: Bool = true
    @Published var environmentLighting: EnvironmentLighting = .outdoor
    
    // MARK: - Service References
    private weak var ecs: ECSCore?
    private weak var renderer: RendererService?
    private weak var registry: SystemRegistry?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Scene Entities
    private var localAvatarEntity: EntityID?
    private var groundPlaneEntity: EntityID?
    private var environmentEntities: [EntityID] = []
    private var lightingEntities: [EntityID] = []
    
    // MARK: - RealityKit References
    private var avatarModelEntity: ModelEntity?
    private var avatarAnchor: AnchorEntity?
    private var groundAnchor: AnchorEntity?
    private var environmentAnchor: AnchorEntity?
    
    // MARK: - Camera Control
    private var cameraController: LocalCameraController?
    private var inputController: LocalInputController?
    
    // MARK: - Initialization
    
    init() {
        print("[🎬] LocalSceneManager initialized")
        setupInputHandling()
    }
    
    func setup(registry: SystemRegistry) {
        self.registry = registry
        self.ecs = registry.ecs
        self.renderer = registry.resolve("renderer")
        
        guard let ecs = ecs, let renderer = renderer else {
            print("[❌] Required services not available for LocalSceneManager")
            sceneState = .error
            return
        }
        
        // Setup camera controller
        cameraController = LocalCameraController(arView: renderer.arView)
        
        // Setup input controller
        inputController = LocalInputController()
        inputController?.delegate = self
        
        // Initialize local scene
        initializeLocalScene()
        
        print("[✅] LocalSceneManager setup complete")
    }
    
    // MARK: - Scene Initialization
    
    private func initializeLocalScene() {
        createGroundPlane()
        createEnvironment()
        setupLighting()
        createLocalAvatar()
        
        sceneState = .localOnly
        print("[🎬] Local scene initialized")
    }
    
    private func createGroundPlane() {
        guard let ecs = ecs, let renderer = renderer else { return }
        
        let world = ecs.getWorld()
        
        // Create ground plane entity in ECS
        groundPlaneEntity = world.createEntity()
        
        // Add components
        let position = PositionComponent(position: SIMD3<Float>(0, -0.1, 0))
        world.addComponent(position, to: groundPlaneEntity!)
        
        let terrain = TerrainComponent(size: 20.0) // 20x20 meter ground plane
        world.addComponent(terrain, to: groundPlaneEntity!)
        
        // Create RealityKit representation
        let groundMesh = MeshResource.generatePlane(width: 20, depth: 20)
        var groundMaterial = SimpleMaterial(color: .init(red: 0.2, green: 0.5, blue: 0.2, alpha: 1.0), isMetallic: false)
        groundMaterial.roughness = 0.8
        
        let groundModel = ModelEntity(mesh: groundMesh, materials: [groundMaterial])
        groundModel.position = SIMD3<Float>(0, -0.1, 0)
        
        // Create anchor for ground
        groundAnchor = AnchorEntity(world: SIMD3<Float>(0, -0.1, 0))
        groundAnchor?.addChild(groundModel)
        renderer.arView.scene.addAnchor(groundAnchor!)
        
        print("[🌍] Ground plane created")
    }
    
    private func createEnvironment() {
        guard let ecs = ecs, let renderer = renderer else { return }
        
        let world = ecs.getWorld()
        
        // Create environment anchor
        environmentAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
        
        // Add some basic environment objects
        createEnvironmentObjects()
        
        renderer.arView.scene.addAnchor(environmentAnchor!)
        print("[🌲] Environment created")
    }
    
    private func createEnvironmentObjects() {
        guard let environmentAnchor = environmentAnchor else { return }
        
        // Create a few trees/pillars for reference
        let positions = [
            SIMD3<Float>(-5, 0, -5),
            SIMD3<Float>(5, 0, -5),
            SIMD3<Float>(-5, 0, 5),
            SIMD3<Float>(5, 0, 5),
            SIMD3<Float>(0, 0, -8)
        ]
        
        for (index, position) in positions.enumerated() {
            let pillarMesh = MeshResource.generateCylinder(height: 3, radius: 0.3)
            var pillarMaterial = SimpleMaterial(color: .init(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0), isMetallic: false)
            pillarMaterial.roughness = 0.9
            
            let pillar = ModelEntity(mesh: pillarMesh, materials: [pillarMaterial])
            pillar.position = position + SIMD3<Float>(0, 1.5, 0) // Lift to ground level
            pillar.name = "pillar_\(index)"
            
            environmentAnchor.addChild(pillar)
            
            // Create ECS entity for each pillar
            if let ecs = ecs {
                let world = ecs.getWorld()
                let pillarEntity = world.createEntity()
                
                let positionComponent = PositionComponent(position: position)
                world.addComponent(positionComponent, to: pillarEntity)
                
                let staticObject = StaticObjectComponent(name: "pillar_\(index)", type: .decoration)
                world.addComponent(staticObject, to: pillarEntity)
                
                environmentEntities.append(pillarEntity)
            }
        }
        
        print("[🏛️] Environment objects created")
    }
    
    private func setupLighting() {
        guard let renderer = renderer else { return }
        
        // Setup directional light (sun)
        let sunLight = DirectionalLight()
        sunLight.light.color = .white
        sunLight.light.intensity = 10000
        sunLight.orientation = simd_quatf(angle: -Float.pi/4, axis: SIMD3<Float>(1, 0, 0))
        
        let lightAnchor = AnchorEntity(world: SIMD3<Float>(0, 10, 0))
        lightAnchor.addChild(sunLight)
        renderer.arView.scene.addAnchor(lightAnchor)
        
        // Add ambient lighting
        renderer.arView.environment.lighting.intensityExponent = 1.5
        
        print("[☀️] Lighting setup complete")
    }
    
    // MARK: - Avatar Creation & Management
    
    private func createLocalAvatar() {
        guard let ecs = ecs, let renderer = renderer else { return }
        
        let world = ecs.getWorld()
        
        // Create avatar entity in ECS
        localAvatarEntity = world.createEntity()
        
        // Add avatar components
        let position = PositionComponent(position: avatarPosition)
        world.addComponent(position, to: localAvatarEntity!)
        
        let rotation = RotationComponent(rotation: avatarRotation)
        world.addComponent(rotation, to: localAvatarEntity!)
        
        let localAvatar = LocalAvatarComponent(
            firstName: "Local",
            lastName: "Avatar",
            fullName: "Local Avatar"
        )
        world.addComponent(localAvatar, to: localAvatarEntity!)
        
        let appearance = AvatarAppearanceComponent(appearance: avatarAppearance)
        world.addComponent(appearance, to: localAvatarEntity!)
        
        // Create visual representation
        createAvatarVisual()
        
        // Setup camera
        setupCameraForAvatar()
        
        print("[👤] Local avatar created")
    }
    
    private func createAvatarVisual() {
        guard let renderer = renderer else { return }
        
        // Create simple avatar representation (capsule for now)
        let bodyMesh = MeshResource.generateCapsule(height: 1.8, radius: 0.3)
        var bodyMaterial = SimpleMaterial(color: avatarAppearance.skinTone.color, isMetallic: false)
        bodyMaterial.roughness = 0.7
        
        avatarModelEntity = ModelEntity(mesh: bodyMesh, materials: [bodyMaterial])
        avatarModelEntity?.position = avatarPosition + SIMD3<Float>(0, 0.9, 0) // Lift to standing position
        avatarModelEntity?.name = "local_avatar"
        
        // Add head (sphere)
        let headMesh = MeshResource.generateSphere(radius: 0.15)
        let headMaterial = SimpleMaterial(color: avatarAppearance.skinTone.color, isMetallic: false)
        let head = ModelEntity(mesh: headMesh, materials: [headMaterial])
        head.position = SIMD3<Float>(0, 0.75, 0) // Top of body
        avatarModelEntity?.addChild(head)
        
        // Create avatar anchor
        avatarAnchor = AnchorEntity(world: avatarPosition)
        avatarAnchor?.addChild(avatarModelEntity!)
        
        // Add to scene
        renderer.arView.scene.addAnchor(avatarAnchor!)
        
        print("[🎭] Avatar visual created")
    }
    
    func updateAvatarAppearance(_ newAppearance: AvatarAppearance) {
        avatarAppearance = newAppearance
        
        // Update ECS component
        if let ecs = ecs, let avatarEntity = localAvatarEntity {
            let world = ecs.getWorld()
            if let appearanceComponent = world.getComponent(ofType: AvatarAppearanceComponent.self, from: avatarEntity) {
                appearanceComponent.appearance = newAppearance
            }
        }
        
        // Update visual representation
        updateAvatarVisual()
        
        print("[🎭] Avatar appearance updated")
    }
    
    private func updateAvatarVisual() {
        guard let avatarModel = avatarModelEntity else { return }
        
        // Update materials based on new appearance
        if let bodyMaterial = avatarModel.model?.materials.first as? SimpleMaterial {
            let newMaterial = SimpleMaterial(color: avatarAppearance.skinTone.color, isMetallic: false)
            avatarModel.model?.materials = [newMaterial]
        }
        
        // Update head material
        if let head = avatarModel.children.first {
            if let headModel = head as? ModelEntity {
                let headMaterial = SimpleMaterial(color: avatarAppearance.skinTone.color, isMetallic: false)
                headModel.model?.materials = [headMaterial]
            }
        }
    }
    
    // MARK: - Avatar Movement
    
    func moveAvatar(to position: SIMD3<Float>, rotation: simd_quatf? = nil) {
        guard sceneState.allowsAvatarControl else {
            print("[⚠️] Avatar movement not allowed in current state: \(sceneState)")
            return
        }
        
        // Update internal state
        avatarPosition = position
        if let rotation = rotation {
            avatarRotation = rotation
        }
        
        // Update ECS components
        updateAvatarECSPosition(position, rotation: rotation)
        
        // Update visual representation
        updateAvatarVisualPosition(position, rotation: rotation)
        
        // Update camera
        cameraController?.updateAvatarPosition(position)
        
        print("[🚶] Avatar moved to: \(position)")
    }
    
    func rotateAvatar(by rotation: simd_quatf) {
        let newRotation = avatarRotation * rotation
        moveAvatar(to: avatarPosition, rotation: newRotation)
    }
    
    func teleportAvatar(to position: SIMD3<Float>) {
        moveAvatar(to: position, rotation: avatarRotation)
        
        // Smooth camera transition for teleport
        cameraController?.smoothTransitionToPosition(position, duration: 1.0)
        
        print("[🚀] Avatar teleported to: \(position)")
    }
    
    private func updateAvatarECSPosition(_ position: SIMD3<Float>, rotation: simd_quatf?) {
        guard let ecs = ecs, let avatarEntity = localAvatarEntity else { return }
        
        let world = ecs.getWorld()
        
        // Update position component
        if let positionComponent = world.getComponent(ofType: PositionComponent.self, from: avatarEntity) {
            positionComponent.position = position
        }
        
        // Update rotation component
        if let rotation = rotation,
           let rotationComponent = world.getComponent(ofType: RotationComponent.self, from: avatarEntity) {
            rotationComponent.rotation = rotation
        }
    }
    
    private func updateAvatarVisualPosition(_ position: SIMD3<Float>, rotation: simd_quatf?) {
        // Update anchor position
        avatarAnchor?.transform.translation = position
        
        // Update model position (offset for standing)
        avatarModelEntity?.position = SIMD3<Float>(0, 0.9, 0)
        
        // Update rotation if provided
        if let rotation = rotation {
            avatarAnchor?.transform.rotation = rotation
        }
    }
    
    // MARK: - Camera Management
    
    private func setupCameraForAvatar() {
        cameraController?.setupForAvatar(position: avatarPosition, rotation: avatarRotation)
        cameraController?.setCameraMode(cameraMode)
    }
    
    func setCameraMode(_ mode: CameraMode) {
        cameraMode = mode
        cameraController?.setCameraMode(mode)
        
        // Update avatar visibility based on camera mode
        isAvatarVisible = (mode != .firstPerson)
        avatarModelEntity?.isEnabled = isAvatarVisible
        
        print("[📷] Camera mode set to: \(mode)")
    }
    
    func adjustCameraDistance(_ delta: Float) {
        cameraController?.adjustDistance(delta)
    }
    
    func rotateCameraAroundAvatar(yaw: Float, pitch: Float) {
        cameraController?.rotateAroundTarget(yaw: yaw, pitch: pitch)
    }
    
    // MARK: - OpenSim Integration
    
    func prepareForOpenSimConnection() {
        print("[🔄] Preparing scene for OpenSim connection...")
        sceneState = .connecting
        
        // Keep local avatar but prepare for synchronization
        // The avatar will be updated with OpenSim data once connected
    }
    
    func synchronizeWithOpenSim(agentID: UUID, sessionID: UUID, serverPosition: SIMD3<Float>?) {
        print("[🔄] Synchronizing local scene with OpenSim...")
        
        // Update avatar with OpenSim session data
        if let ecs = ecs, let avatarEntity = localAvatarEntity {
            let world = ecs.getWorld()
            
            // Add OpenSim session component
            let sessionComponent = OpenSimSessionComponent(
                agentID: agentID,
                sessionID: sessionID,
                isConnected: true
            )
            world.addComponent(sessionComponent, to: avatarEntity)
        }
        
        // Move avatar to server position if provided
        if let serverPosition = serverPosition {
            moveAvatar(to: serverPosition)
        }
        
        sceneState = .synchronized
        print("[✅] Scene synchronized with OpenSim")
    }
    
    func disconnectFromOpenSim() {
        print("[🔄] Disconnecting from OpenSim, returning to local scene...")
        
        // Remove OpenSim session component
        if let ecs = ecs, let avatarEntity = localAvatarEntity {
            let world = ecs.getWorld()
            world.removeComponent(ofType: OpenSimSessionComponent.self, from: avatarEntity)
        }
        
        sceneState = .localOnly
        print("[✅] Returned to local scene mode")
    }
    
    // MARK: - Environment Control
    
    func setEnvironmentLighting(_ lighting: EnvironmentLighting) {
        environmentLighting = lighting
        
        guard let renderer = renderer else { return }
        
        switch lighting {
        case .indoor:
            renderer.arView.environment.lighting.intensityExponent = 0.8
            // Could add warm indoor lighting
            
        case .outdoor:
            renderer.arView.environment.lighting.intensityExponent = 1.5
            // Natural outdoor lighting
            
        case .night:
            renderer.arView.environment.lighting.intensityExponent = 0.3
            // Dim night lighting
            
        case .dramatic:
            renderer.arView.environment.lighting.intensityExponent = 2.0
            // High contrast dramatic lighting
        }
        
        print("[💡] Environment lighting set to: \(lighting)")
    }
    
    // MARK: - Input Handling
    
    private func setupInputHandling() {
        // Setup gesture recognizers and input handling
        // This would integrate with your InputController system
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        // Remove all anchors from scene
        if let renderer = renderer {
            if let avatarAnchor = avatarAnchor {
                renderer.arView.scene.removeAnchor(avatarAnchor)
            }
            if let groundAnchor = groundAnchor {
                renderer.arView.scene.removeAnchor(groundAnchor)
            }
            if let environmentAnchor = environmentAnchor {
                renderer.arView.scene.removeAnchor(environmentAnchor)
            }
        }
        
        // Remove ECS entities
        if let ecs = ecs {
            let world = ecs.getWorld()
            
            if let avatarEntity = localAvatarEntity {
                world.removeEntity(avatarEntity)
            }
            if let groundEntity = groundPlaneEntity {
                world.removeEntity(groundEntity)
            }
            for entity in environmentEntities {
                world.removeEntity(entity)
            }
        }
        
        // Clear references
        localAvatarEntity = nil
        groundPlaneEntity = nil
        environmentEntities.removeAll()
        avatarModelEntity = nil
        avatarAnchor = nil
        groundAnchor = nil
        environmentAnchor = nil
        
        print("[🧹] Local scene cleanup complete")
    }
}

// MARK: - Supporting Enums

enum CameraMode: String, CaseIterable {
    case firstPerson = "First Person"
    case thirdPerson = "Third Person"
    case free = "Free Camera"
    case cinematic = "Cinematic"
    
    var description: String {
        return rawValue
    }
}

enum EnvironmentLighting: String, CaseIterable {
    case indoor = "Indoor"
    case outdoor = "Outdoor"
    case night = "Night"
    case dramatic = "Dramatic"
    
    var description: String {
        return rawValue
    }
}

// MARK: - Input Controller Protocol

protocol LocalInputControllerDelegate: AnyObject {
    func inputController(_ controller: LocalInputController, didReceiveMovementInput direction: SIMD3<Float>)
    func inputController(_ controller: LocalInputController, didReceiveCameraInput yaw: Float, pitch: Float)
    func inputController(_ controller: LocalInputController, didReceiveCameraModeChange mode: CameraMode)
}

class LocalInputController {
    weak var delegate: LocalInputControllerDelegate?
    
    private var currentMovementDirection: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    private var movementSpeed: Float = 2.0 // meters per second
    
    func handleKeyInput(_ key: String, isPressed: Bool) {
        // Handle WASD movement keys
        switch key.lowercased() {
        case "w":
            currentMovementDirection.z = isPressed ? -movementSpeed : 0
        case "s":
            currentMovementDirection.z = isPressed ? movementSpeed : 0
        case "a":
            currentMovementDirection.x = isPressed ? -movementSpeed : 0
        case "d":
            currentMovementDirection.x = isPressed ? movementSpeed : 0
        default:
            break
        }
        
        delegate?.inputController(self, didReceiveMovementInput: currentMovementDirection)
    }
    
    func handleMouseMovement(deltaX: Float, deltaY: Float) {
        let sensitivity: Float = 0.01
        let yaw = deltaX * sensitivity
        let pitch = deltaY * sensitivity
        
        delegate?.inputController(self, didReceiveCameraInput: yaw: yaw, pitch: pitch)
    }
    
    func cycleCameraMode() {
        // Cycle through camera modes
        let modes = CameraMode.allCases
        // Implementation would track current mode and cycle to next
    }
}

// MARK: - Camera Controller

class LocalCameraController {
    private let arView: ARView
    private var cameraAnchor: AnchorEntity?
    private var targetPosition: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    private var currentMode: CameraMode = .thirdPerson
    private var distance: Float = 5.0
    private var yawAngle: Float = 0
    private var pitchAngle: Float = 0
    
    init(arView: ARView) {
        self.arView = arView
        setupCamera()
    }
    
    private func setupCamera() {
        cameraAnchor = AnchorEntity(world: SIMD3<Float>(0, 2, 5))
        arView.scene.addAnchor(cameraAnchor!)
    }
    
    func setupForAvatar(position: SIMD3<Float>, rotation: simd_quatf) {
        targetPosition = position
        updateCameraPosition()
    }
    
    func setCameraMode(_ mode: CameraMode) {
        currentMode = mode
        
        switch mode {
        case .firstPerson:
            distance = 0.1
            pitchAngle = 0
        case .thirdPerson:
            distance = 5.0
            pitchAngle = -0.3
        case .free:
            // Free camera mode - no constraints
            break
        case .cinematic:
            distance = 8.0
            pitchAngle = -0.5
        }
        
        updateCameraPosition()
    }
    
    func updateAvatarPosition(_ position: SIMD3<Float>) {
        targetPosition = position
        updateCameraPosition()
    }
    
    func rotateAroundTarget(yaw: Float, pitch: Float) {
        yawAngle += yaw
        pitchAngle = max(-Float.pi/2, min(Float.pi/2, pitchAngle + pitch))
        updateCameraPosition()
    }
    
    func adjustDistance(_ delta: Float) {
        distance = max(0.5, min(20.0, distance + delta))
        updateCameraPosition()
    }
    
    func smoothTransitionToPosition(_ position: SIMD3<Float>, duration: TimeInterval) {
        targetPosition = position
        // Implement smooth animation here
        updateCameraPosition()
    }
    
    private func updateCameraPosition() {
        guard let anchor = cameraAnchor else { return }
        
        let yawQuat = simd_quatf(angle: yawAngle, axis: SIMD3<Float>(0, 1, 0))
        let pitchQuat = simd_quatf(angle: pitchAngle, axis: SIMD3<Float>(1, 0, 0))
        let rotation = yawQuat * pitchQuat
        
        let offset = rotation.act(SIMD3<Float>(0, 0, distance))
        let cameraPosition = targetPosition + offset + SIMD3<Float>(0, 1.7, 0) // Eye height
        
        anchor.transform.translation = cameraPosition
        anchor.look(at: targetPosition + SIMD3<Float>(0, 1.7, 0), from: cameraPosition, relativeTo: nil)
    }
}

// MARK: - LocalSceneManager Extension for LocalInputControllerDelegate

extension LocalSceneManager: LocalInputControllerDelegate {
    
    func inputController(_ controller: LocalInputController, didReceiveMovementInput direction: SIMD3<Float>) {
        guard sceneState.allowsAvatarControl else { return }
        
        // Apply movement relative to avatar rotation
        let rotatedDirection = avatarRotation.act(direction)
        let newPosition = avatarPosition + (rotatedDirection * 0.016) // Assuming 60fps
        
        moveAvatar(to: newPosition)
    }
    
    func inputController(_ controller: LocalInputController, didReceiveCameraInput yaw: Float, pitch: Float) {
        rotateCameraAroundAvatar(yaw: yaw, pitch: pitch)
    }
    
    func inputController(_ controller: LocalInputController, didReceiveCameraModeChange mode: CameraMode) {
        setCameraMode(mode)
    }
}

// MARK: - Additional ECS Components

final class AvatarAppearanceComponent: Component {
    var appearance: AvatarAppearance
    
    init(appearance: AvatarAppearance) {
        self.appearance = appearance
    }
}

final class OpenSimSessionComponent: Component {
    let agentID: UUID
    let sessionID: UUID
    var isConnected: Bool
    var lastUpdateTime: Date
    
    init(agentID: UUID, sessionID: UUID, isConnected: Bool) {
        self.agentID = agentID
        self.sessionID = sessionID
        self.isConnected = isConnected
        self.lastUpdateTime = Date()
    }
}

final class StaticObjectComponent: Component {
    let name: String
    let type: ObjectType
    
    init(name: String, type: ObjectType) {
        self.name = name
        self.type = type
    }
    
    enum ObjectType {
        case decoration
        case structure
        case interactive
        case terrain
    }
}

// MARK: - Color Extensions

extension SkinTone {
    var color: UIColor {
        switch self {
        case .light:
            return UIColor(red: 0.94, green: 0.83, blue: 0.73, alpha: 1.0)
        case .medium:
            return UIColor(red: 0.80, green: 0.65, blue: 0.50, alpha: 1.0)
        case .dark:
            return UIColor(red: 0.45, green: 0.35, blue: 0.25, alpha: 1.0)
        case .fantasy:
            return UIColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 1.0)
        }
    }
}
