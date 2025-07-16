//
//  Engine/RendererServiceFactory.swift
//  Storm
//
//  Factory for creating platform-specific RendererService instances.
//  Automatically detects platform and returns appropriate implementation.
//  Provides unified interface for cross-platform renderer creation.
//
//  Created by Wenyan Qin on 2025-07-15.
//

import Foundation
import RealityKit

// MARK: - RendererService Factory

/// Factory class for creating platform-appropriate RendererService instances
/// Handles platform detection and returns the correct implementation
class RendererServiceFactory {
    
    /// Creates a RendererService instance appropriate for the current platform
    /// - Parameters:
    ///   - ecs: ECS core instance for entity management
    ///   - arView: ARView instance for rendering
    /// - Returns: Platform-specific RendererService implementation
    static func createRenderer(ecs: ECSCore, arView: ARView) -> any RendererServiceProtocol {
        #if os(iOS)
        print("[🏭] Creating iOS RendererService")
        return RendererService(ecs: ecs, arView: arView)
        #elseif os(macOS)
        print("[🏭] Creating macOS RendererService")
        return RendererService(ecs: ecs, arView: arView)
        #elseif os(visionOS)
        print("[🏭] Creating visionOS RendererService")
        // Future: Create visionOS-specific implementation
        return RendererService(ecs: ecs, arView: arView)
        #else
        fatalError("Unsupported platform for RendererService")
        #endif
    }
    
    /// Creates a renderer with platform-specific configuration
    /// - Parameters:
    ///   - ecs: ECS core instance
    ///   - arView: ARView instance
    ///   - config: Platform-specific configuration options
    /// - Returns: Configured RendererService instance
    static func createRenderer(ecs: ECSCore,
                             arView: ARView,
                             config: RendererConfiguration) -> any RendererServiceProtocol {
        let renderer = createRenderer(ecs: ecs, arView: arView)
        
        // Apply platform-specific configuration
        applyConfiguration(config, to: renderer)
        
        return renderer
    }
    
    /// Applies configuration to the renderer instance
    /// - Parameters:
    ///   - config: Configuration to apply
    ///   - renderer: Renderer instance to configure
    private static func applyConfiguration(_ config: RendererConfiguration,
                                         to renderer: any RendererServiceProtocol) {
        // Apply common configuration options
        // Platform-specific configurations would be handled by the implementations
        
        #if os(iOS)
        if let iosRenderer = renderer as? RendererService,
           let iosConfig = config.iosConfig {
            applyIOSConfiguration(iosConfig, to: iosRenderer)
        }
        #elseif os(macOS)
        if let macosRenderer = renderer as? RendererService,
           let macosConfig = config.macosConfig {
            applyMacOSConfiguration(macosConfig, to: macosRenderer)
        }
        #endif
        
        print("[🏭] Applied platform configuration to renderer")
    }
    
    #if os(iOS)
    /// Applies iOS-specific configuration
    private static func applyIOSConfiguration(_ config: IOSRendererConfiguration,
                                            to renderer: RendererService) {
        // Configure AR session if needed
        if config.enableARTracking {
            renderer.configureARSession(for: config.arSessionType)
        }
        
        // Reset AR session if requested
        if config.resetAROnStart {
            renderer.resetARSession()
        }
    }
    #endif
    
    #if os(macOS)
    /// Applies macOS-specific configuration
    private static func applyMacOSConfiguration(_ config: MacOSRendererConfiguration,
                                              to renderer: RendererService) {
        // Set initial camera mode
        renderer.setCameraMode(config.initialCameraMode)
        
        // Reset camera if requested
        if config.resetCameraOnStart {
            renderer.resetCamera()
        }
    }
    #endif
}

// MARK: - Configuration Types

/// General renderer configuration options
struct RendererConfiguration {
    let quality: RenderQuality
    let performanceMode: PerformanceMode
    
