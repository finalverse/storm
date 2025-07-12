
//
//  Core/InputController.swift
//  Storm
//
//  Cross-platform input controller for handling keyboard and gesture input.
//  Abstracts user input and delegates camera/navigation commands to RendererService.
//
//  Created by Wenyan Qin on 2025-07-12.
//

import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

import RealityKit

protocol InputControllerDelegate: AnyObject {
    func moveCamera(forward: Bool)
    func moveCamera(backward: Bool)
    func moveCamera(left: Bool)
    func moveCamera(right: Bool)
    func rotateCamera(yaw: Float, pitch: Float)
    func zoomCamera(scale: Float)
}

final class InputController {
    weak var delegate: InputControllerDelegate?

#if os(macOS)
    func registerInputHandlers(for view: NSView) {
        let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleKeyDown(event)
            return event
        }
        // Store keyMonitor reference if removal needed later
    }

    private func handleKeyDown(_ event: NSEvent) {
        switch event.keyCode {
        case 13: delegate?.moveCamera(forward: true)  // W
        case 1:  delegate?.moveCamera(backward: true) // S
        case 0:  delegate?.moveCamera(left: true)     // A
        case 2:  delegate?.moveCamera(right: true)    // D
        case 123: delegate?.rotateCamera(yaw: -0.1, pitch: 0)  // ←
        case 124: delegate?.rotateCamera(yaw: 0.1, pitch: 0)   // →
        case 125: delegate?.rotateCamera(yaw: 0, pitch: -0.1)  // ↓
        case 126: delegate?.rotateCamera(yaw: 0, pitch: 0.1)   // ↑
        default: break
        }
    }
#else
    func registerInputHandlers(for view: UIView) {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(panGesture)
        view.addGestureRecognizer(pinchGesture)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view)
        delegate?.rotateCamera(yaw: Float(translation.x) * 0.005, pitch: Float(-translation.y) * 0.005)
        gesture.setTranslation(.zero, in: gesture.view)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        delegate?.zoomCamera(scale: Float(gesture.scale))
        gesture.scale = 1.0
    }
#endif
}
