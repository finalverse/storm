//
//  App/StormApp.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-09.
//

import SwiftUI

@main
struct StormApp: App {

    private let runtime = StormRuntime()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(runtime.getUIComposer() ?? UIComposer())
                .onAppear {
                    runtime.start()
                }
                .onDisappear {
                    runtime.stop()
                }
        }
    }
}
