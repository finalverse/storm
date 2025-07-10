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
        StormLog("[🧠] StormRuntime initialized.")
        setupSystems() // Ensure agentService is ready before StormApp uses it.
    }

    /// Starts the runtime: initializes services, loads plugins, starts kernel ticking.
    func start() {
        StormLog("[▶️] StormRuntime starting...")
        pluginHost.initializePlugins(kernel: kernel, registry: registry)
        if let sceneRenderer: SceneRendererService = registry.resolve("sceneRenderer") {
            kernel.registerSystem { [weak sceneRenderer] _ in
                sceneRenderer?.updateScene()
            }
        }
        kernel.start()
    }

    /// Stops ticking kernel.
    func stop() {
        StormLog("[⏹️] StormRuntime stopping...")
        kernel.stop()
    }

    /// Initializes shared services and registers them in SystemRegistry.
    private func setupSystems() {
        let consoleLog = ConsoleLogService()
        registry.register(consoleLog, for: "consoleLog")
        StormLogger.shared.configure(console: consoleLog)

        let ecs = ECSCore()
        registry.ecs = ecs  // ECS core shared service.

        let sceneRenderer = SceneRendererService(ecs: ecs)
        registry.register(sceneRenderer, for: "sceneRenderer")

        registry.ui = composer  // UIComposer shared service.

        let router = UIScriptRouter()
        registry.router = router  // ScriptRouter shared service.

        // Create initial EchoAgent entity here (previously in EchoAgentPlugin)
        let entity = ecs.getWorld().createEntity()
        let agent = EchoAgentComponent(mood: "Curious", memory: ["Welcome", "First boot"])
        ecs.getWorld().addComponent(agent, to: entity)

        let entity2 = ecs.getWorld().createEntity()
        let agent2 = EchoAgentComponent(mood: "Happy", memory: ["Hello from Agent 2"])
        ecs.getWorld().addComponent(agent2, to: entity2)
        
        let entity3 = ecs.getWorld().createEntity()
        let agent3 = EchoAgentComponent(mood: "Angry", memory: ["Hello from Agent 3"])
        ecs.getWorld().addComponent(agent3, to: entity3)

        let agentSvc = EchoAgentService(ecs: ecs, agentID: entity)
        self.agentService = agentSvc
        registry.agentService = agentSvc  // Make available globally.

        // Register bindable agent service for reactive UI bindings
        let bindableAgent = BindableAgentService(agentService: agentSvc)
        registry.register(bindableAgent, for: "bindableAgent")

        // Register UI-driven "echo" namespace commands.
        router.registerHandler(namespace: "echo") { command, args in
            switch command {
            case "sing":
                StormLog("[🧠] Echo command: sing 🎵")
            case "setMood":
                let mood = args.first ?? "Neutral"
                self.agentService?.updateAgentMood(to: mood)
            default:
                StormLog("[❓] Unknown echo command: \(command)")
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
