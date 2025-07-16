//
//  UI/UIComposer.swift
//  Storm
//
//  Dynamic UI composition engine that manages UI schemas and provides
//  type-safe UI element creation and management for the Storm runtime.
//  Handles schema loading, activation, real-time UI updates, and action routing.
//
//  Created by Wenyan Qin on 2025-07-15.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Type Aliases

/// Handler function for UI actions with command and arguments
typealias UIActionHandler = (_ command: String, _ args: [String]) -> Void

// MARK: - UIElementType Enum

/// Defines all supported UI element types for dynamic schema rendering
enum UIElementType: String, Codable, CaseIterable {
    case button = "button"
    case label = "label"
    case slider = "slider"
    case toggle = "toggle"
    case progress = "progress"
    case input = "input"
    case panel = "panel"
    case spacer = "spacer"
    case divider = "divider"
    case image = "image"
    // Storm-specific element types for system integration
    case bindLabel = "bindLabel"           // Label bound to system values
    case entityCounter = "entityCounter"   // Shows entity count from ECS
    case healthStatus = "healthStatus"     // System health indicator
}

// MARK: - UIElementStyle Structure

/// Styling configuration for UI elements with SwiftUI-compatible properties
struct UIElementStyle: Codable {
    let backgroundColor: String?    // Hex color or named color
    let foregroundColor: String?    // Text/icon color
    let fontSize: Double?          // Font size in points
    let padding: Double?           // Internal padding
    let cornerRadius: Double?      // Corner radius for rounded elements
    let opacity: Double?           // Transparency (0.0 - 1.0)
    let width: Double?             // Fixed width (optional)
    let height: Double?            // Fixed height (optional)
    
    // MARK: - Predefined Styles
    
    /// Standard button styling
    static let defaultButton = UIElementStyle(
        backgroundColor: "#007AFF",
        foregroundColor: "#FFFFFF",
        fontSize: 16,
        padding: 12,
        cornerRadius: 8,
        opacity: 1.0,
        width: nil,
        height: 44
    )
    
    /// Standard label styling
    static let defaultLabel = UIElementStyle(
        backgroundColor: nil,
        foregroundColor: "#FFFFFF",
        fontSize: 14,
        padding: 8,
        cornerRadius: 0,
        opacity: 0.9,
        width: nil,
        height: nil
    )
    
    /// Success state label (green text)
    static let successLabel = UIElementStyle(
        backgroundColor: nil,
        foregroundColor: "#00FF00",
        fontSize: 14,
        padding: 8,
        cornerRadius: 0,
        opacity: 1.0,
        width: nil,
        height: nil
    )
    
    /// Debug button styling (orange background)
    static let debugButton = UIElementStyle(
        backgroundColor: "#FF6B35",
        foregroundColor: "#FFFFFF",
        fontSize: 14,
        padding: 8,
        cornerRadius: 6,
        opacity: 0.8,
        width: 100,
        height: 32
    )
    
    /// Panel container styling
    static let defaultPanel = UIElementStyle(
        backgroundColor: "#000000",
        foregroundColor: "#FFFFFF",
        fontSize: 12,
        padding: 16,
        cornerRadius: 12,
        opacity: 0.8,
        width: 300,
        height: nil
    )
}

// MARK: - UIElementLayout Structure

/// Layout configuration for positioning and alignment of UI elements
struct UIElementLayout: Codable {
    let x: Double?          // X offset from anchor point
    let y: Double?          // Y offset from anchor point
    let anchor: String?     // Anchor position ("topLeading", "center", etc.)
    let spacing: Double?    // Spacing between child elements
    let direction: String?  // Layout direction ("horizontal" or "vertical")
    
    // MARK: - Predefined Layouts
    
    /// Top-left corner positioning
    static let topLeading = UIElementLayout(
        x: 20, y: 60,
        anchor: "topLeading",
        spacing: 8,
        direction: "vertical"
    )
    
    /// Top-right corner positioning
    static let topTrailing = UIElementLayout(
        x: -20, y: 60,
        anchor: "topTrailing",
        spacing: 8,
        direction: "vertical"
    )
    
    /// Bottom-left corner positioning
    static let bottomLeading = UIElementLayout(
        x: 20, y: -20,
        anchor: "bottomLeading",
        spacing: 8,
        direction: "horizontal"
    )
    
    /// Center screen positioning
    static let center = UIElementLayout(
        x: 0, y: 0,
        anchor: "center",
        spacing: 16,
        direction: "vertical"
    )
}

// MARK: - UIElement Structure

