//
//  Network/OpenSimProtocol.swift
//  Storm
//
//  Enhanced OpenSim/SecondLife LLUDP protocol with complete handshake flow
//  Implements UseCircuitCode, RegionHandshake, and CompleteAgentMovement sequences
//  FIXED: Replaced fatalError with graceful handshake reset for reconnection scenarios
//
//  Created for Finalverse Storm - Complete Protocol Implementation

import Foundation
import simd

// MARK: - Protocol Constants

enum ProtocolConstants {
    static let protocolVersion: UInt8 = 1
    static let headerSize = 6
    static let maxPacketSize = 1500
    static let ackFlag: UInt8 = 0x80
    static let resendFlag: UInt8 = 0x40
    static let reliableFlag: UInt8 = 0x20
    static let zerocodeFlag: UInt8 = 0x10
}

// MARK: - Enhanced Message Types (Added handshake messages)

enum MessageType: UInt32, CaseIterable {
    case testMessage = 1
    case testMessageReply = 2
    case packetAck = 3
    case openCircuit = 4
    case closeCircuit = 5
    
    // Authentication & Handshake Flow
    case useCircuitCode = 6
    case completeAgentMovement = 7
    case regionHandshake = 21
    case regionHandshakeReply = 22
    case agentMovementComplete = 25
    
    // Agent updates
    case agentUpdate = 8
    case agentAnimation = 9
    case agentRequestSit = 10
    
    // Object updates
    case objectUpdate = 11
    case objectUpdateCompressed = 12
    case objectUpdateCached = 13
    case killObject = 14
    
    // Communication
    case chatFromSimulator = 15
    case chatFromViewer = 16
    case instantMessage = 17
    
    // Movement and teleportation
    case teleportLocationRequest = 18
    case teleportLocal = 19
    case teleportLandmarkRequest = 20
    case teleportFinish = 27
    case teleportFailed = 28
    
    // Region and sim info
    case simulatorViewerTimeMessage = 23
    case enableSimulator = 29
    case disableSimulator = 30
    
    // Ping and statistics
    case startPingCheck = 24
    case completePingCheck = 26
    case pingCheck = 31
    
    var needsAck: Bool {
        switch self {
        case .agentUpdate, .packetAck, .pingCheck, .completePingCheck:
            return false
        default:
            return true
        }
    }
    
    var isHandshakeMessage: Bool {
        switch self {
        case .useCircuitCode, .regionHandshake, .regionHandshakeReply, .completeAgentMovement, .agentMovementComplete:
            return true
        default:
            return false
        }
    }
}

// MARK: - Enhanced Packet Structure

struct OpenSimPacket {
    let messageType: MessageType
    let payload: Data
    let sequenceNumber: UInt32
    let needsAck: Bool
    let ackNumber: UInt32?
    let isReliable: Bool
    let isResent: Bool
    
    init(messageType: MessageType, payload: Data, sequenceNumber: UInt32, needsAck: Bool? = nil, ackNumber: UInt32? = nil, isReliable: Bool? = nil, isResent: Bool = false) {
        self.messageType = messageType
        self.payload = payload
        self.sequenceNumber = sequenceNumber
        self.needsAck = needsAck ?? messageType.needsAck
        self.ackNumber = ackNumber
        self.isReliable = isReliable ?? messageType.isHandshakeMessage
        self.isResent = isResent
    }
    
    static func parse(_ data: Data) throws -> OpenSimPacket {
        guard data.count >= ProtocolConstants.headerSize else {
            throw ProtocolError.invalidPacketSize
        }
        
        var offset = 0
        
        // Parse flags and sequence number
        let flags = data[offset]
        offset += 1
        
        let needsAck = (flags & ProtocolConstants.ackFlag) != 0
        let isResent = (flags & ProtocolConstants.resendFlag) != 0
        let isReliable = (flags & ProtocolConstants.reliableFlag) != 0
        
        let sequenceNumber = data.withUnsafeBytes { bytes in
            return UInt32(bigEndian: bytes.load(fromByteOffset: offset, as: UInt32.self))
        }
        offset += 4
        
        // Parse message type
        let messageTypeRaw = data.withUnsafeBytes { bytes in
            return UInt32(bigEndian: bytes.load(fromByteOffset: offset, as: UInt32.self))
        }
        offset += 4
        
        guard let messageType = MessageType(rawValue: messageTypeRaw) else {
            throw ProtocolError.unknownMessageType(messageTypeRaw)
        }
        
        // Extract payload
        let payload = data.subdata(in: offset..<data.count)
        
        // Check for ACK number if this is an ACK packet
        var ackNumber: UInt32?
        if messageType == .packetAck && payload.count >= 4 {
            ackNumber = payload.withUnsafeBytes { bytes in
                return UInt32(bigEndian: bytes.load(fromByteOffset: 0, as: UInt32.self))
            }
        }
        
        return OpenSimPacket(
            messageType: messageType,
            payload: payload,
            sequenceNumber: sequenceNumber,
            needsAck: needsAck,
            ackNumber: ackNumber,
            isReliable: isReliable,
            isResent: isResent
        )
    }
    
