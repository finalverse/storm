//
//  UI/OpenSimLoginView.swift
//  Storm
//
//  OpenSim login interface that integrates with Storm's UISchema system and OSConnectManager
//  Provides server connection, avatar selection, and world entry UI components
//  Follows Storm's dynamic UI pattern with UIComposer integration
//
//  Created for Finalverse Storm - OpenSim Login UI Integration
//
//    This provides a comprehensive login UI that:
//
//    Integrates with your existing architecture - Uses SystemRegistry and UIScriptRouter
//    Manages connection lifecycle - Connect → Login → Avatar Control
//    Provides server information display - Shows connection stats and server details
//    Includes avatar control - Quick teleport to common locations
//    Supports UISchema integration - Can be dynamically loaded through UIComposer
//    Handles credential persistence - Saves/loads login info
//    Provides debugging tools - Advanced settings for testing
//

import SwiftUI
import Combine

// MARK: - Login View Model

@MainActor
class OpenSimLoginViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var serverHostname: String = "127.0.0.1"
    @Published var serverPort: String = "9000"
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var password: String = ""
    
    @Published var loginState: OpenSimLoginState = .disconnected
    @Published var connectionStatus: String = "Not Connected"
    @Published var isConnecting: Bool = false
    @Published var errorMessage: String?
    @Published var serverInfo: OpenSimServerInfo?
    
    @Published var showAdvancedSettings: Bool = false
    @Published var autoConnect: Bool = true
    @Published var rememberCredentials: Bool = false
    
    // MARK: - Service References
    private var runtime: StormRuntime?
    private var openSimPlugin: OpenSimPlugin?
    private var connectManager: OSConnectManager?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(runtime: StormRuntime) {
        self.runtime = runtime
        setupServiceReferences()
        setupObservers()
        loadSavedCredentials()
    }
    
    private func setupServiceReferences() {
        // Get OpenSim plugin from system registry
        if let registry = runtime?.registry {
            openSimPlugin = registry.resolve("openSimPlugin")
            connectManager = registry.resolve("openSimConnection")
        }
        
        if openSimPlugin == nil {
            print("[⚠️] OpenSim plugin not available - some features disabled")
        }
    }
    
    private func setupObservers() {
        // Monitor connection state changes
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateConnectionStatus()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Connection Management
    
    func connectToServer() {
        guard !serverHostname.isEmpty,
              let port = UInt16(serverPort) else {
            showError("Invalid server settings")
            return
        }
        
        isConnecting = true
        errorMessage = nil
        connectionStatus = "Connecting..."
        
        // Connect through OpenSim plugin
        openSimPlugin?.connectToServer(hostname: serverHostname, port: port)
        
        // Also send UI command through router
        runtime?.executeCommand("opensim.connect.\(serverHostname).\(serverPort)")
    }
    
    func disconnectFromServer() {
        openSimPlugin?.disconnectFromServer()
        runtime?.executeCommand("opensim.disconnect")
        
        loginState = .disconnected
        connectionStatus = "Disconnected"
        isConnecting = false
        serverInfo = nil
    }
    
    func performLogin() {
        guard !firstName.isEmpty && !lastName.isEmpty else {
            showError("First name and last name are required")
            return
        }
        
        guard loginState == .connected else {
            showError("Must be connected to server before logging in")
            return
        }
        
        connectionStatus = "Logging in..."
        
        // Perform login through plugin
        openSimPlugin?.performLogin(firstName: firstName, lastName: lastName, password: password)
        
        // Also send UI command
        runtime?.executeCommand("opensim.login.\(firstName).\(lastName).\(password)")
        
        // Save credentials if requested
        if rememberCredentials {
            saveCredentials()
        }
    }
    
    // MARK: - Avatar Control
    
    func teleportToLocation(_ location: SIMD3<Float>) {
        guard openSimPlugin?.isReadyForAvatarControl() == true else {
            showError("Not ready for avatar control")
            return
        }
        
        openSimPlugin?.teleportAvatar(to: location)
        connectionStatus = "Teleporting to \(location)..."
    }
    
    func teleportToLandmark(_ landmarkName: String) {
        // Predefined landmark locations
        let landmarks: [String: SIMD3<Float>] = [
            "spawn": SIMD3<Float>(128, 25, 128),
            "center": SIMD3<Float>(128, 25, 128),
            "sandbox": SIMD3<Float>(200, 25, 200),
            "welcome": SIMD3<Float>(100, 25, 100)
        ]
        
        if let location = landmarks[landmarkName.lowercased()] {
            teleportToLocation(location)
        } else {
            showError("Unknown landmark: \(landmarkName)")
        }
    }
    
    // MARK: - Server Information
    
    func requestServerInfo() {
        openSimPlugin?.requestServerInformation()
        runtime?.executeCommand("opensim.info")
        
        // Update local server info
        serverInfo = openSimPlugin?.getServerInfo()
    }
    
    // MARK: - State Management
    
    private func updateConnectionStatus() {
        guard let plugin = openSimPlugin else { return }
        
        let currentState = plugin.getConnectionStatus()
        let currentInfo = plugin.getServerInfo()
        
        if loginState != currentState {
            loginState = currentState
            
            switch currentState {
            case .disconnected:
                connectionStatus = "Disconnected"
                isConnecting = false
                serverInfo = nil
                
            case .connecting:
                connectionStatus = "Connecting..."
                isConnecting = true
                
            case .connected:
                connectionStatus = "Connected - Ready for login"
                isConnecting = false
                
            case .authenticating:
                connectionStatus = "Authenticating..."
                
            case .loggedIn:
                connectionStatus = "Logged in successfully"
                isConnecting = false
                requestServerInfo() // Auto-request server info after login
            }
        }
        
        if serverInfo != currentInfo {
            serverInfo = currentInfo
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        print("[❌] Login Error: \(message)")
        
        // Clear error after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.errorMessage == message {
                self.errorMessage = nil
            }
        }
    }
    
    // MARK: - Credentials Management
    
    private func saveCredentials() {
        UserDefaults.standard.set(serverHostname, forKey: "OpenSim.ServerHostname")
        UserDefaults.standard.set(serverPort, forKey: "OpenSim.ServerPort")
        UserDefaults.standard.set(firstName, forKey: "OpenSim.FirstName")
        UserDefaults.standard.set(lastName, forKey: "OpenSim.LastName")
        UserDefaults.standard.set(rememberCredentials, forKey: "OpenSim.RememberCredentials")
        
        print("[💾] Credentials saved")
    }
    
    private func loadSavedCredentials() {
        if UserDefaults.standard.bool(forKey: "OpenSim.RememberCredentials") {
            serverHostname = UserDefaults.standard.string(forKey: "OpenSim.ServerHostname") ?? "127.0.0.1"
            serverPort = UserDefaults.standard.string(forKey: "OpenSim.ServerPort") ?? "9000"
            firstName = UserDefaults.standard.string(forKey: "OpenSim.FirstName") ?? ""
            lastName = UserDefaults.standard.string(forKey: "OpenSim.LastName") ?? ""
            rememberCredentials = true
            
            print("[📂] Credentials loaded")
            
            // Auto-connect if enabled
            if autoConnect && !firstName.isEmpty && !lastName.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.connectToServer()
                }
            }
        }
    }
    
    // MARK: - Validation
    
    var canConnect: Bool {
        return !serverHostname.isEmpty && !serverPort.isEmpty && !isConnecting
    }
    
    var canLogin: Bool {
        return loginState == .connected && !firstName.isEmpty && !lastName.isEmpty && !isConnecting
    }
    
    var isLoggedIn: Bool {
        return loginState == .loggedIn
    }
}

