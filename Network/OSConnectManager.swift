//
//  Network/OSConnectManager.swift
//  Storm
//
//  Real UDP OpenSim connection manager with Network framework
//  Handles OpenSim LLUDP protocol connection, authentication, and packet routing
//  ENHANCED: Fixed compilation errors and improved integration
//
//  Created for Finalverse Storm - Real Network Implementation

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
        print("[🔗] ECS Bridge handler registered post-initialization")
    }

    /// Update system registry reference (for dependency injection)
    func setSystemRegistry(_ registry: SystemRegistry) {
        print("[🔧] Setting system registry reference")
        self.systemRegistry = registry
        
        // Setup ECS bridge integration if not already done
        if ecsBridgeHandler == nil {
            setupECSBridgeIntegration()
        } else {
            print("[ℹ️] ECS bridge handler already registered")
        }
    }
    
    // MARK: Enhanced service integration methods

    /// Try to integrate with all available services from registry
    func integrateWithServices() {
        guard let systemRegistry = systemRegistry else {
            print("[⚠️] Cannot integrate services: no system registry available")
            return
        }
        
        print("[🔧] Integrating OSConnectManager with available services...")
        
        // Try to get and register ECS bridge
        if ecsBridgeHandler == nil, let ecsBridge = systemRegistry.getOpenSimBridge() {
            registerECSBridge(ecsBridge)
        }
        
        // Log available services for debugging
        logAvailableServices()
    }

    /// Log which services are available in the registry
    private func logAvailableServices() {
        guard let systemRegistry = systemRegistry else { return }
        
        print("[📋] Available services in registry:")
        print("  - ECS: \(systemRegistry.getECS() != nil ? "✅" : "❌")")
        print("  - Renderer: \(systemRegistry.getRenderer() != nil ? "✅" : "❌")")
        print("  - OpenSim Bridge: \(systemRegistry.getOpenSimBridge() != nil ? "✅" : "❌")")
        print("  - Message Router: \(systemRegistry.getMessageRouter() != nil ? "✅" : "❌")")
        print("  - UI Composer: \(systemRegistry.getUIComposer() != nil ? "✅" : "❌")")
        print("  - UI Router: \(systemRegistry.getUIRouter() != nil ? "✅" : "❌")")
    }

    /// Check if all required services are available
    func validateServiceDependencies() -> Bool {
        guard let systemRegistry = systemRegistry else {
            print("[❌] Service validation failed: no system registry")
            return false
        }
        
        let hasRequiredServices =
            systemRegistry.getECS() != nil &&
            systemRegistry.getRenderer() != nil
        
        if hasRequiredServices {
            print("[✅] All required services available for OSConnectManager")
        } else {
            print("[⚠️] Missing required services for OSConnectManager")
        }
        
        return hasRequiredServices
    }
    
    // MARK: - Public Connection Interface
    
    /// Connect to OpenSim server using UDP protocol
    func connect(to host: String, port: UInt16) {
        // Check current connection state
        let canConnect: Bool
        switch connectionStatus {
        case .disconnected, .error:
            canConnect = true
        case .connecting, .connected:
            canConnect = false
        }
        
        guard canConnect else {
            print("[⚠️] Already connecting or connected")
            return
        }
        
        print("[🔌] Connecting to OpenSim server: \(host):\(port)")
        
        // Update UI state on main thread
        DispatchQueue.main.async {
            self.connectionStatus = .connecting
            self.isConnected = false
        }
        
        // Create UDP endpoint for OpenSim server
        let nwEndpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!
        )
        
        // Configure UDP parameters for optimal performance
        let params = NWParameters.udp
        params.allowFastOpen = true
        params.allowLocalEndpointReuse = true
        
        // Create and configure network connection
        connection = NWConnection(to: nwEndpoint, using: params)
        setupConnectionHandlers()
        
        // Start connection on background queue
        connection?.start(queue: queue)
    }
    
    /// Disconnect from OpenSim server and cleanup resources
    func disconnect() {
        print("[🔌] Disconnecting from OpenSim server")
        
        // Send logout message if currently connected
        if isConnected {
            sendLogoutRequest()
        }
        
        // Cancel network connection
        connection?.cancel()
        connection = nil
        
        // Stop all timers to prevent memory leaks
        stopTimers()
        
        // Reset all connection state
        resetConnectionState()
        
        // Update UI state on main thread
        DispatchQueue.main.async {
            self.connectionStatus = .disconnected
            self.isConnected = false
            self.latency = 0
        }
    }
    
    // MARK: - Avatar Movement Interface
    
    /// Send avatar movement update to OpenSim server
    func moveAvatar(position: SIMD3<Float>, rotation: SIMD2<Float>) {
        guard isConnected else {
            print("[⚠️] Cannot move avatar: not connected to server")
            return
        }
        
        // Create agent update message with movement data
        let message = AgentUpdateMessage(
            agentID: agentID,
            sessionID: sessionID,
            bodyRotation: simd_quatf(angle: rotation.x, axis: [0, 1, 0]), // Y-axis rotation for body
            headRotation: simd_quatf(angle: rotation.y, axis: [1, 0, 0]), // X-axis rotation for head
            state: 0, // Walking state
            position: position,
            lookAt: SIMD3<Float>(0, 0, 1), // Forward direction
            upAxis: SIMD3<Float>(0, 1, 0), // Y-up coordinate system
            leftAxis: SIMD3<Float>(-1, 0, 0), // Left-handed coordinate system
            cameraCenter: position,
            cameraAtAxis: SIMD3<Float>(0, 0, 1), // Camera looking forward
            cameraLeftAxis: SIMD3<Float>(-1, 0, 0), // Camera left axis
            cameraUpAxis: SIMD3<Float>(0, 1, 0), // Camera up axis
            far: 256.0, // Far clipping plane
            aspectRatio: 1.0, // Default aspect ratio
            throttles: [0, 0, 0, 0], // No throttle input
            controlFlags: 0, // No control flags set
            flags: 0 // No additional flags
        )
        
        sendMessage(message)
    }
    
    /// Send teleport request to specific position
    func teleportAvatar(to position: SIMD3<Float>) {
        guard isConnected else {
            print("[⚠️] Cannot teleport avatar: not connected to server")
            return
        }
        
        // Create teleport request message
        let message = TeleportLocationRequestMessage(
            agentID: agentID,
            sessionID: sessionID,
            regionHandle: 0, // Current region (0 means current)
            position: position,
            lookAt: SIMD3<Float>(0, 0, 1) // Face forward after teleport
        )
        
        sendMessage(message)
        print("[🚀] Teleport request sent to position: \(position)")
    }
    
    // MARK: - Private Connection Setup
    
    /// Setup network connection event handlers
    private func setupConnectionHandlers() {
        // Handle connection state changes
        connection?.stateUpdateHandler = { [weak self] state in
            self?.handleConnectionStateChange(state)
        }
        
        // Handle connection viability changes
        connection?.viabilityUpdateHandler = { [weak self] isViable in
            if !isViable {
                print("[⚠️] Connection is not viable")
                DispatchQueue.main.async {
                    self?.connectionStatus = .error("Connection lost")
                }
            }
        }
    }
    
    /// Handle network connection state changes
    private func handleConnectionStateChange(_ state: NWConnection.State) {
        DispatchQueue.main.async {
            switch state {
            case .ready:
                print("[✅] UDP connection established")
                self.connectionStatus = .connected
                self.isConnected = true
                self.startReceiveLoop() // Begin receiving packets
                self.startTimers() // Start heartbeat and maintenance timers
                self.sendUseCircuitCode() // Begin OpenSim handshake
                
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
                
            default:
                break
            }
        }
    }
    
    // MARK: - Message Sending
    
    /// Send UseCircuitCode message to begin OpenSim handshake
    private func sendUseCircuitCode() {
        guard let handshakeManager = handshakeManager else {
            print("[❌] Handshake manager not available")
            return
        }
        
        // Start handshake process and get initial message
        let message = handshakeManager.startHandshake()
        sendMessage(message)
        print("[🔑] Sent UseCircuitCode with circuit: \(circuitCode)")
    }
    
    /// Send any OpenSim message to the server
    private func sendMessage<T: OpenSimMessage>(_ message: T) {
        do {
            // Serialize message to binary data
            let payload = try message.serialize()
            
            // Wrap in OpenSim packet with proper headers
            let packet = wrapInPacket(messageType: message.type, payload: payload)
            
            // Send packet over network
            send(data: packet)
            
            // Track message for ACK if reliable delivery required
            if message.needsAck {
                pendingAcks[sequenceNumber] = Date()
            }
            
        } catch {
            print("[❌] Failed to serialize message \(message.type): \(error)")
        }
    }
    
    /// Send raw data over network connection
    private func send(data: Data) {
        connection?.send(content: data, completion: .contentProcessed({ [weak self] error in
            if let error = error {
                print("[❌] Send error: \(error)")
            } else {
                // Update statistics on successful send
                DispatchQueue.main.async {
                    self?.stats.packetsSent += 1
                    self?.stats.bytesSent += UInt64(data.count)
                }
            }
        }))
    }
    
    /// Send logout request message
    private func sendLogoutRequest() {
        let message = LogoutRequestMessage(
            agentID: agentID,
            sessionID: sessionID
        )
        sendMessage(message)
        print("[👋] Logout request sent")
    }
    
    // MARK: - Packet Creation
    
    /// Wrap message payload in OpenSim packet format
    private func wrapInPacket(messageType: MessageType, payload: Data) -> Data {
        // Create packet with proper sequence number and flags
        let packet = OpenSimPacket(
            messageType: messageType,
            payload: payload,
            sequenceNumber: sequenceNumber,
            needsAck: messageType.needsAck,
            ackNumber: nil
        )
        
        // Increment sequence number for next packet
        sequenceNumber += 1
        
        do {
            return try packet.serialize()
        } catch {
            print("[❌] Failed to wrap packet: \(error)")
            return Data()
        }
    }
    
    // MARK: - Packet Reception
    
    /// Start continuous packet reception loop
    private func startReceiveLoop() {
        connection?.receiveMessage { [weak self] (data, context, isComplete, error) in
            // Process received data if available
            if let data = data, !data.isEmpty {
                self?.handleIncomingPacket(data: data)
            }
            
            // Handle receive errors
            if let error = error {
                print("[❌] Receive error: \(error)")
                return
            }
            
            // Continue receiving packets
            self?.startReceiveLoop()
        }
    }
    
    /// Process incoming packet data
    private func handleIncomingPacket(data: Data) {
        receiveQueue.async { [weak self] in
            do {
                // Parse incoming data as OpenSim packet
                let packet = try OpenSimPacket.parse(data)
                
                // Update reception statistics
                DispatchQueue.main.async {
                    self?.stats.packetsReceived += 1
                    self?.stats.bytesReceived += UInt64(data.count)
                }
                
                // Send ACK if packet requires acknowledgment
                if packet.needsAck {
                    self?.sendAcknowledgment(packet.sequenceNumber)
                }
                
                // Route packet to appropriate handlers
                DispatchQueue.main.async {
                    self?.routePacket(packet)
                }
                
            } catch {
                print("[⚠️] Failed to parse incoming packet: \(error)")
            }
        }
    }
    
    /// Route parsed packet to appropriate message handlers
    private func routePacket(_ packet: OpenSimPacket) {
        // Use message router for all packet routing
        messageRouter.routeMessage(packet)
        
        // Handle critical connection management directly
        switch packet.messageType {
        case .packetAck:
            handlePacketAck(packet)
        default:
            break // Let router handle everything else
        }
    }
    
    // MARK: - Direct Message Handlers (Legacy Support)
    
    /// Handle region handshake message (integrated with handshake manager)
    private func handleRegionHandshake(_ packet: OpenSimPacket) {
        do {
            let regionHandshake = try RegionHandshakeMessage.parse(packet.payload)
            
            // Use handshake manager for proper sequence handling
            if let handshakeManager = handshakeManager,
               let reply = handshakeManager.handleRegionHandshake(regionHandshake) {
                sendMessage(reply)
                
                // Send CompleteAgentMovement as next step
                if let completeMovement = handshakeManager.createCompleteAgentMovement() {
                    sendMessage(completeMovement)
                }
            }
        } catch {
            print("[⚠️] Failed to parse RegionHandshake: \(error)")
        }
    }
    
    /// Handle ping response for latency measurement
    private func handlePingResponse(_ packet: OpenSimPacket) {
        if let startTime = lastPingTime {
            let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
            DispatchQueue.main.async {
                self.latency = latencyMs
                self.stats.lastPingTime = Date().timeIntervalSince1970
                self.stats.averageLatency = (self.stats.averageLatency + TimeInterval(latencyMs)) / 2.0
            }
            print("[📡] Ping response: \(latencyMs)ms")
        }
    }
    
    /// Handle packet acknowledgment
    private func handlePacketAck(_ packet: OpenSimPacket) {
        // Remove acknowledged packet from pending list
        if let ackNumber = packet.ackNumber {
            pendingAcks.removeValue(forKey: ackNumber)
        }
    }
    
    // MARK: - ACK Handling
    
    /// Send acknowledgment for received packet
    private func sendAcknowledgment(_ sequenceNumber: UInt32) {
        // TODO: Implement PacketAck message sending
        // For now, just log the ACK requirement
        // print("[📝] ACK needed for sequence: \(sequenceNumber)")
    }
    
    // MARK: - Timers
    
    /// Start periodic timers for connection maintenance
    private func startTimers() {
        // Heartbeat timer - send ping every 5 seconds
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
        
        // ACK timeout checker - check every second for timed out packets
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
