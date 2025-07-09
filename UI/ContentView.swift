//
//  UI/ContentView.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-09.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var composer: UIComposer
    @Environment(\.systemRegistry) var registry
    
    var body: some View {
        VStack(spacing: 16) {
            Text("🌩️ Finalverse Storm v0.1.0")
                .font(.title)
                .bold()
            
            if let root = composer.rootSchema {
                UISchemaView(schema: root)
            } else {
                Text("No HUD loaded.")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.95))
        .foregroundColor(.white)
    }
}