/// Individual UI element definition with type, content, and behavior
struct UIElement: Codable, Identifiable {
    let id: String                      // Unique identifier for element
    let type: UIElementType            // Element type (button, label, etc.)
    let text: String?                  // Display text or placeholder
    let action: String?                // Action to trigger on interaction
    let style: UIElementStyle?         // Visual styling configuration
    let layout: UIElementLayout?       // Positioning and layout rules
    let children: [UIElement]?         // Child elements for containers
    let isVisible: Bool               // Visibility state
    let isEnabled: Bool               // Interaction enabled state
    
    /// Initialize a new UI element with sensible defaults
    init(
        id: String,
        type: UIElementType,
        text: String? = nil,
        action: String? = nil,
        style: UIElementStyle? = nil,
        layout: UIElementLayout? = nil,
        children: [UIElement]? = nil,
        isVisible: Bool = true,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.action = action
        self.style = style
        self.layout = layout
        self.children = children
        self.isVisible = isVisible
        self.isEnabled = isEnabled
    }
}

// MARK: - UISchema Structure

/// Complete UI schema definition containing multiple elements and metadata
struct UISchema: Codable, Identifiable {
    let id: String              // Unique schema identifier
    let name: String           // Human-readable schema name
    let description: String    // Schema description for debugging
    let version: String        // Schema version for compatibility
    let elements: [UIElement]  // Array of UI elements in this schema
    let isActive: Bool         // Whether schema should be activated on load
    
    /// Initialize a new UI schema
    init(
        id: String,
        name: String,
        description: String,
        version: String = "1.0.0",
        elements: [UIElement],
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.version = version
        self.elements = elements
        self.isActive = isActive
    }
}

// MARK: - UIComposer Class

/// Main UI composition engine that manages schemas, routing, and provides reactive UI updates
final class UIComposer: ObservableObject {
    
    // MARK: - Published Properties (Observable by SwiftUI)
    
    @Published var activeSchemas: [UISchema] = []    // Currently active schemas
    @Published var hudElements: [UIElement] = []     // HUD overlay elements
    @Published var debugElements: [UIElement] = []   // Debug panel elements
    @Published var isHUDVisible: Bool = true        // HUD visibility toggle
    @Published var isDebugVisible: Bool = false     // Debug panel visibility toggle
    
    // MARK: - Private Properties
    
    private var loadedSchemas: [String: UISchema] = [:]     // All loaded schemas by ID
    private var cancellables = Set<AnyCancellable>()        // Combine subscriptions
    private weak var systemRegistry: SystemRegistry?        // Reference to system services
    
    // MARK: - Action Routing Properties (Integrated from UIScriptRouter)
    
    private var actionHandlers: [String: UIActionHandler] = [:]  // Namespace -> handler mapping
    
    // MARK: - Initialization
    
    /// Initialize UIComposer with optional system registry for service integration
    init(systemRegistry: SystemRegistry? = nil) {
        self.systemRegistry = systemRegistry
        setupDefaultActionHandlers()
        setupDefaultSchemas()
        print("[🎨] UIComposer initialized with \(loadedSchemas.count) default schemas")
    }
    
    // MARK: - Action Routing (Integrated UIScriptRouter functionality)
    
    /// Register an action handler for a specific namespace
    func registerActionHandler(namespace: String, handler: @escaping UIActionHandler) {
        actionHandlers[namespace] = handler
        print("[🎯] Registered UI namespace: \(namespace)")
    }
    
    /// Route an action string to the appropriate handler
    func routeAction(_ actionString: String) {
        // Parse action format: "namespace.command.arg1.arg2..."
        let parts = actionString.split(separator: ".").map(String.init)
        guard parts.count >= 2 else {
            print("[⚠️] Invalid action format: \(actionString)")
            return
        }
        
        let namespace = parts[0]
        let command = parts[1]
        let args = Array(parts.dropFirst(2))
        
        // Find and execute handler
        if let handler = actionHandlers[namespace] {
            print("[🎯] Routing action: \(namespace).\(command) with args: \(args)")
            handler(command, args)
        } else {
            print("[❌] No handler registered for namespace: \(namespace)")
            // Try to route to system registry as fallback
            routeToSystemRegistry(actionString)
        }
    }
    
    /// Setup default action handlers for built-in UI functionality
    private func setupDefaultActionHandlers() {
        // Register built-in UI namespace handler
        registerActionHandler(namespace: "ui") { [weak self] command, args in
            self?.handleBuiltInUIAction(command: command, args: args)
        }
        
        // Register echo namespace for testing
        registerActionHandler(namespace: "echo") { command, args in
            print("[🔊] Echo: \(command) with args: \(args)")
        }
    }
    
