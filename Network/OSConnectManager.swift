//
//  Network/OSConnectManager.swift
//  Storm
//
//  Real UDP OpenSim connection manager with Network framework
//  Handles OpenSim LLUDP protocol connection, authentication, and packet routing
//  FIXED: Reset handshake manager on disconnect to prevent "already in progress" error
//  FIXED: Compilation errors with NWEndpoint.Port and messageRouter.routeMessage
//
//  Created for Finalverse Storm - Fixed Network Implementation

import Foundation
import Network
import Combine
import simd

// MARK: - Connection Status

enum OSConnectionStatus {
    case disconnected
    case connecting
    case connected
    case error(String)
}

// MARK: - Connection Statistics

struct ConnectionStats {
    var packetsReceived: UInt64 = 0
    var packetsSent: UInt64 = 0
    var bytesReceived: UInt64 = 0
    var bytesSent: UInt64 = 0
    var lastPingTime: TimeInterval = 0
    var averageLatency: TimeInterval = 0
}

class OSConnectManager: ObservableObject {
    // MARK: - Published Properties
    @Published var connectionStatus: OSConnectionStatus = .disconnected
    @Published var isConnected: Bool = false
    @Published var latency: Int = 0
    @Published var stats = ConnectionStats()
    
    // MARK: - Network Connection
    private var connection: NWConnection?
    private var endpoint: NWEndpoint?
    private var queue = DispatchQueue(label: "OSConnectManagerQueue", qos: .userInitiated)
    private var receiveQueue = DispatchQueue(label: "OSReceiveQueue", qos: .userInitiated)
    
    // MARK: - OpenSim Session Data
    private var agentID = UUID()
    private var sessionID = UUID()
    private var circuitCode: UInt32 = 0
    private var sequenceNumber: UInt32 = 1
    private var isHandshakeComplete = false
    
    // MARK: - Packet Tracking
    private var pendingAcks: [UInt32: Date] = [:]
    private var receivedPackets: Set<UInt32> = []
    private var lastPingTime: Date?
    
    // MARK: - Timers
    private var heartbeatTimer: Timer?
    private var ackTimer: Timer?
    private var latencyTimer: Timer?
    
    // MARK: - Service Integration
    private var handshakeManager: OpenSimHandshakeManager?
    private var messageRouter: OSMessageRouter!
    private var handshakeHandler: HandshakeMessageHandler!
    
    // System registry reference for service integration
    private weak var systemRegistry: SystemRegistry?
    
    // Bridge handler for ECS integration
    private var ecsBridgeHandler: ECSBridgeMessageHandler?
    
    // MARK: - Initialization
    
    init(systemRegistry: SystemRegistry? = nil) {
        // Generate unique session identifiers for this connection
        agentID = UUID()
        sessionID = UUID()
        circuitCode = UInt32.random(in: 100000...999999)
        
        // Store system registry reference for service integration
        self.systemRegistry = systemRegistry
        
        // Initialize message router for packet dispatching
        messageRouter = OSMessageRouter()
        
        // Setup handshake manager with session data
        handshakeManager = OpenSimHandshakeManager(
            agentID: agentID,
            sessionID: sessionID,
            circuitCode: circuitCode
        )
        
        // Register handshake handler with message router
        handshakeHandler = HandshakeMessageHandler(handshakeManager: handshakeManager!)
        messageRouter.registerHandler(handshakeHandler)
        
        // Register enhanced ECS bridge handler if available
        setupECSBridgeIntegration()
        
        // Register chat handler for communication messages
        let chatHandler = ChatMessageHandler()
        messageRouter.registerHandler(chatHandler)
        
        // Configure router for development debugging
        messageRouter.setDebugMode(true)
        
        print("[🌐] OSConnectManager initialized with AgentID: \(agentID)")
    }
    
    // MARK: - Service Integration Setup

