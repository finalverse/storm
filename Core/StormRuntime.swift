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

final class StormRuntime {

    // Core subsystems
    private let kernel = Kernel()
    private let registry = SystemRegistry()
    private let pluginHost = PluginHost()
    private let composer = UIComposer()
    private var agentService: EchoAgentService? = nil

    init() {
        print("[🧠] StormRuntime initialized.")
        setupSystems() // Ensure agentService is ready before StormApp uses it.
    }

    /// Starts the runtime: initializes services, loads plugins, starts kernel ticking.
    func start() {
        print("[▶️] StormRuntime starting...")
        pluginHost.initializePlugins(kernel: kernel, registry: registry)
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

        registry.ui = composer  // UIComposer shared service.

        let router = UIScriptRouter()
        registry.router = router  // ScriptRouter shared service.

        // Create initial EchoAgent entity here (previously in EchoAgentPlugin)
        let entity = ecs.getWorld().createEntity()
        let agent = EchoAgentComponent(mood: "Curious", memory: ["Welcome", "First boot"])
        ecs.getWorld().addComponent(agent, to: entity)

        let agentSvc = EchoAgentService(ecs: ecs, agentID: entity)
        self.agentService = agentSvc
        registry.agentService = agentSvc  // Make available globally.

        // Register UI-driven "echo" namespace commands.
        router.registerHandler(namespace: "echo") { command, args in
            switch command {
            case "sing":
                print("[🧠] Echo command: sing 🎵")
            case "setMood":
                let mood = args.first ?? "Neutral"
                self.agentService?.updateAgentMood(to: mood)
            default:
                print("[❓] Unknown echo command: \(command)")
            }
        }
    }

    /// Accessor for SystemRegistry.
    func getRegistry() -> SystemRegistry {
        return registry
    }

    /// Accessor for UIComposer instance.
    func getUIComposer() -> UIComposer {
        return composer
    }

    /// Accessor for EchoAgentService.
    func getAgentService() -> EchoAgentService? {
        return agentService
    }
}