    /// Handle built-in UI actions like toggle, reload, etc.
    private func handleBuiltInUIAction(command: String, args: [String]) {
        switch command {
        case "toggle_hud":
            isHUDVisible.toggle()
            print("[👁️] HUD visibility: \(isHUDVisible)")
        case "toggle_debug":
            isDebugVisible.toggle()
            print("[🐛] Debug panel visibility: \(isDebugVisible)")
        case "reload_schemas":
            reloadAllSchemas()
        case "clear_all":
            clearAllSchemas()
        case "activate_schema":
            if let schemaId = args.first {
                activateSchema(schemaId)
            }
        case "deactivate_schema":
            if let schemaId = args.first {
                deactivateSchema(schemaId)
            }
        default:
            print("[⚠️] Unknown UI command: \(command)")
        }
    }
    
    /// Fallback routing to system registry if available
    private func routeToSystemRegistry(_ actionString: String) {
        // This maintains compatibility with any existing system registry routing
        print("[🔄] Attempting fallback routing to system registry for: \(actionString)")
        // Implementation would depend on SystemRegistry interface
    }
    
    // MARK: - Schema Management
    
    /// Load a schema into the composer (does not automatically activate)
    func loadSchema(_ schema: UISchema) {
        loadedSchemas[schema.id] = schema
        
        // Auto-activate if schema is marked as active
        if schema.isActive {
            activeSchemas.append(schema)
            updateUIElements()
        }
        
        print("[📋] Loaded UI schema: \(schema.name)")
    }
    
    /// Load multiple schemas at once
    func loadSchemas(_ schemas: [UISchema]) {
        for schema in schemas {
            loadSchema(schema)
        }
    }
    
    /// Activate a previously loaded schema by ID
    func activateSchema(_ schemaId: String) {
        guard let schema = loadedSchemas[schemaId] else {
            print("[⚠️] Schema not found: \(schemaId)")
            return
        }
        
        // Prevent duplicate activation
        if !activeSchemas.contains(where: { $0.id == schemaId }) {
            activeSchemas.append(schema)
            updateUIElements()
            print("[✅] Activated schema: \(schema.name)")
        }
    }
    
    /// Deactivate an active schema by ID
    func deactivateSchema(_ schemaId: String) {
        activeSchemas.removeAll { $0.id == schemaId }
        updateUIElements()
        print("[➖] Deactivated schema: \(schemaId)")
    }
    
    /// Toggle schema activation state
    func toggleSchema(_ schemaId: String) {
        if activeSchemas.contains(where: { $0.id == schemaId }) {
            deactivateSchema(schemaId)
        } else {
            activateSchema(schemaId)
        }
    }
    
    // MARK: - UI Element Updates
    
    /// Update HUD and debug element arrays from active schemas
    private func updateUIElements() {
        var newHudElements: [UIElement] = []
        var newDebugElements: [UIElement] = []
        
        // Separate elements based on schema type
        for schema in activeSchemas {
            for element in schema.elements {
                if schema.id.contains("debug") {
                    newDebugElements.append(element)
                } else {
                    newHudElements.append(element)
                }
            }
        }
        
        // Update published properties to trigger SwiftUI refresh
        hudElements = newHudElements
        debugElements = newDebugElements
    }
    
    // MARK: - Action Handling (Public Interface)
    
    /// Handle UI action triggers from user interactions (main entry point)
    func handleAction(_ actionName: String, context: [String: Any] = [:]) {
        print("[🎯] UI Action: \(actionName)")
        
        // Add context information for debugging
        if !context.isEmpty {
            print("[📄] Action context: \(context)")
        }
        
        // Route action through integrated routing system
        routeAction(actionName)
    }
    
    // MARK: - Schema Factory Methods
    
    /// Create and load default schemas for HUD and debug functionality
    private func setupDefaultSchemas() {
        let hudSchema = createDefaultHUDSchema()
        loadSchema(hudSchema)
        
        let debugSchema = createDebugSchema()
        loadSchema(debugSchema)
    }
    
    /// Create the default HUD schema with system status elements
    private func createDefaultHUDSchema() -> UISchema {
        let elements: [UIElement] = [
            // FPS counter in top-right corner
            UIElement(
                id: "fps_counter",
                type: .bindLabel,
                text: "FPS: --",
                style: .defaultLabel,
                layout: .topTrailing
            ),
            // Entity count in top-left corner
            UIElement(
                id: "entity_count",
                type: .entityCounter,
                text: "Entities: 0",
                style: .defaultLabel,
                layout: .topLeading
            ),
            // System health status below entity count
            UIElement(
                id: "system_status",
                type: .healthStatus,
                text: "System: OK",
                style: .successLabel,
                layout: UIElementLayout(
                    x: 20, y: 100,
                    anchor: "topLeading",
                    spacing: 4,
                    direction: "vertical"
                )
            )
        ]
        
        return UISchema(
            id: "default_hud",
            name: "Default HUD",
            description: "Basic HUD elements for Storm runtime",
            elements: elements,
            isActive: true
        )
    }
    
