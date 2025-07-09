//
//  Core/HUDTestPlugin.swift
//  Storm
//
//  Injects a test HUD into the UIComposer at runtime.
//
//  Created by Wenyan Qin on 2025-07-09.
//

import Foundation

final class HUDTestPlugin: StormPlugin {
    func setup(registry: SystemRegistry) {
        print("[🧪] HUDTestPlugin setup...")

        guard let composer = registry.ui else {
            print("[⚠️] UIComposer not found.")
            return
        }

        let json = """
        {
          "id": "hud_root",
          "type": "panel",
          "children": [
            {
              "id": "btn_sing",
              "type": "button",
              "label": "Sing",
              "icon": "music.note",
              "action": "echo.sing"
            },
            {
              "id": "lbl_hello",
              "type": "label",
              "label": "Welcome, Echo."
            }
          ]
        }
        """
        composer.loadSchema(from: json)
    }

    func update(deltaTime: TimeInterval) {
        // This plugin is static; no updates needed.
    }
}
