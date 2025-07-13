//
//  UI/Core/CockpitViewShared.swift
//  Storm
//
//  Shared components, types, and supporting classes for professional cockpit
//  Used by both macOS and iOS implementations
//
//  CLEANED: Removed redundant declarations, consolidated shared functionality
//  Created for Finalverse Storm Professional Edition

import SwiftUI
import RealityKit
import Combine

// MARK: - UI-Specific Supporting Types (Not ECS Components)

enum HUDMode: CaseIterable {
    case exploration, inspection, building, navigation
    
    var icon: String {
        switch self {
        case .exploration: return "safari"
        case .inspection: return "magnifyingglass"
        case .building: return "hammer"
        case .navigation: return "location"
        }
    }
    
    var title: String {
        switch self {
        case .exploration: return "Explore"
        case .inspection: return "Inspect"
        case .building: return "Build"
        case .navigation: return "Navigate"
        }
    }
    
    mutating func toggle() {
        let cases = Self.allCases
        if let currentIndex = cases.firstIndex(of: self) {
            let nextIndex = (currentIndex + 1) % cases.count
            self = cases[nextIndex]
        }
    }
}

enum MinimapStyle: CaseIterable {
    case radar, topDown, compass
    
    var icon: String {
        switch self {
        case .radar: return "dot.radiowaves.up.forward"
        case .topDown: return "map"
        case .compass: return "location.north"
        }
    }
}

enum ConnectionStatus: Equatable {
    case disconnected, connecting, connected, error(String)
    
    var description: String {
        switch self {
        case .disconnected: return "Offline"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error(let msg): return "Error: \(msg)"
        }
    }
    
