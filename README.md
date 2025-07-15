# File: README.md
# Description: Main project documentation for Finalverse Storm - AI-driven virtual world client
# This README provides comprehensive setup, architecture, and usage information for the Storm project

# 🌩️ Finalverse Storm

**An AI-driven, plugin-extensible, cross-platform virtual world client built for the future of immersive experiences.**

> Storm is a next-generation virtual world client built in Swift and Rust, designed for macOS, iOS, and visionOS. It features a modular architecture powered by ECS (Entity Component System), runtime-driven UI, and seamless AI integration with OpenSim compatibility.

## ✨ Key Features

### 🚀 Core Architecture
- **SwiftUI Runtime Orchestrator** - `StormRuntime` with `Kernel` tick engine for real-time simulation
- **Plugin System** - Modular `PluginHost` with dynamic plugin registration and lifecycle management
- **ECS Engine** - High-performance Entity Component System for scalable world simulation
- **OpenSim Integration** - Full compatibility with OpenSimulator protocols and worlds
- **Cross-Platform** - Native support for macOS, iOS, and iOS Simulator with visionOS readiness

### 🎮 Advanced Systems
- **Runtime UI** - Dynamic interface generation using `UISchema` + `UIComposer`
- **Rust Core** - High-performance staticlib with seamless Swift FFI integration
- **OpenSim Protocol** - Native OpenSimulator protocol support with avatar movement and chat
- **RealityKit Bridge** - Seamless integration with Apple's RealityKit for AR/VR experiences
- **Cockpit Interface** - Advanced control interface for world navigation and interaction

### 🔌 Plugin Ecosystem
- **Hello Plugin** - Basic plugin demonstration and template
- **Local World Plugin** - Standalone world simulation and testing environment
- **OpenSim Plugin** - Full OpenSimulator world connectivity and interaction
- **Extensible Architecture** - Easy plugin development with comprehensive API

## 📁 Project Structure

