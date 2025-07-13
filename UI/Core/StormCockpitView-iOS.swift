//
//  UI/CockpitView-iOS.swift
//  Storm
//
//  iOS professional cockpit view optimized for mobile interaction
//  Features touch-optimized controls, floating panels, and spinning cube demo
//
//  Created for Finalverse Storm Professional Edition - iOS

#if os(iOS)
import SwiftUI
import RealityKit
import ARKit
import Combine

struct CockpitView: View {
    @Environment(\.systemRegistry) var registry
    @StateObject private var cockpitState = CockpitState()
    @StateObject private var openSimConnection = OSConnectManager()
    @StateObject private var gestureController = GestureController()
    @StateObject private var touchController = TouchController()
    
    // Mobile-optimized UI state
    @State private var selectedEntityID: EntityID?
    @State private var hudMode: HUDMode = .exploration
    @State private var minimapStyle: MinimapStyle = .radar
    @State private var showFloatingPanel = false
    @State private var showMinimap = true
    @State private var consoleMessages: [ConsoleMessage] = []
    @State private var connectionStatus: ConnectionStatus = .disconnected
    
    // Mobile gesture and camera state
    @State private var cameraPosition = SIMD3<Float>(0, 1.5, 3)
    @State private var cameraRotation = SIMD2<Float>(0, 0)
    @State private var zoomLevel: Float = 1.0
    @State private var lastPanGesture = CGSize.zero
    @State private var lastRotationAngle: Double = 0
    
    // Mobile UI layout state
    @State private var showConsole = false
    @State private var activeTab: ControlTab = .main
    @State private var panelHeight: CGFloat = 200
    @State private var isConnecting = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main AR/3D render view with spinning cube
                mainRenderView
                
                // Mobile-optimized HUD overlay
                mobileHUDOverlay(geometry: geometry)
                
