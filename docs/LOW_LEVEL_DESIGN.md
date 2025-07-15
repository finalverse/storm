# 🔬 Finalverse Storm - Low-Level Design Document

**File Path:** `storm/docs/LOW_LEVEL_DESIGN.md`

**Description:** Detailed low-level implementation specifications, class diagrams, data structures, algorithms, and implementation guidelines for Storm project components.

## 🧱 Core Data Structures

### **ECS Implementation Details**

#### **Entity Storage**
```swift
// High-performance entity management
typealias EntityID = UUID
typealias ComponentTypeID = String

class ECSWorld {
    // Primary storage: Entity → Component mapping
    private var components: [EntityID: [ComponentTypeID: Component]] = [:]
    
    // Performance optimization: Component type → Entity list
    private var entitySets: [ComponentTypeID: Set<EntityID>] = [:]
    
    // Entity lifecycle tracking
    private var entityVersions: [EntityID: UInt64] = [:]
    private var recycledEntities: [EntityID] = []
    
    // Memory management
    private let componentPool = ComponentPool()
}
```

#### **Component Pool Implementation**
```swift
class ComponentPool {
    private var pools: [ComponentTypeID: Any] = [:]
    
    func getPool<T: Component>(_ type: T.Type) -> Pool<T> {
        let typeID = String(describing: T.self)
        if let pool = pools[typeID] as? Pool<T> {
            return pool
        }
        let newPool = Pool<T>()
        pools[typeID] = newPool
        return newPool
    }
}

class Pool<T: Component> {
    private var objects: [T] = []
    private var freeIndices: [Int] = []
    
    func allocate() -> T? {
        if let index = freeIndices.popLast() {
            return objects[index]
        }
        return nil // Requires new allocation
    }
    
    func deallocate(_ object: T) {
        if let index = objects.firstIndex(where: { $0 === object }) {
            freeIndices.append(index)
        }
    }
}
```

### **System Registry Implementation**
```swift
class SystemRegistry {
    // Type-safe service storage
    private var services: [String: Any] = [:]
    private var serviceTypes: [String: Any.Type] = [:]
    
    // Service lifecycle management
    private var startupOrder: [String] = []
    private var shutdownOrder: [String] = []
    
    // Health monitoring
    private var healthChecks: [String: () -> ServiceHealth] = [:]
    
    func register<T>(_ service: T, for key: String, 
                    startup: Int = 0, shutdown: Int = 0) {
        services[key] = service
        serviceTypes[key] = T.self
        
        // Manage startup/shutdown ordering
        insertOrdered(key, in: &startupOrder, priority: startup)
        insertOrdered(key, in: &shutdownOrder, priority: shutdown)
    }
    
    func resolve<T>(_ key: String) -> T? {
        guard let service = services[key] as? T else {
            logServiceResolutionError(key, expectedType: T.self)
            return nil
        }
        return service
    }
    
    private func insertOrdered(_ key: String, in array: inout [String], priority: Int) {
        // Binary search insertion for ordered startup/shutdown
        let insertIndex = array.firstIndex { priorityFor($0) > priority } ?? array.count
        array.insert(key, at: insertIndex)
    }
}
```

## 🎮 Input System Architecture

### **Cross-Platform Input Abstraction**
```swift
// Input event normalization
enum InputEvent {
    case keyDown(KeyCode)
    case keyUp(KeyCode)
    case mouseMove(CGPoint, delta: CGPoint)
    case mouseClick(CGPoint, button: MouseButton)
    case touchBegan(CGPoint, id: Int)
    case touchMoved(CGPoint, id: Int)
    case touchEnded(CGPoint, id: Int)
    case gestureRecognized(GestureType, data: GestureData)
}

// Platform-specific input handling
protocol InputSource {
    func startListening()
    func stopListening()
    var eventStream: AsyncStream<InputEvent> { get }
}

#if os(macOS)
class MacOSInputSource: InputSource {
    private let eventMonitor: NSEventMonitor
    // ... macOS-specific implementation
}
#else
class IOSInputSource: InputSource {
    private let gestureRecognizers: [UIGestureRecognizer]
    // ... iOS-specific implementation
}
#endif
```

### **Input Processing Pipeline**
```swift
class InputController {
    private let inputSources: [InputSource]
    private var inputFilters: [InputFilter] = []
    weak var delegate: InputControllerDelegate?
    
    func processInput() async {
        for source in inputSources {
            for await event in source.eventStream {
                let processedEvent = applyFilters(event)
                dispatch(processedEvent)
            }
        }
    }
    
    private func applyFilters(_ event: InputEvent) -> InputEvent {
        return inputFilters.reduce(event) { result, filter in
            filter.process(result)
        }
    }
    
    private func dispatch(_ event: InputEvent) {
        switch event {
        case .keyDown(let key):
            handleKeyDown(key)
        case .mouseMove(let position, let delta):
            delegate?.rotateCamera(
                yaw: Float(delta.x * 0.01),
                pitch: Float(delta.y * 0.01)
            )
        // ... other cases
        }
    }
}
```

