//
//  Tests/OpenSimTestSuites.swift
//  Storm
//
//  Comprehensive test suites for OpenSim integration components
//  Integration, unit, performance, and memory leak detection tests
//
//  Created for Finalverse Storm - Test Suites Implementation

//import XCTest
import Foundation
import RealityKit
import Combine
//@testable import Storm

// MARK: - Integration Test Suite

class OpenSimIntegrationTests: XCTestCase {
    var mockServer: MockOpenSimServer!
    var connectManager: OSConnectManager!
    var testRegistry: SystemRegistry!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Start mock server
        mockServer = MockOpenSimServer()
        try mockServer.start()
        
        // Setup test system registry
        testRegistry = SystemRegistry()
        let ecs = ECSCore()
        testRegistry.register(ecs, for: "ecs")
        
        // Create connection manager for testing
        connectManager = OSConnectManager(systemRegistry: testRegistry)
        
        // Wait for server to be ready
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }
    
    override func tearDown() async throws {
        mockServer.stop()
        connectManager.disconnect()
        try await super.tearDown()
    }
    
    // MARK: - Connection Tests
    
    func testBasicConnection() async throws {
        let expectation = XCTestExpectation(description: "Connection established")
        
        connectManager.connect(to: TestConfiguration.mockServerHost, port: TestConfiguration.mockServerPort)
        
        // Wait for connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.connectManager.isConnected {
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: TestConfiguration.testTimeout)
        XCTAssertTrue(connectManager.isConnected)
    }
    
    func testHandshakeSequence() async throws {
        let handshakeExpectation = XCTestExpectation(description: "Handshake completed")
        
        // Monitor handshake completion
        NotificationCenter.default.addObserver(forName: .openSimAgentMovementComplete, object: nil, queue: .main) { _ in
            handshakeExpectation.fulfill()
        }
        
        connectManager.connect(to: TestConfiguration.mockServerHost, port: TestConfiguration.mockServerPort)
        
        await fulfillment(of: [handshakeExpectation], timeout: TestConfiguration.testTimeout)
        
        // Verify session info is set
        let sessionInfo = connectManager.getSessionInfo()
        XCTAssertNotEqual(sessionInfo.agentID, UUID())
        XCTAssertNotEqual(sessionInfo.circuitCode, 0)
    }
    
    func testReconnection() async throws {
        // Connect first
        try await testBasicConnection()
        
        // Disconnect
        connectManager.disconnect()
        XCTAssertFalse(connectManager.isConnected)
        
        // Wait a moment
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        // Reconnect
        try await testBasicConnection()
    }
    
    // MARK: - Message Tests
    
    func testChatMessage() async throws {
        try await testBasicConnection()
        
        let chatExpectation = XCTestExpectation(description: "Chat message received")
        
        NotificationCenter.default.addObserver(forName: .openSimChatMessage, object: nil, queue: .main) { notification in
            if let chatMessage = notification.object as? ChatFromSimulatorMessage {
                XCTAssertTrue(chatMessage.message.contains("Test Echo"))
                chatExpectation.fulfill()
            }
        }
        
        // Send chat message
        let chatMessage = ChatFromViewerMessage(
            agentID: connectManager.getSessionInfo().agentID,
            sessionID: connectManager.getSessionInfo().sessionID,
            message: "Hello World",
            chatType: 1,
            channel: 0
        )
        
        connectManager.sendMessage(chatMessage)
        
        await fulfillment(of: [chatExpectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testObjectUpdates() async throws {
        try await testBasicConnection()
        
        let objectExpectation = XCTestExpectation(description: "Object update received")
        
        NotificationCenter.default.addObserver(forName: .openSimObjectUpdate, object: nil, queue: .main) { notification in
            if let objectUpdate = notification.object as? ObjectUpdateMessage {
                XCTAssertGreaterThan(objectUpdate.localID, 0)
                objectExpectation.fulfill()
            }
        }
        
        // Trigger object update from mock server
        mockServer.simulateObjectUpdate(localID: 1001)
        
        await fulfillment(of: [objectExpectation], timeout: TestConfiguration.testTimeout)
    }
    
    // MARK: - Error Handling Tests
    
    func testConnectionTimeout() async throws {
        let timeoutExpectation = XCTestExpectation(description: "Connection timeout handled")
        
        // Try to connect to non-existent server
        connectManager.connect(to: "192.0.2.0", port: 12345) // RFC5737 test address
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            XCTAssertFalse(self.connectManager.isConnected)
            timeoutExpectation.fulfill()
        }
        
        await fulfillment(of: [timeoutExpectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testMalformedPacket() async throws {
        try await testBasicConnection()
        
        // This test would verify that malformed packets don't crash the system
        // Implementation would depend on specific error handling mechanisms
        XCTAssertTrue(connectManager.isConnected)
    }
}

// MARK: - Unit Tests for Individual Components

class OpenSimComponentTests: XCTestCase {
    
    // MARK: - Protocol Tests
    
    func testMessageSerialization() throws {
        let agentID = UUID()
        let sessionID = UUID()
        
        let useCircuitMessage = UseCircuitCodeMessage(
            circuitCode: 12345,
            sessionID: sessionID,
            agentID: agentID
        )
        
        let serializedData = try useCircuitMessage.serialize()
        XCTAssertGreaterThan(serializedData.count, 0)
        
        // Verify message type is correct
        let messageType = serializedData.readUInt32(at: 0)
        XCTAssertEqual(messageType, MessageType.useCircuitCode.rawValue)
    }
    
    func testPacketParsing() throws {
        // Create test packet data
        var testData = Data()
        
        // Add message type
        var msgType = MessageType.testMessage.rawValue.bigEndian
        testData.append(Data(bytes: &msgType, count: 4))
        
        // Add sequence number
        var sequence: UInt32 = 100
        testData.append(Data(bytes: &sequence.bigEndian, count: 4))
        
        // Add payload
        let payload = "Test payload".data(using: .utf8)!
        testData.append(payload)
        
        let packet = try OpenSimPacket.parse(testData)
        XCTAssertEqual(packet.messageType, .testMessage)
        XCTAssertEqual(packet.sequenceNumber, 100)
    }
    
    // MARK: - ECS Component Tests
    
    func testECSEntityCreation() throws {
        let ecs = ECSCore()
        let world = ecs.getWorld()
        
        let entityID = world.createEntity()
        XCTAssertNotNil(entityID)
        
        let position = PositionComponent(position: SIMD3<Float>(1, 2, 3))
        world.addComponent(position, to: entityID)
        
        let retrievedPosition = world.getComponent(ofType: PositionComponent.self, from: entityID)
        XCTAssertNotNil(retrievedPosition)
        XCTAssertEqual(retrievedPosition?.position, SIMD3<Float>(1, 2, 3))
    }
    
    func testECSEntityRemoval() throws {
        let ecs = ECSCore()
        let world = ecs.getWorld()
        
        let entityID = world.createEntity()
        let position = PositionComponent(position: SIMD3<Float>(0, 0, 0))
        world.addComponent(position, to: entityID)
        
        world.removeEntity(entityID)
        
        let retrievedPosition = world.getComponent(ofType: PositionComponent.self, from: entityID)
        XCTAssertNil(retrievedPosition)
    }
    
    // MARK: - State Management Tests
    
    func testStateSnapshot() throws {
        let stateManager = OpenSimStateManager()
        
        // This would test state snapshot functionality
        // Implementation depends on specific state manager setup
        XCTAssertNotNil(stateManager)
    }
    
    func testErrorRecovery() throws {
        let errorContext = ErrorContext(
            error: TestError.mockError,
            timestamp: Date(),
            systemState: createMockSystemState(),
            recoveryStrategy: .immediate,
            severity: .medium,
            component: .network,
            userImpact: .moderate
        )
        
        XCTAssertEqual(errorContext.severity, .medium)
        XCTAssertEqual(errorContext.component, .network)
    }
    
    private func createMockSystemState() -> SystemStateSnapshot {
        return SystemStateSnapshot(
            timestamp: Date(),
            connectionState: ConnectionState(
                isConnected: true,
                serverHost: "test",
                serverPort: 9000,
                agentID: UUID(),
                sessionID: UUID(),
                circuitCode: 12345,
                lastHeartbeat: Date(),
                connectionDuration: 60
            ),
            ecsEntityCount: 10,
            visualEntityCount: 8,
            openSimObjectCount: 12,
            memoryUsage: 100_000_000,
            frameRate: 60.0,
            latency: 0.05,
            sequenceNumber: 1000,
            regionHandle: 1099511627776,
            avatarPosition: SIMD3<Float>(128, 25, 128),
            checksum: "test123"
        )
    }
    
    enum TestError: Error {
        case mockError
    }
}

// MARK: - Performance Benchmark Tests

class OpenSimPerformanceTests: XCTestCase {
    
    func testConnectionPerformance() throws {
        let connectManager = OSConnectManager()
        
        measure {
            // Measure connection setup time
            let startTime = CFAbsoluteTimeGetCurrent()
            
            for _ in 0..<TestConfiguration.performanceIterations {
                // Simulate connection setup overhead
                let _ = connectManager.getSessionInfo()
            }
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let avgTime = (endTime - startTime) / Double(TestConfiguration.performanceIterations)
            
            XCTAssertLessThan(avgTime * 1000, 1.0) // Less than 1ms per operation
        }
    }
    
    func testMessageProcessingPerformance() throws {
        let messageRouter = OSMessageRouter()
        
        measure {
            for _ in 0..<TestConfiguration.performanceIterations {
                let testPacket = createTestPacket()
                messageRouter.routeMessage(testPacket)
            }
        }
    }
    
    func testECSPerformance() throws {
        let ecs = ECSCore()
        let world = ecs.getWorld()
        
        measure {
            // Create many entities
            for _ in 0..<1000 {
                let entityID = world.createEntity()
                let position = PositionComponent(position: SIMD3<Float>(
                    Float.random(in: 0...256),
                    Float.random(in: 0...50),
                    Float.random(in: 0...256)
                ))
                world.addComponent(position, to: entityID)
            }
            
            // Query entities
            let entities = world.entities(with: PositionComponent.self)
            XCTAssertEqual(entities.count, 1000)
        }
    }
    
    func testMemoryUsageUnderLoad() throws {
        let initialMemory = getMemoryUsage()
        
        // Create load
        let ecs = ECSCore()
        let world = ecs.getWorld()
        var entities: [EntityID] = []
        
        for _ in 0..<10000 {
            let entityID = world.createEntity()
            entities.append(entityID)
            
            let position = PositionComponent(position: SIMD3<Float>(0, 0, 0))
            world.addComponent(position, to: entityID)
        }
        
        let peakMemory = getMemoryUsage()
        
        // Cleanup
        for entityID in entities {
            world.removeEntity(entityID)
        }
        
        // Force cleanup
        autoreleasepool {}
        
        let finalMemory = getMemoryUsage()
        
        // Verify memory usage
        let memoryIncrease = peakMemory - initialMemory
        let memoryRecovered = peakMemory - finalMemory
        
        XCTAssertLessThan(memoryIncrease, TestConfiguration.memoryLeakThreshold)
        XCTAssertGreaterThan(memoryRecovered, memoryIncrease * 0.8) // 80% recovery
    }
    
    func testFrameRateStability() throws {
        var frameTimes: [TimeInterval] = []
        
        // Simulate 60 FPS for 5 seconds
        for _ in 0..<300 {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Simulate frame processing
            simulateFrameProcessing()
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let frameTime = endTime - startTime
            frameTimes.append(frameTime)
        }
        
        let avgFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
        let maxFrameTime = frameTimes.max() ?? 0
        
        XCTAssertLessThan(avgFrameTime * 1000, TestConfiguration.frameBudgetMs)
        XCTAssertLessThan(maxFrameTime * 1000, TestConfiguration.frameBudgetMs * 2)
    }
    
    private func createTestPacket() -> OpenSimPacket {
        return OpenSimPacket(
            messageType: .testMessage,
            sequenceNumber: 1,
            payload: Data("test".utf8),
            timestamp: Date()
        )
    }
    
    private func simulateFrameProcessing() {
        // Simulate typical frame processing workload
        let ecs = ECSCore()
        let world = ecs.getWorld()
        
        // Create some entities
        for _ in 0..<10 {
            let entityID = world.createEntity()
            let position = PositionComponent(position: SIMD3<Float>(
                Float.random(in: 0...256),
                Float.random(in: 0...50),
                Float.random(in: 0...256)
            ))
            world.addComponent(position, to: entityID)
        }
        
        // Simulate some processing
        Thread.sleep(forTimeInterval: 0.001) // 1ms of work
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - Memory Leak Detection Tests

class OpenSimMemoryTests: XCTestCase {
    
    func testConnectionManagerMemoryLeaks() throws {
        weak var weakManager: OSConnectManager?
        
        autoreleasepool {
            let manager = OSConnectManager()
            weakManager = manager
            
            // Perform operations that might create retain cycles
            manager.connect(to: "127.0.0.1", port: 9000)
            manager.disconnect()
        }
        
        // Wait a bit for cleanup
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        XCTAssertNil(weakManager, "OSConnectManager should be deallocated")
    }
    
    func testECSBridgeMemoryLeaks() throws {
        weak var weakBridge: OpenSimECSBridge?
        
        autoreleasepool {
            let ecs = ECSCore()
            let config = EntityCreationConfig(
                enableVisualRepresentation: true,
                enablePhysics: true,
                enableInteraction: true,
                debugVisualization: false,
                materialQuality: .medium,
                lodDistance: 100.0,
                maxEntities: 1000
            )
            
            let bridge = OpenSimECSBridge(ecs: ecs, config: config)
            weakBridge = bridge
            
            // Create and destroy entities
            for _ in 0..<100 {
                let objectData = createTestObjectData()
                bridge.handleObjectUpdate(objectData)
            }
        }
        
        // Wait for cleanup
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        XCTAssertNil(weakBridge, "OpenSimECSBridge should be deallocated")
    }
    
    func testMessageRouterMemoryLeaks() throws {
        weak var weakRouter: OSMessageRouter?
        
        autoreleasepool {
            let router = OSMessageRouter()
            weakRouter = router
            
            // Register handlers
            let handler = TestMessageHandler()
            router.registerHandler(handler)
            
            // Process messages
            for _ in 0..<50 {
                let packet = createTestPacket()
                router.routeMessage(packet)
            }
            
            // Unregister handlers
            router.unregisterHandler("TestHandler")
        }
        
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        XCTAssertNil(weakRouter, "OSMessageRouter should be deallocated")
    }
    
    private func createTestObjectData() -> ObjectUpdateMessage {
        return ObjectUpdateMessage(
            localID: UInt32.random(in: 1000...9999),
            fullID: UUID(),
            position: SIMD3<Float>(
                Float.random(in: 0...256),
                Float.random(in: 0...50),
                Float.random(in: 0...256)
            ),
            rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
            scale: SIMD3<Float>(1, 1, 1),
            pcode: 9, // Primitive
            material: 3,
            flags: 0
        )
    }
    
    private func createTestPacket() -> OpenSimPacket {
        return OpenSimPacket(
            messageType: .testMessage,
            sequenceNumber: UInt32.random(in: 1...1000),
            payload: Data("test payload".utf8),
            timestamp: Date()
        )
    }
}

// MARK: - Test Message Handler

class TestMessageHandler: OSMessageHandler {
    let handlerName = "TestHandler"
    let priority = MessagePriority.normal
    
    func canHandle(_ messageType: MessageType) -> Bool {
        return messageType == .testMessage
    }
    
    func handle(_ message: OpenSimPacket) async throws {
        // Simple test handling
        print("[🧪] Test handler processed message: \(message.messageType)")
    }
}

// MARK: - Stress Testing Suite

class OpenSimStressTests: XCTestCase {
    
    func testHighVolumeMessageProcessing() throws {
        let messageRouter = OSMessageRouter()
        let handler = TestMessageHandler()
        messageRouter.registerHandler(handler)
        
        let messageCount = 10000
        let startTime = Date()
        
        // Send high volume of messages
        for i in 0..<messageCount {
            let packet = OpenSimPacket(
                messageType: .testMessage,
                sequenceNumber: UInt32(i),
                payload: Data("stress test message \(i)".utf8),
                timestamp: Date()
            )
            messageRouter.routeMessage(packet)
        }
        
        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)
        let messagesPerSecond = Double(messageCount) / processingTime
        
        print("[📊] Processed \(messageCount) messages in \(processingTime)s (\(messagesPerSecond) msg/s)")
        
        // Should handle at least 1000 messages per second
        XCTAssertGreaterThan(messagesPerSecond, 1000)
    }
    
    func testConcurrentConnections() async throws {
        let connectionCount = 10
        var managers: [OSConnectManager] = []
        
        // Create multiple connection managers
        for _ in 0..<connectionCount {
            let manager = OSConnectManager()
            managers.append(manager)
        }
        
        // Test concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for manager in managers {
                group.addTask {
                    // Simulate connection operations
                    for _ in 0..<100 {
                        let sessionInfo = manager.getSessionInfo()
                        XCTAssertNotEqual(sessionInfo.agentID, UUID())
                    }
                }
            }
        }
        
        // Verify all managers are still functional
        for manager in managers {
            let sessionInfo = manager.getSessionInfo()
            XCTAssertNotEqual(sessionInfo.circuitCode, 0)
        }
    }
    
    func testMemoryStressUnderLoad() throws {
        let initialMemory = getMemoryUsage()
        var entities: [EntityID] = []
        
        let ecs = ECSCore()
        let world = ecs.getWorld()
        
        // Create stress load
        for cycle in 0..<100 {
            // Create entities
            for _ in 0..<1000 {
                let entityID = world.createEntity()
                entities.append(entityID)
                
                let position = PositionComponent(position: SIMD3<Float>(
                    Float.random(in: 0...256),
                    Float.random(in: 0...50),
                    Float.random(in: 0...256)
                ))
                world.addComponent(position, to: entityID)
            }
            
            // Check memory every 10 cycles
            if cycle % 10 == 0 {
                let currentMemory = getMemoryUsage()
                let memoryIncrease = currentMemory - initialMemory
                
                // Memory shouldn't grow indefinitely
                XCTAssertLessThan(memoryIncrease, TestConfiguration.memoryLeakThreshold * 10)
                
                // Clean up some entities to prevent infinite growth
                if entities.count > 50000 {
                    for _ in 0..<25000 {
                        if let entityID = entities.popLast() {
                            world.removeEntity(entityID)
                        }
                    }
                }
            }
        }
        
        // Final cleanup
        for entityID in entities {
            world.removeEntity(entityID)
        }
        
        // Force memory cleanup
        autoreleasepool {}
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Final memory usage should be reasonable
        XCTAssertLessThan(memoryIncrease, TestConfiguration.memoryLeakThreshold)
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}
