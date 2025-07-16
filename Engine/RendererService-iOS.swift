//
//  Engine/RendererService-iOS.swift
//  Storm
//
//  iOS-specific RendererService implementation using AR Camera.
//  Provides touch-based camera controls optimized for mobile devices.
//  Inherits shared functionality from RendererServiceBase.
//
//  Created by Wenyan Qin on 2025-07-15.
//

#if os(iOS)
import Foundation
import RealityKit
import ARKit
import simd

// MARK: - iOS RendererService Implementation

/// iOS-specific implementation of RendererService
/// Uses AR camera for immersive mobile experience
final class RendererService: RendererServiceBase, RendererServiceProtocol {
    
    // MARK: - iOS-Specific Properties
    
    /// Cumulative rotation applied to the root anchor
    private var currentRotation: simd_quatf = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    
    /// Current zoom level (distance from origin)
    private var currentZoom: Float = 0.0
    
    /// Touch sensitivity multipliers
    private let rotationSensitivity: Float = 0.01
    private let zoomSensitivity: Float = 0.1
    private let panSensitivity: Float = 0.01
    
    // MARK: - Initialization
    
    override init(ecs: ECSCore, arView: ARView) {
        super.init(ecs: ecs, arView: arView)
        setupIOSSpecific()
    }
    
    // MARK: - iOS-Specific Setup
    
    /// Configures iOS-specific AR and rendering settings
    private func setupIOSSpecific() {
        // Configure AR session for world tracking
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        // Enable realistic lighting
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        
        // Start AR session
        arView.session.run(configuration)
        
        // Enable RealityKit features
        arView.renderOptions.insert(.disablePersonOcclusion)
        arView.renderOptions.insert(.disableMotionBlur)
        
        // Setup additional iOS test geometry
        setupIOSTestGeometry()
        
        print("[📱] iOS RendererService initialized with AR tracking")
    }
    
    /// Creates iOS-specific test geometry
    private func setupIOSTestGeometry() {
        // Create a floating sphere above the main cube
        let floatingSphere = ModelEntity(
            mesh: MeshResource.generateSphere(radius: 0.15),
            materials: [SimpleMaterial(color: .cyan, isMetallic: true)]
        )
        floatingSphere.position = SIMD3<Float>(0, 1.5, 0)
        rootAnchor.addChild(floatingSphere)
        
        // Create ground plane indicator
        let groundPlane = ModelEntity(
            mesh: MeshResource.generatePlane(width: 2.0, depth: 2.0),
            materials: [SimpleMaterial(color: UIColor.gray.withAlphaComponent(0.3), isMetallic: false)]
        )
        groundPlane.position = SIMD3<Float>(0, 0, 0)
        rootAnchor.addChild(groundPlane)
        
        // Add some visual anchors for AR reference
        createARReferencePoints()
    }
    
    /// Creates reference points to help with AR tracking
    private func createARReferencePoints() {
        let referencePoints: [SIMD3<Float>] = [
            SIMD3<Float>(1, 0.1, 1),    // Front right
            SIMD3<Float>(-1, 0.1, 1),   // Front left
            SIMD3<Float>(1, 0.1, -1),   // Back right
            SIMD3<Float>(-1, 0.1, -1)   // Back left
        ]
        
        for (index, point) in referencePoints.enumerated() {
            let marker = ModelEntity(
                mesh: MeshResource.generateSphere(radius: 0.05),
                materials: [SimpleMaterial(color: .orange, isMetallic: false)]
            )
            marker.position = point
            rootAnchor.addChild(marker)
        }
    }
    
    // MARK: - RendererServiceProtocol Implementation
    
    /// Updates the 3D scene - iOS optimized
    func updateScene() {
        // Call shared update logic
        updateSharedScene()
        
        // iOS-specific scene updates
        updateIOSSpecificScene()
    }
    
    /// iOS-specific scene update logic
    private func updateIOSSpecificScene() {
        // Update AR anchors if needed
        updateARAnchors()
        
        // Apply any iOS-specific optimizations
        optimizeForMobile()
    }
    
    /// Updates AR anchors based on tracking state
    private func updateARAnchors() {
        // Monitor AR tracking state
        switch arView.session.currentFrame?.camera.trackingState {
        case .normal:
            // Good tracking - nothing special needed
            break
        case .limited(let reason):
            // Handle limited tracking
            handleLimitedTracking(reason: reason)
        case .notAvailable:
            // Handle tracking loss
            handleTrackingLoss()
        case .none:
            break
        }
    }
    
