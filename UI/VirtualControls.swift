//
//  UI/Components/VirtualControls.swift
//  Storm
//
//  Virtual on-screen controls for touch and gesture input
//  Extracted from CockpitViewShared to reduce file size and improve organization
//
//  Created for Finalverse Storm

import SwiftUI
import simd

// MARK: - iOS Virtual Controls
#if os(iOS)

struct VirtualJoystick: View {
    let onMove: (SIMD2<Float>) -> Void
    
    @State private var knobPosition: CGPoint = .zero
    @State private var isDragging: Bool = false
    @State private var basePosition: CGPoint = .zero
    
    private let baseRadius: CGFloat = 50
    private let knobRadius: CGFloat = 20
    private let maxDistance: CGFloat = 30
    
    var body: some View {
        ZStack {
            // Base circle
            Circle()
                .fill(Color.white.opacity(0.1))
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                .frame(width: baseRadius * 2, height: baseRadius * 2)
                .overlay(
                    // Inner guide circle
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        .frame(width: maxDistance * 2, height: maxDistance * 2)
                )
            
            // Knob
            Circle()
                .fill(Color.cyan.opacity(0.7))
                .stroke(Color.white, lineWidth: 1)
                .frame(width: knobRadius * 2, height: knobRadius * 2)
                .position(knobPosition)
                .scaleEffect(isDragging ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isDragging)
        }
        .onAppear {
            // Center the knob initially
            basePosition = CGPoint(x: baseRadius, y: baseRadius)
            knobPosition = basePosition
        }
        .gesture(
            DragGesture(coordinateSpace: .local)
                .onChanged { value in
                    isDragging = true
                    
                    // Calculate offset from center
                    let offset = CGPoint(
                        x: value.location.x - basePosition.x,
                        y: value.location.y - basePosition.y
                    )
                    
                    // Limit to max distance
                    let distance = sqrt(offset.x * offset.x + offset.y * offset.y)
                    if distance <= maxDistance {
                        knobPosition = value.location
                    } else {
                        // Clamp to circle edge
                        let angle = atan2(offset.y, offset.x)
                        knobPosition = CGPoint(
                            x: basePosition.x + cos(angle) * maxDistance,
                            y: basePosition.y + sin(angle) * maxDistance
                        )
                    }
                    
                    // Convert to normalized coordinates (-1 to 1)
                    let normalizedX = Float((knobPosition.x - basePosition.x) / maxDistance)
                    let normalizedY = Float(-(knobPosition.y - basePosition.y) / maxDistance) // Invert Y
                    
                    onMove(SIMD2<Float>(normalizedX, normalizedY))
                }
                .onEnded { _ in
                    isDragging = false
                    
                    // Spring back to center
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                        knobPosition = basePosition
                    }
                    
                    // Send zero movement
                    onMove(SIMD2<Float>(0, 0))
                }
        )
    }
}

struct VirtualCameraControls: View {
    let onRotate: (SIMD2<Float>) -> Void
    let onZoom: (Float) -> Void
    
    @State private var isDragging: Bool = false
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.white.opacity(0.1))
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                .overlay(
                    // Camera icon
                    Image(systemName: "camera.rotate")
                        .foregroundColor(.white)
                        .font(.title2)
                )
            
            // Zoom controls overlay
            VStack {
                Button(action: { onZoom(0.1) }) {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                .buttonStyle(VirtualControlButtonStyle())
                
                Spacer()
                
                Button(action: { onZoom(-0.1) }) {
                    Image(systemName: "minus")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                .buttonStyle(VirtualControlButtonStyle())
            }
            .padding(8)
        }
        .scaleEffect(isDragging ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isDragging)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    
                    // Convert drag to rotation
                    let sensitivity: Float = 0.01
                    let deltaX = Float(value.translation.width) * sensitivity
                    let deltaY = Float(-value.translation.height) * sensitivity
                    
                    onRotate(SIMD2<Float>(deltaX, deltaY))
                }
                .onEnded { _ in
                    isDragging = false
                }
                .simultaneously(with:
                    MagnificationGesture()
                        .onChanged { value in
                            let zoomDelta = Float(value - 1.0) * 0.1
                            onZoom(zoomDelta)
                        }
                )
        )
    }
}

struct VirtualControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(
                Circle()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.4 : 0.2))
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let virtualMovement = Notification.Name("virtualMovement")
    static let virtualRotation = Notification.Name("virtualRotation")
    static let virtualZoom = Notification.Name("virtualZoom")
}

#endif