    func serialize() throws -> Data {
        var data = Data()
        
        // Enhanced flags
        var flags: UInt8 = 0
        if needsAck { flags |= ProtocolConstants.ackFlag }
        if isResent { flags |= ProtocolConstants.resendFlag }
        if isReliable { flags |= ProtocolConstants.reliableFlag }
        data.append(flags)
        
        // Sequence number (big endian)
        var seqNum = sequenceNumber.bigEndian
        data.append(Data(bytes: &seqNum, count: 4))
        
        // Message type (big endian)
        var msgType = messageType.rawValue.bigEndian
        data.append(Data(bytes: &msgType, count: 4))
        
        // Payload
        data.append(payload)
        
        return data
    }
}

// MARK: - Base Message Protocol

protocol OpenSimMessage {
    var type: MessageType { get }
    var needsAck: Bool { get }
    func serialize() throws -> Data
}

// MARK: - Authentication Messages (Enhanced)

struct UseCircuitCodeMessage: OpenSimMessage {
    let type = MessageType.useCircuitCode
    let needsAck = true
    
    let circuitCode: UInt32
    let sessionID: UUID
    let agentID: UUID
    
    func serialize() throws -> Data {
        var data = Data()
        
        // Circuit code (4 bytes)
        var code = circuitCode.bigEndian
        data.append(Data(bytes: &code, count: 4))
        
        // Session ID (16 bytes)
        data.append(withUnsafeBytes(of: sessionID.uuid) { Data($0) })
        
        // Agent ID (16 bytes)
        let agentIDData = withUnsafeBytes(of: agentID.uuid) { Data($0) }
        data.append(agentIDData)
        
        return data
    }
    
    static func parse(_ data: Data) throws -> UseCircuitCodeMessage {
        guard data.count >= 36 else { // 4 + 16 + 16
            throw ProtocolError.insufficientData
        }
        
        let circuitCode = data.readUInt32(at: 0)
        let sessionID = UUID(uuid: data.subdata(in: 4..<20).withUnsafeBytes { $0.load(as: uuid_t.self) })
        let agentID = UUID(uuid: data.subdata(in: 20..<36).withUnsafeBytes { $0.load(as: uuid_t.self) })
        
        return UseCircuitCodeMessage(
            circuitCode: circuitCode,
            sessionID: sessionID,
            agentID: agentID
        )
    }
}

struct CompleteAgentMovementMessage: OpenSimMessage {
    let type = MessageType.completeAgentMovement
    let needsAck = true
    
    let agentID: UUID
    let sessionID: UUID
    let circuitCode: UInt32
    
    func serialize() throws -> Data {
        var data = Data()
        
        // Agent ID
        let agentIDData = withUnsafeBytes(of: agentID.uuid) { Data($0) }
        data.append(agentIDData)
        
        // Session ID
        let sessionIDData = withUnsafeBytes(of: sessionID.uuid) { Data($0) }
        data.append(sessionIDData)
        
        // Circuit code
        var code = circuitCode.bigEndian
        data.append(Data(bytes: &code, count: 4))
        
        return data
    }
    
    static func parse(_ data: Data) throws -> CompleteAgentMovementMessage {
        guard data.count >= 36 else { // 16 + 16 + 4
            throw ProtocolError.insufficientData
        }
        
        let agentID = UUID(uuid: data.subdata(in: 0..<16).withUnsafeBytes { $0.load(as: uuid_t.self) })
        let sessionID = UUID(uuid: data.subdata(in: 16..<32).withUnsafeBytes { $0.load(as: uuid_t.self) })
        let circuitCode = data.readUInt32(at: 32)
        
        return CompleteAgentMovementMessage(
            agentID: agentID,
            sessionID: sessionID,
            circuitCode: circuitCode
        )
    }
}

// MARK: - NEW: RegionHandshake Message (Server to Client)

struct RegionHandshakeMessage: OpenSimMessage {
    let type = MessageType.regionHandshake
    let needsAck = true
    
    let regionFlags: UInt64
    let simAccess: UInt8
    let simName: String
    let simOwner: UUID
    let isEstateManager: Bool
    let waterHeight: Float
    let billableFactor: Float
    let cacheID: UUID
    let regionHandle: UInt64
    
