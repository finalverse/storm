//
//  UI/UISchemaView.swift
//  Storm
//
//  SwiftUI view component that renders UI schemas dynamically.
//  Transforms UISchema definitions into interactive SwiftUI views
//  with proper layout, styling, and action handling.
//
//  Created by Wenyan Qin on 2025-07-15.
//

import SwiftUI
import Combine

// MARK: - ElementState

/// Runtime state for individual UI elements (separate from schema definition)
struct ElementState {
    var text: String = ""               // Current display text
    var isEnabled: Bool = true          // Current enabled state
    var isVisible: Bool = true          // Current visibility state
    var sliderValue: Double = 0.0       // Slider control value
    var toggleValue: Bool = false       // Toggle control state
    var progressValue: Double = 0.0     // Progress indicator value
}

// MARK: - UISchemaView

/// Main view that renders a complete UI schema with all its elements
struct UISchemaView: View {
    let schema: UISchema                // Schema definition to render
    let uiComposer: UIComposer         // Composer for action handling
    
    @State private var elementStates: [String: ElementState] = [:]  // Runtime state for elements
    
    var body: some View {
        ZStack {
            // Render all top-level elements in the schema
            ForEach(schema.elements) { element in
                if element.isVisible {
                    UIElementView(
                        element: element,
                        uiComposer: uiComposer,
                        elementState: bindingForElement(element.id)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            initializeElementStates()
        }
    }
    
    /// Create a binding for element state management
    private func bindingForElement(_ elementId: String) -> Binding<ElementState> {
        return Binding(
            get: { elementStates[elementId] ?? ElementState() },
            set: { elementStates[elementId] = $0 }
        )
    }
    
    /// Initialize state for all elements in the schema hierarchy
    private func initializeElementStates() {
        for element in schema.elements {
            initializeElementStateRecursive(element)
        }
    }
    
    /// Recursively initialize state for element and its children
    private func initializeElementStateRecursive(_ element: UIElement) {
        if elementStates[element.id] == nil {
            elementStates[element.id] = ElementState(
                text: element.text ?? "",
                isEnabled: element.isEnabled,
                isVisible: element.isVisible
            )
        }
        
        // Initialize children recursively
        if let children = element.children {
            for child in children {
                initializeElementStateRecursive(child)
            }
        }
    }
}

// MARK: - UIElementView

/// Individual UI element renderer that handles different element types
struct UIElementView: View {
    let element: UIElement              // Element definition
    let uiComposer: UIComposer         // Composer for action handling
    @Binding var elementState: ElementState  // Runtime state
    
    var body: some View {
        Group {
            if element.isVisible && elementState.isVisible {
                // Switch on element type to render appropriate view
                switch element.type {
                case .button:
                    ButtonElementView(element: element, uiComposer: uiComposer)
                case .label, .bindLabel, .entityCounter, .healthStatus:
                    LabelElementView(element: element, elementState: elementState)
                case .slider:
                    SliderElementView(element: element, elementState: $elementState)
                case .toggle:
                    ToggleElementView(element: element, elementState: $elementState)
                case .progress:
                    ProgressElementView(element: element, elementState: elementState)
                case .input:
                    InputElementView(element: element, elementState: $elementState)
                case .panel:
                    PanelElementView(element: element, uiComposer: uiComposer)
                case .spacer:
                    SpacerElementView(element: element)
                case .divider:
                    DividerElementView(element: element)
                case .image:
                    ImageElementView(element: element)
                }
            }
        }
        .modifier(UIElementLayoutModifier(layout: element.effectiveLayout))
        .modifier(UIElementStyleModifier(style: element.effectiveStyle))
        .opacity(element.isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - Specific Element Views

/// Button element renderer with action handling
struct ButtonElementView: View {
    let element: UIElement
    let uiComposer: UIComposer
    
    var body: some View {
        Button(action: {
            // Trigger action when button is pressed
            if let action = element.action {
                uiComposer.handleAction(
                    action,
                    context: ["elementId": element.id]
                )
            }
        }) {
            Text(element.text ?? "Button")
                .font(element.effectiveStyle.swiftUIFont)
        }
        .disabled(!element.isEnabled)
    }
}

/// Label element renderer (handles all label types)
struct LabelElementView: View {
    let element: UIElement
    let elementState: ElementState
    
    var body: some View {
        Text(
            elementState.text.isEmpty ? (element.text ?? "") : elementState.text
        )
        .font(element.effectiveStyle.swiftUIFont)
        .foregroundColor(element.effectiveStyle.swiftUIForegroundColor)
    }
}

/// Slider element renderer with value binding
struct SliderElementView: View {
    let element: UIElement
    @Binding var elementState: ElementState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Optional label above slider
            if let text = element.text {
                Text(text)
                    .font(element.effectiveStyle.swiftUIFont)
                    .foregroundColor(element.effectiveStyle.swiftUIForegroundColor)
            }
            
            Slider(value: $elementState.sliderValue, in: 0...1)
                .disabled(!element.isEnabled)
        }
    }
}

/// Toggle element renderer with state binding
struct ToggleElementView: View {
    let element: UIElement
    @Binding var elementState: ElementState
    
    var body: some View {
        Toggle(element.text ?? "Toggle", isOn: $elementState.toggleValue)
            .font(element.effectiveStyle.swiftUIFont)
            .foregroundColor(element.effectiveStyle.swiftUIForegroundColor)
            .disabled(!element.isEnabled)
    }
}

/// Progress bar element renderer
struct ProgressElementView: View {
    let element: UIElement
    let elementState: ElementState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Optional label above progress bar
            if let text = element.text {
                Text(text)
                    .font(element.effectiveStyle.swiftUIFont)
                    .foregroundColor(element.effectiveStyle.swiftUIForegroundColor)
            }
            
            ProgressView(value: elementState.progressValue, total: 1.0)
        }
    }
}

/// Text input element renderer
struct InputElementView: View {
    let element: UIElement
    @Binding var elementState: ElementState
    
    var body: some View {
        TextField(element.text ?? "Input", text: $elementState.text)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .font(element.effectiveStyle.swiftUIFont)
            .disabled(!element.isEnabled)
    }
}

/// Panel container element renderer (recursive for children)
struct PanelElementView: View {
    let element: UIElement
    let uiComposer: UIComposer
    
    var body: some View {
        VStack(spacing: 8) {
            // Render all child elements
            if let children = element.children {
                ForEach(children) { child in
                    UIElementView(
                        element: child,
                        uiComposer: uiComposer,
                        elementState: .constant(ElementState())
                    )
                }
            }
        }
        .padding(element.effectiveStyle.swiftUIPadding)
        .background(
            RoundedRectangle(cornerRadius: element.effectiveStyle.swiftUICornerRadius)
                .fill(element.effectiveStyle.swiftUIBackgroundColor)
                .opacity(element.effectiveStyle.swiftUIOpacity)
        )
    }
}

/// Spacer element renderer
struct SpacerElementView: View {
    let element: UIElement
    
    var body: some View {
        Spacer()
            .frame(
                width: element.effectiveStyle.swiftUIWidth,
                height: element.effectiveStyle.swiftUIHeight
            )
    }
}

/// Divider element renderer
struct DividerElementView: View {
    let element: UIElement
    
    var body: some View {
        Divider()
            .background(element.effectiveStyle.swiftUIForegroundColor)
    }
}

/// Image element renderer (uses SF Symbols)
struct ImageElementView: View {
    let element: UIElement
    
    var body: some View {
        if let imageName = element.text {
            Image(systemName: imageName)
                .font(element.effectiveStyle.swiftUIFont)
                .foregroundColor(element.effectiveStyle.swiftUIForegroundColor)
        } else {
            Image(systemName: "photo")
                .font(element.effectiveStyle.swiftUIFont)
                .foregroundColor(element.effectiveStyle.swiftUIForegroundColor)
        }
    }
}

// MARK: - Layout & Style Modifiers

/// Layout modifier that applies positioning and alignment
struct UIElementLayoutModifier: ViewModifier {
    let layout: UIElementLayout
    
    func body(content: Content) -> some View {
        content
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: swiftUIAlignment
            )
            .offset(x: CGFloat(layout.x ?? 0), y: CGFloat(layout.y ?? 0))
    }
    
    /// Convert layout anchor string to SwiftUI Alignment
    private var swiftUIAlignment: Alignment {
        switch layout.anchor ?? "topLeading" {
        case "topLeading": return .topLeading
        case "top": return .top
        case "topTrailing": return .topTrailing
        case "leading": return .leading
        case "center": return .center
        case "trailing": return .trailing
        case "bottomLeading": return .bottomLeading
        case "bottom": return .bottom
        case "bottomTrailing": return .bottomTrailing
        default: return .topLeading
        }
    }
}

/// Style modifier that applies visual styling
struct UIElementStyleModifier: ViewModifier {
    let style: UIElementStyle
    