// MARK: - Main Login View

struct OpenSimLoginView: View {
    @StateObject private var viewModel: OpenSimLoginViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(runtime: StormRuntime) {
        self._viewModel = StateObject(wrappedValue: OpenSimLoginViewModel(runtime: runtime))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerSection
                
                if viewModel.isLoggedIn {
                    loggedInView
                } else {
                    loginFormView
                }
                
                Spacer()
                
                statusSection
            }
            .padding()
            .navigationTitle("OpenSim Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        viewModel.showAdvancedSettings.toggle()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAdvancedSettings) {
                AdvancedSettingsView(viewModel: viewModel)
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("Finalverse Storm")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("OpenSim Virtual World Client")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var loginFormView: some View {
        VStack(spacing: 15) {
            // Server Connection Section
            GroupBox("Server Connection") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Server:")
                        TextField("hostname", text: $viewModel.serverHostname)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("Port:")
                        TextField("port", text: $viewModel.serverPort)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                    }
                    
                    Button(action: {
                        if viewModel.loginState == .disconnected {
                            viewModel.connectToServer()
                        } else {
                            viewModel.disconnectFromServer()
                        }
                    }) {
                        HStack {
                            if viewModel.isConnecting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(viewModel.loginState == .disconnected ? "Connect" : "Disconnect")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!viewModel.canConnect && viewModel.loginState == .disconnected)
                    .buttonStyle(.borderedProminent)
                }
            }
            
            // Avatar Login Section
            if viewModel.loginState == .connected {
                GroupBox("Avatar Login") {
                    VStack(spacing: 12) {
                        HStack {
                            TextField("First Name", text: $viewModel.firstName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("Last Name", text: $viewModel.lastName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        SecureField("Password (optional)", text: $viewModel.password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Toggle("Remember credentials", isOn: $viewModel.rememberCredentials)
                            .font(.caption)
                        
                        Button("Login") {
                            viewModel.performLogin()
                        }
                        .disabled(!viewModel.canLogin)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
    
    private var loggedInView: some View {
        VStack(spacing: 15) {
            Text("✅ Logged In Successfully!")
                .font(.headline)
                .foregroundColor(.green)
            
            if let serverInfo = viewModel.serverInfo {
                ServerInfoView(serverInfo: serverInfo)
            }
            
            // Avatar Control Section
            GroupBox("Avatar Control") {
                VStack(spacing: 10) {
                    Text("Quick Teleport")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                        teleportButton("Spawn", "spawn")
                        teleportButton("Center", "center")
                        teleportButton("Sandbox", "sandbox")
                        teleportButton("Welcome", "welcome")
                    }
                }
            }
            
            Button("Disconnect") {
                viewModel.disconnectFromServer()
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func teleportButton(_ title: String, _ landmark: String) -> some View {
        Button(title) {
            viewModel.teleportToLandmark(landmark)
        }
        .font(.caption)
        .frame(maxWidth: .infinity)
        .buttonStyle(.bordered)
    }
    
    private var statusSection: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(viewModel.connectionStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(viewModel.loginState.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .cornerRadius(4)
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var statusColor: Color {
        switch viewModel.loginState {
        case .disconnected:
            return .gray
        case .connecting, .authenticating:
            return .orange
        case .connected:
            return .blue
        case .loggedIn:
            return .green
        }
    }
}

// MARK: - Server Info View

struct ServerInfoView: View {
    let serverInfo: OpenSimServerInfo
    
    var body: some View {
        GroupBox("Server Information") {
            VStack(alignment: .leading, spacing: 8) {
                InfoRow("Agent ID", serverInfo.agentID.uuidString.prefix(8) + "...")
                InfoRow("Circuit Code", String(serverInfo.circuitCode))
                InfoRow("Latency", String(format: "%.1f ms", serverInfo.connectionStats.averageLatency))
                InfoRow("Packets Sent", String(serverInfo.connectionStats.packetsSent))
                InfoRow("Packets Received", String(serverInfo.connectionStats.packetsReceived))
            }
            .font(.caption)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
    
    var body: some View {
        HStack {
            Text("\(label):")
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Advanced Settings View

struct AdvancedSettingsView: View {
    @ObservedObject var viewModel: OpenSimLoginViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Connection Settings") {
                    Toggle("Auto-connect on launch", isOn: $viewModel.autoConnect)
                    Toggle("Remember credentials", isOn: $viewModel.rememberCredentials)
                }
                
                Section("Debug") {
                    Button("Request Server Info") {
                        viewModel.requestServerInfo()
                    }
                    
                    Button("Show Connection Status") {
                        viewModel.runtime?.executeCommand("opensim.status")
                    }
                    
                    Button("Test Plugin Integration") {
                        debugPluginIntegration()
                    }
                }
                
                Section("Reset") {
                    Button("Clear Saved Data", role: .destructive) {
                        clearSavedData()
                    }
                }
            }
            .navigationTitle("Advanced Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func debugPluginIntegration() {
        if let connectManager = viewModel.openSimPlugin?.getConnectionManager() {
            connectManager.debugServiceIntegration()
        }
    }
    
    private func clearSavedData() {
        UserDefaults.standard.removeObject(forKey: "OpenSim.ServerHostname")
        UserDefaults.standard.removeObject(forKey: "OpenSim.ServerPort")
        UserDefaults.standard.removeObject(forKey: "OpenSim.FirstName")
        UserDefaults.standard.removeObject(forKey: "OpenSim.LastName")
        UserDefaults.standard.removeObject(forKey: "OpenSim.RememberCredentials")
        
        // Reset form
        viewModel.serverHostname = "127.0.0.1"
        viewModel.serverPort = "9000"
        viewModel.firstName = ""
        viewModel.lastName = ""
        viewModel.rememberCredentials = false
        
        print("[🗑️] Saved data cleared")
    }
}

// MARK: - Integration with UISchema System

extension OpenSimLoginView {
    
    /// Create UISchema definition for dynamic UI integration
    static func createUISchema() -> [String: Any] {
        return [
            "type": "container",
            "id": "opensim_login",
            "title": "OpenSim Login",
            "children": [
                [
                    "type": "input",
                    "id": "server_hostname",
                    "label": "Server Hostname",
                    "placeholder": "127.0.0.1",
                    "action": "opensim.setHostname"
                ],
                [
                    "type": "input",
                    "id": "server_port",
                    "label": "Server Port",
                    "placeholder": "9000",
                    "action": "opensim.setPort"
                ],
                [
                    "type": "button",
                    "id": "connect_button",
                    "label": "Connect",
                    "action": "opensim.connect"
                ],
                [
                    "type": "input",
                    "id": "first_name",
                    "label": "First Name",
                    "action": "opensim.setFirstName"
                ],
                [
                    "type": "input",
                    "id": "last_name",
                    "label": "Last Name",
                    "action": "opensim.setLastName"
                ],
                [
                    "type": "button",
                    "id": "login_button",
                    "label": "Login",
                    "action": "opensim.login"
                ]
            ]
        ]
    }
}

// MARK: - ContentView Integration

extension ContentView {
    
    /// Add OpenSim login button to main interface
    var openSimLoginButton: some View {
        Button("OpenSim Login") {
            showOpenSimLogin = true
        }
        .sheet(isPresented: $showOpenSimLogin) {
            if let runtime = getStormRuntime() {
                OpenSimLoginView(runtime: runtime)
            }
        }
    }
    
    // Add this property to ContentView
    @State private var showOpenSimLogin = false
    
    private func getStormRuntime() -> StormRuntime? {
        // Access your StormRuntime instance
        // This would depend on how you're managing the runtime in your app
        return nil // Replace with actual runtime access
    }
}
