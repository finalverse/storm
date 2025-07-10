//
//  ConsoleLogService.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-11.
//

import Foundation
import Combine

/// Service that collects log messages for display in UI.
final class ConsoleLogService: ObservableObject {
    @Published var logs: [String] = []

    func append(_ line: String) {
        DispatchQueue.main.async {
            self.logs.append(line)
            if self.logs.count > 500 {
                self.logs.removeFirst(self.logs.count - 500)
            }
        }
    }
}
