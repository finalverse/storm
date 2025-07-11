//
//  UI/SceneViewContainer.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-11.
//

import Foundation

//
//  SceneViewContainer.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-11.
//

import SwiftUI
import SceneKit

struct SceneViewContainer: NSViewRepresentable {
    let scene: SCNScene
    let onSelect: ((SCNNode) -> Void)?

    @Environment(\.systemRegistry) private var systemRegistry

    func makeNSView(context: Context) -> SCNView {
        let scnView = InteractiveSceneView()
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.backgroundColor = .black

        let clickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        scnView.addGestureRecognizer(clickGesture)

        let rightClickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRightClick(_:)))
        rightClickGesture.buttonMask = 0x2  // Right mouse button
        scnView.addGestureRecognizer(rightClickGesture)

        scnView.hoverHandler = { point in
            if let sceneRenderer: SceneRendererService = systemRegistry?.resolve("sceneRenderer"),
               let node = sceneRenderer.node(at: point, in: scnView) {
                let mood = node.childNode(withName: "label", recursively: false)?.geometry.flatMap { ($0 as? SCNText)?.string as? String } ?? "Unknown"
                scnView.toolTip = "🧠 EchoAgent\nMood: \(mood)"
            } else {
                scnView.toolTip = nil
            }
        }


        return scnView
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        // Future dynamic updates for ECS-driven entities can go here
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(scene: scene, registry: systemRegistry, onSelect: onSelect)
    }

    class Coordinator: NSObject {
        let scene: SCNScene
        let registry: SystemRegistry?
        let onSelect: ((SCNNode) -> Void)?
        var selectedNode: SCNNode?

        init(scene: SCNScene, registry: SystemRegistry?, onSelect: ((SCNNode) -> Void)?) {
            self.scene = scene
            self.registry = registry
            self.onSelect = onSelect
        }

        @objc func handleClick(_ sender: NSClickGestureRecognizer) {
            guard let view = sender.view as? SCNView else { return }
            let location = sender.location(in: view)

            if let registry = registry,
               let sceneRenderer: SceneRendererService = registry.resolve("sceneRenderer"),
               let node = sceneRenderer.node(at: location, in: view) {
                sceneRenderer.highlight(node: node)
                self.onSelect?(node)
            }
        }
        
        @objc func handleRightClick(_ sender: NSClickGestureRecognizer) {
            guard let view = sender.view as? SCNView else { return }
            let location = sender.location(in: view)

            if let registry = registry,
               let sceneRenderer: SceneRendererService = registry.resolve("sceneRenderer"),
               let node = sceneRenderer.node(at: location, in: view) {
                self.selectedNode = node
                let inspectItem = NSMenuItem(title: "Inspect", action: #selector(inspectAgent), keyEquivalent: "i")
                inspectItem.keyEquivalentModifierMask = [.command]
                inspectItem.target = self

                let removeItem = NSMenuItem(title: "Remove", action: #selector(removeAgent), keyEquivalent: "\u{8}") // Backspace/Delete
                removeItem.keyEquivalentModifierMask = []
                removeItem.target = self

                let menu = NSMenu(title: "Agent Actions")
                menu.addItem(inspectItem)
                menu.addItem(removeItem)
                menu.popUp(positioning: nil, at: location, in: view)
            }
        }

        @objc func inspectAgent() {
            print("Inspect action triggered")
        }

        @objc func removeAgent() {
            guard let registry = registry,
                  let sceneRenderer: SceneRendererService = registry.resolve("sceneRenderer"),
                  let ecs = registry.ecs,
                  let node = selectedNode,
                  let entityID = sceneRenderer.entityID(for: node) else {
                return
            }

            let alert = NSAlert()
            alert.messageText = "Remove Agent"
            alert.informativeText = "Are you sure you want to remove this agent?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Remove")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                ecs.getWorld().removeEntity(entityID)
            }
        }
        
        // Tooltip on hover: mouseMoved
        @objc func mouseMoved(with event: NSEvent) {
            guard let view = event.window?.contentView?.subviews.first(where: { $0 is SCNView }) as? SCNView else { return }
            let location = view.convert(event.locationInWindow, from: nil)

            if let registry = registry,
               let sceneRenderer: SceneRendererService = registry.resolve("sceneRenderer"),
               let node = sceneRenderer.node(at: location, in: view) {
                let mood = node.childNode(withName: "label", recursively: false)?.geometry.flatMap { ($0 as? SCNText)?.string as? String } ?? "Unknown"
                view.toolTip = "🧠 EchoAgent\nMood: \(mood)"
            } else {
                view.toolTip = nil
            }
        }

        @objc func handleKeyDown(_ event: NSEvent) {
            if event.keyCode == 53 {  // 53 is Escape key
                selectedNode = nil
                print("Selection cleared (Escape)")
            }
        }
    }
}
