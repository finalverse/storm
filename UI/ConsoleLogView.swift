//
//  ConsoleLogView.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-11.
//

import SwiftUI

struct ConsoleLogView: View {
    @ObservedObject var console: ConsoleLogService

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(console.logs.indices, id: \.self) { index in
                        Text(console.logs[index])
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(4)
            }
            .background(Color.black.opacity(0.8))
            .onChange(of: console.logs.count) {
                if let last = console.logs.indices.last {
                    withAnimation {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
        .frame(width: 300)  // Fixed width for right side panel
    }
}
