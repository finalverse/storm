//
//  Core/StormRuntime.swift
//  Storm
//
//  High-level orchestrator for Finalverse Storm app lifecycle.
//  Coordinates kernel ticking, plugin loading, system setup, and service injection.
//
//  Created by Wenyan Qin on 2025-07-10.
//

import Foundation
import RealityKit

final class StormRuntime {

    // Core subsystems
    private let kernel = Kernel()
    private let registry = SystemRegistry()
    private let pluginHost = PluginHost()
    private let composer = UIComposer()

    init() {
        print("[🧠] StormRuntime initialized.")
        setupSystems() // Ensure agentService is ready before StormApp uses it.
    }

    /// Starts the runtime: initializes services, loads plugins, starts kernel ticking.
    func start() {
        print("[▶️] StormRuntime starting...")
        pluginHost.initializePlugins(kernel: kernel, registry: registry)
        if let renderer: RendererService = registry.resolve("renderer") {
            kernel.registerSystem { [weak renderer] _ in
                renderer?.updateScene()
            }
        }
        kernel.start()
    }

    /// Stops ticking kernel.
    func stop() {
        print("[⏹️] StormRuntime stopping...")
        kernel.stop()
    }

    /// Initializes shared services and registers them in SystemRegistry.
    private func setupSystems() {
        let ecs = ECSCore()
        registry.ecs = ecs  // ECS core shared service.

        // REMOVE ARView creation and RendererService initialization here.
        // RendererService will be constructed later in StormCockpitView and injected properly.

        registry.ui = composer  // UIComposer shared service.

        let router = UIScriptRouter()
        registry.router = router  // ScriptRouter shared service.
    }

    /// Accessor for SystemRegistry.
    func getRegistry() -> SystemRegistry {
        return registry
    }

    /// Accessor for UIComposer instance.
    func getUIComposer() -> UIComposer {
        return composer
    }
}
