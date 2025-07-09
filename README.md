

# 🌩️ Finalverse Storm

Finalverse Storm is an AI-driven, plugin-extensible, cross-platform virtual world client built in Swift and Rust.

> Built for macOS, iOS, and visionOS, Storm is modular, ECS-powered, and ready for the age of AI-native simulation.

## 🚀 Features (v0.1.0)
- SwiftUI runtime with 60Hz ticking kernel
- PluginHost system with modular plugin registration
- ECSCore engine for simulation
- Runtime-driven UI using UISchema + UIComposer
- Rust staticlib with Swift interop
- UIScriptRouter for declarative UI commands
- Multiplatform support (macOS, iOS, iOS Simulator)

## 📁 Project Structure
```
.
├── App/              # App entry point and SwiftUI lifecycle
├── Core/             # Kernel runtime, registry, routers
├── Engine/           # Core systems like ECS
├── Plugins/          # Modular plugins (HUD, Echo, etc.)
├── UI/               # UISchemaView + Composer
├── RustCore/         # Rust staticlib via FFI
└── Libs/             # Compiled libstorm.a for macOS/iOS
```

## 📦 Requirements
- macOS 13+
- Xcode 15+
- Rust + cargo
- Swift toolchain with modulemap support

## 🛠️ Setup
1. Build Rust static libs:
   ```bash
   ./scripts/build-rust-universal.sh
   ```
2. Open `storm.xcodeproj` and run the app (macOS/iOS)
3. Watch tick logs and press **Sing** button in HUD

## 📜 License
Copyright — Finalverse 2025