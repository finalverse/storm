//
//  Core/SystemRegistry.swift
//  Storm
//
//  Acts as a container for shared services (ECS, UI, LLM, Audio, etc.)
//
//  Created by Wenyan Qin on 2025-07-09.
//

import Foundation

/// Acts as a container for shared services (ECS, UI, LLM, Audio, etc.)
final class SystemRegistry {

    // Add services here as needed
    var ecs: ECSCore? = nil
    var ui: UIComposer? = nil
    var router: UIScriptRouter? = nil
    //var llm: LLMBroker? = nil
    //var audio: AudioEngine? = nil

    // Optional metadata
    var metadata: [String: Any] = [:]

    func register<T>(_ service: T, for key: String) {
        metadata[key] = service
    }

    func resolve<T>(_ key: String) -> T? {
        return metadata[key] as? T
    }
}
