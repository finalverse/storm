//
//  Engine/AgentViewModel.swift
//  Storm
//
//  Provides a reactive view model for observing EchoAgent state from ECS.
//
//  Created by Wenyan Qin on 2025-07-10.
//

import Foundation
import Combine

final class AgentViewModel: ObservableObject {
    private let ecs: ECSCore
    private var timer: Timer?
    @Published var mood: String = "Unknown"

    init(ecs: ECSCore) {
        self.ecs = ecs
        startPolling()
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pollMood()
        }
    }

    private func pollMood() {
        if let agent = ecs.getWorld().entities(with: EchoAgentComponent.self).first?.1 {
            mood = agent.mood
        } else {
            mood = "Unknown"
        }
    }

    deinit {
        timer?.invalidate()
    }
}
