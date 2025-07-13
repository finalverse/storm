//
//  UI/CockpitView-macOS.swift
//  Storm
//
//  macOS professional cockpit view with spinning cube interaction
//  Based on working macOS implementation with enhanced features
//
//  Created for Finalverse Storm Professional Edition

#if os(macOS)
import SwiftUI
import RealityKit
import Combine
import AppKit

struct CockpitView: View {
    @Environment(\.systemRegistry) var registry
    @StateObject private var cockpitState = CockpitState()
    @StateObject private var openSimConnection = OSConnectManager()
    @StateObject private var gestureController = GestureController()
    
    // Professional HUD state management
    @State private var selectedEntityID: EntityID?
    @State private var hudMode: HUDMode = .exploration
    @State private var minimapStyle: MinimapStyle = .radar
    @State private var showAdvancedControls = false
    @State private var consoleMessages: [ConsoleMessage] = []
    @State private var connectionStatus: ConnectionStatus = .disconnected
    
    // Camera and navigation state
    @State private var cameraPosition = SIMD3<Float>(0, 1.5, 3)
    @State private var cameraRotation = SIMD2<Float>(0, 0) // yaw, pitch
    @State private var zoomLevel: Float = 1.0

    var body: some View {
        ZStack {
            // Main 3D render view
            mainRenderView
            
            // Professional HUD overlay
            professionalHUDOverlay
            
            // Advanced controls panel (collapsible)
            if showAdvancedControls {
                advancedControlsPanel
                    .transition(.move(edge: .trailing))
            }
        }
        .onAppear {
            setupProfessionalCockpit()
        }
        .gesture(
            // Professional gesture handling
            DragGesture()
                .onChanged(handleCameraDrag)
                .simultaneously(with: MagnificationGesture()
                    .onChanged(handleZoom))
        )
        .onReceive(openSimConnection.$connectionStatus) { osStatus in
            // Convert OSConnectionStatus to our ConnectionStatus
            connectionStatus = convertConnectionStatus(osStatus)
            addConsoleMessage("Connection status: \(connectionStatus.description)")
        }
    }
    
