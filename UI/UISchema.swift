//
//  UI/UISchema.swift
//  Storm
//
//  UI Schema definitions and validation for dynamic UI composition.
//  Provides type-safe structure definitions for UI elements and schemas
//  used by UIComposer for runtime UI generation.
//
//  Created by Wenyan Qin on 2025-07-15.
//

import Foundation
import SwiftUI

// MARK: - UISchemaError

/// Comprehensive error types for UI schema validation and processing
enum UISchemaError: Error, LocalizedError {
    case invalidJSON                    // JSON parsing failed
    case missingRequiredField(String)   // Required field missing from schema
    case invalidElementType(String)     // Unsupported element type specified
    case cyclicDependency              // Circular reference in element hierarchy
    case invalidColor(String)          // Invalid color format (hex or named)
    case invalidLayout                 // Invalid layout configuration
    case invalidSchema(String)         // General schema validation failure
    case duplicateElementID(String)    // Duplicate element IDs found
    
    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Invalid JSON format in UI schema"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .invalidElementType(let type):
            return "Invalid UI element type: \(type)"
        case .cyclicDependency:
            return "Cyclic dependency detected in UI schema"
        case .invalidColor(let color):
            return "Invalid color format: \(color)"
        case .invalidLayout:
            return "Invalid layout configuration"
        case .invalidSchema(let reason):
            return "Invalid schema: \(reason)"
        case .duplicateElementID(let id):
            return "Duplicate element ID found: \(id)"
        }
    }
}

// MARK: - UISchemaValidator

/// Comprehensive validation system for UI schemas before loading
struct UISchemaValidator {
    
    /// Validate a complete UI schema for correctness and safety
    static func validate(_ schema: UISchema) -> Result<Void, UISchemaError> {
        // Validate basic schema structure requirements
        if schema.id.isEmpty {
            return .failure(.missingRequiredField("id"))
        }
        
        if schema.name.isEmpty {
            return .failure(.missingRequiredField("name"))
        }
        
        // Validate version format (semantic versioning)
        if !isValidVersion(schema.version) {
            return .failure(.invalidSchema("Invalid version format: \(schema.version)"))
        }
        
        // Track element IDs to detect duplicates across hierarchy
        var elementIDs: Set<String> = []
        
        // Validate each element and its children recursively
        for element in schema.elements {
            if let error = validateElement(element, collectedIDs: &elementIDs) {
                return .failure(error)
            }
        }
        
        // Check for circular references in element hierarchy
        if hasCyclicDependencies(schema.elements) {
            return .failure(.cyclicDependency)
        }
        
        return .success(())
    }
    
    /// Validate individual element and recursively check children
    private static func validateElement(_ element: UIElement, collectedIDs: inout Set<String>) -> UISchemaError? {
        // Ensure unique element IDs across entire schema
        if collectedIDs.contains(element.id) {
            return .duplicateElementID(element.id)
        }
        collectedIDs.insert(element.id)
        
        // Validate element ID is not empty
        if element.id.isEmpty {
            return .missingRequiredField("element.id")
        }
        
        // Validate element type is supported by the system
        if !UIElementType.allCases.contains(element.type) {
            return .invalidElementType(element.type.rawValue)
        }
        
        // Validate color formats in style if present
        if let style = element.style {
            if let bgColor = style.backgroundColor, !isValidColor(bgColor) {
                return .invalidColor(bgColor)
            }
            if let fgColor = style.foregroundColor, !isValidColor(fgColor) {
                return .invalidColor(fgColor)
            }
        }
        
        // Validate layout configuration if present
        if let layout = element.layout {
            if let anchor = layout.anchor, !isValidAnchor(anchor) {
                return .invalidLayout
            }
            if let direction = layout.direction, !isValidDirection(direction) {
                return .invalidLayout
            }
        }
        
        // Recursively validate all child elements
        if let children = element.children {
            for child in children {
                if let error = validateElement(child, collectedIDs: &collectedIDs) {
                    return error
                }
            }
        }
        
        return nil
    }
    
