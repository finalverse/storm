//
//  Network/OSMessageRouter.swift
//  Storm
//
//  Advanced message parsing and routing system for OpenSim protocol
//  Handles packet dispatching, message validation, and notification integration
//  Routes messages to appropriate handlers and manages message queues
//
//  Created for Finalverse Storm - Message Routing Implementation

import Foundation
import Combine
import simd

// MARK: - Message Priority System

enum MessagePriority: Int, CaseIterable {
    case critical = 0    // Handshake, connection management
    case high = 1        // Agent updates, object updates
    case normal = 2      // Chat messages, general updates
    case low = 3         // Statistics, background data
    
    var queueName: String {
        return "OSMessageQueue-\(self)"
    }
}

// MARK: - Message Processing Statistics

struct MessageProcessingStats {
    var totalProcessed: UInt64 = 0
    var processingErrors: UInt64 = 0
    var averageProcessingTime: TimeInterval = 0
    var messagesByType: [MessageType: UInt64] = [:]
    var lastResetTime: Date = Date()
    
    mutating func recordMessage(_ type: MessageType, processingTime: TimeInterval) {
        totalProcessed += 1
        messagesByType[type, default: 0] += 1
        
        // Running average
        averageProcessingTime = (averageProcessingTime * Double(totalProcessed - 1) + processingTime) / Double(totalProcessed)
    }
    
    mutating func recordError() {
        processingErrors += 1
    }
    
    mutating func reset() {
        totalProcessed = 0
        processingErrors = 0
        averageProcessingTime = 0
        messagesByType.removeAll()
        lastResetTime = Date()
    }
}

// MARK: - Message Handler Protocol

protocol OSMessageHandler {
    func canHandle(_ messageType: MessageType) -> Bool
    func handle(_ message: OpenSimPacket) async throws
    var handlerName: String { get }
    var priority: MessagePriority { get }
}

// MARK: - Routing Result

enum RoutingResult {
    case handled
    case unhandled
    case error(Error)
    case deferred
}

// MARK: - Message Router

class OSMessageRouter: ObservableObject {
    
    // MARK: - Published Properties
    @Published var stats = MessageProcessingStats()
    @Published var isProcessing = false
    @Published var queueDepth: [MessagePriority: Int] = [:]
    
    // MARK: - Private Properties
    private var handlers: [MessagePriority: [OSMessageHandler]] = [:]
    private var messageQueues: [MessagePriority: DispatchQueue] = [:]
    private var pendingMessages: [MessagePriority: [(OpenSimPacket, Date)]] = [:]
    private let statsQueue = DispatchQueue(label: "OSMessageRouter.stats")
    private let routingQueue = DispatchQueue(label: "OSMessageRouter.routing", qos: .userInitiated)
    
    // Message filtering
    private var messageFilters: [MessageType: Bool] = [:]
    private var debugMode = false
    
    // Performance monitoring
    private var processingTimes: [TimeInterval] = []
    private let maxProcessingTimeHistory = 100
    
    init() {
        setupMessageQueues()
        setupDefaultFilters()
        setupPerformanceMonitoring()
        print("[🎯] OSMessageRouter initialized with \(MessagePriority.allCases.count) priority queues")
    }
    
    // MARK: - Queue Setup
    
    private func setupMessageQueues() {
        for priority in MessagePriority.allCases {
            let qos: DispatchQoS = switch priority {
            case .critical: .userInteractive
            case .high: .userInitiated
            case .normal: .default
            case .low: .background
            }
            
            messageQueues[priority] = DispatchQueue(
                label: priority.queueName,
                qos: qos,
                attributes: priority == .critical ? [] : .concurrent
            )
            
            pendingMessages[priority] = []
            queueDepth[priority] = 0
        }
    }
    
    private func setupDefaultFilters() {
        // Enable all message types by default
        for messageType in MessageType.allCases {
            messageFilters[messageType] = true
        }
        
        // Disable noisy messages in production
        #if !DEBUG
        messageFilters[.agentUpdate] = false
        messageFilters[.pingCheck] = false
        #endif
    }
    