    func body(content: Content) -> some View {
        content
            .font(style.swiftUIFont)
            .foregroundColor(style.swiftUIForegroundColor)
            .padding(style.swiftUIPadding)
            .frame(
                width: style.swiftUIWidth,
                height: style.swiftUIHeight
            )
            .background(
                RoundedRectangle(cornerRadius: style.swiftUICornerRadius)
                    .fill(style.swiftUIBackgroundColor)
            )
            .opacity(style.swiftUIOpacity)
    }
}

// MARK: - Composite UI Views

/// HUD overlay view that displays all HUD elements from UIComposer
struct HUDOverlayView: View {
    @ObservedObject var uiComposer: UIComposer
    
    var body: some View {
        ZStack {
            ForEach(uiComposer.hudElements) { element in
                UIElementView(
                    element: element,
                    uiComposer: uiComposer,
                    elementState: .constant(ElementState())
                )
            }
        }
        .allowsHitTesting(true)
    }
}

/// Debug panel view that shows debug elements when enabled
struct DebugPanelView: View {
    @ObservedObject var uiComposer: UIComposer
    
    var body: some View {
        if uiComposer.isDebugVisible {
            ZStack {
                ForEach(uiComposer.debugElements) { element in
                    UIElementView(
                        element: element,
                        uiComposer: uiComposer,
                        elementState: .constant(ElementState())
                    )
                }
            }
            .transition(.opacity.combined(with: .scale))
        }
    }
}

/// Schema list view for debugging and management
struct SchemaListView: View {
    @ObservedObject var uiComposer: UIComposer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UI Schemas")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(uiComposer.getSchemaNames(), id: \.self) { schemaName in
                HStack {
                    Text(schemaName)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(
                        uiComposer.getActiveSchemaNames().contains(schemaName)
                            ? "Active" : "Inactive"
                    ) {
                        uiComposer.toggleSchema(schemaName)
                    }
                    .foregroundColor(
                        uiComposer.getActiveSchemaNames().contains(schemaName)
                            ? .green : .gray
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
        )
    }
}

// MARK: - Error Handling Views

/// Error view for displaying schema validation errors
struct UISchemaErrorView: View {
    let error: UISchemaError
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text("UI Schema Error")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Dismiss") {
                // Handle error dismissal - implementation depends on usage context
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.9))
                .stroke(Color.red, lineWidth: 2)
        )
    }
}