    var color: Color {
        switch self {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
    
    static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.connected, .connected):
            return true
        case (.error(let lhsMsg), .error(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

struct ConsoleMessage {
    let timestamp: Date
    let level: LogLevel
    let text: String
    
    enum LogLevel {
        case info, warning, error, debug
        
        var color: Color {
            switch self {
            case .info: return .white
            case .warning: return .orange
            case .error: return .red
            case .debug: return .gray
            }
        }
        
        var prefix: String {
            switch self {
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .debug: return "🔍"
            }
        }
    }
}

// MARK: - iOS-Specific UI Types
#if os(iOS)
enum ControlTab: CaseIterable {
    case main, settings, debug
    
    var title: String {
        switch self {
        case .main: return "Main"
        case .settings: return "Settings"
        case .debug: return "Debug"
        }
    }
    
    var icon: String {
        switch self {
        case .main: return "cube.transparent"
        case .settings: return "gear"
        case .debug: return "ladybug"
        }
    }
}
#endif

// MARK: - Shared UI Components

struct MetricView: View {
    let icon: String
    let value: String
    let unit: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.cyan)
            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
            Text(unit)
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Shared Console Components

struct ConsoleMessageView: View {
    let message: ConsoleMessage
    
    var body: some View {
        HStack(spacing: 6) {
            Text(message.level.prefix)
                .font(.caption)
            Text("[\(formatTimestamp(message.timestamp))]")
                .font(.caption2)
                .foregroundColor(.gray)
            Text(message.text)
                .font(.caption)
                .foregroundColor(message.level.color)
            Spacer()
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - iOS-Specific UI Components
#if os(iOS)
struct MobileConsoleMessageView: View {
    let message: ConsoleMessage
    
    var body: some View {
        HStack(spacing: 4) {
            Text(message.level.prefix)
                .font(.caption2)
            Text(message.text)
                .font(.caption2)
                .foregroundColor(message.level.color)
            Spacer()
            Text(formatTimestamp(message.timestamp))
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

class TouchController: ObservableObject {
    @Published var lastTouchLocation: CGPoint = .zero
    @Published var touchCount: Int = 0
    
    func handleTouch(at location: CGPoint) {
        lastTouchLocation = location
        touchCount += 1
    }
    
    func reset() {
        touchCount = 0
    }
}
#endif

// MARK: - Shared Button Styles

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.3 : 0.2))
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ProfessionalButtonStyle: ButtonStyle {
    let isActive: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.cyan.opacity(0.3) : Color.white.opacity(0.1))
                    .stroke(isActive ? Color.cyan : Color.white.opacity(0.3), lineWidth: 1)
            )
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#if os(iOS)
struct MobileGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.3 : 0.2))
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct MobilePrimaryButtonStyle: ButtonStyle {
    let isActive: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? Color.cyan.opacity(0.3) : Color.white.opacity(0.1))
                    .stroke(isActive ? Color.cyan : Color.white.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
#endif

// MARK: - Shared Gesture Controller

class GestureController: ObservableObject {
    @Published var isGestureActive: Bool = false
    @Published var currentGesture: GestureType = .none
    
    enum GestureType {
        case none, movement, rotation, zoom, selection
    }
    
    func handleMovement(_ vector: SIMD2<Float>) {
        currentGesture = vector.x != 0 || vector.y != 0 ? .movement : .none
        isGestureActive = currentGesture != .none
        
        #if os(iOS)
        // Send movement via notification for iOS virtual controls
        NotificationCenter.default.post(
            name: .virtualMovement,
            object: vector
        )
        #endif
    }
    
    func handleRotation(_ delta: SIMD2<Float>) {
        currentGesture = .rotation
        isGestureActive = true
        
        #if os(iOS)
        // Send rotation via notification for iOS virtual controls
        NotificationCenter.default.post(
            name: .virtualRotation,
            object: delta
        )
        #endif
    }
    
    func handleZoom(_ delta: Float) {
        currentGesture = .zoom
        isGestureActive = true
        
        #if os(iOS)
        // Send zoom via notification for iOS virtual controls
        NotificationCenter.default.post(
            name: .virtualZoom,
            object: delta
        )
        #endif
        
        // Reset gesture state after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.currentGesture = .none
            self.isGestureActive = false
        }
    }
}

// MARK: - Shared Supporting Classes

class CockpitState: ObservableObject {
    @Published var fps: Int = 60
    @Published var entityCount: Int = 0
    @Published var showConsole: Bool = false
    
    func setupECSMonitoring(ecs: ECSCore) {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.fps = Int.random(in: 55...60)
                self.entityCount = self.countEntitiesInECS(ecs: ecs)
            }
        }
    }
    
    private func countEntitiesInECS(ecs: ECSCore) -> Int {
        let world = ecs.getWorld()
        let positionEntities = world.entities(with: PositionComponent.self)
        return positionEntities.count
    }
}

// MARK: - Shared Functionality Extensions

extension CockpitState {
    // Shared functionality for both iOS and macOS cockpit views
    static func convertOSConnectionStatus(_ osStatus: OSConnectionStatus) -> ConnectionStatus {
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
    
    static func createConsoleMessage(_ text: String, level: ConsoleMessage.LogLevel = .info) -> ConsoleMessage {
        return ConsoleMessage(
            timestamp: Date(),
            level: level,
            text: text
        )
    }
}

// MARK: - Shared Spinning Logic

class SpinEntityManager {
    static func spinSelectedEntity(entityID: EntityID, ecs: ECSCore, renderer: RendererService, addConsoleMessage: @escaping (String) -> Void) {
        let world = ecs.getWorld()
        
        // Check if entity has SpinComponent
        guard world.hasComponent(SpinComponent.self, for: entityID) else {
            addConsoleMessage("Entity cannot spin - no SpinComponent")
            return
        }
        
        // Find the ModelEntity in the ARView that corresponds to this entityID
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
    
    static func spinModelEntity(_ entity: ModelEntity) {
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
    
    static func createDemoSpinEntities(ecs: ECSCore, addConsoleMessage: @escaping (String) -> Void) {
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
}

// MARK: - Minimap Components (UI-Only)

struct RadarMinimapView: View {
    let renderer: RendererService?
    @State private var refreshID = UUID()
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.1))
                .overlay(
                    Circle()
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            
            RadarSweepView()
            
            if let renderer = renderer {
                ForEach(Array(renderer.arView.scene.anchors.enumerated()), id: \.offset) { index, anchor in
                    Circle()
                        .fill(Color.green.opacity(0.8))
                        .frame(width: 4, height: 4)
                        .position(
                            x: 60 + CGFloat(anchor.position.x * 20),
                            y: 60 - CGFloat(anchor.position.z * 20)
                        )
                }
            }
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            refreshID = UUID()
        }
        .id(refreshID)
    }
}

struct TopDownMinimapView: View {
    let renderer: RendererService?
    @State private var refreshID = UUID()
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    GridPattern()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                )
            
            if let renderer = renderer {
                ForEach(Array(renderer.arView.scene.anchors.enumerated()), id: \.offset) { index, anchor in
                    Rectangle()
                        .fill(Color.blue.opacity(0.8))
                        .frame(width: 6, height: 6)
                        .position(
                            x: 60 + CGFloat(anchor.position.x * 15),
                            y: 60 - CGFloat(anchor.position.z * 15)
                        )
                }
            }
            
            Circle()
                .fill(Color.cyan)
                .frame(width: 8, height: 8)
                .position(x: 60, y: 60)
        }
        .clipShape(Circle())
        .onReceive(Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()) { _ in
            refreshID = UUID()
        }
        .id(refreshID)
    }
}

struct RadarSweepView: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 60, y: 60))
            path.addLine(to: CGPoint(x: 60, y: 10))
        }
        .stroke(Color.green, lineWidth: 1)
        .rotationEffect(.degrees(rotation))
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 20
        
        for x in stride(from: 0, through: rect.width, by: step) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        for y in stride(from: 0, through: rect.height, by: step) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        return path
    }
}

struct CompassMiniMapView: View {
    let cameraYaw: Float
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
            
            // Compass rose
            ForEach(0..<8) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1, height: 20)
                    .offset(y: -30)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
            
            // North indicator
            Triangle()
                .fill(Color.red)
                .frame(width: 8, height: 12)
                .offset(y: -35)
            
            // Camera direction marker
            Triangle()
                .fill(Color.cyan)
                .frame(width: 6, height: 10)
                .offset(y: -30)
                .rotationEffect(.radians(Double(cameraYaw)))
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