## 🎨 UI Schema System

### **Schema Definition Structure**
```swift
struct UISchema: Codable, Identifiable {
    let id: String
    let type: UIElementType
    let properties: UIProperties
    let layout: UILayout
    let children: [UISchema]?
    let bindings: [UIBinding]?
    let animations: [UIAnimation]?
}

enum UIElementType: String, Codable {
    case button, label, panel, slider, toggle
    case bindLabel, entityCounter, healthStatus
    case customView
}

struct UIProperties: Codable {
    let label: String?
    let action: String?
    let value: AnyCodable?
    let style: UIStyle?
    let constraints: UIConstraints?
}

struct UILayout: Codable {
    let alignment: UIAlignment
    let spacing: CGFloat
    let padding: UIEdgeInsets
    let distribution: UIDistribution
}
```

### **Dynamic UI Rendering Engine**
```swift
class UISchemaRenderer {
    private let registry: SystemRegistry
    private var elementFactories: [UIElementType: UIElementFactory] = [:]
    
    func render(_ schema: UISchema) -> AnyView {
        guard let factory = elementFactories[schema.type] else {
            return AnyView(errorView(for: schema))
        }
        
        let element = factory.createElement(
            schema: schema,
            registry: registry
        )
        
        return AnyView(
            element
                .modifier(LayoutModifier(schema.layout))
                .modifier(AnimationModifier(schema.animations))
        )
    }
    
    func registerFactory<T: View>(
        for type: UIElementType,
        factory: @escaping (UISchema, SystemRegistry) -> T
    ) {
        elementFactories[type] = UIElementFactory(factory)
    }
}

struct UIElementFactory {
    let createElement: (UISchema, SystemRegistry) -> AnyView
}
```

### **UI Command Routing Implementation**
```swift
class UIScriptRouter {
    // Command registry with namespace isolation
    private var handlers: [String: [String: UIActionHandler]] = [:]
    private var middleware: [UIMiddleware] = []
    
    func registerHandler(
        namespace: String,
        command: String,
        handler: @escaping UIActionHandler
    ) {
        if handlers[namespace] == nil {
            handlers[namespace] = [:]
        }
        handlers[namespace]?[command] = handler
    }
    
    func route(action: String) {
        let command = parseCommand(action)
        let processedCommand = applyMiddleware(command)
        executeCommand(processedCommand)
    }
    
    private func parseCommand(_ action: String) -> UICommand {
        let parts = action.split(separator: ".").map(String.init)
        guard parts.count >= 2 else {
            return UICommand.invalid(action)
        }
        
        return UICommand(
            namespace: parts[0],
            command: parts[1],
            arguments: Array(parts.dropFirst(2)),
            rawAction: action
        )
    }
    
    private func executeCommand(_ command: UICommand) {
        guard let namespaceHandlers = handlers[command.namespace],
              let handler = namespaceHandlers[command.command] else {
            logUnhandledCommand(command)
            return
        }
        
        handler(command.command, command.arguments)
    }
}

struct UICommand {
    let namespace: String
    let command: String
    let arguments: [String]
    let rawAction: String
    
    static func invalid(_ action: String) -> UICommand {
        return UICommand(
            namespace: "invalid",
            command: "unknown",
            arguments: [],
            rawAction: action
        )
    }
}
```

## 🦀 Rust-Swift FFI Implementation

### **Memory-Safe FFI Bridge**
```rust
// Rust side: Safe abstractions over raw C interface
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_float, c_uint, c_ulong};

#[repr(C)]
pub struct AgentSpec {
    pub x: c_float,
    pub y: c_float,
    pub z: c_float,
    pub mood: c_uint,
}

// Internal Rust types (safe)
pub struct Agent {
    pub position: (f32, f32, f32),
    pub mood: Mood,
    pub id: uuid::Uuid,
    pub created_at: std::time::Instant,
}

#[derive(Debug, Clone, Copy)]
pub enum Mood {
    Neutral = 0,
    Happy = 1,
    Angry = 2,
    Curious = 3,
}

// FFI functions with error handling
#[no_mangle]
pub extern "C" fn storm_local_world_init(
    specs: *mut AgentSpec,
    max: c_ulong
) -> c_ulong {
    if specs.is_null() || max == 0 {
        return 0;
    }
