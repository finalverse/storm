//
//  UI/ContentView.swift
//  Storm
//
//  Displays main UI including dynamic HUD, agent mood, and background.
//
//  Created by Wenyan Qin on 2025-07-09.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var composer: UIComposer
    @Environment(\.systemRegistry) var registry

    var body: some View {
        // Updated to use StormCockpitView as main cockpit entry
        StormCockpitView()
    }
}