    static func parse(_ data: Data) throws -> RegionHandshakeMessage {
        guard data.count >= 50 else { // Minimum expected size
            throw ProtocolError.insufficientData
        }
        
        var offset = 0
        
        let regionFlags = data.readUInt64(at: offset)
        offset += 8
        
        let simAccess = data[offset]
        offset += 1
        
        // Parse sim name (variable length string)
        let simNameLength = Int(data[offset])
        offset += 1
        guard offset + simNameLength <= data.count else {
            throw ProtocolError.insufficientData
        }
        let simName = String(data: data.subdata(in: offset..<offset+simNameLength), encoding: .utf8) ?? ""
        offset += simNameLength
        
        guard offset + 16 <= data.count else {
            throw ProtocolError.insufficientData
        }
        let simOwner = UUID(uuid: data.subdata(in: offset..<offset+16).withUnsafeBytes { $0.load(as: uuid_t.self) })
        offset += 16
        
        let isEstateManager = data[offset] != 0
        offset += 1
        
        let waterHeight = data.readFloat(at: offset)
        offset += 4
        
        let billableFactor = data.readFloat(at: offset)
        offset += 4
        
        let cacheID = UUID(uuid: data.subdata(in: offset..<offset+16).withUnsafeBytes { $0.load(as: uuid_t.self) })
        offset += 16
        
        let regionHandle = data.readUInt64(at: offset)
        
        return RegionHandshakeMessage(
            regionFlags: regionFlags,
            simAccess: simAccess,
            simName: simName,
            simOwner: simOwner,
            isEstateManager: isEstateManager,
            waterHeight: waterHeight,
            billableFactor: billableFactor,
            cacheID: cacheID,
            regionHandle: regionHandle
        )
    }
    
    func serialize() throws -> Data {
        // This would be used if we need to send RegionHandshake (typically server->client only)
        throw ProtocolError.serializationError("RegionHandshake is typically server-sent only")
    }
}

// MARK: - NEW: RegionHandshakeReply Message (Client to Server)

struct RegionHandshakeReplyMessage: OpenSimMessage {
    let type = MessageType.regionHandshakeReply
    let needsAck = true
    
    let agentID: UUID
    let sessionID: UUID
    let flags: UInt32
    
    init(agentID: UUID, sessionID: UUID, flags: UInt32 = 0) {
        self.agentID = agentID
        self.sessionID = sessionID
        self.flags = flags
    }
    
    func serialize() throws -> Data {
        var data = Data()
        
        // Agent ID (16 bytes)
        let agentIDData = withUnsafeBytes(of: agentID.uuid) { Data($0) }
        data.append(agentIDData)
        
        // Session ID (16 bytes)
        let sessionIDData = withUnsafeBytes(of: sessionID.uuid) { Data($0) }
        data.append(sessionIDData)
        
        // Flags (4 bytes)
        var flagsBytes = flags.bigEndian
        data.append(Data(bytes: &flagsBytes, count: 4))
        
        return data
    }
}

// MARK: - NEW: AgentMovementComplete Message (Server confirmation)

struct AgentMovementCompleteMessage: OpenSimMessage {
    let type = MessageType.agentMovementComplete
    let needsAck = true
    
    let agentID: UUID
    let sessionID: UUID
    let position: SIMD3<Float>
    let lookAt: SIMD3<Float>
    let regionHandle: UInt64
    let timestamp: UInt32
    
    static func parse(_ data: Data) throws -> AgentMovementCompleteMessage {
        guard data.count >= 60 else { // 16 + 16 + 12 + 12 + 8 + 4
            throw ProtocolError.insufficientData
        }
        
        let agentID = UUID(uuid: data.subdata(in: 0..<16).withUnsafeBytes { $0.load(as: uuid_t.self) })
        let sessionID = UUID(uuid: data.subdata(in: 16..<32).withUnsafeBytes { $0.load(as: uuid_t.self) })
        let position = data.readVector3(at: 32)
        let lookAt = data.readVector3(at: 44)
        let regionHandle = data.readUInt64(at: 56)
        let timestamp = data.readUInt32(at: 64)
        
        return AgentMovementCompleteMessage(
            agentID: agentID,
            sessionID: sessionID,
            position: position,
            lookAt: lookAt,
            regionHandle: regionHandle,
            timestamp: timestamp
        )
    }
    
    func serialize() throws -> Data {
        var data = Data()
        
        // Agent ID
        let agentIDData = withUnsafeBytes(of: agentID.uuid) { Data($0) }
        data.append(agentIDData)
        
        // Session ID
        let sessionIDData = withUnsafeBytes(of: sessionID.uuid) { Data($0) }
        data.append(sessionIDData)
        
        // Position
        let positionArray = [position.x, position.y, position.z]
        for component in positionArray {
            var floatBytes = component.bitPattern.bigEndian
            data.append(Data(bytes: &floatBytes, count: 4))
        }
        
        // Look at
        let lookAtArray = [lookAt.x, lookAt.y, lookAt.z]
        for component in lookAtArray {
            var floatBytes = component.bitPattern.bigEndian
            data.append(Data(bytes: &floatBytes, count: 4))
        }
        
        // Region handle
        var handleBytes = regionHandle.bigEndian
        data.append(Data(bytes: &handleBytes, count: 8))
        
        // Timestamp
        var timestampBytes = timestamp.bigEndian
        data.append(Data(bytes: &timestampBytes, count: 4))
        
        return data
    }
}