```
storm/
├── App/                        # Application entry point and resources
│   ├── Assets.xcassets        # App icons, images, and visual assets
│   ├── Storm.entitlements     # App permissions and capabilities
│   └── StormApp.swift         # Main app structure and SwiftUI lifecycle
├── Core/                       # Core runtime systems and orchestration
│   ├── InputController.swift  # Input handling and device interaction
│   ├── Kernel.swift          # Real-time tick engine and update loop
│   ├── PluginHost.swift      # Plugin lifecycle and management system
│   ├── StormRuntime.swift    # Main runtime orchestrator and coordinator
│   ├── SystemRegistry.swift  # Component and system registration
│   └── UIScriptRouter.swift  # UI command routing and script execution
├── Engine/                     # Core simulation and world systems
│   ├── ECSComponents.swift    # Entity Component System data structures
│   ├── ECSCore.swift         # Core ECS implementation and logic
│   ├── ECSRealityKitBridge.swift # RealityKit integration for AR/VR
│   ├── LocalSceneManager.swift   # Local world scene management
│   ├── OpenSim/              # OpenSimulator integration systems
│   │   ├── OpenSimAvatarMovementSystem.swift # Avatar control and physics
│   │   ├── OpenSimChatSystem.swift          # Chat and communication
│   │   ├── OpenSimCleanupManager.swift      # Resource management
│   │   ├── OpenSimECSBridge.swift           # ECS-OpenSim integration
│   │   ├── OpenSimObjectLifecycleManager.swift # Object state management
│   │   ├── OpenSimStateManager.swift        # World state synchronization
│   │   └── OpenSimWorldIntegrator.swift     # World integration layer
│   ├── RendererService-iOS.swift    # iOS-specific rendering implementation
│   ├── RendererService-macOS.swift  # macOS-specific rendering implementation
│   └── RendererService.swift       # Cross-platform rendering interface
├── Network/                    # Network communication and protocols
│   ├── OpenSimProtocol.swift # OpenSimulator protocol implementation
│   ├── OSConnectManager.swift # Connection management and authentication
│   └── OSMessageRouter.swift # Message routing and protocol handling
├── Plugins/                   # Modular plugin implementations
│   ├── HelloPlugin.swift     # Example plugin and development template
│   ├── LocalWorldPlugin.swift # Local world simulation plugin
│   └── OpenSimPlugin.swift   # OpenSimulator connectivity plugin
├── RustCore/                  # Rust-based performance-critical systems
│   ├── Cargo.lock           # Rust dependency lock file
│   ├── Cargo.toml           # Rust project configuration and dependencies
│   ├── module.modulemap     # Swift-Rust FFI module mapping
│   ├── src/                 # Rust source code for core algorithms
│   │   └── lib.rs          # Main Rust library implementation
│   └── storm.h             # C header for Swift-Rust interop
├── scripts/                  # Build and development automation
│   └── build-rust-universal.sh # Rust library compilation for all platforms
├── Tests/                    # Comprehensive testing framework
│   ├── OpenSimAdvancedTesting.swift # Advanced OpenSim integration tests
│   ├── OpenSimTestFramework.swift   # Testing utilities and framework
│   └── OpenSimTestSuites.swift      # Test suites for OpenSim features
├── UI/                       # User interface components and systems
│   ├── CockpitView-iOS.swift      # iOS-specific cockpit interface
│   ├── CockpitView-macOS.swift    # macOS-specific cockpit interface
│   ├── CockpitViewShared.swift    # Shared cockpit functionality
│   ├── ContentView.swift         # Main content view and navigation
│   ├── Core/                     # Core UI infrastructure
│   │   ├── StormCockpitView-iOS.swift  # Advanced iOS cockpit controls
│   │   └── StormCockpitView-macOS.swift # Advanced macOS cockpit controls
│   ├── OpenSimLoginView.swift    # OpenSim world login and authentication
│   ├── UIComposer.swift          # Dynamic UI composition and layout
│   ├── UISchemaView.swift        # Schema-based UI generation
│   └── VirtualControls.swift     # Virtual control widgets and interactions
└── libs/                     # Compiled static libraries for all platforms
    ├── libstorm-ios-sim.a   # iOS Simulator universal binary
    ├── libstorm-ios.a       # iOS device universal binary
    └── libstorm-macos.a     # macOS universal binary (Apple Silicon + Intel)
```

## 🛠️ Development Setup

### Prerequisites
- **macOS 13+** with Xcode 15+
- **Swift 5.9+** with Swift Package Manager
- **Rust 1.70+** with Cargo and cross-compilation support
- **Git** for version control
- **OpenSimulator** server (optional, for testing OpenSim features)

### Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/finalverse/storm.git
   cd storm
   ```

2. **Build Rust dependencies**
   ```bash
   chmod +x scripts/build-rust-universal.sh
   ./scripts/build-rust-universal.sh
   ```

3. **Open in Xcode**
   ```bash
   open storm.xcodeproj
   ```

4. **Run the application**
   - Select your target platform (macOS/iOS)
   - Build and run (⌘+R)
   - The app will launch with the default cockpit interface

### Development Workflow

```bash
# Build Rust core for all platforms (run after Rust code changes)
./scripts/build-rust-universal.sh