    /// Handles limited AR tracking scenarios
    private func handleLimitedTracking(reason: ARCamera.TrackingState.Reason) {
        switch reason {
        case .initializing:
            print("[📱] AR initializing...")
        case .excessiveMotion:
            print("[📱] AR tracking limited: excessive motion")
        case .insufficientFeatures:
            print("[📱] AR tracking limited: insufficient features")
        case .relocalizing:
            print("[📱] AR relocalizing...")
        @unknown default:
            print("[📱] AR tracking limited: unknown reason")
        }
    }
    
    /// Handles complete tracking loss
    private func handleTrackingLoss() {
        print("[📱] AR tracking not available")
        // Could implement fallback camera mode here
    }
    
    /// Applies mobile-specific optimizations
    private func optimizeForMobile() {
        // Reduce update frequency for distant entities
        // Implement LOD (Level of Detail) based on distance
        // These would be implemented based on performance needs
    }
    
    // MARK: - Camera Control Methods (Touch-Optimized)
    
    /// Rotates the scene around the center point (touch-optimized)
    /// - Parameters:
    ///   - yaw: Horizontal rotation (radians)
    ///   - pitch: Vertical rotation (radians)
    func rotateCamera(yaw: Float, pitch: Float) {
        // Apply sensitivity scaling for touch input
        let scaledYaw = yaw * rotationSensitivity
        let scaledPitch = pitch * rotationSensitivity
        
        // Create rotation quaternions
        let yawRotation = simd_quatf(angle: scaledYaw, axis: SIMD3<Float>(0, 1, 0))
        let pitchRotation = simd_quatf(angle: scaledPitch, axis: SIMD3<Float>(1, 0, 0))
        
        // Combine rotations and apply to current rotation
        currentRotation = yawRotation * pitchRotation * currentRotation
        
        // Apply to root anchor
        rootAnchor.orientation = currentRotation
    }
    
    /// Zooms by moving the entire scene (pinch-optimized)
    /// - Parameter delta: Zoom amount (scaled for touch input)
    func zoomCamera(delta: Float) {
        let scaledDelta = delta * zoomSensitivity
        currentZoom += scaledDelta
        
        // Clamp zoom to reasonable limits
        currentZoom = max(-5.0, min(5.0, currentZoom))
        
        // Apply zoom by translating the root anchor
        rootAnchor.transform.translation.z = currentZoom
    }
    
    /// Pans the scene (two-finger pan optimized)
    /// - Parameters:
    ///   - x: Horizontal pan amount
    ///   - y: Vertical pan amount
    func panCamera(x: Float, y: Float) {
        let scaledX = x * panSensitivity
        let scaledY = y * panSensitivity
        
        // Apply pan to root anchor translation
        rootAnchor.transform.translation.x += scaledX
        rootAnchor.transform.translation.y += scaledY
    }
    
    // MARK: - iOS-Specific Methods
    
    /// Resets the AR session
    func resetARSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        // Reset transformations
        currentRotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        currentZoom = 0.0
        rootAnchor.transform = Transform.identity
        
        print("[📱] AR session reset")
    }
    
    /// Gets the current AR camera transform
    func getCurrentCameraTransform() -> Transform? {
        guard let frame = arView.session.currentFrame else { return nil }
        let transform = Transform(matrix: frame.camera.transform)
        return transform
    }
    
    /// Places an object at the current AR camera position
    func placeObjectAtCamera() {
        guard let cameraTransform = getCurrentCameraTransform() else { return }
        
        let newObject = ModelEntity(
            mesh: MeshResource.generateSphere(radius: 0.1),
            materials: [SimpleMaterial(color: .green, isMetallic: false)]
        )
        
        let objectAnchor = AnchorEntity(world: cameraTransform.translation)
        objectAnchor.addChild(newObject)
        arView.scene.addAnchor(objectAnchor)
        
        print("[📱] Object placed at camera position: \(cameraTransform.translation)")
    }
}

// MARK: - iOS Extensions

extension RendererService {
    
    /// Configures AR session for specific use cases
    func configureARSession(for useCase: ARSessionUseCase) {
        let configuration: ARConfiguration
        
        switch useCase {
        case .worldTracking:
            let worldConfig = ARWorldTrackingConfiguration()
            worldConfig.planeDetection = [.horizontal, .vertical]
            worldConfig.environmentTexturing = .automatic
            configuration = worldConfig
            
        case .faceTracking:
            if ARFaceTrackingConfiguration.isSupported {
                configuration = ARFaceTrackingConfiguration()
            } else {
                print("[📱] Face tracking not supported, falling back to world tracking")
                configuration = ARWorldTrackingConfiguration()
            }
            
        case .imageTracking:
            let imageConfig = ARImageTrackingConfiguration()
            // Would need to set up reference images here
            configuration = imageConfig
        }
        
        arView.session.run(configuration)
    }
}

// MARK: - Supporting Types

enum ARSessionUseCase {
    case worldTracking
    case faceTracking
    case imageTracking
}

#endif