// MARK: - Agent Update Messages (Existing - Enhanced)

struct AgentUpdateMessage: OpenSimMessage {
    let type = MessageType.agentUpdate
    let needsAck = false
    
    let agentID: UUID
    let sessionID: UUID
    let bodyRotation: simd_quatf
    let headRotation: simd_quatf
    let state: UInt8
    let position: SIMD3<Float>
    let lookAt: SIMD3<Float>
    let upAxis: SIMD3<Float>
    let leftAxis: SIMD3<Float>
    let cameraCenter: SIMD3<Float>
    let cameraAtAxis: SIMD3<Float>
    let cameraLeftAxis: SIMD3<Float>
    let cameraUpAxis: SIMD3<Float>
    let far: Float
    let aspectRatio: Float
    let throttles: [UInt8]
    let controlFlags: UInt32
    let flags: UInt8
    
    func serialize() throws -> Data {
        var data = Data()
        
        // Agent ID
        let agentIDData = withUnsafeBytes(of: agentID.uuid) { Data($0) }
        data.append(agentIDData)
        
        // Session ID
        let sessionIDData = withUnsafeBytes(of: sessionID.uuid) { Data($0) }
        data.append(sessionIDData)
        
        // Body rotation (quaternion as 4 floats)
        let bodyRot = [bodyRotation.vector.x, bodyRotation.vector.y, bodyRotation.vector.z, bodyRotation.vector.w]
        for component in bodyRot {
            var floatBytes = component.bitPattern.bigEndian
            data.append(Data(bytes: &floatBytes, count: 4))
        }
        
        // Head rotation (quaternion as 4 floats)
        let headRot = [headRotation.vector.x, headRotation.vector.y, headRotation.vector.z, headRotation.vector.w]
        for component in headRot {
            var floatBytes = component.bitPattern.bigEndian
            data.append(Data(bytes: &floatBytes, count: 4))
        }
        
        // State
        data.append(state)
        
        // Position (3 floats)
        let positionArray = [position.x, position.y, position.z]
        for component in positionArray {
            var floatBytes = component.bitPattern.bigEndian
            data.append(Data(bytes: &floatBytes, count: 4))
        }
        
        // Look at (3 floats)
        let lookAtArray = [lookAt.x, lookAt.y, lookAt.z]
        for component in lookAtArray {
            var floatBytes = component.bitPattern.bigEndian
            data.append(Data(bytes: &floatBytes, count: 4))
        }
        
        // Up axis (3 floats)
        let upAxisArray = [upAxis.x, upAxis.y, upAxis.z]
        for component in upAxisArray {
            var floatBytes = component.bitPattern.bigEndian
            data.append(Data(bytes: &floatBytes, count: 4))
        }
        
        // Left axis (3 floats)
        let leftAxisArray = [leftAxis.x, leftAxis.y, leftAxis.z]
        for component in leftAxisArray {
            var floatBytes = component.bitPattern.bigEndian
            data.append(Data(bytes: &floatBytes, count: 4))
        }
        
        // Camera center (3 floats)
        let centerArray = [cameraCenter.x, cameraCenter.y, cameraCenter.z]
        for component in centerArray {
            var floatBytes = component.bitPattern.bigEndian
            data.append(Data(bytes: &floatBytes, count: 4))
        }
        
        // Camera at axis (3 floats)
        let atAxisArray = [cameraAtAxis.x, cameraAtAxis.y, cameraAtAxis.z]
        for component in atAxisArray {
            var floatBytes = component.bitPattern.bigEndian
            data.append(Data(bytes: &floatBytes, count: 4))
        }
        
        // Camera left axis (3 floats)
        let leftAxisArray2 = [cameraLeftAxis.x, cameraLeftAxis.y, cameraLeftAxis.z]
        for component in leftAxisArray2 {
            var floatBytes = component.bitPattern.bigEndian
            data.append(Data(bytes: &floatBytes, count: 4))
        }
        
        // Camera up axis (3 floats)
        let upAxisArray2 = [cameraUpAxis.x, cameraUpAxis.y, cameraUpAxis.z]
        for component in upAxisArray2 {
            var floatBytes = component.bitPattern.bigEndian
            data.append(Data(bytes: &floatBytes, count: 4))
        }
        
        // Far clip distance
        var farBytes = far.bitPattern.bigEndian
        data.append(Data(bytes: &farBytes, count: 4))
        
        // Aspect ratio
        var aspectBytes = aspectRatio.bitPattern.bigEndian
        data.append(Data(bytes: &aspectBytes, count: 4))
        
        // Throttles (4 bytes)
        for i in 0..<4 {
            data.append(i < throttles.count ? throttles[i] : 0)
        }
        
        // Control flags
        var controlFlagsBytes = controlFlags.bigEndian
        data.append(Data(bytes: &controlFlagsBytes, count: 4))
        
        // Flags
        data.append(flags)
        
        return data
    }
}