                // Floating control panel (bottom sheet style)
                if showFloatingPanel {
                    floatingControlPanel(geometry: geometry)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Touch-optimized virtual controls
                mobileVirtualControls(geometry: geometry)
            }
        }
        .onAppear {
            setupMobileCockpit()
        }
        .gesture(
            // Mobile gesture handling - prioritize touch over drag
            simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged(handleMobilePan)
                    .onEnded(handleMobilePanEnd)
            )
            .simultaneously(with:
                MagnificationGesture()
                    .onChanged(handleMobileZoom)
            )
            .simultaneously(with:
                RotationGesture()
                    .onChanged(handleMobileRotation)
            )
        )
        .onReceive(openSimConnection.$connectionStatus) { osStatus in
            connectionStatus = convertConnectionStatus(osStatus)
            addConsoleMessage("Connection: \(connectionStatus.description)")
        }
        .ignoresSafeArea(.all, edges: .all)
    }
    
    // MARK: - Main Render View with Spinning Cube
    private var mainRenderView: some View {
        Group {
            if let renderer: RendererService = registry?.resolve("renderer") {
                ARViewContainerIOS(
                    renderer: renderer,
                    gestureController: gestureController,
                    touchController: touchController,
                    onEntitySelected: { entityID in
                        selectedEntityID = entityID
                        addConsoleMessage("Tapped entity: \(entityID)")
                        
                        // Spin the cube when tapped (like macOS version)
                        if let ecs = registry?.ecs {
                            spinSelectedEntity(entityID: entityID, ecs: ecs, renderer: renderer)
                        }
                    }
                )
                .edgesIgnoringSafeArea(.all)
            } else {
                // Mobile loading screen
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                            .scaleEffect(2.0)
                        
                        VStack(spacing: 8) {
                            Text("Finalverse Storm")
                                .foregroundColor(.white)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Mobile Professional")
                                .foregroundColor(.cyan)
                                .font(.headline)
                            
                            Text("Initializing AR environment...")
                                .foregroundColor(.gray)
                                .font(.body)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Mobile HUD Overlay
    private func mobileHUDOverlay(geometry: GeometryProxy) -> some View {
        VStack {
            // Top status bar (compact for mobile)
            mobileTopBar(geometry: geometry)
            
            Spacer()
            
            // Bottom floating controls
            mobileBottomControls(geometry: geometry)
        }
    }
    
    // MARK: - Mobile Top Bar
    private func mobileTopBar(geometry: GeometryProxy) -> some View {
        HStack {
            // Compact brand and status
            VStack(alignment: .leading, spacing: 2) {
                Text("Storm Pro")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    connectionIndicator
                    performanceIndicator
                }
            }
            
            Spacer()
            
            // Mobile action buttons
            HStack(spacing: 12) {
                // Minimap toggle
                Button(action: {
                    withAnimation(.spring()) {
                        showMinimap.toggle()
                    }
                }) {
                    Image(systemName: showMinimap ? "map.fill" : "map")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                .buttonStyle(MobileGlassButtonStyle())
                
                // Panel toggle
                Button(action: {
                    withAnimation(.spring()) {
                        showFloatingPanel.toggle()
                    }
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                .buttonStyle(MobileGlassButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            // Mobile glassmorphism background
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .blur(radius: 0.5)
        )
        .padding(.top, 50) // Safe area compensation
        .padding(.horizontal, 12)
    }
    
    // MARK: - Mobile Bottom Controls
    private func mobileBottomControls(geometry: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            // Minimap overlay (if enabled)
            if showMinimap {
                mobileMinimap
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Primary control bar
            HStack(spacing: 20) {
                // Mode selector
                Button(action: {
                    withAnimation(.easeInOut) {
                        hudMode.toggle()
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: hudMode.icon)
                            .font(.title2)
                        Text(hudMode.title)
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(MobilePrimaryButtonStyle(isActive: true))
                
                // Console toggle
                Button(action: {
                    withAnimation(.spring()) {
                        showConsole.toggle()
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "terminal")
                            .font(.title2)
                        Text("Console")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(MobilePrimaryButtonStyle(isActive: showConsole))
                
                // Connection button
                Button(action: handleMobileConnection) {
                    VStack(spacing: 4) {
                        Image(systemName: isConnecting ? "arrow.triangle.2.circlepath" : "network")
                            .font(.title2)
                            .rotationEffect(.degrees(isConnecting ? 360 : 0))
                            .animation(isConnecting ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isConnecting)
                        Text(connectionStatus == .connected ? "Online" : "Connect")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(MobilePrimaryButtonStyle(isActive: connectionStatus == .connected))
                
                // Clear selection
                Button(action: {
                    selectedEntityID = nil
                    addConsoleMessage("Selection cleared")
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                            .font(.title2)
                        Text("Clear")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(MobilePrimaryButtonStyle(isActive: false))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.7))
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            
            // Console view (when enabled)
            if showConsole {
                mobileConsoleView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 40) // Safe area compensation
    }
    
    // MARK: - Mobile Minimap
    private var mobileMinimap: some View {
        VStack(spacing: 8) {
            // Minimap style selector (compact)
            HStack(spacing: 12) {
                ForEach(MinimapStyle.allCases, id: \.self) { style in
                    Button(action: {
                        withAnimation(.easeInOut) {
                            minimapStyle = style
                        }
                    }) {
                        Image(systemName: style.icon)
                            .font(.caption)
                            .foregroundColor(minimapStyle == style ? .cyan : .gray)
                    }
                }
            }
            
            // Minimap view (smaller for mobile)
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
            .frame(width: 80, height: 80)
            .background(Color.black.opacity(0.8))
            .cornerRadius(40)
            .overlay(
                Circle()
                    .stroke(Color.cyan.opacity(0.6), lineWidth: 1.5)
            )
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.5))
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Mobile Console View
    private var mobileConsoleView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(consoleMessages.indices, id: \.self) { index in
                        MobileConsoleMessageView(message: consoleMessages[index])
                    }
                }
                .padding(8)
                .onChange(of: consoleMessages.count) { _, _ in
                    if let lastIndex = consoleMessages.indices.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }
                }
            }
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.9))
                    .stroke(Color.green.opacity(0.4), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Floating Control Panel
    private func floatingControlPanel(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Panel handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.5))
                .frame(width: 40, height: 6)
                .padding(.top, 8)
            
            // Panel content with tabs
            VStack(spacing: 16) {
                // Tab selector
                HStack(spacing: 0) {
                    ForEach(ControlTab.allCases, id: \.self) { tab in
                        Button(action: { activeTab = tab }) {
                            VStack(spacing: 4) {
                                Image(systemName: tab.icon)
                                    .font(.caption)
                                Text(tab.title)
                                    .font(.caption2)
                            }
                            .foregroundColor(activeTab == tab ? .cyan : .gray)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                // Tab content
                Group {
                    switch activeTab {
                    case .main:
                        mainTabContent
                    case .settings:
                        settingsTabContent
                    case .debug:
                        debugTabContent
                    }
                }
                .frame(height: 120)
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.9))
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .frame(height: panelHeight)
        .frame(maxWidth: .infinity)
        .position(x: geometry.size.width / 2, y: geometry.size.height - panelHeight / 2)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newHeight = max(150, min(400, panelHeight - value.translation.y))
                    panelHeight = newHeight
                }
        )
    }
    
    // MARK: - Tab Contents
    private var mainTabContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Entity Inspector")
                .font(.headline)
                .foregroundColor(.cyan)
            
            if let entityID = selectedEntityID {
                Text("Selected: \(entityID.uuidString.prefix(8))...")
                    .font(.caption)
                    .foregroundColor(.white)
                
                // Entity component info
                if let ecs = registry?.ecs {
                    entityComponentInfo(entityID: entityID, ecs: ecs)
                }
            } else {
                Text("Tap any cube to select and spin it")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var settingsTabContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connection Settings")
                .font(.headline)
                .foregroundColor(.cyan)
            
            HStack {
                Text("OpenSim Status:")
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
    }
    
    private var debugTabContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug Information")
                .font(.headline)
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
    }
    
    // MARK: - Entity Component Info Helper
    private func entityComponentInfo(entityID: EntityID, ecs: ECSCore) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            let world = ecs.getWorld()
            
            if let position = world.getComponent(ofType: PositionComponent.self, from: entityID) {
                Text("Pos: (\(String(format: "%.1f", position.position.x)), \(String(format: "%.1f", position.position.y)), \(String(format: "%.1f", position.position.z)))")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            
            if let mood = world.getComponent(ofType: MoodComponent.self, from: entityID) {
                Text("Mood: \(mood.mood)")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            
            if world.hasComponent(SpinComponent.self, for: entityID) {
                Text("Can Spin: Yes")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
    }
    
    // MARK: - Mobile Virtual Controls
    private func mobileVirtualControls(geometry: GeometryProxy) -> some View {
        HStack {
            VStack {
                Spacer()
                
                // Left side - Movement joystick
                VirtualJoystick(onMove: handleVirtualMovement)
                    .frame(width: 80, height: 80)
                    .padding(.leading, 20)
                    .padding(.bottom, 160)
            }
            
            Spacer()
            
            VStack {
                Spacer()
                
                // Right side - Camera controls
                VirtualCameraControls(
                    onRotate: handleVirtualRotation,
                    onZoom: handleVirtualZoom
                )
                .frame(width: 80, height: 80)
                .padding(.trailing, 20)
                .padding(.bottom, 160)
            }
        }
    }
    
    // MARK: - Mobile Gesture Handlers
    private func handleMobilePan(_ value: DragGesture.Value) {
        let sensitivity: Float = 0.003
        let deltaX = Float(value.translation.width - lastPanGesture.width) * sensitivity
        let deltaY = Float(-(value.translation.height - lastPanGesture.height)) * sensitivity
        
        cameraRotation.x += deltaX
        cameraRotation.y += deltaY
        
        // Clamp pitch for mobile comfort
        cameraRotation.y = max(-Float.pi/3, min(Float.pi/3, cameraRotation.y))
        
        if let renderer: RendererService = registry?.resolve("renderer") {
            renderer.rotateCamera(yaw: deltaX, pitch: deltaY)
        }
        
        lastPanGesture = value.translation
    }
    
    private func handleMobilePanEnd(_ value: DragGesture.Value) {
        lastPanGesture = .zero
    }
    
    private func handleMobileZoom(_ value: MagnificationGesture.Value) {
        let newZoom = zoomLevel * Float(value.magnitude)
        let clampedZoom = max(0.2, min(5.0, newZoom))
        
        if let renderer: RendererService = registry?.resolve("renderer") {
            renderer.zoomCamera(delta: clampedZoom - zoomLevel)
        }
        
        zoomLevel = clampedZoom
    }
    
    private func handleMobileRotation(_ value: RotationGesture.Value) {
        let currentAngle = value.rotation.radians
        let deltaAngle = currentAngle - lastRotationAngle
        
        // Use rotation for camera roll or special effects
        if abs(deltaAngle) > 0.1 {
            addConsoleMessage("Rotation gesture: \(String(format: "%.2f", deltaAngle))")
        }
        
        lastRotationAngle = currentAngle
    }
    
    // MARK: - Virtual Control Handlers
    private func handleVirtualMovement(_ vector: SIMD2<Float>) {
        gestureController.handleMovement(vector)
        addConsoleMessage("Movement: (\(String(format: "%.2f", vector.x)), \(String(format: "%.2f", vector.y)))")
    }
    
    private func handleVirtualRotation(_ delta: SIMD2<Float>) {
        gestureController.handleRotation(delta)
    }
    
    private func handleVirtualZoom(_ delta: Float) {
        gestureController.handleZoom(delta)
    }
    
    // MARK: - Cube Spinning Function (Like macOS version)
    private func spinSelectedEntity(entityID: EntityID, ecs: ECSCore, renderer: RendererService) {
        let world = ecs.getWorld()
        
        // Check if entity has SpinComponent
        guard world.hasComponent(SpinComponent.self, for: entityID) else {
            addConsoleMessage("Entity cannot spin - no SpinComponent")
            return
        }
        
        // Find the ModelEntity in the ARView that corresponds to this entityID
        // This is a simplified approach - in a real implementation you'd maintain
        // a mapping between ECS entities and RealityKit entities
        for anchor in renderer.arView.scene.anchors {
            for child in anchor.children {
                if let modelEntity = child as? ModelEntity {
                    // Spin the first available cube (simplified approach)
                    spinModelEntity(modelEntity)
                    addConsoleMessage("Spinning cube entity!")
                    return
                }
            }
        }
    }
    
    private func spinModelEntity(_ entity: ModelEntity) {
        // Create spin animation similar to macOS version
        let spinTransform = Transform(
            scale: entity.transform.scale,
            rotation: simd_quatf(angle: 2 * .pi, axis: [0, 1, 0]), // Full rotation around Y axis
            translation: entity.transform.translation
        )
        
        // Animate the spin over 1 second
        entity.move(to: spinTransform, relativeTo: entity.parent, duration: 1.0, timingFunction: .easeInOut)
        
        // After animation completes, reset to original rotation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let resetTransform = Transform(
                scale: entity.transform.scale,
                rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
                translation: entity.transform.translation
            )
            entity.move(to: resetTransform, relativeTo: entity.parent, duration: 0.1)
        }
    }
    
    // MARK: - Helper Functions
    private func setupMobileCockpit() {
        addConsoleMessage("Initializing Storm Mobile Professional...")
        
        if let ecs = registry?.ecs {
            cockpitState.setupECSMonitoring(ecs: ecs)
            
            // Add some demo entities with SpinComponent for mobile interaction
            createDemoSpinEntities(ecs: ecs)
        }
        
        openSimConnection.setup()
        addConsoleMessage("Mobile cockpit ready - tap cubes to spin!")
    }
    
    private func createDemoSpinEntities(ecs: ECSCore) {
        let world = ecs.getWorld()
        
        // Create a few entities with SpinComponent for demo
        for i in 0..<3 {
            let entityID = world.createEntity()
            
            // Add position component
            let position = PositionComponent(position: SIMD3<Float>(Float(i - 1), 1, 0))
            world.addComponent(position, to: entityID)
            
            // Add spin component
            let spinComponent = SpinComponent()
            world.addComponent(spinComponent, to: entityID)
            
            // Add mood component for demo
            let mood = MoodComponent(mood: "Spinnable")
            world.addComponent(mood, to: entityID)
        }
        
        addConsoleMessage("Created \(3) spinnable demo entities")
    }
    
    private func handleMobileConnection() {
        isConnecting = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isConnecting = false
            
            if openSimConnection.isConnected {
                openSimConnection.disconnect()
            } else {
                openSimConnection.connect(to: "mobile.sim.example.com", port: 9000)
            }
        }
    }
    
    private func addConsoleMessage(_ text: String) {
        let message = ConsoleMessage(
            timestamp: Date(),
            level: .info,
            text: text
        )
        consoleMessages.append(message)
        
        // Limit console history for mobile performance
        if consoleMessages.count > 50 {
            consoleMessages.removeFirst(consoleMessages.count - 50)
        }
    }
    
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
    
    // MARK: - Mobile UI Indicators
    private var connectionIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(connectionStatus.color)
                .frame(width: 6, height: 6)
            Text(connectionStatus == .connected ? "Online" : "Offline")
                .font(.caption2)
                .foregroundColor(.white)
        }
    }
    
    private var performanceIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "speedometer")
                .font(.caption2)
                .foregroundColor(.cyan)
            Text("\(cockpitState.fps)")
                .font(.caption2)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Mobile ARView Container with Touch Handling
struct ARViewContainerIOS: UIViewRepresentable {
    let renderer: RendererService
    let gestureController: GestureController
    let touchController: TouchController
    let onEntitySelected: (EntityID) -> Void
    
    func makeUIView(context: Context) -> ARView {
        let arView = renderer.arView
        
        // Setup touch gesture for entity selection
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        renderer.updateScene()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: ARViewContainerIOS
        
        init(_ parent: ARViewContainerIOS) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = gesture.view as? ARView else { return }
            
            let location = gesture.location(in: arView)
            
            // Perform ray casting to find tapped entity
            if let entity = arView.entity(at: location) {
                // Generate a demo EntityID for the tapped entity
                let entityID = UUID()
                parent.onEntitySelected(entityID)
            }
        }
    }
}

#endif