// MARK: - Performance Optimizations

/// Lazy loading version of UISchemaView for large schemas
struct LazyUISchemaView: View {
    let schema: UISchema
    let uiComposer: UIComposer
    @State private var visibleElements: Set<String> = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(schema.elements) { element in
                    if visibleElements.contains(element.id) {
                        UIElementView(
                            element: element,
                            uiComposer: uiComposer,
                            elementState: .constant(ElementState())
                        )
                    }
                }
            }
            .onAppear {
                updateVisibleElements(in: geometry.frame(in: .local))
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIDevice.orientationDidChangeNotification
                )
            ) { _ in
                updateVisibleElements(in: geometry.frame(in: .local))
            }
        }
    }
    
    /// Update which elements should be visible based on viewport
    private func updateVisibleElements(in frame: CGRect) {
        // Simplified implementation - could be enhanced with actual bounds checking
        visibleElements = Set(
            schema.elements.filter { $0.isVisible }.map { $0.id }
        )
    }
}

// MARK: - Platform-Specific Extensions

#if os(iOS)
extension UISchemaView {
    /// iOS-specific touch handling for UI elements
    func handleTouch(at location: CGPoint, element: UIElement) {
        if element.isInteractive && element.isEnabled {
            // Provide haptic feedback for interactive elements
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Handle the action
            if let action = element.action {
                uiComposer.handleAction(
                    action,
                    context: [
                        "elementId": element.id,
                        "touchLocation": location
                    ]
                )
            }
        }
    }
}
#endif

