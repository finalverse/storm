# 🌩️ Finalverse Storm — Architecture Overview

> Version: 0.1.0  
> Updated: July 9, 2025  
> Author: Finalverse Core Engineering

## 🧠 Runtime Layer

The Storm engine is orchestrated by a Swift-native `RuntimeKernel`, which ticks registered systems at 60 FPS. It supports:

- Plugin-based modular loading
- ECS simulation ticks
- UI updates
- System-level routing via `SystemRegistry`

### 🔷 High-Level Runtime Overview

```mermaid
graph TD
    App["🧩 StormApp (SwiftUI Host)"]
    Kernel["🌀 RuntimeKernel"]
    Host["🔌 PluginHost"]
    Reg["🧠 SystemRegistry"]
    ECS["🧱 ECSCore"]
    UI["🎨 UIComposer"]
    Router["🎯 UIScriptRouter"]

    App --> Kernel
    App --> Reg
    App --> Host

    Host -->|registers| HelloPlugin
    Host --> PingPlugin
    Host --> HUDTestPlugin

    Reg --> ECS
    Reg --> UI
    Reg --> Router

    UI -->|injects| UISchemaView
    UISchemaView --> Router
```

### 🔷 Plugin Architecture (Current Plugins)

```mermaid
graph TD
    Host["🔌 PluginHost"] --> HelloPlugin
    Host --> PingPlugin
    Host --> HUDTestPlugin

    HelloPlugin -->|log| Console
    PingPlugin --> ECSCore
    HUDTestPlugin --> UIComposer
```

## 📦 Plugin Architecture

Each plugin conforms to the `StormPlugin` protocol and registers into the runtime with access to shared systems:

```
PluginHost → HelloPlugin, PingPlugin, HUDTestPlugin
          ↘︎ each plugin gets update(deltaTime:)
```

## 🧱 SystemRegistry

Central hub for service sharing and discovery:

| Key      | Service Type         |
|----------|----------------------|
| ecs      | ECSCore              |
| ui       | UIComposer           |
| router   | UIScriptRouter       |
| audio    | AudioEngine (planned)|
| llm      | LLMBroker (planned)  |

## 🧩 UISchema & UIComposer

- Dynamic HUDs are defined in JSON via `UISchema`
- Loaded by `UIComposer` at runtime
- Rendered recursively via `UISchemaView`
- Routed via `UIScriptRouter` to trigger commands (e.g., `echo.sing`)

## 🧠 ECSCore Engine

Lightweight ECS with:
- `EntityID → [Component]` store
- `ECSStepSystem` update interface
- Example: PingPlugin prints every 3 seconds

## 🦀 Rust FFI Layer

Rust logic is compiled into `libstorm.a` via staticlib and linked into Swift. Used for:

- Future ECS tick acceleration
- AI/LLM tokenization
- Procedural worldgen
- Audio synthesis

Targets:
- `aarch64-apple-darwin` for macOS
- `aarch64/x86_64-apple-ios` for iOS + simulator

## 📂 Folder Layout

```
storm/
├── App/           → SwiftUI entrypoint
├── Core/          → RuntimeKernel, SystemRegistry, Router
├── Engine/        → ECSCore and future systems
├── Plugins/       → HelloPlugin, PingPlugin, HUDTestPlugin
├── UI/            → ContentView, UISchemaView, UIComposer
├── RustCore/      → Rust logic (lib.rs, storm.h)
├── Libs/          → Precompiled libstorm.a per platform
└── docs/          → Documentation
```

## 🔜 Upcoming Modules

- EchoAgent.swift → memory, persona, prompt patching
- LLMBridge.swift → unified token streaming + function calling
- ProceduralWorld.swift → noise-based region layering
- AudioSongLayer.swift → dynamic audio themes

---

Finalverse Storm is built for AI-native simulation across devices.