    #if os(iOS)
    let iosConfig: IOSRendererConfiguration?
    #else
    let iosConfig: IOSRendererConfiguration? = nil
    #endif
    
    #if os(macOS)
    let macosConfig: MacOSRendererConfiguration?
    #else
    let macosConfig: MacOSRendererConfiguration? = nil
    #endif
    
    #if os(visionOS)
    let visionOSConfig: VisionOSRendererConfiguration?
    #else
    let visionOSConfig: VisionOSRendererConfiguration? = nil
    #endif
    
    /// Creates default configuration for current platform
    static func `default`() -> RendererConfiguration {
        #if os(iOS)
        return RendererConfiguration(
            quality: .balanced,
            performanceMode: .adaptive,
            iosConfig: IOSRendererConfiguration.default()
        )
        #elseif os(macOS)
        return RendererConfiguration(
            quality: .high,
            performanceMode: .performance,
            macosConfig: MacOSRendererConfiguration.default()
        )
        #elseif os(visionOS)
        return RendererConfiguration(
            quality: .high,
            performanceMode: .immersive,
            visionOSConfig: VisionOSRendererConfiguration.default()
        )
        #else
        return RendererConfiguration(
            quality: .balanced,
            performanceMode: .adaptive
        )
        #endif
    }
}

#if os(iOS)
/// iOS-specific renderer configuration
struct IOSRendererConfiguration {
    let enableARTracking: Bool
    let arSessionType: ARSessionUseCase
    let resetAROnStart: Bool
    let touchSensitivity: Float
    let optimizeForBattery: Bool
    
    static func `default`() -> IOSRendererConfiguration {
        return IOSRendererConfiguration(
            enableARTracking: true,
            arSessionType: .worldTracking,
            resetAROnStart: false,
            touchSensitivity: 1.0,
            optimizeForBattery: true
        )
    }
}
#endif

#if os(macOS)
/// macOS-specific renderer configuration
struct MacOSRendererConfiguration {
    let initialCameraMode: CameraMode
    let resetCameraOnStart: Bool
    let mouseSensitivity: Float
    let keyboardSensitivity: Float
    let enableHighQualityRendering: Bool
    
    static func `default`() -> MacOSRendererConfiguration {
        return MacOSRendererConfiguration(
            initialCameraMode: .free,
            resetCameraOnStart: false,
            mouseSensitivity: 1.0,
            keyboardSensitivity: 1.0,
            enableHighQualityRendering: true
        )
    }
}
#endif

#if os(visionOS)
/// visionOS-specific renderer configuration (future)
struct VisionOSRendererConfiguration {
    let enableHandTracking: Bool
    let enableEyeTracking: Bool
    let spatialMode: SpatialMode
    
    static func `default`() -> VisionOSRendererConfiguration {
        return VisionOSRendererConfiguration(
            enableHandTracking: true,
            enableEyeTracking: true,
            spatialMode: .immersive
        )
    }
}

enum SpatialMode {
    case window
    case immersive
    case mixed
}
#endif

// MARK: - Quality and Performance Enums

/// Rendering quality levels
enum RenderQuality {
    case low
    case balanced
    case high
    case ultra
    
    var description: String {
        switch self {
        case .low: return "Low Quality (Battery Optimized)"
        case .balanced: return "Balanced Quality"
        case .high: return "High Quality"
        case .ultra: return "Ultra Quality (Performance Impact)"
        }
    }
}

/// Performance optimization modes
enum PerformanceMode {
    case battery        // Optimize for battery life
    case balanced       // Balance performance and battery
    case performance    // Maximize performance
    case adaptive       // Automatically adjust based on conditions
    case immersive      // Maximum quality for immersive experiences
    
    var description: String {
        switch self {
        case .battery: return "Battery Optimized"
        case .balanced: return "Balanced Performance"
        case .performance: return "High Performance"
        case .adaptive: return "Adaptive Performance"
        case .immersive: return "Immersive Experience"
        }
    }
}

