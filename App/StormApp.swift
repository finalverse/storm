//
//  App/StormApp.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-09.
//

import SwiftUI

@main
struct StormApp: App {

    private let runtime: StormRuntime
    //private let uiComposer: UIComposer

    init() {
        let runtimeInstance = StormRuntime()
        self.runtime = runtimeInstance
        //self.uiComposer = runtimeInstance.getUIComposer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                //.environmentObject(uiComposer)
                .environment(\.systemRegistry, runtime.getRegistry())
                .onAppear {
                    runtime.start()
                }
                .onDisappear {
                    runtime.stop()
                }
        }
    }
}
