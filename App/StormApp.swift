//
//  StormApp.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-09.
//

import SwiftUI

@main
struct StormApp: App {

    @StateObject private var kernel = RuntimeKernel()
    private let pluginHost = PluginHost()
    private let registry = SystemRegistry()
    @StateObject private var composer = UIComposer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(composer)
                .onAppear {
                    // Register ECS first
                    let ecs = ECSCore()
                    registry.ecs = ecs
                    
                    // Register router
                    let router = UIScriptRouter()
                    router.registerHandler(namespace: "echo") { command, args in
                        switch command {
                        case "sing":
                            print("[🧠] Echo command: sing 🎵")
                        default:
                            print("[❓] Unknown echo command: \(command)")
                        }
                    }
                    registry.router = router
                    
                    registry.ui = composer
                    
                    // Now initialize plugins
                    pluginHost.initializePlugins(kernel: kernel, registry: registry)
                    kernel.start()
                }
                .onDisappear {
                    kernel.stop()
                }
        }
    }
}