// MARK: - Platform Detection Utilities

/// Utility extensions for platform-specific behavior
extension RendererServiceFactory {
    
    /// Returns the optimal configuration for the current device
    static func getOptimalConfiguration() -> RendererConfiguration {
        #if os(iOS)
        return getOptimalIOSConfiguration()
        #elseif os(macOS)
        return getOptimalMacOSConfiguration()
        #elseif os(visionOS)
        return getOptimalVisionOSConfiguration()
        #else
        return RendererConfiguration.default()
        #endif
    }
    
    #if os(iOS)
    /// Returns optimal configuration for current iOS device
    private static func getOptimalIOSConfiguration() -> RendererConfiguration {
        // Detect device capabilities and return appropriate config
        let deviceModel = UIDevice.current.model
        let processorInfo = ProcessInfo.processInfo
        
        // Use high quality on newer devices, balanced on older ones
        let quality: RenderQuality = processorInfo.processorCount >= 6 ? .high : .balanced
        let performanceMode: PerformanceMode = .adaptive
        
        let iosConfig = IOSRendererConfiguration(
            enableARTracking: true,
            arSessionType: .worldTracking,
            resetAROnStart: false,
            touchSensitivity: 1.0,
            optimizeForBattery: quality == .balanced
        )
        
        return RendererConfiguration(
            quality: quality,
            performanceMode: performanceMode,
            iosConfig: iosConfig
        )
    }
    #endif
    
    #if os(macOS)
    /// Returns optimal configuration for current macOS device
    private static func getOptimalMacOSConfiguration() -> RendererConfiguration {
        // Detect Mac capabilities and return appropriate config
        let processorInfo = ProcessInfo.processInfo
        
        // Use ultra quality on high-end Macs, high on others
        let quality: RenderQuality = processorInfo.processorCount >= 8 ? .ultra : .high
        let performanceMode: PerformanceMode = .performance
        
        let macosConfig = MacOSRendererConfiguration(
            initialCameraMode: .free,
            resetCameraOnStart: false,
            mouseSensitivity: 1.0,
            keyboardSensitivity: 1.0,
            enableHighQualityRendering: true
        )
        
        return RendererConfiguration(
            quality: quality,
            performanceMode: performanceMode,
            macosConfig: macosConfig
        )
    }
    #endif
    
    #if os(visionOS)
    /// Returns optimal configuration for visionOS device
    private static func getOptimalVisionOSConfiguration() -> RendererConfiguration {
        let visionOSConfig = VisionOSRendererConfiguration.default()
        
        return RendererConfiguration(
            quality: .ultra,
            performanceMode: .immersive,
            visionOSConfig: visionOSConfig
        )
    }
    #endif
    
    /// Gets platform capabilities for the current device
    static func getPlatformCapabilities() -> PlatformCapabilities.Type {
        return PlatformCapabilities.self
    }
}

// MARK: - Renderer Service Manager

/// Manager class for handling multiple renderer instances (future use)
class RendererServiceManager {
    private var renderers: [String: any RendererServiceProtocol] = [:]
    
    /// Registers a renderer with a specific identifier
    func register(renderer: any RendererServiceProtocol, withID id: String) {
        renderers[id] = renderer
        print("[🏭] Registered renderer with ID: \(id)")
    }
    
    /// Gets a renderer by ID
    func getRenderer(withID id: String) -> (any RendererServiceProtocol)? {
        return renderers[id]
    }
    
    /// Removes a renderer
    func removeRenderer(withID id: String) {
        renderers.removeValue(forKey: id)
        print("[🏭] Removed renderer with ID: \(id)")
    }
    
    /// Updates all registered renderers
    func updateAllRenderers() {
        for (id, renderer) in renderers {
            renderer.updateScene()
        }
    }
    
    /// Gets all renderer IDs
    func getAllRendererIDs() -> [String] {
        return Array(renderers.keys)
    }
}
