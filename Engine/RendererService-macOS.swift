//
//  Engine/RendererService-macOS.swift
//  Storm
//
//  macOS-specific RendererService implementation using Perspective Camera.
//  Provides mouse and keyboard camera controls optimized for desktop use.
//  Inherits shared functionality from RendererServiceBase.
//
//  Created by Wenyan Qin on 2025-07-15.
//

#if os(macOS)
import Foundation
import RealityKit
import simd

// MARK: - macOS RendererService Implementation

/// macOS-specific implementation of RendererService
/// Uses perspective camera with mouse/keyboard controls for desktop experience
final class RendererService: RendererServiceBase, RendererServiceProtocol {
    
    // MARK: - macOS-Specific Properties
    
    /// Camera anchor for perspective view
    private let cameraAnchor = AnchorEntity(world: SIMD3<Float>(0, 1.5, 3))
    
    /// Current camera orientation
    private var cameraOrientation: simd_quatf
    
    /// Current camera position
    private var cameraPosition: SIMD3<Float>
    
    /// Mouse sensitivity multipliers
    private let mouseSensitivity: Float = 0.005
    private let zoomSensitivity: Float = 0.1
    private let panSensitivity: Float = 0.01
    
    /// Keyboard movement speeds
    private let keyboardMoveSpeed: Float = 2.0
    private let keyboardRotateSpeed: Float = 1.0
    
    // MARK: - Initialization
    
    override init(ecs: ECSCore, arView: ARView) {
        // Initialize camera properties
        self.cameraPosition = SIMD3<Float>(0, 1.5, 3)
        self.cameraOrientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        
        super.init(ecs: ecs, arView: arView)
        setupMacOSSpecific()
    }
    
    // MARK: - macOS-Specific Setup
    
    /// Configures macOS-specific rendering and camera settings
    private func setupMacOSSpecific() {
        // Setup perspective camera
        cameraAnchor.components.set(PerspectiveCameraComponent(
            near: 0.1,
            far: 1000.0,
            fieldOfViewInDegrees: 60.0
        ))
        
        // Position camera to look at the scene center
        setupCameraLookAt()
        
        // Add camera to root anchor
        rootAnchor.addChild(cameraAnchor)
        
        // Create enhanced test geometry for macOS
        setupMacOSTestGeometry()
        
        // Configure desktop-specific rendering options
        configureDesktopRendering()
        
        print("[🖥️] macOS RendererService initialized with perspective camera")
    }
    
    /// Sets up initial camera look-at configuration
    private func setupCameraLookAt() {
        let lookAt = SIMD3<Float>(0, 1, 0)  // Look at scene center
        let eye = cameraPosition
        let forward = normalize(lookAt - eye)
        
        // Calculate initial orientation to look at target
        cameraOrientation = simd_quatf(from: SIMD3<Float>(0, 0, -1), to: forward)
        cameraAnchor.orientation = cameraOrientation
        cameraAnchor.position = cameraPosition
    }
    
    /// Creates enhanced test geometry for macOS
    private func setupMacOSTestGeometry() {
        // Right pyramid (green)
        let rightPyramid = ModelEntity(
            mesh: MeshResource.generateCone(height: 0.5, radius: 0.3),
            materials: [SimpleMaterial(color: .green, isMetallic: false)]
        )
        rightPyramid.position = SIMD3<Float>(1, 1, 0)
        rootAnchor.addChild(rightPyramid)
        
        // Left pyramid (blue)
        let leftPyramid = ModelEntity(
            mesh: MeshResource.generateCone(height: 0.5, radius: 0.3),
            materials: [SimpleMaterial(color: .blue, isMetallic: false)]
        )
        leftPyramid.position = SIMD3<Float>(-1, 1, 0)
        rootAnchor.addChild(leftPyramid)
        
        // Create array of test cubes around the scene
        createTestCubeArray()
        
        // Create a ground grid for better spatial reference
        createGroundGrid()
    }
    
