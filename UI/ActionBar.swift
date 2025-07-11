//
//  UI/ActionBar.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-11.
//

import SwiftUI

struct ActionBar: View {
    var onInspect: (() -> Void)?
    var onTeleport: (() -> Void)?
    var onClearSelection: (() -> Void)?
    var onToggleMinimap: (() -> Void)?
    var onToggleConsoleLog: (() -> Void)?

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            actionButton(systemImage: "magnifyingglass", label: "Inspect", action: onInspect)
            actionButton(systemImage: "location.north.line", label: "Teleport", action: onTeleport)
            actionButton(systemImage: "xmark.circle", label: "Clear", action: onClearSelection)
            actionButton(systemImage: "map", label: "Minimap", action: onToggleMinimap)
            actionButton(systemImage: "terminal", label: "Console", action: onToggleConsoleLog)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .shadow(radius: 8)
    }

    @ViewBuilder
    private func actionButton(systemImage: String, label: String, action: (() -> Void)?) -> some View {
        @State var isHovering = false

        Button(action: {
            action?()
        }) {
            ZStack {
                Image(systemName: systemImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .scaleEffect(isHovering ? 1.2 : 1.0)
                    .foregroundColor(.white)
                    .animation(.easeInOut(duration: 0.2), value: isHovering)

                if isHovering {
                    Text(label)
                        .font(.caption2)
                        .padding(.top, 36)
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovering = hovering
        }
        .help(label)
    }
}