// MARK: - Object Update Messages (Existing - Enhanced)

struct ObjectUpdateMessage: OpenSimMessage {
    let type = MessageType.objectUpdate
    let needsAck = true
    
    let regionHandle: UInt64
    let timeDilation: UInt16
    let objects: [ObjectUpdateData]
    
    struct ObjectUpdateData {
        let localID: UInt32
        let state: UInt8
        let fullID: UUID
        let crc: UInt32
        let pcode: UInt8
        let material: UInt8
        let clickAction: UInt8
        let scale: SIMD3<Float>
        let position: SIMD3<Float>
        let rotation: simd_quatf
        let flags: UInt32
        let pathCurve: UInt8
        let profileCurve: UInt8
        let pathBegin: UInt16
        let pathEnd: UInt16
        let pathScaleX: UInt8
        let pathScaleY: UInt8
        let pathShearX: UInt8
        let pathShearY: UInt8
        let pathTwist: Int8
        let pathTwistBegin: Int8
        let pathRadiusOffset: Int8
        let pathTaperX: Int8
        let pathTaperY: Int8
        let pathRevolutions: UInt8
        let pathSkew: Int8
        let profileBegin: UInt16
        let profileEnd: UInt16
        let profileHollow: UInt16
    }
    
    static func parse(_ data: Data) throws -> ObjectUpdateMessage {
        var offset = 0
        
        guard offset + 10 <= data.count else {
            throw ProtocolError.insufficientData
        }
        
        // Parse region handle
        let regionHandle = data.readUInt64(at: offset)
        offset += 8
        
        // Parse time dilation
        let timeDilation = data.readUInt16(at: offset)
        offset += 2
        
        // Parse object count
        let objectCount = data[offset]
        offset += 1
        
        var objects: [ObjectUpdateData] = []
        
        for _ in 0..<objectCount {
            // Parse each object (enhanced parsing)
            guard offset + 21 <= data.count else { break }
            
            let localID = data.readUInt32(at: offset)
            offset += 4
            
            let state = data[offset]
            offset += 1
            
            let fullID = UUID(uuid: data.subdata(in: offset..<offset+16).withUnsafeBytes { $0.load(as: uuid_t.self) })
            offset += 16
            
            // For now, create simplified object data
            // Full parsing would require more complex state machine
            let objectData = ObjectUpdateData(
                localID: localID,
                state: state,
                fullID: fullID,
                crc: 0, pcode: 9, material: 3, clickAction: 0, // Default primitive values
                scale: SIMD3<Float>(1, 1, 1),
                position: SIMD3<Float>(Float(localID % 10), 1, Float(localID % 5)),
                rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                flags: 0, pathCurve: 16, profileCurve: 1,
                pathBegin: 0, pathEnd: 0, pathScaleX: 100, pathScaleY: 100,
                pathShearX: 0, pathShearY: 0, pathTwist: 0, pathTwistBegin: 0,
                pathRadiusOffset: 0, pathTaperX: 0, pathTaperY: 0,
                pathRevolutions: 1, pathSkew: 0, profileBegin: 0,
                profileEnd: 0, profileHollow: 0
            )
            
            objects.append(objectData)
            
            // Skip remaining object data for simplified parsing
            // Real implementation would parse all fields based on UpdateFlags
        }
        
        return ObjectUpdateMessage(
            regionHandle: regionHandle,
            timeDilation: timeDilation,
            objects: objects
        )
    }
    
    func serialize() throws -> Data {
        // Implementation for serializing object updates
        // (Would be used for sending object updates, less common for client)
        return Data()
    }
}

// MARK: - Communication Messages (Existing)

struct ChatFromSimulatorMessage {
    let fromName: String
    let sourceID: UUID
    let ownerID: UUID
    let sourceType: UInt8
    let chatType: UInt8
    let audible: UInt8
    let position: SIMD3<Float>
    let message: String
    
    init(fromName: String, sourceID: UUID, ownerID: UUID, sourceType: UInt8, chatType: UInt8, audible: UInt8, position: SIMD3<Float>, message: String) {
        self.fromName = fromName
        self.sourceID = sourceID
        self.ownerID = ownerID
        self.sourceType = sourceType
        self.chatType = chatType
        self.audible = audible
        self.position = position
        self.message = message
    }
    