    /// Creates an array of test cubes for visual reference
    private func createTestCubeArray() {
        let cubeMesh = MeshResource.generateBox(size: 0.2)
        let cubeMaterial = SimpleMaterial(color: .yellow, isMetallic: false)
        
        let offsets: [SIMD3<Float>] = [
            SIMD3<Float>(1, 0, 0),      // Right
            SIMD3<Float>(-1, 0, 0),     // Left
            SIMD3<Float>(0, 1, 0),      // Up
            SIMD3<Float>(0, -1, 0),     // Down
            SIMD3<Float>(0, 0, 1),      // Forward
            SIMD3<Float>(0, 0, -1),     // Back
            SIMD3<Float>(1, 1, 1),      // Upper right forward
            SIMD3<Float>(-1, -1, -1)    // Lower left back
        ]
        
        for offset in offsets {
            let testCube = ModelEntity(mesh: cubeMesh, materials: [cubeMaterial])
            testCube.position = offset
            rootAnchor.addChild(testCube)
        }
    }
    
    /// Creates a ground grid for spatial reference
    private func createGroundGrid() {
        let gridSize = 10
        let spacing: Float = 0.5
        let lineHeight: Float = 0.01
        
        for i in -gridSize...gridSize {
            let x = Float(i) * spacing
            
            // Create X-direction lines
            let xLine = ModelEntity(
                mesh: MeshResource.generateBox(size: SIMD3<Float>(Float(gridSize * 2) * spacing, lineHeight, lineHeight)),
                materials: [SimpleMaterial(color: UIColor.gray.withAlphaComponent(0.3), isMetallic: false)]
            )
            xLine.position = SIMD3<Float>(0, 0, x)
            rootAnchor.addChild(xLine)
            
            // Create Z-direction lines
            let zLine = ModelEntity(
                mesh: MeshResource.generateBox(size: SIMD3<Float>(lineHeight, lineHeight, Float(gridSize * 2) * spacing)),
                materials: [SimpleMaterial(color: UIColor.gray.withAlphaComponent(0.3), isMetallic: false)]
            )
            zLine.position = SIMD3<Float>(x, 0, 0)
            rootAnchor.addChild(zLine)
        }
    }
    