# Clean build (if experiencing linking issues)
rm -rf libs/*.a
./scripts/build-rust-universal.sh
xcodebuild clean -project storm.xcodeproj

# Run comprehensive tests
xcodebuild test -scheme Storm -destination 'platform=macOS'

# Build for release distribution
xcodebuild build -scheme Storm -configuration Release
```

## 🏗️ Architecture Overview

### Runtime System
The `StormRuntime` acts as the central orchestrator, managing the tick-based simulation loop through the `Kernel` system. This architecture ensures consistent frame timing and efficient resource management across all platforms.

```swift
// Core runtime initialization and lifecycle management
class StormRuntime {
    private let kernel: Kernel
    private let pluginHost: PluginHost
    private let systemRegistry: SystemRegistry
    
    func startRuntime() {
        // Initialize core systems and begin simulation loop
        kernel.startTicking()
    }
}
```

### Plugin Architecture
Storm's modular design allows for dynamic loading and management of plugins through the `PluginHost` system. Each plugin can register its own components, systems, and UI elements with the runtime.

```swift
// Plugin interface for extensible functionality
protocol StormPlugin {
    func initialize(runtime: StormRuntime)
    func update(deltaTime: Float)
    func shutdown()
}
```

### ECS Integration
The Entity Component System provides a data-oriented approach to world simulation, allowing for efficient processing of large numbers of entities with complex behaviors and interactions.

### OpenSim Compatibility
Full integration with OpenSimulator protocols enables Storm to connect to existing OpenSim worlds while providing enhanced features through the modern Swift/Rust architecture.

### Swift-Rust Interop
Performance-critical systems are implemented in Rust and exposed through a carefully designed FFI layer, providing native Swift integration while maintaining optimal performance.

## 🎯 Getting Started

### Basic Usage

1. **Launch Storm** - The application initializes with the cockpit interface
2. **Choose Connection Type**:
   - **Local World** - Use the Local World Plugin for standalone exploration
   - **OpenSim World** - Connect to OpenSimulator grids and worlds
3. **Navigate the Interface** - Use the cockpit controls for world interaction
4. **Enable Plugins** - Access additional functionality through the plugin system

### Connecting to OpenSim Worlds

```swift
// Example OpenSim connection configuration
let config = OpenSimConfig(
    gridURL: "http://osgrid.org:8002",
    username: "YourAvatarName",
    password: "YourPassword",
    startLocation: "Wright Plaza/128/128/25"
)

// Connect through the OpenSim plugin
await openSimPlugin.connect(config: config)
```

### Plugin Development

```swift
// Example custom plugin implementation
class MyCustomPlugin: StormPlugin {
    func initialize(runtime: StormRuntime) {
        // Register custom components and systems
        runtime.systemRegistry.register(MyCustomSystem())
        
        // Set up plugin-specific UI
        setupCustomUI()
    }
    
    func update(deltaTime: Float) {
        // Per-frame plugin update logic
        processCustomLogic(deltaTime)
    }
    
    func shutdown() {
        // Cleanup plugin resources
        cleanupResources()
    }
}
```

### ECS Component Development

```swift
// Custom component for game entities
struct CustomComponent: Component {
    var customProperty: String
    var numericValue: Float
    var isActive: Bool
}

// System to process custom components
class CustomSystem: System {
    func update(deltaTime: Float) {
        // Process all entities with CustomComponent
        forEachEntity(with: CustomComponent.self) { entity, component in
            // Update logic here
        }
    }
}
```

## 🔧 Configuration

### Build Configuration
Storm uses Xcode build configurations for different deployment scenarios:

- **Debug** - Full debugging support with runtime checks and logging
- **Release** - Optimized builds for distribution with minimal logging
- **Profile** - Performance profiling with debug symbols retained

### Runtime Configuration
```swift
// Configure Storm runtime parameters
let config = StormConfiguration(
    targetFrameRate: 60,
    maxPlugins: 16,
    enableDebugUI: true,
    renderingAPI: .metal,
    openSimCompatibility: true
)
```

### OpenSim Configuration
```swift
// OpenSimulator-specific settings
let openSimConfig = OpenSimPluginConfig(
    maxConcurrentConnections: 4,
    enableVoiceChat: true,
    enablePhysics: true,
    cachingEnabled: true,
    maxCacheSize: 256 // MB
)
```

## 🧪 Testing

### Unit Tests
```bash
# Run all unit tests
xcodebuild test -scheme Storm -destination 'platform=macOS'

# Run specific test suite
xcodebuild test -scheme Storm -destination 'platform=macOS' -only-testing:StormTests.OpenSimTests
```

### OpenSim Integration Tests
```bash
# Run OpenSim-specific integration tests (requires OpenSim server)
xcodebuild test -scheme Storm -destination 'platform=macOS' -only-testing:StormTests.OpenSimAdvancedTesting
```

### Performance Testing
```bash
# Profile application performance
xcodebuild build -scheme Storm -configuration Profile
# Then use Instruments for detailed performance analysis
```

## 🚀 Deployment

### iOS Deployment
1. Configure code signing and provisioning profiles in Xcode
2. Select iOS target device or simulator
3. Ensure all Rust libraries are built for iOS architectures
4. Build and deploy using Xcode or Xcode Cloud

### macOS Deployment
1. Build the macOS target with universal binary support
2. Code sign for distribution (required for App Store or notarization)
3. Create distribution package using Xcode's built-in tools

### Distribution Checklist
- [ ] Rust libraries built for all target architectures
- [ ] Code signing certificates configured
- [ ] App entitlements properly configured
- [ ] Privacy usage descriptions added for required permissions
- [ ] Performance testing completed on target devices

## 🤝 Contributing

We welcome contributions to Storm! Please follow these guidelines:

### Development Process
1. Fork the repository and create a feature branch
2. Implement changes with comprehensive tests
3. Ensure Rust code compiles for all platforms
4. Update documentation for API changes
5. Submit pull request with detailed description

### Code Style Guidelines
- **Swift**: Follow Swift style guidelines and use SwiftLint
- **Rust**: Use `cargo fmt` and `cargo clippy` for code formatting
- **Documentation**: Include comprehensive documentation for public APIs
- **Testing**: Write unit tests for new functionality

### Commit Message Format
```
type(scope): brief description

Detailed explanation of changes if needed

- Breaking changes noted here
- Additional context or reasoning
```

## 📚 Documentation

- **[Architecture Guide](docs/ARCHITECTURE.md)** - Detailed system architecture and design patterns
- **API Reference** - Complete API documentation (generated from code)
- **Plugin Development Guide** - Creating custom plugins and extensions
- **OpenSim Integration Guide** - Working with OpenSimulator worlds and protocols

## 🐛 Troubleshooting

### Common Issues

**Rust Library Compilation Fails**
```bash
# Ensure Rust targets are installed
rustup target add aarch64-apple-ios
rustup target add x86_64-apple-ios
rustup target add aarch64-apple-darwin
rustup target add x86_64-apple-darwin

# Rebuild libraries
./scripts/build-rust-universal.sh
```

**OpenSim Connection Issues**
- Verify grid URL and credentials
- Check network connectivity
- Ensure OpenSim server supports required protocols
- Review connection logs in debug mode

**Performance Issues**
- Enable Metal performance HUD in debug builds
- Use Instruments for detailed profiling
- Check ECS system update frequencies
- Verify Rust library optimization levels

## 📄 License

Copyright © 2025 Finalverse. All rights reserved.

This project is proprietary software. Unauthorized copying, modification, distribution, or use of this software is strictly prohibited without explicit written permission from Finalverse.

## 🔗 Links

- **Website**: [https://finalverse.com](https://finalverse.com)
- **Documentation**: [https://docs.finalverse.com/storm](https://docs.finalverse.com/storm)
- **Community**: [https://community.finalverse.com](https://community.finalverse.com)
- **Support**: [support@finalverse.com](mailto:support@finalverse.com)
- **OpenSim Compatibility**: [http://opensimulator.org](http://opensimulator.org)

## 🎯 Roadmap

### Version 0.2.0 - Enhanced Integration
- [ ] Advanced RealityKit AR/VR features
- [ ] Improved OpenSim protocol support
- [ ] Enhanced plugin development tools
- [ ] Performance optimizations for mobile devices

### Version 0.3.0 - Advanced Features
- [ ] Multi-grid OpenSim support
- [ ] Advanced physics simulation
- [ ] Voice chat integration
- [ ] Cloud synchronization and backup

### Version 1.0.0 - Production Ready
- [ ] Full OpenSim feature parity
- [ ] Comprehensive plugin ecosystem
- [ ] Professional-grade performance
- [ ] Enterprise deployment support

---

**Built with ❤️ by the Finalverse team for the future of virtual worlds.**