// Network/OpenSimProtocol.swift
//
// OpenSim/SecondLife LLUDP protocol message definitions and parsing
// Implements the core message types for avatar movement, object updates, and communication
//
// Created for Finalverse Storm - Protocol Implementation

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

// MARK: - Message Types

enum MessageType: UInt32, CaseIterable {
    case testMessage = 1
    case testMessageReply = 2
    case packetAck = 3
    case openCircuit = 4
    case closeCircuit = 5
    
    // Authentication
    case useCircuitCode = 6
    case completeAgentMovement = 7
    
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
    
    // Region and sim info
    case regionHandshake = 21
    case regionHandshakeReply = 22
    case simulatorViewerTimeMessage = 23
    
    // Ping and statistics
    case startPingCheck = 24
    case completePingCheck = 25
    case pingCheck = 26
    
    var needsAck: Bool {
        switch self {
        case .agentUpdate, .packetAck:
            return false
        default:
            return true
        }
    }
}

// MARK: - Packet Structure

struct OpenSimPacket {
    let messageType: MessageType
    let payload: Data
    let sequenceNumber: UInt32
    let needsAck: Bool
    let ackNumber: UInt32?
    
    static func parse(_ data: Data) throws -> OpenSimPacket {
        guard data.count >= ProtocolConstants.headerSize else {
            throw ProtocolError.invalidPacketSize
        }
        
        var offset = 0
        
        // Parse flags and sequence number
        let flags = data[offset]
        offset += 1
        
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
            needsAck: messageType.needsAck,
            ackNumber: ackNumber
        )
    }
    
    func serialize() throws -> Data {
        var data = Data()
        
        // Flags
        var flags: UInt8 = 0
        if needsAck {
            flags |= ProtocolConstants.reliableFlag
        }
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

// MARK: - Authentication Messages

struct UseCircuitCodeMessage: OpenSimMessage {
    let type = MessageType.useCircuitCode
    let needsAck = true
    
    let circuitCode: UInt32
    let sessionID: UUID
    let agentID: UUID
    
    func serialize() throws -> Data {
        var data = Data()
        
        // Circuit code
        var code = circuitCode.bigEndian
        data.append(Data(bytes: &code, count: 4))
        
        // Session ID (16 bytes)
        data.append(withUnsafeBytes(of: sessionID.uuid) { Data($0) })
        
        // Agent ID (16 bytes) - same format as session ID
        let agentIDData = withUnsafeBytes(of: agentID.uuid) { Data($0) }
        data.append(agentIDData)
        
        return data
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
}

// MARK: - Agent Update Messages

struct AgentUpdateMessage: OpenSimMessage {
    let type = MessageType.agentUpdate
    let needsAck = false
    
    let agentID: UUID
    let sessionID: UUID
    let bodyRotation: simd_quatf
    let headRotation: simd_quatf
    let state: UInt8
    let cameraCenter: SIMD3<Float>
    let cameraAtAxis: SIMD3<Float>
    let cameraLeftAxis: SIMD3<Float>
    let cameraUpAxis: SIMD3<Float>
    let far: Float
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
        var headRot = [headRotation.vector.x, headRotation.vector.y, headRotation.vector.z, headRotation.vector.w]
        for component in headRot {
            var floatBytes = component.bitPattern.bigEndian
            data.append(Data(bytes: &floatBytes, count: 4))
        }
        
        // State
        data.append(state)
        
        // Camera center (3 floats)
        var center = [cameraCenter.x, cameraCenter.y, cameraCenter.z]
        for component in center {
            var floatBytes = component.bitPattern.bigEndian
            data.append(Data(bytes: &floatBytes, count: 4))
        }
        
        // Camera at axis (3 floats)
        var atAxis = [cameraAtAxis.x, cameraAtAxis.y, cameraAtAxis.z]
        for component in atAxis {
            var floatBytes = component.bitPattern.bigEndian
            data.append(Data(bytes: &floatBytes, count: 4))
        }
        
        // Camera left axis (3 floats)
        var leftAxis = [cameraLeftAxis.x, cameraLeftAxis.y, cameraLeftAxis.z]
        for component in leftAxis {
            var floatBytes = component.bitPattern.bigEndian
            data.append(Data(bytes: &floatBytes, count: 4))
        }
        
        // Camera up axis (3 floats)
        var upAxis = [cameraUpAxis.x, cameraUpAxis.y, cameraUpAxis.z]
        for component in upAxis {
            var floatBytes = component.bitPattern.bigEndian
            data.append(Data(bytes: &floatBytes, count: 4))
        }
        
        // Far clip distance
        var farBytes = far.bitPattern.bigEndian
        data.append(Data(bytes: &farBytes, count: 4))
        
        // Control flags
        var controlFlagsBytes = controlFlags.bigEndian
        data.append(Data(bytes: &controlFlagsBytes, count: 4))
        
        // Flags
        data.append(flags)
        
        return data
    }
}

// MARK: - Object Update Messages

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
        
        // Parse region handle
        let regionHandle = data.withUnsafeBytes { bytes in
            return UInt64(bigEndian: bytes.load(fromByteOffset: offset, as: UInt64.self))
        }
        offset += 8
        
        // Parse time dilation
        let timeDilation = data.withUnsafeBytes { bytes in
            return UInt16(bigEndian: bytes.load(fromByteOffset: offset, as: UInt16.self))
        }
        offset += 2
        
        // Parse object count
        let objectCount = data[offset]
        offset += 1
        
        var objects: [ObjectUpdateData] = []
        
        for _ in 0..<objectCount {
            // Parse each object (simplified - full parsing would be more complex)
            guard offset + 84 <= data.count else { break }
            
            let localID = data.withUnsafeBytes { bytes in
                return UInt32(bigEndian: bytes.load(fromByteOffset: offset, as: UInt32.self))
            }
            offset += 4
            
            let state = data[offset]
            offset += 1
            
            let fullIDData = data.subdata(in: offset..<offset+16)
            let fullID = UUID(uuid: (
                fullIDData[0], fullIDData[1], fullIDData[2], fullIDData[3],
                fullIDData[4], fullIDData[5], fullIDData[6], fullIDData[7],
                fullIDData[8], fullIDData[9], fullIDData[10], fullIDData[11],
                fullIDData[12], fullIDData[13], fullIDData[14], fullIDData[15]
            ) as uuid_t)
            offset += 16
            
            // Continue parsing object data...
            // (This is a simplified version - full implementation would parse all fields)
            
            let objectData = ObjectUpdateData(
                localID: localID,
                state: state,
                fullID: fullID,
                crc: 0, pcode: 0, material: 0, clickAction: 0,
                scale: SIMD3<Float>(1, 1, 1),
                position: SIMD3<Float>(0, 0, 0),
                rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
                flags: 0, pathCurve: 0, profileCurve: 0,
                pathBegin: 0, pathEnd: 0, pathScaleX: 0, pathScaleY: 0,
                pathShearX: 0, pathShearY: 0, pathTwist: 0, pathTwistBegin: 0,
                pathRadiusOffset: 0, pathTaperX: 0, pathTaperY: 0,
                pathRevolutions: 0, pathSkew: 0, profileBegin: 0,
                profileEnd: 0, profileHollow: 0
            )
            
            objects.append(objectData)
            
            // Skip remaining object data for now
            offset += 63 // Approximate remaining size
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

// MARK: - Communication Messages

struct ChatFromSimulatorMessage {
    let fromName: String
    let sourceID: UUID
    let ownerID: UUID
    let sourceType: UInt8
    let chatType: UInt8
    let audible: UInt8
    let position: SIMD3<Float>
    let message: String
    
    static func parse(_ data: Data) throws -> ChatFromSimulatorMessage {
        var offset = 0
        
        // Parse from name (variable length string)
        guard offset < data.count else { throw ProtocolError.insufficientData }
        let nameLength = Int(data[offset])
        offset += 1
        
        let fromName = String(data: data.subdata(in: offset..<offset+nameLength), encoding: .utf8) ?? ""
        offset += nameLength
        
        // Parse source ID
        let sourceIDData = data.subdata(in: offset..<offset+16)
        let sourceID = UUID(uuid: (
            sourceIDData[0], sourceIDData[1], sourceIDData[2], sourceIDData[3],
            sourceIDData[4], sourceIDData[5], sourceIDData[6], sourceIDData[7],
            sourceIDData[8], sourceIDData[9], sourceIDData[10], sourceIDData[11],
            sourceIDData[12], sourceIDData[13], sourceIDData[14], sourceIDData[15]
        ) as uuid_t)
        offset += 16
        
        // Parse owner ID
        let ownerIDData = data.subdata(in: offset..<offset+16)
        let ownerID = UUID(uuid: (
            ownerIDData[0], ownerIDData[1], ownerIDData[2], ownerIDData[3],
            ownerIDData[4], ownerIDData[5], ownerIDData[6], ownerIDData[7],
            ownerIDData[8], ownerIDData[9], ownerIDData[10], ownerIDData[11],
            ownerIDData[12], ownerIDData[13], ownerIDData[14], ownerIDData[15]
        ) as uuid_t)
        offset += 16
        
        // Parse chat parameters
        let sourceType = data[offset]
        offset += 1
        let chatType = data[offset]
        offset += 1
        let audible = data[offset]
        offset += 1
        
        // Parse position
        let positionData = data.subdata(in: offset..<offset+12)
        let position = positionData.withUnsafeBytes { bytes in
            return SIMD3<Float>(
                Float(bitPattern: UInt32(bigEndian: bytes.load(fromByteOffset: 0, as: UInt32.self))),
                Float(bitPattern: UInt32(bigEndian: bytes.load(fromByteOffset: 4, as: UInt32.self))),
                Float(bitPattern: UInt32(bigEndian: bytes.load(fromByteOffset: 8, as: UInt32.self)))
            )
        }
        offset += 12
        
        // Parse message (variable length string)
        let messageLength = Int(data.withUnsafeBytes { bytes in
            return UInt16(bigEndian: bytes.load(fromByteOffset: offset, as: UInt16.self))
        })
        offset += 2
        
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

 // MARK: - Teleportation Messages

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

 // MARK: - Ping Messages

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

 // MARK: - Protocol Errors

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

 // MARK: - Helper Extensions

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
 }
