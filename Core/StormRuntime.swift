//
//  Core/StormRuntime.swift
//  Storm
//
//  High-level orchestrator for Finalverse Storm app lifecycle.
//
//  Created by Wenyan Qin on 2025-07-10.
//

import Foundation

final class StormRuntime {

    private let kernel = Kernel()
    private let registry = SystemRegistry()
    private let pluginHost = PluginHost()
    private let composer = UIComposer()

    init() {
        print("[🧠] StormRuntime initialized.")
    }

    func start() {
        print("[▶️] StormRuntime starting...")
        setupSystems()
        pluginHost.initializePlugins(kernel: kernel, registry: registry)
        kernel.start()
    }

    func stop() {
        print("[⏹️] StormRuntime stopping...")
        kernel.stop()
    }

    private func setupSystems() {
        let ecs = ECSCore()
        registry.ecs = ecs

        registry.ui = composer

        let router = UIScriptRouter()
        registry.router = router

        let agentService = EchoAgentService(ecs: ecs)

        router.registerHandler(namespace: "echo") { command, args in
            switch command {
            case "sing":
                print("[🧠] Echo command: sing 🎵")
            case "setMood":
                let mood = args.first ?? "Neutral"
                agentService.updateAgentMood(to: mood)
            default:
                print("[❓] Unknown echo command: \(command)")
            }
        }
    }

    func getRegistry() -> SystemRegistry {
        return registry
    }

    func getUIComposer() -> UIComposer {
        return composer
    }
}