    /// Setup ECS bridge integration if available in system registry
    private func setupECSBridgeIntegration() {
        // Try to get ECS bridge from system registry using type-safe method
        if let systemRegistry = systemRegistry {
            if let ecsBridge = systemRegistry.getOpenSimBridge() {
                // Create and register ECS bridge handler
                ecsBridgeHandler = ECSBridgeMessageHandler(ecsBridge: ecsBridge)
                messageRouter.registerHandler(ecsBridgeHandler!)
                print("[🔗] ECS Bridge handler registered with message router")
            } else {
                print("[ℹ️] ECS Bridge not available during initialization - will register later")
            }
        } else {
            print("[ℹ️] System registry not available - ECS bridge will be registered later")
        }
    }

    /// Register ECS bridge after initialization (for late binding scenarios)
    func registerECSBridge(_ ecsBridge: OpenSimECSBridge) {
        // Remove existing handler if present to avoid duplicates
        if let existingHandler = ecsBridgeHandler {
            messageRouter.unregisterHandler(existingHandler.handlerName)
            print("[🔄] Removed existing ECS bridge handler")
        }
        
        // Register new ECS bridge handler
        ecsBridgeHandler = ECSBridgeMessageHandler(ecsBridge: ecsBridge)
        messageRouter.registerHandler(ecsBridgeHandler!)
        print("[🔗] ECS bridge registered with connection manager")
    }
    
    /// Set system registry reference and integrate with services
    func setSystemRegistry(_ registry: SystemRegistry) {
        systemRegistry = registry
        print("[🔧] Setting system registry reference")
        
        // Try to integrate with available services
        setupECSBridgeIntegration()
        print("[🔧] Enhanced service integration attempted")
    }
    
    /// Validate that all required service dependencies are satisfied
    func validateServiceDependencies() -> Bool {
        let hasMessageRouter = messageRouter != nil
        let hasHandshakeManager = handshakeManager != nil
        let hasHandshakeHandler = handshakeHandler != nil
        
        return hasMessageRouter && hasHandshakeManager && hasHandshakeHandler
    }
    
    /// Integrate with system services (called after system initialization)
    func integrateWithServices() {
        guard let systemRegistry = systemRegistry else {
            print("[⚠️] Cannot integrate services - no system registry available")
            return
        }
        
        // Register ourselves in the system registry if not already registered
        if systemRegistry.resolve("openSimConnection") == nil {
            systemRegistry.register(self, for: "openSimConnection")
            print("[📝] Self-registered in system registry")
        }
        
        // Try to get renderer for enhanced visualization
        if let renderer: RendererService = systemRegistry.resolve("renderer") {
            print("[🎨] Renderer service available for enhanced visualization")
            // Additional renderer integration could go here
        }
        
        // Check for additional service integrations
        logAvailableServices()
    }
    
    /// Log available services for debugging
    private func logAvailableServices() {
        guard let systemRegistry = systemRegistry else { return }
        
        let services = [
            ("ECS", systemRegistry.ecs != nil),
            ("UI", systemRegistry.ui != nil),
            ("Renderer", systemRegistry.resolve("renderer") != nil),
            ("OpenSim Bridge", systemRegistry.getOpenSimBridge() != nil)
        ]
        
        for (name, available) in services {
            print("[🔍] Service \(name): \(available ? "✅" : "❌")")
        }
    }
    
    // MARK: - Connection Management
    
    /// Connect to OpenSim server
    func connect(to hostname: String, port: UInt16) {
        // FIXED: Reset handshake manager before attempting new connection
        resetHandshakeManager()
        
        print("[🔌] Connecting to OpenSim server: \(hostname):\(port)")
        
        // Update connection status
        DispatchQueue.main.async {
            self.connectionStatus = .connecting
            self.isConnected = false
        }
        
        // FIXED: Proper NWEndpoint.Port creation without force unwrap
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            print("[❌] Invalid port number: \(port)")
            DispatchQueue.main.async {
                self.connectionStatus = .error("Invalid port number")
            }
            return
        }
        
