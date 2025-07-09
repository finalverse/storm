//
//  RuntimeKernel.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-09.
//

import Foundation
import Combine

/// FinalStorm Runtime Kernel — drives frame updates and plugin dispatch
final class RuntimeKernel: ObservableObject {

    // MARK: - Properties

    private var timer: Cancellable?
    private let tickRate: TimeInterval = 1.0 / 60.0
    private var lastTick: Date = .now

    /// Registered plugin update handlers
    private var systems: [(TimeInterval) -> Void] = []

    // MARK: - Lifecycle

    func start() {
        print("[🌀] RuntimeKernel starting...")
        lastTick = .now
        timer = Timer.publish(every: tickRate, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                self?.tick(now: now)
            }
    }

    func stop() {
        print("[🛑] RuntimeKernel stopped.")
        timer?.cancel()
        timer = nil
    }

    // MARK: - Tick Loop

    private func tick(now: Date) {
        let delta = now.timeIntervalSince(lastTick)
        lastTick = now

        // Call each system
        for system in systems {
            system(delta)
        }

        print("[⏱️] Tick @ \(String(format: "%.3f", delta))s")
    }

    // MARK: - Plugin/System Registration

    func registerSystem(_ system: @escaping (TimeInterval) -> Void) {
        systems.append(system)
    }
}