#if os(macOS)
extension UISchemaView {
    /// macOS-specific mouse handling for UI elements
    func handleMouseClick(at location: CGPoint, element: UIElement) {
        if element.isInteractive && element.isEnabled {
            if let action = element.action {
                uiComposer.handleAction(
                    action,
                    context: [
                        "elementId": element.id,
                        "mouseLocation": location
                    ]
                )
            }
        }
    }
}
#endif

// MARK: - Accessibility Support

extension UIElementView {
    /// Add accessibility information to element views
    func accessibilityElement() -> some View {
        self
            .accessibilityLabel(element.text ?? element.id)
            .accessibilityHint(
                element.action != nil ? "Performs action \(element.action!)" : ""
            )
            .accessibilityAddTraits(
                element.isInteractive ? .isButton : .isStaticText
            )
            .accessibilityRemoveTraits(element.isEnabled ? [] : .isButton)
    }
}

// MARK: - Animation Support

/// Animation modifier for interactive elements
struct UIElementAnimationModifier: ViewModifier {
    let element: UIElement
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isAnimating)
            .onTapGesture {
                if element.isInteractive {
                    withAnimation {
                        isAnimating = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            isAnimating = false
                        }
                    }
                }
            }
    }
}

// MARK: - Utility Extensions

extension UIElement {
    /// Calculate the effective frame for this element based on its layout and style
    func effectiveFrame(in containerSize: CGSize) -> CGRect {
        let layout = self.effectiveLayout
        let style = self.effectiveStyle
        let width = style.swiftUIWidth ?? 100
        let height = style.swiftUIHeight ?? 44
        
        let x = layout.x ?? 0
        let y = layout.y ?? 0
        
        // Adjust position based on anchor
        var adjustedX = x
        var adjustedY = y
        
        switch layout.anchor ?? "topLeading" {
        case "topTrailing":
            adjustedX = containerSize.width + x - width
        case "bottomLeading":
            adjustedY = containerSize.height + y - height
        case "bottomTrailing":
            adjustedX = containerSize.width + x - width
            adjustedY = containerSize.height + y - height
        case "center":
            adjustedX = (containerSize.width / 2) + x - (width / 2)
            adjustedY = (containerSize.height / 2) + y - (height / 2)
        default:
            break
        }
        
        return CGRect(x: adjustedX, y: adjustedY, width: width, height: height)
    }
}

// MARK: - Preview Helpers

#if DEBUG
struct UISchemaView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSchema = UISchema(
            id: "preview_schema",
            name: "Preview Schema",
            description: "Sample schema for preview",
            elements: [
                UIElement(
                    id: "sample_label",
                    type: .label,
                    text: "Sample Label",
                    style: .defaultLabel,
                    layout: .topLeading
                ),
                UIElement(
                    id: "sample_button",
                    type: .button,
                    text: "Sample Button",
                    action: "sample_action",
                    style: .defaultButton,
                    layout: UIElementLayout(
                        x: 20, y: 60,
                        anchor: "topLeading",
                        spacing: 8,
                        direction: "vertical"
                    )
                )
            ]
        )
        
        let sampleUIComposer = UIComposer()
        
        UISchemaView(schema: sampleSchema, uiComposer: sampleUIComposer)
            .frame(width: 400, height: 300)
            .background(Color.black)
            .previewDisplayName("UI Schema Preview")
    }
}

struct HUDOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        let uiComposer = UIComposer()
        
        ZStack {
            Color.black.ignoresSafeArea()
            HUDOverlayView(uiComposer: uiComposer)
        }
        .previewDisplayName("HUD Overlay")
    }
}

struct DebugPanelView_Previews: PreviewProvider {
    static var previews: some View {
        let uiComposer = UIComposer()
        uiComposer.isDebugVisible = true
        uiComposer.activateSchema("debug_panel")
        
        ZStack {
            Color.black.ignoresSafeArea()
            DebugPanelView(uiComposer: uiComposer)
        }
        .previewDisplayName("Debug Panel")
    }
}
#endif