    /// Detect circular references in element hierarchy using DFS
    private static func hasCyclicDependencies(_ elements: [UIElement]) -> Bool {
        var visited: Set<String> = []
        var recursionStack: Set<String> = []
        
        // Depth-first search to detect cycles
        func hasCircularReference(_ element: UIElement) -> Bool {
            // If element is in current recursion path, we have a cycle
            if recursionStack.contains(element.id) {
                return true
            }
            
            // If already visited and not in recursion stack, no cycle here
            if visited.contains(element.id) {
                return false
            }
            
            // Mark as visited and add to recursion stack
            visited.insert(element.id)
            recursionStack.insert(element.id)
            
            // Check all children for cycles
            if let children = element.children {
                for child in children {
                    if hasCircularReference(child) {
                        return true
                    }
                }
            }
            
            // Remove from recursion stack when done with this branch
            recursionStack.remove(element.id)
            return false
        }
        
        // Check each top-level element for cycles
        for element in elements {
            if hasCircularReference(element) {
                return true
            }
        }
        
        return false
    }
    
    /// Validate semantic version format (x.y.z)
    private static func isValidVersion(_ version: String) -> Bool {
        let versionRegex = #"^\d+\.\d+\.\d+$"#
        return version.range(of: versionRegex, options: .regularExpression) != nil
    }
    
    /// Validate color format (hex or named colors)
    private static func isValidColor(_ color: String) -> Bool {
        // Support hex colors (#RRGGBB or #RGB format)
        if color.hasPrefix("#") {
            let hex = String(color.dropFirst())
            return hex.count == 6 || hex.count == 3
        }
        
        // Support common CSS/SwiftUI color names
        let validColorNames = [
            "black", "white", "red", "green", "blue", "yellow", "orange", "purple",
            "pink", "brown", "gray", "grey", "cyan", "magenta", "clear"
        ]
        return validColorNames.contains(color.lowercased())
    }
    
    /// Validate layout anchor position
    private static func isValidAnchor(_ anchor: String) -> Bool {
        let validAnchors = [
            "topLeading", "top", "topTrailing",
            "leading", "center", "trailing",
            "bottomLeading", "bottom", "bottomTrailing"
        ]
        return validAnchors.contains(anchor)
    }
    
    /// Validate layout direction
    private static func isValidDirection(_ direction: String) -> Bool {
        return direction == "horizontal" || direction == "vertical"
    }
}

// MARK: - UISchema Extensions

extension UISchema {
    
    /// Find an element by ID within this schema (searches recursively)
    func findElement(byId id: String) -> UIElement? {
        return findElementRecursive(id: id, in: elements)
    }
    
    /// Recursive helper to search element hierarchy
    private func findElementRecursive(id: String, in elements: [UIElement]) -> UIElement? {
        for element in elements {
            // Check if this element matches
            if element.id == id {
                return element
            }
            
            // Search in children if present
            if let children = element.children,
               let found = findElementRecursive(id: id, in: children) {
                return found
            }
        }
        return nil
    }
    
    /// Get all elements of a specific type (searches recursively)
    func getElements(ofType type: UIElementType) -> [UIElement] {
        return getElementsRecursive(ofType: type, in: elements)
    }
    
    /// Recursive helper to collect elements by type
    private func getElementsRecursive(ofType type: UIElementType, in elements: [UIElement]) -> [UIElement] {
        var result: [UIElement] = []
        
        for element in elements {
            // Add element if type matches
            if element.type == type {
                result.append(element)
            }
            
            // Search children if present
            if let children = element.children {
                result.append(contentsOf: getElementsRecursive(ofType: type, in: children))
            }
        }
        
        return result
    }
    
    /// Create new schema with updated element text by ID
    func updatingElementText(id: String, newText: String) -> UISchema? {
        // Verify element exists before creating new schema
        guard let _ = findElement(byId: id) else { return nil }
        
        let updatedElements = updateElementRecursive(id: id, newText: newText, in: elements)
        
        return UISchema(
            id: self.id,
            name: self.name,
            description: self.description,
            version: self.version,
            elements: updatedElements,
            isActive: self.isActive
        )
    }
    
    /// Recursive helper to update element text in hierarchy
    private func updateElementRecursive(id: String, newText: String, in elements: [UIElement]) -> [UIElement] {
        return elements.map { element in
            if element.id == id {
                // Create updated element with new text
                return UIElement(
                    id: element.id,
                    type: element.type,
                    text: newText,
                    action: element.action,
                    style: element.style,
                    layout: element.layout,
                    children: element.children,
                    isVisible: element.isVisible,
                    isEnabled: element.isEnabled
                )
            } else if let children = element.children {
                // Recursively update children
                let updatedChildren = updateElementRecursive(id: id, newText: newText, in: children)
                return UIElement(
                    id: element.id,
                    type: element.type,
                    text: element.text,
                    action: element.action,
                    style: element.style,
                    layout: element.layout,
                    children: updatedChildren,
                    isVisible: element.isVisible,
                    isEnabled: element.isEnabled
                )
            } else {
                // Return unchanged element
                return element
            }
        }
    }
    
