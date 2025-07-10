//
//  StormLogger.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-11.
//

import Foundation

/// Simple logger utility that forwards logs to ConsoleLogService.
final class StormLogger {
    static let shared = StormLogger()
    private var console: ConsoleLogService?

    private init() {}

    func configure(console: ConsoleLogService) {
        self.console = console
    }

    func log(_ text: String) {
        print(text)
        console?.append(text)
    }
}

@inline(__always)
func StormLog(_ text: String) {
    StormLogger.shared.log(text)
}