        // Create endpoint
        endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(hostname),
            port: nwPort
        )
        
        // Create UDP connection
        connection = NWConnection(to: endpoint!, using: .udp)
        
        // Setup connection state handler
        connection?.stateUpdateHandler = { [weak self] state in
            self?.handleConnectionStateChange(state)
        }
        
        // Start the connection
        connection?.start(queue: queue)
        
        // Reset connection state
        resetConnectionState()
        
        // Start receiving data
        startReceiving()
    }
    
    /// Disconnect from OpenSim server
    func disconnect() {
        print("[🔌] Disconnecting from OpenSim server")
        
        // Send logout request if connected
        if isConnected {
            let logoutMessage = LogoutRequestMessage(agentID: agentID, sessionID: sessionID)
            sendMessage(logoutMessage)
            print("[👋] Logout request sent")
        }
        
        // FIXED: Reset handshake manager on disconnect
        resetHandshakeManager()
        
        // Cancel connection
        connection?.cancel()
        connection = nil
        
        // Stop timers
        stopTimers()
        
        // Update connection status
        DispatchQueue.main.async {
            self.connectionStatus = .disconnected
            self.isConnected = false
            self.latency = 0
        }
        
        // Reset state
        resetConnectionState()
        
        print("[🔌] Connection disconnected")
    }
    
    // MARK: - FIXED: Handshake Manager Reset
    
    /// Reset handshake manager to allow fresh connection attempts
    private func resetHandshakeManager() {
        // Reset the handshake manager state
        handshakeManager?.reset()
        print("[🔄] Handshake manager reset for fresh connection")
        
        // Generate new session identifiers for the new connection
        agentID = UUID()
        sessionID = UUID()
        circuitCode = UInt32.random(in: 100000...999999)
        
        // Create new handshake manager with fresh session data
        handshakeManager = OpenSimHandshakeManager(
            agentID: agentID,
            sessionID: sessionID,
            circuitCode: circuitCode
        )
        
        // Update the handshake handler with the new manager
        handshakeHandler = HandshakeMessageHandler(handshakeManager: handshakeManager!)
        
        // Re-register the handler with the message router
        messageRouter.unregisterHandler("HandshakeHandler")
        messageRouter.registerHandler(handshakeHandler)
        
        print("[🔄] Fresh handshake manager created with new session data")
        print("[🆔] New AgentID: \(agentID)")
        print("[🎫] New CircuitCode: \(circuitCode)")
    }
    
    // MARK: - Connection State Handling
    
    /// Handle network connection state changes
    private func handleConnectionStateChange(_ state: NWConnection.State) {
        DispatchQueue.main.async {
            switch state {
            case .ready:
                print("[✅] UDP connection established")
                self.connectionStatus = .connected
                self.isConnected = true
                self.initiateHandshake()
                self.startTimers()
                
            case .failed(let error):
                print("[❌] Connection failed: \(error)")
                self.connectionStatus = .error(error.localizedDescription)
                self.isConnected = false
                
            case .cancelled:
                print("[🔌] Connection cancelled")
                self.connectionStatus = .disconnected
                self.isConnected = false
                
            case .waiting(let error):
                print("[⏳] Connection waiting: \(error)")
                self.connectionStatus = .connecting
                
            default:
                break
            }
        }
    }
    
    /// Start the OpenSim handshake process
    private func initiateHandshake() {
        guard let handshakeManager = handshakeManager else {
            print("[❌] Cannot initiate handshake: handshake manager not available")
            return
        }
        
        let useCircuitMessage = handshakeManager.startHandshake()
        sendMessage(useCircuitMessage)
        print("[🔑] Sent UseCircuitCode with circuit: \(circuitCode)")
    }
    
    // MARK: - Message Sending
    
    /// Send a message to the OpenSim server
    func sendMessage<T: OpenSimMessage>(_ message: T) {
        guard let connection = connection, isConnected else {
            print("[⚠️] Cannot send message: not connected")
            return
        }
        
        do {
            // Serialize the message
            let messageData = try message.serialize()
            
            // Create packet
            let packet = OpenSimPacket(
                messageType: message.type,
                payload: messageData,
                sequenceNumber: sequenceNumber,
                needsAck: message.needsAck
            )
            
            // Serialize packet
            let packetData = try packet.serialize()
            
            // Send packet
            connection.send(content: packetData, completion: .contentProcessed { error in
                if let error = error {
                    print("[❌] Send error: \(error)")
                } else {
                    // Track packet for ACK if needed
                    if packet.needsAck {
                        self.pendingAcks[self.sequenceNumber] = Date()
                    }
                    
                    // Update statistics
                    self.stats.packetsSent += 1
                    self.stats.bytesSent += UInt64(packetData.count)
                    
                    // Increment sequence number
                    self.sequenceNumber += 1
                }
            })
            
        } catch {
            print("[❌] Failed to send message: \(error)")
        }
    }
    
    // MARK: - Message Receiving
    
    /// Start receiving data from the connection
    private func startReceiving() {
        guard let connection = connection else { return }
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1500) { [weak self] data, context, isComplete, error in
            
            if let error = error {
                print("[❌] Receive error: \(error)")
                return
            }
            
            if let data = data, !data.isEmpty {
                self?.receiveQueue.async {
                    self?.handleReceivedData(data)
                }
            }
            
            // Continue receiving
            if !isComplete {
                self?.startReceiving()
            }
        }
    }
    
    /// Handle received packet data
    private func handleReceivedData(_ data: Data) {
        do {
            // Parse the packet
            let packet = try OpenSimPacket.parse(data)
            
            // Update statistics
            stats.packetsReceived += 1
            stats.bytesReceived += UInt64(data.count)
            
            // Handle ACK packets
            if packet.messageType == .packetAck {
                if let ackNumber = packet.ackNumber {
                    handleAckReceived(ackNumber)
                }
                return
            }
            
            // Check for duplicate packets
            if receivedPackets.contains(packet.sequenceNumber) {
                print("[⚠️] Duplicate packet received: \(packet.sequenceNumber)")
                return
            }
            receivedPackets.insert(packet.sequenceNumber)
            
            // Send ACK if needed
            if packet.needsAck {
                sendAck(for: packet.sequenceNumber)
            }
            
            // FIXED: Route the message through the message router with correct method signature
            messageRouter.routeMessage(packet)
            
        } catch {
            print("[❌] Failed to parse received packet: \(error)")
        }
    }
    
    /// Handle ACK received for sent packet
    private func handleAckReceived(_ ackNumber: UInt32) {
        if let sentTime = pendingAcks.removeValue(forKey: ackNumber) {
            let roundTrip = Date().timeIntervalSince(sentTime) * 1000 // Convert to milliseconds
            
            // Update latency (simple moving average)
            if stats.averageLatency == 0 {
                stats.averageLatency = roundTrip
            } else {
                stats.averageLatency = (stats.averageLatency * 0.8) + (roundTrip * 0.2)
            }
            
            DispatchQueue.main.async {
                self.latency = Int(self.stats.averageLatency)
            }
        }
    }
    
    /// Send ACK for received packet
    private func sendAck(for sequenceNumber: UInt32) {
        guard let connection = connection else { return }
        
        // Create ACK packet
        var ackData = Data()
        ackData.append(ProtocolConstants.ackFlag)
        
        var seqNum = self.sequenceNumber.bigEndian
        ackData.append(Data(bytes: &seqNum, count: 4))
        
        var msgType = MessageType.packetAck.rawValue.bigEndian
        ackData.append(Data(bytes: &msgType, count: 4))
        
        var ackSeqNum = sequenceNumber.bigEndian
        ackData.append(Data(bytes: &ackSeqNum, count: 4))
        
        // Send ACK
        connection.send(content: ackData, completion: .idempotent)
        self.sequenceNumber += 1
    }
    
    // MARK: - Movement and Avatar Control
    
    /// Teleport avatar to specified position
    func teleportAvatar(to position: SIMD3<Float>) {
        guard isHandshakeComplete else {
            print("[⚠️] Cannot teleport: handshake not complete")
            return
        }
        
        let teleportMessage = TeleportLocationRequestMessage(
            agentID: agentID,
            sessionID: sessionID,
            regionHandle: 0, // Default region handle
            position: position,
            lookAt: SIMD3<Float>(1, 0, 0)
        )
        
        sendMessage(teleportMessage)
        print("[🚀] Teleport request sent to position: \(position)")
    }
    
    /// Move avatar with position and rotation
    func moveAvatar(position: SIMD3<Float>, rotation: SIMD2<Float>) {
        guard isHandshakeComplete else {
            print("[⚠️] Cannot move avatar: handshake not complete")
            return
        }
        
        // Create agent update message
        let agentUpdate = AgentUpdateMessage(
            agentID: agentID,
            sessionID: sessionID,
            bodyRotation: simd_quatf(angle: rotation.y, axis: SIMD3<Float>(0, 1, 0)),
            headRotation: simd_quatf(angle: rotation.x, axis: SIMD3<Float>(1, 0, 0)),
            state: 0,
            position: position,
            lookAt: SIMD3<Float>(1, 0, 0),
            upAxis: SIMD3<Float>(0, 1, 0),
            leftAxis: SIMD3<Float>(-1, 0, 0),
            cameraCenter: position,
            cameraAtAxis: SIMD3<Float>(1, 0, 0),
            cameraLeftAxis: SIMD3<Float>(-1, 0, 0),
            cameraUpAxis: SIMD3<Float>(0, 1, 0),
            far: 512.0,
            aspectRatio: 1.33,
            throttles: [255, 255, 255, 255],
            controlFlags: 0,
            flags: 0
        )
        
        sendMessage(agentUpdate)
        print("[🚶] Agent update sent: position \(position), rotation \(rotation)")
    }
    
    // MARK: - Timer Management
    
    /// Start periodic timers for connection maintenance
    private func startTimers() {
        // Heartbeat timer (send pings)
        latencyTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
        
        // ACK timeout timer
        ackTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkAckTimeouts()
        }
    }
    
    /// Stop all periodic timers
    private func stopTimers() {
        heartbeatTimer?.invalidate()
        ackTimer?.invalidate()
        latencyTimer?.invalidate()
        
        heartbeatTimer = nil
        ackTimer = nil
        latencyTimer = nil
    }
    
    /// Send ping message to measure latency
    private func sendPing() {
        guard isConnected else { return }
        
        lastPingTime = Date()
        let message = PingCheckMessage()
        sendMessage(message)
    }
    
    /// Check for packets that haven't been acknowledged within timeout
    private func checkAckTimeouts() {
        let timeout: TimeInterval = 10.0
        let now = Date()
        
        // Remove timed out packets from pending list
        for (seq, time) in pendingAcks {
            if now.timeIntervalSince(time) > timeout {
                pendingAcks.removeValue(forKey: seq)
                print("[⚠️] ACK timeout for packet \(seq)")
            }
        }
    }
    
    // MARK: - State Management
    
    /// Reset all connection state variables
    private func resetConnectionState() {
        isHandshakeComplete = false
        pendingAcks.removeAll()
        receivedPackets.removeAll()
        sequenceNumber = 1
        lastPingTime = nil
        stats = ConnectionStats()
    }
    
    // MARK: - Public Utilities
    
    /// Complete setup after initialization
    func setup() {
        print("[🔧] OSConnectManager setup complete")
    }
    
    /// Get current connection statistics
    func getConnectionStats() -> ConnectionStats {
        return stats
    }
    
    /// Get session information
    func getSessionInfo() -> (agentID: UUID, sessionID: UUID, circuitCode: UInt32) {
        return (agentID: agentID, sessionID: sessionID, circuitCode: circuitCode)
    }
    
    /// Debug method to check service integration status
    func debugServiceIntegration() {
        print("=== OSConnectManager Service Integration Debug ===")
        print("System Registry: \(systemRegistry != nil ? "✅" : "❌")")
        print("Message Router: \(messageRouter != nil ? "✅" : "❌")")
        print("Handshake Manager: \(handshakeManager != nil ? "✅" : "❌")")
        print("Handshake Handler: \(handshakeHandler != nil ? "✅" : "❌")")
        print("ECS Bridge Handler: \(ecsBridgeHandler != nil ? "✅" : "❌")")
        
        if let systemRegistry = systemRegistry {
            print("Available Services in Registry:")
            logAvailableServices()
        }
        print("==============================================")
    }
    
    /// Get integration status for UI display
    func getIntegrationStatus() -> [String: Bool] {
        return [
            "hasSystemRegistry": systemRegistry != nil,
            "hasMessageRouter": messageRouter != nil,
            "hasHandshakeManager": handshakeManager != nil,
            "hasECSBridgeHandler": ecsBridgeHandler != nil,
            "servicesValidated": validateServiceDependencies()
        ]
    }
}