    /// Create debug controls schema for development tools
    private func createDebugSchema() -> UISchema {
        let elements: [UIElement] = [
            // Debug panel toggle button
            UIElement(
                id: "debug_panel_toggle",
                type: .button,
                text: "Debug Panel",
                action: "ui.toggle_debug",
                style: .debugButton,
                layout: .bottomLeading
            ),
            // UI reload button for development
            UIElement(
                id: "reload_button",
                type: .button,
                text: "Reload UI",
                action: "ui.reload_schemas",
                style: .debugButton,
                layout: UIElementLayout(
                    x: 120, y: -20,
                    anchor: "bottomLeading",
                    spacing: 8,
                    direction: "horizontal"
                )
            ),
            // Echo test button for plugin testing
            UIElement(
                id: "echo_test",
                type: .button,
                text: "Echo Test",
                action: "echo.sing",
                style: .debugButton,
                layout: UIElementLayout(
                    x: 220, y: -20,
                    anchor: "bottomLeading",
                    spacing: 8,
                    direction: "horizontal"
                )
            )
        ]
        
        return UISchema(
            id: "debug_controls",
            name: "Debug Controls",
            description: "Developer debug controls and testing tools",
            elements: elements,
            isActive: false
        )
    }
    
    // MARK: - Element Finding & Updates
    
    /// Find a specific element by ID across all active schemas
    func findElement(byId id: String) -> UIElement? {
        for schema in activeSchemas {
            if let element = schema.findElement(byId: id) {
                return element
            }
        }
        return nil
    }
    
    /// Update element text by ID and refresh UI
    func updateElementText(elementId: String, newText: String) {
        for i in 0..<activeSchemas.count {
            if let updatedSchema = activeSchemas[i].updatingElementText(id: elementId, newText: newText) {
                activeSchemas[i] = updatedSchema
                updateUIElements()
                break
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// Reload all schemas from defaults (useful for development)
    private func reloadAllSchemas() {
        let currentActiveIds = activeSchemas.map { $0.id }
        
        // Clear current state
        loadedSchemas.removeAll()
        activeSchemas.removeAll()
        
        // Rebuild from defaults
        setupDefaultSchemas()
        
        // Reactivate previously active schemas if they still exist
        for id in currentActiveIds {
            if loadedSchemas[id] != nil {
                activateSchema(id)
            }
        }
        
        print("[🔄] All UI schemas reloaded")
    }
    
    /// Clear all schemas (useful for testing)
    private func clearAllSchemas() {
        loadedSchemas.removeAll()
        activeSchemas.removeAll()
        updateUIElements()
        print("[🗑️] All UI schemas cleared")
    }
    
    /// Get list of all loaded schema names
    func getSchemaNames() -> [String] {
        return Array(loadedSchemas.keys)
    }
    
    /// Get list of currently active schema names
    func getActiveSchemaNames() -> [String] {
        return activeSchemas.map { $0.name }
    }
    
    // MARK: - Debug Methods
    
    /// Print comprehensive schema and routing information for debugging
    func dumpSchemaInfo() {
        print("=== UIComposer Schema Info ===")
        print("Total Schemas: \(loadedSchemas.count)")
        print("Active Schemas: \(activeSchemas.count)")
        print("HUD Elements: \(hudElements.count)")
        print("Debug Elements: \(debugElements.count)")
        print("Registered Action Handlers: \(actionHandlers.count)")
        print("")
        
        print("Loaded Schemas:")
        for (id, schema) in loadedSchemas {
            print("  \(id): \(schema.name) (\(schema.elements.count) elements)")
        }
        
        print("Active Schemas:")
        for schema in activeSchemas {
            print("  \(schema.id): \(schema.name)")
        }
        
        print("Action Handlers:")
        for namespace in actionHandlers.keys {
            print("  \(namespace)")
        }
        print("==============================")
    }
}

// MARK: - UIComposer Extensions

extension UIComposer {
    
    /// Helper to create button elements quickly
    static func createButton(
        id: String,
        text: String,
        action: String,
        x: Double = 0,
        y: Double = 0
    ) -> UIElement {
        return UIElement(
            id: id,
            type: .button,
            text: text,
            action: action,
            style: .defaultButton,
            layout: UIElementLayout(
                x: x, y: y,
                anchor: "topLeading",
                spacing: 8,
                direction: "vertical"
            )
        )
    }
    
    /// Helper to create label elements quickly
    static func createLabel(
        id: String,
        text: String,
        x: Double = 0,
        y: Double = 0
    ) -> UIElement {
        return UIElement(
            id: id,
            type: .label,
            text: text,
            style: .defaultLabel,
            layout: UIElementLayout(
                x: x, y: y,
                anchor: "topLeading",
                spacing: 4,
                direction: "vertical"
            )
        )
    }
}
