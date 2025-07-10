//
//  InteractiveSceneView.swift
//  Storm
//
//  Created by Wenyan Qin on 2025-07-11.
//

import SceneKit

final class InteractiveSceneView: SCNView {

    var hoverHandler: ((CGPoint) -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let options: NSTrackingArea.Options = [.mouseMoved, .activeInKeyWindow, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        hoverHandler?(location)
    }
}