    private func setupPerformanceMonitoring() {
        // Reset stats every 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.resetStatsIfNeeded()
        }
    }
    
    // MARK: - Handler Registration
    
    func registerHandler(_ handler: OSMessageHandler) {
        let priority = handler.priority
        
        routingQueue.async { [weak self] in
            if self?.handlers[priority] == nil {
                self?.handlers[priority] = []
            }
            self?.handlers[priority]?.append(handler)
            
            DispatchQueue.main.async {
                print("[🎯] Registered handler '\(handler.handlerName)' for priority \(priority)")
            }
        }
    }
    
    func unregisterHandler(_ handlerName: String) {
        routingQueue.async { [weak self] in
            for priority in MessagePriority.allCases {
                self?.handlers[priority]?.removeAll { $0.handlerName == handlerName }
            }
            
            DispatchQueue.main.async {
                print("[🎯] Unregistered handler '\(handlerName)'")
            }
        }
    }
    
    // MARK: - Message Routing
    
    func routeMessage(_ packet: OpenSimPacket) {
        let startTime = Date()
        
        // Check if message type is filtered
        guard messageFilters[packet.messageType] == true else {
            if debugMode {
                print("[🔇] Filtered message type: \(packet.messageType)")
            }
            return
        }
        
        let priority = determinePriority(for: packet.messageType)
        
        // Add to pending queue
        routingQueue.async { [weak self] in
            self?.pendingMessages[priority]?.append((packet, startTime))
            
            DispatchQueue.main.async {
                self?.queueDepth[priority] = self?.pendingMessages[priority]?.count ?? 0
                self?.isProcessing = true
            }
        }
        
        // Process on appropriate queue
        messageQueues[priority]?.async { [weak self] in
            guard let self = self else { return }
            Task {
                await self.processMessage(packet, startTime: startTime, priority: priority)
            }
        }
    }
    
    private func processMessage(_ packet: OpenSimPacket, startTime: Date, priority: MessagePriority) async {
        defer {
            // Remove from pending queue
            routingQueue.async { [weak self] in
                self?.pendingMessages[priority]?.removeFirst()
                
                DispatchQueue.main.async {
                    self?.queueDepth[priority] = self?.pendingMessages[priority]?.count ?? 0
                    self?.isProcessing = self?.pendingMessages.values.contains { !$0.isEmpty } ?? false
                }
            }
        }
        
        do {
            // Find appropriate handlers
            let availableHandlers = handlers[priority] ?? []
            let applicableHandlers = availableHandlers.filter { $0.canHandle(packet.messageType) }
            
            if applicableHandlers.isEmpty {
                // Try default routing
                handleUnroutedMessage(packet)
                return
            }
            
            // Process with each applicable handler
            for handler in applicableHandlers {
                do {
                    try await handler.handle(packet)
                    
                    if debugMode {
                        print("[🎯] Message \(packet.messageType) handled by \(handler.handlerName)")
                    }
                } catch {
                    print("[❌] Handler \(handler.handlerName) failed to process \(packet.messageType): \(error)")
                    recordError()
                }
            }
            
            // Record successful processing
            let processingTime = Date().timeIntervalSince(startTime)
            recordProcessingStats(packet.messageType, processingTime: processingTime)
            
        } catch {
            print("[❌] Failed to process message \(packet.messageType): \(error)")
            recordError()
        }
    }
    
    private func determinePriority(for messageType: MessageType) -> MessagePriority {
        switch messageType {
        // Critical: Connection and handshake
        case .useCircuitCode, .completeAgentMovement, .regionHandshake, .regionHandshakeReply, .agentMovementComplete, .closeCircuit:
            return .critical
            
        // High: Real-time updates
        case .objectUpdate, .objectUpdateCompressed, .objectUpdateCached, .killObject, .agentUpdate:
            return .high
            
        // Normal: Communication and interaction
        case .chatFromSimulator, .chatFromViewer, .instantMessage, .teleportLocationRequest, .teleportLocal:
            return .normal
            
        // Low: Statistics and background
        case .pingCheck, .completePingCheck, .startPingCheck, .simulatorViewerTimeMessage:
            return .low
            
        default:
            return .normal
        }
    }
    
    // MARK: - Default Message Handlers
    
    private func handleUnroutedMessage(_ packet: OpenSimPacket) {
        // Route to appropriate notification or default handler
        switch packet.messageType {
        case .objectUpdate:
            handleObjectUpdateDefault(packet)
        case .killObject:
            handleKillObjectDefault(packet)
        case .chatFromSimulator:
            handleChatMessageDefault(packet)
        case .regionHandshake:
            handleRegionHandshakeDefault(packet)
        case .agentMovementComplete:
            handleAgentMovementCompleteDefault(packet)
        case .completePingCheck:
            handlePingResponseDefault(packet)
        default:
            if debugMode {
                print("[🔹] Unhandled message type: \(packet.messageType)")
            }
        }
    }
    
    private func handleObjectUpdateDefault(_ packet: OpenSimPacket) {
        do {
            let update = try ObjectUpdateMessage.parse(packet.payload)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openSimObjectUpdate, object: update)
            }
        } catch {
            print("[⚠️] Failed to parse ObjectUpdate: \(error)")
        }
    }
    
    private func handleKillObjectDefault(_ packet: OpenSimPacket) {
        // Parse kill object message
        guard packet.payload.count >= 4 else {
            print("[⚠️] KillObject payload too small")
            return
        }
        
        let localID = packet.payload.readUInt32(at: 0)
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .openSimObjectRemoved,
                object: ["localID": localID]
            )
        }
    }
    
    private func handleChatMessageDefault(_ packet: OpenSimPacket) {
        do {
            let chat = try ChatFromSimulatorMessage.parse(packet.payload)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openSimChatMessage, object: chat)
            }
        } catch {
            print("[⚠️] Failed to parse ChatMessage: \(error)")
        }
    }
    
    private func handleRegionHandshakeDefault(_ packet: OpenSimPacket) {
        do {
            let handshake = try RegionHandshakeMessage.parse(packet.payload)
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("openSimRegionHandshake"),
                    object: handshake
                )
            }
        } catch {
            print("[⚠️] Failed to parse RegionHandshake: \(error)")
        }
    }
    
    private func handleAgentMovementCompleteDefault(_ packet: OpenSimPacket) {
        do {
            let movementComplete = try AgentMovementCompleteMessage.parse(packet.payload)
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("openSimAgentMovementComplete"),
                    object: movementComplete
                )
            }
        } catch {
            print("[⚠️] Failed to parse AgentMovementComplete: \(error)")
        }
    }
    
    private func handlePingResponseDefault(_ packet: OpenSimPacket) {
        do {
            let pingResponse = try CompletePingCheckMessage.parse(packet.payload)
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("openSimPingResponse"),
                    object: pingResponse
                )
            }
        } catch {
            print("[⚠️] Failed to parse PingResponse: \(error)")
        }
    }
    
    // MARK: - Statistics and Monitoring
    
    private func recordProcessingStats(_ messageType: MessageType, processingTime: TimeInterval) {
        statsQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.stats.recordMessage(messageType, processingTime: processingTime)
            }
            
            // Record processing time for performance monitoring
            self.processingTimes.append(processingTime)
            if self.processingTimes.count > self.maxProcessingTimeHistory {
                self.processingTimes.removeFirst()
            }
        }
    }
    
    private func recordError() {
        DispatchQueue.main.async { [weak self] in
            self?.stats.recordError()
        }
    }
    
    private func resetStatsIfNeeded() {
        let resetInterval: TimeInterval = 300 // 5 minutes
        if Date().timeIntervalSince(stats.lastResetTime) > resetInterval {
            stats.reset()
            processingTimes.removeAll()
            print("[📊] Message processing stats reset")
        }
    }
    
    // MARK: - Configuration
    
    func setMessageFilter(_ messageType: MessageType, enabled: Bool) {
        messageFilters[messageType] = enabled
        print("[🔇] Message filter for \(messageType): \(enabled ? "enabled" : "disabled")")
    }
    
    func setDebugMode(_ enabled: Bool) {
        debugMode = enabled
        print("[🐛] Debug mode: \(enabled ? "enabled" : "disabled")")
    }
    
    func getAverageProcessingTime() -> TimeInterval {
        guard !processingTimes.isEmpty else { return 0 }
        return processingTimes.reduce(0, +) / Double(processingTimes.count)
    }
    
    func getMessageTypeStats() -> [MessageType: UInt64] {
        return stats.messagesByType
    }
    
    // MARK: - Queue Management
    
    func clearPendingMessages() {
        routingQueue.async { [weak self] in
            for priority in MessagePriority.allCases {
                self?.pendingMessages[priority]?.removeAll()
            }
            
            DispatchQueue.main.async {
                for priority in MessagePriority.allCases {
                    self?.queueDepth[priority] = 0
                }
                self?.isProcessing = false
            }
        }
        
        print("[🗑️] Cleared all pending messages")
    }
    
    func pauseProcessing() {
        for queue in messageQueues.values {
            queue.suspend()
        }
        print("[⏸️] Message processing paused")
    }
    
    func resumeProcessing() {
        for queue in messageQueues.values {
            queue.resume()
        }
        print("[▶️] Message processing resumed")
    }
}

