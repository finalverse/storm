//
//  MiniMapView.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-11.
//

import Foundation

//
//  MiniMapView.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-11.
//

import SwiftUI

struct MiniMapView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )

            Text("🗺️ Mini-Map")
                .font(.caption)
                .foregroundColor(.white)
        }
        .frame(width: 100, height: 100)
        .background(Color.black.opacity(0.7))
        .clipShape(Circle())
    }
}
