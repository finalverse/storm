//
//  Core/Kernel.swift
//  Storm
//
//  Pure ticking engine responsible only for simulation timing and system callbacks.
//
//  Created by Wenyan Qin on 2025-07-10.
//

import Foundation
import Combine

/// The Kernel is a minimal tick engine that drives system updates at a fixed frame rate.
/// It does not manage plugins, UI, or registry—it simply schedules per-frame callbacks.
final class Kernel {
    private var timer: Cancellable?
    private let tickRate: TimeInterval = 1.0 / 60.0 // Targeting ~60 FPS
    private var lastTick: Date = .now

    // Registered system update closures to invoke every tick
    private var systems: [(TimeInterval) -> Void] = []

    /// Initializes the Kernel instance.
    init() {
        print("[🌀] Kernel initialized.")
    }

    /// Starts the ticking timer and begins calling registered systems.
    func start() {
        print("[🌀] Kernel starting...")
        lastTick = .now
        timer = Timer.publish(every: tickRate, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                self?.tick(now: now)
            }
    }

    /// Stops the ticking timer.
    func stop() {
        print("[🛑] Kernel stopped.")
        timer?.cancel()
        timer = nil
    }

    /// Performs a tick cycle, calculates deltaTime, and invokes all registered systems.
    private func tick(now: Date) {
        let delta = now.timeIntervalSince(lastTick)
        lastTick = now

        for system in systems {
            system(delta)
        }
    }

    /// Registers a new system callback to be invoked every tick.
    func registerSystem(_ system: @escaping (TimeInterval) -> Void) {
        systems.append(system)
    }
}