// MARK: - Default Message Handlers

// MARK: - Handshake Handler

class HandshakeMessageHandler: OSMessageHandler {
    let handlerName = "HandshakeHandler"
    let priority = MessagePriority.critical
    
    private weak var handshakeManager: OpenSimHandshakeManager?
    
    init(handshakeManager: OpenSimHandshakeManager) {
        self.handshakeManager = handshakeManager
    }
    
    func canHandle(_ messageType: MessageType) -> Bool {
        return messageType.isHandshakeMessage
    }
    
    func handle(_ message: OpenSimPacket) async throws {
        guard let handshakeManager = handshakeManager else {
            throw ProtocolError.parsingError("No handshake manager available")
        }
        
        switch message.messageType {
        case .regionHandshake:
            let regionHandshake = try RegionHandshakeMessage.parse(message.payload)
            _ = handshakeManager.handleRegionHandshake(regionHandshake)
            
        case .agentMovementComplete:
            let movementComplete = try AgentMovementCompleteMessage.parse(message.payload)
            handshakeManager.handleAgentMovementComplete(movementComplete)
            
        default:
            print("[🤝] Handshake handler received unhandled message: \(message.messageType)")
        }
    }
}

// MARK: - ECS Bridge Handler

class ECSBridgeMessageHandler: OSMessageHandler {
    let handlerName = "ECSBridgeHandler"
    let priority = MessagePriority.high
    