    /// Configures desktop-specific rendering options
    private func configureDesktopRendering() {
        // Enable high-quality rendering options for desktop
        arView.renderOptions.insert(.disablePersonOcclusion)
        arView.renderOptions.insert(.disableMotionBlur)
        
        // Configure environment for better desktop experience
        arView.environment.background = .color(.black)
        arView.environment.lighting.intensityExponent = 1.0
        
        // Enable advanced graphics features available on macOS
        if #available(macOS 13.0, *) {
            // Use higher quality rendering modes
            arView.preferredFramesPerSecond = 60
        }
    }
    
    // MARK: - RendererServiceProtocol Implementation
    
    /// Updates the 3D scene - macOS optimized
    func updateScene() {
        // Call shared update logic
        updateSharedScene()
        
        // macOS-specific scene updates
        updateMacOSSpecificScene()
    }
    
    /// macOS-specific scene update logic
    private func updateMacOSSpecificScene() {
        // Update camera based on current position and orientation
        updateCameraTransform()
        
        // Apply desktop-specific optimizations
        optimizeForDesktop()
        
        // Handle keyboard input for camera movement
        handleKeyboardInput()
    }
    
    /// Updates camera transform based on current position and orientation
    private func updateCameraTransform() {
        cameraAnchor.position = cameraPosition
        cameraAnchor.orientation = cameraOrientation
    }
    
    /// Applies desktop-specific optimizations
    private func optimizeForDesktop() {
        // Desktop has more processing power, so we can:
        // - Render more detailed geometry
        // - Use higher quality materials
        // - Enable advanced lighting effects
        // These would be implemented based on performance needs
    }
    
    /// Handles keyboard input for camera movement (WASD + arrow keys)
    private func handleKeyboardInput() {
        // This would integrate with InputController for actual keyboard handling
        // For now, this is a placeholder for the keyboard input system
    }
    
    // MARK: - Camera Control Methods (Mouse/Keyboard Optimized)
    
    /// Rotates the camera using mouse input
    /// - Parameters:
    ///   - yaw: Horizontal rotation (radians)
    ///   - pitch: Vertical rotation (radians)
    func rotateCamera(yaw: Float, pitch: Float) {
        // Apply sensitivity scaling for mouse input
        let scaledYaw = yaw * mouseSensitivity
        let scaledPitch = pitch * mouseSensitivity
        
        // Create rotation quaternions
        let yawRotation = simd_quatf(angle: scaledYaw, axis: SIMD3<Float>(0, 1, 0))
        let pitchRotation = simd_quatf(angle: scaledPitch, axis: SIMD3<Float>(1, 0, 0))
        
        // Apply rotations to current orientation
        cameraOrientation = yawRotation * pitchRotation * cameraOrientation
        
        // Normalize to prevent drift
        cameraOrientation = normalize(cameraOrientation)
    }
    
    /// Zooms by moving camera forward/backward along view direction
    /// - Parameter delta: Zoom amount (mouse wheel input)
    func zoomCamera(delta: Float) {
        let scaledDelta = delta * zoomSensitivity
        
        // Calculate forward direction from current orientation
        let forward = getForwardVector(from: cameraOrientation)
        
        // Move camera along forward vector
        cameraPosition += forward * scaledDelta
        
        // Clamp camera position to reasonable bounds
        clampCameraPosition()
    }
    
    /// Pans the camera using middle mouse drag
    /// - Parameters:
    ///   - x: Horizontal pan amount
    ///   - y: Vertical pan amount
    func panCamera(x: Float, y: Float) {
        let scaledX = x * panSensitivity
        let scaledY = y * panSensitivity
        
        // Get camera basis vectors
        let right = getRightVector(from: cameraOrientation)
        let up = getUpVector(from: cameraOrientation)
        
        // Apply pan movement in camera space
        cameraPosition += right * scaledX
        cameraPosition += up * scaledY
        
        // Clamp camera position to reasonable bounds
        clampCameraPosition()
    }
    
    /// Clamps camera position to prevent it from going too far from scene
    private func clampCameraPosition() {
        let maxDistance: Float = 50.0
        let minDistance: Float = 0.5
        
        // Calculate distance from origin
        let distance = length(cameraPosition)
        
        if distance > maxDistance {
            cameraPosition = normalize(cameraPosition) * maxDistance
        } else if distance < minDistance {
            cameraPosition = normalize(cameraPosition) * minDistance
        }
    }
    
    // MARK: - macOS-Specific Camera Methods
    
    /// Moves camera using WASD keyboard input
    /// - Parameters:
    ///   - forward: Forward/backward movement (-1 to 1)
    ///   - right: Left/right movement (-1 to 1)
    ///   - up: Up/down movement (-1 to 1)
    ///   - deltaTime: Time since last update for frame-rate independent movement
    func moveCamera(forward: Float, right: Float, up: Float, deltaTime: Float) {
        let moveSpeed = keyboardMoveSpeed * deltaTime
        
        // Calculate movement vectors in camera space
        let forwardVector = getForwardVector(from: cameraOrientation)
        let rightVector = getRightVector(from: cameraOrientation)
        let upVector = SIMD3<Float>(0, 1, 0) // World up for vertical movement
        
        // Apply movement
        cameraPosition += forwardVector * (forward * moveSpeed)
        cameraPosition += rightVector * (right * moveSpeed)
        cameraPosition += upVector * (up * moveSpeed)
        
        clampCameraPosition()
    }
    
    /// Rotates camera using keyboard arrow keys
    /// - Parameters:
    ///   - yaw: Yaw rotation input (-1 to 1)
    ///   - pitch: Pitch rotation input (-1 to 1)
    ///   - deltaTime: Time since last update
    func rotateCamera(yaw: Float, pitch: Float, deltaTime: Float) {
        let rotateSpeed = keyboardRotateSpeed * deltaTime
        
        // Apply keyboard rotation
        rotateCamera(yaw: yaw * rotateSpeed, pitch: pitch * rotateSpeed)
    }
    
    /// Sets camera to look at a specific point
    /// - Parameters:
    ///   - target: World position to look at
    ///   - position: Camera position (optional, uses current if nil)
    func lookAt(target: SIMD3<Float>, position: SIMD3<Float>? = nil) {
        if let newPosition = position {
            cameraPosition = newPosition
        }
        
        // Calculate direction from camera to target
        let direction = normalize(target - cameraPosition)
        
        // Calculate new orientation to look at target
        cameraOrientation = simd_quatf(from: SIMD3<Float>(0, 0, -1), to: direction)
    }
    
    /// Orbits camera around a target point
    /// - Parameters:
    ///   - target: Point to orbit around
    ///   - radius: Distance from target
    ///   - yaw: Horizontal angle (radians)
    ///   - pitch: Vertical angle (radians)
    func orbitCamera(around target: SIMD3<Float>, radius: Float, yaw: Float, pitch: Float) {
        // Calculate spherical coordinates
        let x = radius * cos(pitch) * sin(yaw)
        let y = radius * sin(pitch)
        let z = radius * cos(pitch) * cos(yaw)
        
        // Set camera position
        cameraPosition = target + SIMD3<Float>(x, y, z)
        
        // Look at the target
        lookAt(target: target)
    }
    
    /// Resets camera to default position and orientation
    func resetCamera() {
        cameraPosition = SIMD3<Float>(0, 1.5, 3)
        cameraOrientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        setupCameraLookAt()
        
        print("[🖥️] Camera reset to default position")
    }
    
    /// Gets current camera state for saving/restoring
    func getCameraState() -> CameraState {
        return CameraState(position: cameraPosition, orientation: cameraOrientation)
    }
    
    /// Restores camera to a previously saved state
    func setCameraState(_ state: CameraState) {
        cameraPosition = state.position
        cameraOrientation = state.orientation
    }
    
    /// Smoothly transitions camera to a new position and orientation
    /// - Parameters:
    ///   - targetPosition: Target camera position
    ///   - targetOrientation: Target camera orientation
    ///   - duration: Animation duration in seconds
    func animateCamera(to targetPosition: SIMD3<Float>,
                      orientation targetOrientation: simd_quatf,
                      duration: Float) {
        // This would implement smooth camera animation
        // For now, we'll do an immediate transition
        cameraPosition = targetPosition
        cameraOrientation = targetOrientation
        
        print("[🖥️] Camera animated to new position")
    }
}

