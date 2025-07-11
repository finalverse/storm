//
//  ActionBar.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-11.
//

import SwiftUI

struct ActionBar: View {
    var onInspect: (() -> Void)?
    var onTeleport: (() -> Void)?
    var onClearSelection: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                onInspect?()
            }) {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.white)

            Button(action: {
                onTeleport?()
            }) {
                Image(systemName: "location.north.line")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.white)

            Button(action: {
                onClearSelection?()
            }) {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.white)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .shadow(radius: 8)
    }
}