    private weak var ecsbridge: OpenSimECSBridge?
    
    init(ecsBridge: OpenSimECSBridge) {
        self.ecsbridge = ecsBridge
    }
    
    func canHandle(_ messageType: MessageType) -> Bool {
        switch messageType {
        case .objectUpdate, .objectUpdateCompressed, .objectUpdateCached, .killObject:
            return true
        default:
            return false
        }
    }
    
    func handle(_ message: OpenSimPacket) async throws {
        // ECS bridge will handle through notifications
        // This handler ensures proper priority routing
        switch message.messageType {
        case .objectUpdate:
            let update = try ObjectUpdateMessage.parse(message.payload)
            await MainActor.run {
                NotificationCenter.default.post(name: .openSimObjectUpdate, object: update)
            }
            
        case .killObject:
            let localID = message.payload.readUInt32(at: 0)
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .openSimObjectRemoved,
                    object: ["localID": localID]
                )
            }
            
        default:
            break
        }
    }
}

// MARK: - Chat Handler

class ChatMessageHandler: OSMessageHandler {
    let handlerName = "ChatHandler"
    let priority = MessagePriority.normal
    
    func canHandle(_ messageType: MessageType) -> Bool {
        switch messageType {
        case .chatFromSimulator, .instantMessage:
            return true
        default:
            return false
        }
    }
    
    func handle(_ message: OpenSimPacket) async throws {
        switch message.messageType {
        case .chatFromSimulator:
            let chat = try ChatFromSimulatorMessage.parse(message.payload)
            await MainActor.run {
                NotificationCenter.default.post(name: .openSimChatMessage, object: chat)
            }
            
        default:
            break
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let openSimRegionHandshake = Notification.Name("openSimRegionHandshake")
    static let openSimAgentMovementComplete = Notification.Name("openSimAgentMovementComplete")
    static let openSimPingResponse = Notification.Name("openSimPingResponse")
    static let openSimConnectionStateChanged = Notification.Name("openSimConnectionStateChanged")
    static let openSimHandshakeStateChanged = Notification.Name("openSimHandshakeStateChanged")
}
