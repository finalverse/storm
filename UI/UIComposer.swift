//
//  UI/UIComposer.swift
//  Storm
//
//  Loads and manages dynamic UI schemas from plugins or LLMs.
//
//  Created by Wenyan Qin on 2025-07-09.
//

import Foundation
import SwiftUI

/// A unified schema for declaring HUD/UI nodes
struct UISchema: Codable, Identifiable {
    var id: String
    var type: String  // "button", "label", "panel", etc.
    var label: String?
    var icon: String?
    var action: String?
    var bind: String?  // Optional binding expression
    var children: [UISchema]?
}

/// Responsible for managing the live UI schema tree
final class UIComposer: ObservableObject {
    @Published var rootSchema: UISchema?

    func loadSchema(from file: URL) {
        do {
            let data = try Data(contentsOf: file)
            let schema = try JSONDecoder().decode(UISchema.self, from: data)
            self.rootSchema = schema
            StormLog("[🧩] Loaded UI schema: \(schema.id)")
        } catch {
            StormLog("[❌] Failed to load UI schema: \(error)")
        }
    }

    func loadSchema(from jsonString: String) {
        if let data = jsonString.data(using: .utf8) {
            do {
                self.rootSchema = try JSONDecoder().decode(UISchema.self, from: data)
                StormLog("[🧩] Parsed inline UI schema: \(rootSchema?.id ?? "?")")
            } catch {
                StormLog("[❌] JSON parse error: \(error)")
            }
        }
    }
}