    /// Create new schema with updated element visibility by ID
    func updatingElementVisibility(id: String, isVisible: Bool) -> UISchema? {
        let updatedElements = updateElementVisibilityRecursive(id: id, isVisible: isVisible, in: elements)
        
        return UISchema(
            id: self.id,
            name: self.name,
            description: self.description,
            version: self.version,
            elements: updatedElements,
            isActive: self.isActive
        )
    }
    
    /// Recursive helper to update element visibility in hierarchy
    private func updateElementVisibilityRecursive(id: String, isVisible: Bool, in elements: [UIElement]) -> [UIElement] {
        return elements.map { element in
            if element.id == id {
                // Create updated element with new visibility
                return UIElement(
                    id: element.id,
                    type: element.type,
                    text: element.text,
                    action: element.action,
                    style: element.style,
                    layout: element.layout,
                    children: element.children,
                    isVisible: isVisible,
                    isEnabled: element.isEnabled
                )
            } else if let children = element.children {
                // Recursively update children
                let updatedChildren = updateElementVisibilityRecursive(id: id, isVisible: isVisible, in: children)
                return UIElement(
                    id: element.id,
                    type: element.type,
                    text: element.text,
                    action: element.action,
                    style: element.style,
                    layout: element.layout,
                    children: updatedChildren,
                    isVisible: element.isVisible,
                    isEnabled: element.isEnabled
                )
            } else {
                // Return unchanged element
                return element
            }
        }
    }
    
    /// Get all element IDs in this schema (flattened hierarchy)
    func getAllElementIDs() -> [String] {
        return collectElementIDsRecursive(in: elements)
    }
    
    /// Recursive helper to collect all element IDs
    private func collectElementIDsRecursive(in elements: [UIElement]) -> [String] {
        var ids: [String] = []
        
        for element in elements {
            // Add this element's ID
            ids.append(element.id)
            
            // Add children IDs if present
            if let children = element.children {
                ids.append(contentsOf: collectElementIDsRecursive(in: children))
            }
        }
        
        return ids
    }
    
    /// Create a copy of this schema with new elements
    func withElements(_ newElements: [UIElement]) -> UISchema {
        return UISchema(
            id: self.id,
            name: self.name,
            description: self.description,
            version: self.version,
            elements: newElements,
            isActive: self.isActive
        )
    }
    
    /// Create a copy of this schema with updated activation state
    func withActiveState(_ isActive: Bool) -> UISchema {
        return UISchema(
            id: self.id,
            name: self.name,
            description: self.description,
            version: self.version,
            elements: self.elements,
            isActive: isActive
        )
    }
}

// MARK: - UIElement Extensions

extension UIElement {
    
    /// Check if this element has child elements
    var hasChildren: Bool {
        return children?.isEmpty == false
    }
    
    /// Get total number of child elements (recursive count)
    var totalChildCount: Int {
        guard let children = children else { return 0 }
        return children.count + children.reduce(0) { $0 + $1.totalChildCount }
    }
    
    /// Check if this element is a container type (can hold children)
    var isContainer: Bool {
        return type == .panel
    }
    
    /// Check if this element is interactive (responds to user input)
    var isInteractive: Bool {
        return type == .button || type == .slider || type == .toggle || action != nil
    }
    
    /// Get effective style with defaults applied for missing values
    var effectiveStyle: UIElementStyle {
        return style ?? {
            switch type {
            case .button:
                return .defaultButton
            case .label, .bindLabel, .entityCounter, .healthStatus:
                return .defaultLabel
            case .panel:
                return .defaultPanel
            default:
                return .defaultLabel
            }
        }()
    }
    
    /// Get effective layout with defaults applied for missing values
    var effectiveLayout: UIElementLayout {
        return layout ?? .topLeading
    }
    
    /// Create a copy with updated text content
    func withText(_ newText: String?) -> UIElement {
        return UIElement(
            id: self.id,
            type: self.type,
            text: newText,
            action: self.action,
            style: self.style,
            layout: self.layout,
            children: self.children,
            isVisible: self.isVisible,
            isEnabled: self.isEnabled
        )
    }
    
    /// Create a copy with updated visibility state
    func withVisibility(_ isVisible: Bool) -> UIElement {
        return UIElement(
            id: self.id,
            type: self.type,
            text: self.text,
            action: self.action,
            style: self.style,
            layout: self.layout,
            children: self.children,
            isVisible: isVisible,
            isEnabled: self.isEnabled
        )
    }
    
