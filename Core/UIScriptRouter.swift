//
//  Core/UIScriptRouter.swift
//  Storm
//
//  Routes schema action strings like `echo.sing` or `ui.reload` to runtime systems.
//
//  Created by Wenyan Qin on 2025-07-09.
//

import Foundation

typealias UIActionHandler = (_ command: String, _ args: [String]) -> Void

final class UIScriptRouter {

    private var handlers: [String: UIActionHandler] = [:]

    func registerHandler(namespace: String, handler: @escaping UIActionHandler) {
        handlers[namespace] = handler
        StormLog("[🎯] Registered UI namespace: \(namespace)")
    }

    func route(action: String) {
        let parts = action.split(separator: ".").map(String.init)
        guard parts.count >= 2 else {
            StormLog("[⚠️] Invalid action: \(action)")
            return
        }

        let namespace = parts[0]
        let command = parts[1]
        let args = Array(parts.dropFirst(2))

        if let handler = handlers[namespace] {
            handler(command, args)
        } else {
            StormLog("[❌] No handler for namespace: \(namespace)")
        }
    }
}
