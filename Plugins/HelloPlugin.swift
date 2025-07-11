//
//  HelloPlugin.swift
//  Storm
//
//  A simple plugin that logs its update ticks.
//
//  Created by Wenyan Qin on 2025-07-09.
//

import Foundation
import RustStorm

/// A simple plugin that logs its update ticks.
final class HelloPlugin: StormPlugin {
    private var tickCount = 0

    func setup(registry: SystemRegistry) {
        print("[👋] HelloPlugin setup complete.")
        storm_hello()   // <---- Should print from Rust
    }

    func update(deltaTime: TimeInterval) {
        tickCount += 1
        if tickCount % 60 == 0 {
            print("[👋] HelloPlugin ticked: \(tickCount)")
        }
    }
}