    // MARK: - Main Render View
    private var mainRenderView: some View {
        Group {
            if let renderer: RendererService = registry?.resolve("renderer") {
                ARViewContainerMacOS(
                    renderer: renderer,
                    gestureController: gestureController,
                    onEntitySelected: { entityID in
                        selectedEntityID = entityID
                        addConsoleMessage("Selected entity: \(entityID)")
                        spinSelectedEntity(entityID: entityID, renderer: renderer)
                    }
                )
                .edgesIgnoringSafeArea(.all)
            } else {
                // Professional loading screen
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                            .scaleEffect(1.5)
                        Text("Initializing Finalverse Storm...")
                            .foregroundColor(.white)
                            .font(.title2)
                            .padding(.top)
                    }
                }
            }
        }
    }
    
    // MARK: - Professional HUD Overlay
    private var professionalHUDOverlay: some View {
        VStack {
            // Top status bar with glassmorphism effect
            topStatusBar
            
            Spacer()
            
            HStack {
                // Left side tools
                VStack(spacing: 16) {
                    toolButton(icon: "cube.transparent", title: "Inspect") {
                        handleInspectAction()
                    }
                    toolButton(icon: "location.north.line", title: "Teleport") {
                        handleTeleportAction()
                    }
                    toolButton(icon: "antenna.radiowaves.left.and.right", title: "Network") {
                        showAdvancedControls.toggle()
                    }
                }
                .padding(.leading, 20)
                
                Spacer()
                
                // Right side minimap and info
                VStack {
                    // Enhanced minimap with professional styling
                    enhancedMinimap
                    
                    // Entity info panel
                    if let entityID = selectedEntityID {
                        entityInfoPanel(entityID: entityID)
                    }
                }
                .padding(.trailing, 20)
            }
            
            // Bottom console and controls
            bottomControlsPanel
        }
    }
    
    // MARK: - Tool Button Helper
    @ViewBuilder
    private func toolButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.6))
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Top Status Bar
    private var topStatusBar: some View {
        HStack {
            // Finalverse Storm branding
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                Text("Finalverse Storm")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("Professional")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.3))
                    .cornerRadius(4)
            }
            .foregroundColor(.white)
            
            Spacer()
            
            // Connection and performance metrics
            HStack(spacing: 16) {
                // OpenSim connection status
                connectionIndicator
                
                // Performance metrics
                performanceMetrics
                
                // Settings button
                Button(action: { showAdvancedControls.toggle() }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }
                .buttonStyle(GlassButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            // Glassmorphism background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.top, 20)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Connection Indicator
    private var connectionIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionStatus.color)
                .frame(width: 8, height: 8)
                .scaleEffect(connectionStatus == .connected ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                          value: connectionStatus == .connected)
            
            Text(connectionStatus.description)
                .font(.caption)
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Performance Metrics
    private var performanceMetrics: some View {
        HStack(spacing: 12) {
            // FPS counter
            MetricView(icon: "speedometer", value: "\(cockpitState.fps)", unit: "FPS")
            
            // Entity count
            MetricView(icon: "cube.box", value: "\(cockpitState.entityCount)", unit: "ENT")
            
            // Network latency
            MetricView(icon: "timer", value: "\(openSimConnection.latency)", unit: "ms")
        }
    }
    
    // MARK: - Enhanced Minimap
    private var enhancedMinimap: some View {
        VStack(spacing: 8) {
            // Minimap style selector
            HStack {
                ForEach(MinimapStyle.allCases, id: \.self) { style in
                    Button(action: { minimapStyle = style }) {
                        Image(systemName: style.icon)
                            .foregroundColor(minimapStyle == style ? .cyan : .gray)
                    }
                }
            }
            .font(.caption)
            
            // Actual minimap view
            Group {
                switch minimapStyle {
                case .radar:
                    RadarMinimapView(renderer: registry?.resolve("renderer"))
                case .topDown:
                    TopDownMinimapView(renderer: registry?.resolve("renderer"))
                case .compass:
                    CompassMiniMapView(cameraYaw: cameraRotation.x)
                }
            }
            .frame(width: 120, height: 120)
            .background(Color.black.opacity(0.7))
            .cornerRadius(60)
            .overlay(
                Circle()
                    .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
            )
        }
    }
    
    // MARK: - Entity Info Panel
    private func entityInfoPanel(entityID: EntityID) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Entity Inspector")
                .font(.headline)
                .foregroundColor(.cyan)
            
            Text("ID: \(entityID.uuidString.prefix(8))...")
                .font(.caption2)
                .foregroundColor(.gray)
            
            // Get entity components and display info
            if let ecs = registry?.ecs {
                let world = ecs.getWorld()
                
                if let position = world.getComponent(ofType: PositionComponent.self, from: entityID) {
                    Text("Position: (\(String(format: "%.1f", position.position.x)), \(String(format: "%.1f", position.position.y)), \(String(format: "%.1f", position.position.z)))")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                
                if let mood = world.getComponent(ofType: MoodComponent.self, from: entityID) {
                    Text("Mood: \(mood.mood)")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                
                if world.hasComponent(SpinComponent.self, for: entityID) {
                    Text("Can Spin: Yes")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.8))
                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
        )
        .frame(width: 200)
    }
    
    // MARK: - Bottom Controls Panel
    private var bottomControlsPanel: some View {
        VStack(spacing: 0) {
            // Console log (collapsible)
            if cockpitState.showConsole {
                consoleLogView
                    .transition(.opacity)
            }
            
            // Control buttons
            HStack(spacing: 20) {
                // Navigation mode toggle
                Button(action: { hudMode.toggle() }) {
                    HStack {
                        Image(systemName: hudMode.icon)
                        Text(hudMode.title)
                    }
                }
                .buttonStyle(ProfessionalButtonStyle(isActive: true))
                
                // Console toggle
                Button(action: {
                    withAnimation(.easeInOut) {
                        cockpitState.showConsole.toggle()
                    }
                }) {
                    Image(systemName: "terminal")
                }
                .buttonStyle(ProfessionalButtonStyle(isActive: cockpitState.showConsole))
                
                // OpenSim connection toggle
                Button(action: handleOpenSimConnection) {
                    HStack {
                        Image(systemName: "network")
                        Text(openSimConnection.isConnected ? "Disconnect" : "Connect")
                    }
                }
                .buttonStyle(ProfessionalButtonStyle(isActive: openSimConnection.isConnected))
                
                Spacer()
                
                // Clear selection
                Button(action: { selectedEntityID = nil }) {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(ProfessionalButtonStyle(isActive: false))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.7))
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Console Log View
    private var consoleLogView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(consoleMessages.indices, id: \.self) { index in
                        ConsoleMessageView(message: consoleMessages[index])
                    }
                }
                .padding(8)
                .onChange(of: consoleMessages.count) { _, _ in
                    // Auto-scroll to bottom on new messages
                    if let lastIndex = consoleMessages.indices.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }
                }
            }
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.9))
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Advanced Controls Panel
    private var advancedControlsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Advanced Controls")
                .font(.headline)
                .foregroundColor(.white)
            
            // OpenSim connection settings
            openSimConnectionSettings
            
            // Rendering settings
            renderingSettings
            
            // Debug information
            debugInformation
            
            Spacer()
        }
        .padding(20)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.9))
                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
        )
        .padding(.trailing, 20)
    }
    
    // MARK: - Advanced Control Sections
    private var openSimConnectionSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OpenSim Connection")
                .font(.subheadline)
                .foregroundColor(.cyan)
            
            HStack {
                Text("Status:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text(connectionStatus.description)
                    .font(.caption)
                    .foregroundColor(connectionStatus.color)
            }
            
            HStack {
                Text("Latency:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(openSimConnection.latency)ms")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    private var renderingSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rendering")
                .font(.subheadline)
                .foregroundColor(.cyan)
            
            HStack {
                Text("FPS:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(cockpitState.fps)")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            HStack {
                Text("Entities:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(cockpitState.entityCount)")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    private var debugInformation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug Info")
                .font(.subheadline)
                .foregroundColor(.cyan)
            
            HStack {
                Text("Selected:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text(selectedEntityID != nil ? "Entity" : "None")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            HStack {
                Text("HUD Mode:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text(hudMode.title)
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    // MARK: - Gesture Handlers
    private func handleCameraDrag(_ value: DragGesture.Value) {
        // Professional camera control with smooth interpolation
        let sensitivity: Float = 0.005
        let deltaX = Float(value.translation.width) * sensitivity
        let deltaY = Float(-value.translation.height) * sensitivity
        cameraRotation.x += deltaX
        cameraRotation.y += deltaY
        
        // Clamp pitch rotation
        cameraRotation.y = max(-Float.pi/2, min(Float.pi/2, cameraRotation.y))
        
        // Apply to renderer
        if let renderer: RendererService = registry?.resolve("renderer") {
            renderer.rotateCamera(yaw: deltaX, pitch: deltaY)
        }
    }
    
    private func handleZoom(_ value: MagnificationGesture.Value) {
        let newZoom = zoomLevel * Float(value.magnitude)
        let clampedZoom = max(0.1, min(10.0, newZoom))
        
        if let renderer: RendererService = registry?.resolve("renderer") {
            renderer.zoomCamera(delta: clampedZoom - zoomLevel)
        }
        
        zoomLevel = clampedZoom
    }
    
    // MARK: - Spinning Functionality
    private func spinSelectedEntity(entityID: EntityID, renderer: RendererService) {
        // Find and spin the first available cube in the scene
        for anchor in renderer.arView.scene.anchors {
            for child in anchor.children {
                if let modelEntity = child as? ModelEntity {
                    spinModelEntity(modelEntity)
                    addConsoleMessage("Spinning cube entity!")
                    return
                }
            }
        }
        addConsoleMessage("No spinnable entity found")
    }
    
    private func spinModelEntity(_ entity: ModelEntity) {
        // Create spin animation (like SimpleView-macOS)
        let originalTransform = entity.transform
        let spinTransform = Transform(
            scale: originalTransform.scale,
            rotation: simd_quatf(angle: 2 * .pi, axis: [0, 1, 0]),
            translation: originalTransform.translation
        )
        
        // Animate the spin over 1 second
        entity.move(to: spinTransform, relativeTo: entity.parent, duration: 1.0, timingFunction: .easeInOut)
        
        // Reset rotation after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            entity.move(to: originalTransform, relativeTo: entity.parent, duration: 0.1)
        }
    }
    
    // MARK: - Helper Functions
    private func setupProfessionalCockpit() {
        // Initialize professional cockpit state
        addConsoleMessage("Initializing Finalverse Storm Professional...")
        
        // Setup ECS integration
        if let ecs = registry?.ecs {
            cockpitState.setupECSMonitoring(ecs: ecs)
            createDemoSpinEntities(ecs: ecs)
        }
        
        // Setup OpenSim connection manager
        openSimConnection.setup()
        
        addConsoleMessage("Professional cockpit ready - click cubes to spin!")
    }
    
    private func createDemoSpinEntities(ecs: ECSCore) {
        let world = ecs.getWorld()
        
        // Create demo entities with SpinComponent
        for i in 0..<3 {
            let entityID = world.createEntity()
            
            let position = PositionComponent(position: SIMD3<Float>(Float(i - 1), 1, 0))
            world.addComponent(position, to: entityID)
            
            let spinComponent = SpinComponent()
            world.addComponent(spinComponent, to: entityID)
            
            let mood = MoodComponent(mood: "Spinnable")
            world.addComponent(mood, to: entityID)
        }
        
        addConsoleMessage("Created 3 spinnable demo entities")
    }
    
    private func handleInspectAction() {
        addConsoleMessage("Inspection mode activated")
        hudMode = .inspection
    }
    
    private func handleTeleportAction() {
        addConsoleMessage("Teleport functionality not yet implemented")
    }
    
    private func handleOpenSimConnection() {
        if openSimConnection.isConnected {
            openSimConnection.disconnect()
        } else {
            openSimConnection.connect(to: "sim.example.com", port: 9000)
        }
    }
    
    private func addConsoleMessage(_ text: String) {
        let message = ConsoleMessage(
            timestamp: Date(),
            level: .info,
            text: text
        )
        consoleMessages.append(message)
        
        // Limit console history
        if consoleMessages.count > 100 {
            consoleMessages.removeFirst(consoleMessages.count - 100)
        }
    }
    
    // MARK: - Connection Status Conversion
    private func convertConnectionStatus(_ osStatus: OSConnectionStatus) -> ConnectionStatus {
        switch osStatus {
        case .disconnected:
            return .disconnected
        case .connecting:
            return .connecting
        case .connected:
            return .connected
        case .error(let message):
            return .error(message)
        }
    }
}

// MARK: - ARView Container
struct ARViewContainerMacOS: NSViewRepresentable {
    let renderer: RendererService
    let gestureController: GestureController
    let onEntitySelected: (EntityID) -> Void
    
    func makeNSView(context: Context) -> ARView {
        let arView = renderer.arView
        
        // Setup click gesture for entity selection
        let clickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        arView.addGestureRecognizer(clickGesture)
        
        return arView
    }
    
    func updateNSView(_ nsView: ARView, context: Context) {
        renderer.updateScene()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ARViewContainerMacOS
        
        init(_ parent: ARViewContainerMacOS) {
            self.parent = parent
        }
        
        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let arView = gesture.view as? ARView else { return }
            
            let location = gesture.location(in: arView)
            
            if let entity = arView.entity(at: location) {
                let entityID = UUID()
                parent.onEntitySelected(entityID)
            }
        }
    }
}

#endif
