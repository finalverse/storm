//
//  Core/PluginHost.swift
//  Storm
//
//  A system plugin that can register into the runtime and receive updates.
//
//  Created by Wenyan Qin on 2025-07-09.
//

import Foundation

/// A system plugin that can register into the runtime and receive updates.
protocol StormPlugin {
    /// Called once when plugin is added
    func setup(registry: SystemRegistry)

    /// Called every frame with delta time
    func update(deltaTime: TimeInterval)
}

/// Hosts and manages plugins registered into the runtime kernel.
final class PluginHost {

    /// Registered plugins
    private var plugins: [StormPlugin] = []

    /// Initialize and register all plugins (demo: only HelloPlugin)
    func initializePlugins(kernel: Kernel, registry: SystemRegistry) {
        print("[🔌] PluginHost initializing plugins...")

        let logPlugin = HelloPlugin()
        register(plugin: logPlugin, into: kernel, registry: registry)
    }

    /// Registers plugin and links it to the kernel tick loop
    private func register(plugin: StormPlugin, into kernel: Kernel, registry: SystemRegistry) {
        plugins.append(plugin)
        plugin.setup(registry: registry)

        kernel.registerSystem { delta in
            plugin.update(deltaTime: delta)
        }

        print("[✅] Registered plugin: \(type(of: plugin))")
    }
}