// MARK: - macOS Extensions

extension RendererService {
    
    /// Configures camera for specific viewing modes
    func setCameraMode(_ mode: CameraMode) {
        switch mode {
        case .free:
            // Default free-look camera mode
            break
            
        case .orbit(let target, let radius):
            // Orbit around a target point
            orbitCamera(around: target, radius: radius, yaw: 0, pitch: 0)
            
        case .fixed(let position, let target):
            // Fixed position looking at target
            cameraPosition = position
            lookAt(target: target)
            
        case .follow(let entity):
            // Follow an entity (would need entity tracking)
            if let position = ecs.getComponent(PositionComponent.self, for: entity)?.value {
                lookAt(target: position, position: position + SIMD3<Float>(0, 2, 3))
            }
        }
    }
    
    /// Updates viewport for window resizing
    func updateViewport(size: CGSize) {
        // Update camera aspect ratio based on window size
        if var camera = cameraAnchor.components[PerspectiveCameraComponent.self] {
            // This would update the camera's aspect ratio
            // RealityKit handles this automatically, but we could override if needed
            print("[🖥️] Viewport updated: \(size)")
        }
    }
}

// MARK: - Supporting Types

struct CameraState {
    let position: SIMD3<Float>
    let orientation: simd_quatf
}

enum CameraMode {
    case free
    case orbit(target: SIMD3<Float>, radius: Float)
    case fixed(position: SIMD3<Float>, target: SIMD3<Float>)
    case follow(entity: EntityID)
}

#endif