    /// Create a copy with updated enabled state
    func withEnabledState(_ isEnabled: Bool) -> UIElement {
        return UIElement(
            id: self.id,
            type: self.type,
            text: self.text,
            action: self.action,
            style: self.style,
            layout: self.layout,
            children: self.children,
            isVisible: self.isVisible,
            isEnabled: isEnabled
        )
    }
    
    /// Create a copy with updated style
    func withStyle(_ newStyle: UIElementStyle) -> UIElement {
        return UIElement(
            id: self.id,
            type: self.type,
            text: self.text,
            action: self.action,
            style: newStyle,
            layout: self.layout,
            children: self.children,
            isVisible: self.isVisible,
            isEnabled: self.isEnabled
        )
    }
}

// MARK: - UIElementStyle Extensions

extension UIElementStyle {
    
    /// Convert color string to SwiftUI Color object
    func swiftUIColor(from colorString: String?) -> Color {
        guard let colorString = colorString else { return .primary }
        
        // Handle hex color format (#RRGGBB or #RGB)
        if colorString.hasPrefix("#") {
            return Color(hex: colorString) ?? .primary
        }
        
        // Handle named color strings
        switch colorString.lowercased() {
        case "black": return .black
        case "white": return .white
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "brown": return .brown
        case "gray", "grey": return .gray
        case "cyan": return .cyan
        case "clear": return .clear
        default: return .primary
        }
    }
    
    /// Get SwiftUI background color
    var swiftUIBackgroundColor: Color {
        return swiftUIColor(from: backgroundColor)
    }
    
    /// Get SwiftUI foreground color
    var swiftUIForegroundColor: Color {
        return swiftUIColor(from: foregroundColor)
    }
    
    /// Get SwiftUI font with proper size
    var swiftUIFont: Font {
        let size = fontSize ?? 14
        return .system(size: size)
    }
    
    /// Get SwiftUI corner radius as CGFloat
    var swiftUICornerRadius: CGFloat {
        return CGFloat(cornerRadius ?? 0)
    }
    
    /// Get SwiftUI padding as CGFloat
    var swiftUIPadding: CGFloat {
        return CGFloat(padding ?? 8)
    }
    
    /// Get SwiftUI opacity value
    var swiftUIOpacity: Double {
        return opacity ?? 1.0
    }
    
    /// Get SwiftUI frame width (optional)
    var swiftUIWidth: CGFloat? {
        guard let width = width else { return nil }
        return CGFloat(width)
    }
    
    /// Get SwiftUI frame height (optional)
    var swiftUIHeight: CGFloat? {
        guard let height = height else { return nil }
        return CGFloat(height)
    }
}

// MARK: - Color Extension for Hex Support

extension Color {
    /// Initialize Color from hex string (#RGB, #RRGGBB, or #AARRGGBB)
    init?(hex: String) {
        // Clean hex string (remove # and non-alphanumeric characters)
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit) - expand to 24-bit
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit) - default alpha to full opacity
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit) - full color with alpha
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil // Invalid hex format
        }
        
        // Initialize SwiftUI Color with normalized values
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Platform Compatibility Extensions

extension UISchema {
    /// Check if this schema is compatible with the current platform
    var isCompatibleWithCurrentPlatform: Bool {
        #if os(iOS)
        return true // iOS supports all element types
        #elseif os(macOS)
        return true // macOS supports all element types
        #elseif os(visionOS)
        // visionOS might have specific limitations for certain element types
        return !elements.contains { $0.type == .input } // Example: no text input in spatial UI
        #else
        return false // Unknown platform
        #endif
    }
    
    /// Get platform-specific adjustments for this schema
    func platformAdjustedSchema() -> UISchema {
        #if os(iOS)
        // iOS-specific adjustments (larger touch targets for mobile)
        let adjustedElements = elements.map { element in
            var style = element.effectiveStyle
            if element.type == .button {
                // Ensure minimum touch target size per iOS HIG
                style = UIElementStyle(
                    backgroundColor: style.backgroundColor,
                    foregroundColor: style.foregroundColor,
                    fontSize: style.fontSize,
                    padding: max(style.padding ?? 8, 12), // Minimum touch padding
                    cornerRadius: style.cornerRadius,
                    opacity: style.opacity,
                    width: style.width,
                    height: max(style.height ?? 44, 44) // iOS minimum touch height
                )
            }
            return element.withStyle(style)
        }
        return withElements(adjustedElements)
        #else
        return self // No adjustments needed for other platforms
        #endif
    }
}
