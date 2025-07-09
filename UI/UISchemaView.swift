//
//  UI/UISchemaView.swift
//  Storm
//
//  Renders UI elements dynamically from UISchema definitions.
//
//  Created by Wenyan Qin on 2025-07-09.
//

import SwiftUI

struct UISchemaView: View {
    @Environment(\.systemRegistry) var registry
    let schema: UISchema

    var body: some View {
        switch schema.type {
        case "button":
            Button(action: {
                print("[🧪] Action triggered: \(schema.action ?? "none")")
                
                // TODO: route action to LLM/Echo later
                if let action = schema.action {
                    registry?.router?.route(action: action)
                }
                
            }) {
                HStack {
                    if let icon = schema.icon {
                        Image(systemName: icon)
                    }
                    Text(schema.label ?? "Button")
                }
            }
            .buttonStyle(.borderedProminent)

        case "label":
            Text(schema.label ?? "")
                .font(.headline)

        case "panel":
            VStack(alignment: .leading, spacing: 8) {
                ForEach(schema.children ?? []) { child in
                    UISchemaView(schema: child)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.15))
            .cornerRadius(8)

        default:
            Text("[⚠️] Unknown element: \(schema.type)")
        }
    }
}

private struct SystemRegistryKey: EnvironmentKey {
    static let defaultValue: SystemRegistry? = nil
}

extension EnvironmentValues {
    var systemRegistry: SystemRegistry? {
        get { self[SystemRegistryKey.self] }
        set { self[SystemRegistryKey.self] = newValue }
    }
}
