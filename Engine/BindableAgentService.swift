//
//  BindableAgentService.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-11.
//

import Foundation
import Combine

/// Reactive wrapper for EchoAgentService for UI binding.
final class BindableAgentService: ObservableObject {
    @Published var mood: String = "Unknown"
    private var cancellable: AnyCancellable?

    init(agentService: EchoAgentService) {
        // Initialize with current mood immediately
        mood = agentService.currentMood

        // Subscribe to changes from agentService
        cancellable = agentService
            .objectWillChange
            .sink { [weak self] in
                self?.mood = agentService.currentMood
            }
    }
}