    static func parse(_ data: Data) throws -> ChatFromSimulatorMessage {
        var offset = 0

        // Parse from name (variable length string)
        guard offset < data.count else { throw ProtocolError.insufficientData }
        let nameLength = Int(data[offset])
        offset += 1

        guard offset + nameLength <= data.count else { throw ProtocolError.insufficientData }
        let fromName = String(data: data.subdata(in: offset..<offset+nameLength), encoding: .utf8) ?? ""
        offset += nameLength

        // Parse source ID
        guard offset + 16 <= data.count else { throw ProtocolError.insufficientData }
        let sourceID = UUID(uuid: data.subdata(in: offset..<offset+16).withUnsafeBytes { $0.load(as: uuid_t.self) })
        offset += 16

        // Parse owner ID
        guard offset + 16 <= data.count else { throw ProtocolError.insufficientData }
        let ownerID = UUID(uuid: data.subdata(in: offset..<offset+16).withUnsafeBytes { $0.load(as: uuid_t.self) })
        offset += 16

        // Parse sourceType, chatType, audible (each 1 byte)
        guard offset + 3 <= data.count else { throw ProtocolError.insufficientData }
        let sourceType = data[offset]
        offset += 1
        let chatType = data[offset]
        offset += 1
        let audible = data[offset]
        offset += 1

        // Parse position
        guard offset + 12 <= data.count else { throw ProtocolError.insufficientData }
        let position = data.readVector3(at: offset)
        offset += 12

        // Parse message (variable length string)
        guard offset + 2 <= data.count else { throw ProtocolError.insufficientData }
        let messageLength = Int(data.readUInt16(at: offset))
        offset += 2

        guard offset + messageLength <= data.count else { throw ProtocolError.insufficientData }
        let message = String(data: data.subdata(in: offset..<offset+messageLength), encoding: .utf8) ?? ""

        return ChatFromSimulatorMessage(
            fromName: fromName,
            sourceID: sourceID,
            ownerID: ownerID,
            sourceType: sourceType,
            chatType: chatType,
            audible: audible,
            position: position,
            message: message
        )
    }
}

// MARK: - Teleportation Messages (Existing)

struct TeleportLocationRequestMessage: OpenSimMessage {
    let type = MessageType.teleportLocationRequest
    let needsAck = true
    
    let agentID: UUID
    let sessionID: UUID
    let regionHandle: UInt64
    let position: SIMD3<Float>
    let lookAt: SIMD3<Float>
    
    func serialize() throws -> Data {
        var data = Data()
        
        // Agent ID
        let agentIDData = withUnsafeBytes(of: agentID.uuid) { Data($0) }
        data.append(agentIDData)
        
        // Session ID
        let sessionIDData = withUnsafeBytes(of: sessionID.uuid) { Data($0) }
        data.append(sessionIDData)
        
        // Region handle
        var handle = regionHandle.bigEndian
        data.append(Data(bytes: &handle, count: 8))
        
        // Position (3 floats)
        let positionArray = [position.x, position.y, position.z]
        for component in positionArray {
            var floatBytes = component.bitPattern.bigEndian
            data.append(Data(bytes: &floatBytes, count: 4))
        }
        
        // Look at (3 floats)
        let lookAtArray = [lookAt.x, lookAt.y, lookAt.z]
        for component in lookAtArray {
            var floatBytes = component.bitPattern.bigEndian
            data.append(Data(bytes: &floatBytes, count: 4))
        }
        
        return data
    }
}

// MARK: - Ping Messages (Existing)

struct PingCheckMessage: OpenSimMessage {
    let type = MessageType.pingCheck
    let needsAck = false
    
    func serialize() throws -> Data {
        var data = Data()
        
        // Ping ID (timestamp)
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
        var timestampBytes = timestamp.bigEndian
        data.append(Data(bytes: &timestampBytes, count: 8))
        
        return data
    }
}

struct CompletePingCheckMessage: OpenSimMessage {
    let type = MessageType.completePingCheck
    let needsAck = false
    
    let pingID: UInt64
    
    func serialize() throws -> Data {
        var data = Data()
        
        // Echo back the ping ID
        var pingIDBytes = pingID.bigEndian
        data.append(Data(bytes: &pingIDBytes, count: 8))
        
        return data
    }
    
    static func parse(_ data: Data) throws -> CompletePingCheckMessage {
        guard data.count >= 8 else {
            throw ProtocolError.insufficientData
        }
        
        let pingID = data.readUInt64(at: 0)
        return CompletePingCheckMessage(pingID: pingID)
    }
}

struct LogoutRequestMessage: OpenSimMessage {
    let type = MessageType.closeCircuit
    let needsAck = true
    
    let agentID: UUID
    let sessionID: UUID
    
    func serialize() throws -> Data {
        var data = Data()
        
        // Agent ID
        let agentIDData = withUnsafeBytes(of: agentID.uuid) { Data($0) }
        data.append(agentIDData)
        
        // Session ID
        let sessionIDData = withUnsafeBytes(of: sessionID.uuid) { Data($0) }
        data.append(sessionIDData)
        
        return data
    }
}

// MARK: - Protocol Errors (Existing)

enum ProtocolError: Error {
    case invalidPacketSize
    case unknownMessageType(UInt32)
    case insufficientData
    case parsingError(String)
    case serializationError(String)
    
    var localizedDescription: String {
        switch self {
        case .invalidPacketSize:
            return "Invalid packet size"
        case .unknownMessageType(let type):
            return "Unknown message type: \(type)"
        case .insufficientData:
            return "Insufficient data for parsing"
        case .parsingError(let message):
            return "Parsing error: \(message)"
        case .serializationError(let message):
            return "Serialization error: \(message)"
        }
    }
}

// MARK: - Helper Extensions (Enhanced)

extension UUID {
    var data: Data {
        return withUnsafeBytes(of: uuid) { Data($0) }
    }
}

extension Data {
    func readUInt32(at offset: Int) -> UInt32 {
        return withUnsafeBytes { bytes in
            return UInt32(bigEndian: bytes.load(fromByteOffset: offset, as: UInt32.self))
        }
    }
    
    func readUInt16(at offset: Int) -> UInt16 {
        return withUnsafeBytes { bytes in
            return UInt16(bigEndian: bytes.load(fromByteOffset: offset, as: UInt16.self))
        }
    }
    
    func readUInt64(at offset: Int) -> UInt64 {
        return withUnsafeBytes { bytes in
            return UInt64(bigEndian: bytes.load(fromByteOffset: offset, as: UInt64.self))
        }
    }
    
    func readFloat(at offset: Int) -> Float {
        return withUnsafeBytes { bytes in
            let bits = UInt32(bigEndian: bytes.load(fromByteOffset: offset, as: UInt32.self))
            return Float(bitPattern: bits)
        }
    }
    
    func readVector3(at offset: Int) -> SIMD3<Float> {
        return SIMD3<Float>(
            readFloat(at: offset),
            readFloat(at: offset + 4),
            readFloat(at: offset + 8)
        )
    }
    
    func readQuaternion(at offset: Int) -> simd_quatf {
        return simd_quatf(
            ix: readFloat(at: offset),
            iy: readFloat(at: offset + 4),
            iz: readFloat(at: offset + 8),
            r: readFloat(at: offset + 12)
        )
    }
    
    func readString(at offset: Int, length: Int) -> String {
        let stringData = subdata(in: offset..<offset+length)
        return String(data: stringData, encoding: .utf8) ?? ""
    }
}

// MARK: - NEW: Handshake State Management

enum HandshakeState: Equatable {
    case notStarted
    case sentUseCircuitCode
    case receivedRegionHandshake
    case sentRegionHandshakeReply
    case sentCompleteAgentMovement
    case receivedAgentMovementComplete
    case handshakeComplete
    case failed(String)
    
    static func == (lhs: HandshakeState, rhs: HandshakeState) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted),
             (.sentUseCircuitCode, .sentUseCircuitCode),
             (.receivedRegionHandshake, .receivedRegionHandshake),
             (.sentRegionHandshakeReply, .sentRegionHandshakeReply),
             (.sentCompleteAgentMovement, .sentCompleteAgentMovement),
             (.receivedAgentMovementComplete, .receivedAgentMovementComplete),
             (.handshakeComplete, .handshakeComplete):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
    
    var isComplete: Bool {
        if case .handshakeComplete = self {
            return true
        } else {
            return false
        }
    }
    
    var description: String {
        switch self {
        case .notStarted:
            return "Not Started"
        case .sentUseCircuitCode:
            return "Sent UseCircuitCode"
        case .receivedRegionHandshake:
            return "Received RegionHandshake"
        case .sentRegionHandshakeReply:
            return "Sent RegionHandshakeReply"
        case .sentCompleteAgentMovement:
            return "Sent CompleteAgentMovement"
        case .receivedAgentMovementComplete:
            return "Received AgentMovementComplete"
        case .handshakeComplete:
            return "Handshake Complete"
        case .failed(let error):
            return "Failed: \(error)"
        }
    }
}

// MARK: - FIXED: Handshake Manager (Replaces previous implementation)

class OpenSimHandshakeManager {
    private(set) var state: HandshakeState = .notStarted
    private var agentID: UUID
    private var sessionID: UUID
    private var circuitCode: UInt32
    private var handshakeStartTime: Date?
    
    // Callbacks for state changes
    var onStateChanged: ((HandshakeState) -> Void)?
    var onHandshakeComplete: ((RegionHandshakeMessage) -> Void)?
    var onHandshakeFailed: ((String) -> Void)?
    
    init(agentID: UUID, sessionID: UUID, circuitCode: UInt32) {
        self.agentID = agentID
        self.sessionID = sessionID
        self.circuitCode = circuitCode
    }
    
    // FIXED: Replace fatalError with graceful handling
    func startHandshake() -> UseCircuitCodeMessage {
        // If handshake is already in progress, reset it and start fresh
        if !state.isComplete && state != .notStarted {
            print("[⚠️] Handshake already started in state: \(state.description)")
            print("[🔄] Resetting handshake to allow fresh start")
            reset()
        }
        
        // Ensure we're in the correct state
        guard case .notStarted = state else {
            print("[❌] Handshake in unexpected state after reset: \(state.description)")
            // Force reset if somehow still not in the right state
            reset()
            return startHandshake()
        }
        
        handshakeStartTime = Date()
        setState(.sentUseCircuitCode)
        
        let message = UseCircuitCodeMessage(
            circuitCode: circuitCode,
            sessionID: sessionID,
            agentID: agentID
        )
        
        print("[🤝] Handshake: Starting with UseCircuitCode (circuit: \(circuitCode))")
        return message
    }
    
    func handleRegionHandshake(_ message: RegionHandshakeMessage) -> RegionHandshakeReplyMessage? {
        guard case .sentUseCircuitCode = state else {
            print("[⚠️] Received RegionHandshake in wrong state: \(state.description)")
            return nil
        }
        
        setState(.receivedRegionHandshake)
        print("[🤝] Handshake: Received RegionHandshake for region '\(message.simName)'")
        
        // Send reply
        let reply = RegionHandshakeReplyMessage(agentID: agentID, sessionID: sessionID)
        setState(.sentRegionHandshakeReply)
        print("[🤝] Handshake: Sending RegionHandshakeReply")
        
        return reply
    }
    
    func createCompleteAgentMovement() -> CompleteAgentMovementMessage? {
        guard case .sentRegionHandshakeReply = state else {
            print("[⚠️] Cannot send CompleteAgentMovement in state: \(state.description)")
            return nil
        }
        
        setState(.sentCompleteAgentMovement)
        let message = CompleteAgentMovementMessage(
            agentID: agentID,
            sessionID: sessionID,
            circuitCode: circuitCode
        )
        
        print("[🤝] Handshake: Sending CompleteAgentMovement")
        return message
    }
    
    func handleAgentMovementComplete(_ message: AgentMovementCompleteMessage) {
        guard case .sentCompleteAgentMovement = state else {
            print("[⚠️] Received AgentMovementComplete in wrong state: \(state.description)")
            return
        }
        
        setState(.receivedAgentMovementComplete)
        setState(.handshakeComplete)
        
        let duration = handshakeStartTime?.timeIntervalSinceNow ?? 0
        print("[✅] Handshake: Complete! Agent positioned at \(message.position) (took \(abs(duration))s)")
        
        // Create a RegionHandshakeMessage for the callback (mock data for now)
        let regionInfo = RegionHandshakeMessage(
            regionFlags: 0,
            simAccess: 0,
            simName: "Connected Region",
            simOwner: UUID(),
            isEstateManager: false,
            waterHeight: 20.0,
            billableFactor: 1.0,
            cacheID: UUID(),
            regionHandle: message.regionHandle
        )
        
        onHandshakeComplete?(regionInfo)
    }
    
    func handleHandshakeFailure(_ error: String) {
        setState(.failed(error))
        print("[❌] Handshake failed: \(error)")
        onHandshakeFailed?(error)
    }
    
    // ENHANCED: Reset method with better logging
    func reset() {
        let oldState = state
        state = .notStarted
        handshakeStartTime = nil
        print("[🔄] Handshake manager reset: \(oldState.description) → \(state.description)")
    }
    
    // ENHANCED: Update session data for new connection
    func updateSessionData(agentID: UUID, sessionID: UUID, circuitCode: UInt32) {
        self.agentID = agentID
        self.sessionID = sessionID
        self.circuitCode = circuitCode
        print("[🆔] Handshake session data updated:")
        print("  AgentID: \(agentID)")
        print("  SessionID: \(sessionID)")
        print("  CircuitCode: \(circuitCode)")
    }
    
    private func setState(_ newState: HandshakeState) {
        let oldState = state
        state = newState
        
        print("[🤝] Handshake state: \(oldState.description) → \(newState.description)")
        onStateChanged?(newState)
    }
    
    // Timeout checking
    func checkTimeout() -> Bool {
        guard let startTime = handshakeStartTime,
              !state.isComplete,
              ({
                  if case .failed = state {
                      return false
                  } else {
                      return true
                  }
              })()
        else {
            return false
        }
        
        let timeout: TimeInterval = 30.0 // 30 second timeout
        if Date().timeIntervalSince(startTime) > timeout {
            handleHandshakeFailure("Handshake timeout after \(timeout) seconds")
            return true
        }
        
        return false
    }
    
    // ENHANCED: Get current session info
    func getSessionInfo() -> (agentID: UUID, sessionID: UUID, circuitCode: UInt32) {
        return (agentID: agentID, sessionID: sessionID, circuitCode: circuitCode)
    }
    
    // ENHANCED: Check if ready for next handshake step
    func canProceedToNextStep() -> Bool {
        switch state {
        case .notStarted, .handshakeComplete:
            return true
        case .failed:
            return true // Can restart after failure
        default:
            return false // In progress
        }
    }
    
    // ENHANCED: Force restart handshake (for recovery scenarios)
    func forceRestart() {
        print("[🔄] Force restarting handshake from state: \(state.description)")
        reset()
    }
}
