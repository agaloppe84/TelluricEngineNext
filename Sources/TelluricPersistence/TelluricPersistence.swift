import Foundation
import TelluricCore
import TelluricDeterminism
import TelluricDiagnostics
import TelluricSimulation

/// Version of the persistence envelope format.
public struct PersistenceFormatVersion: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Supported Phase 11 JSON envelope format.
    public static let supported = PersistenceFormatVersion(rawValue: 1)

    /// Raw format version. Validation reports unsupported values.
    public let rawValue: UInt16

    /// Creates a persistence format version.
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(UInt16.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: PersistenceFormatVersion, rhs: PersistenceFormatVersion) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(UInt64(rawValue))
    }
}

/// Stable schema identifier for a persisted package.
public struct PersistenceSchemaID: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Default schema for snapshot packages.
    public static let snapshotPackage = PersistenceSchemaID("telluric.snapshot.package")

    /// Default schema for replay packages.
    public static let replayPackage = PersistenceSchemaID("telluric.replay.package")

    /// Default schema for report packages.
    public static let reportPackage = PersistenceSchemaID("telluric.report.package")

    /// Raw schema string. Empty values are allowed so validation can report them.
    public let rawValue: String

    /// Creates a schema identifier.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: PersistenceSchemaID, rhs: PersistenceSchemaID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

/// Kind of payload wrapped by a persistence envelope.
public struct PersistenceEnvelopeKind: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Snapshot payload, such as runtime, simulation, or render snapshots.
    public static let snapshot = PersistenceEnvelopeKind("snapshot")

    /// Replay payload, such as a replay input log.
    public static let replay = PersistenceEnvelopeKind("replay")

    /// Report payload, such as diagnostics or CLI reports.
    public static let report = PersistenceEnvelopeKind("report")

    /// Known Phase 11 envelope kinds.
    public static let supported: [PersistenceEnvelopeKind] = [.snapshot, .replay, .report]

    /// Raw kind string. Unknown values are decoded and reported by validation.
    public let rawValue: String

    /// Creates an envelope kind.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// True when this kind is supported by the current format version.
    public var isSupported: Bool {
        Self.supported.contains(self)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: PersistenceEnvelopeKind, rhs: PersistenceEnvelopeKind) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

/// Stable hash of encoded payload bytes.
public struct PersistencePayloadHash: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Raw stable payload hash.
    public let rawValue: StableHash

    /// Creates a payload hash.
    public init(rawValue: StableHash) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = StableHash(rawValue: try container.decode(UInt64.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue.rawValue)
    }

    public static func < (lhs: PersistencePayloadHash, rhs: PersistencePayloadHash) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

/// Ordered key-value metadata entry for persistence envelopes.
public struct PersistenceMetadataEntry: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Metadata key. Empty keys are allowed so validation can report them.
    public let key: String

    /// String metadata value.
    public let value: String

    /// Creates an ordered metadata entry.
    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }

    public static func < (lhs: PersistenceMetadataEntry, rhs: PersistenceMetadataEntry) -> Bool {
        if lhs.key != rhs.key {
            return lhs.key < rhs.key
        }

        return lhs.value < rhs.value
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(key)
        hasher.combine(value)
    }
}

/// Generic deterministic persistence envelope containing payload data and its stable hash.
public struct PersistenceEnvelope<Payload: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    /// Schema identifier for the envelope payload.
    public let schemaID: PersistenceSchemaID

    /// Persistence format version.
    public let formatVersion: PersistenceFormatVersion

    /// Engine version that produced the envelope.
    public let engineVersion: EngineVersion

    /// Payload kind.
    public let kind: PersistenceEnvelopeKind

    /// Stable hash of deterministically encoded payload bytes.
    public let payloadHash: PersistencePayloadHash

    /// Ordered metadata. Ordering is preserved and included in envelope hashes.
    public let metadata: [PersistenceMetadataEntry]

    /// Encoded payload value.
    public let payload: Payload

    /// Stable hash of envelope fields and payload hash.
    public var stableHash: StableHash {
        PersistenceHasher.hash(envelope: self)
    }

    /// Creates an envelope and computes the payload hash unless an explicit hash is provided for validation tests.
    public init(
        schemaID: PersistenceSchemaID,
        formatVersion: PersistenceFormatVersion = .supported,
        engineVersion: EngineVersion,
        kind: PersistenceEnvelopeKind,
        payloadHash: PersistencePayloadHash? = nil,
        metadata: [PersistenceMetadataEntry] = [],
        payload: Payload
    ) throws {
        self.schemaID = schemaID
        self.formatVersion = formatVersion
        self.engineVersion = engineVersion
        self.kind = kind
        if let payloadHash {
            self.payloadHash = payloadHash
        } else {
            self.payloadHash = try PersistenceHasher.hashPayload(payload)
        }
        self.metadata = metadata
        self.payload = payload
    }
}

/// Persistence package for engine snapshots.
public struct SnapshotPackage<Payload: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    /// Wrapped snapshot envelope.
    public let envelope: PersistenceEnvelope<Payload>

    /// Snapshot payload.
    public var payload: Payload {
        envelope.payload
    }

    /// Stable package hash.
    public var stableHash: StableHash {
        envelope.stableHash
    }

    /// Creates a snapshot package.
    public init(
        schemaID: PersistenceSchemaID = .snapshotPackage,
        formatVersion: PersistenceFormatVersion = .supported,
        engineVersion: EngineVersion,
        metadata: [PersistenceMetadataEntry] = [],
        payload: Payload
    ) throws {
        self.envelope = try PersistenceEnvelope(
            schemaID: schemaID,
            formatVersion: formatVersion,
            engineVersion: engineVersion,
            kind: .snapshot,
            metadata: metadata,
            payload: payload
        )
    }

    /// Validates the wrapped envelope.
    public func validate() -> PersistenceValidationReport {
        PersistenceValidation.validate(envelope: envelope)
    }
}

/// Persistence package for replay logs and replay-like deterministic inputs.
public struct ReplayPackage<Payload: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    /// Wrapped replay envelope.
    public let envelope: PersistenceEnvelope<Payload>

    /// Replay payload.
    public var payload: Payload {
        envelope.payload
    }

    /// Stable package hash.
    public var stableHash: StableHash {
        envelope.stableHash
    }

    /// Creates a replay package.
    public init(
        schemaID: PersistenceSchemaID = .replayPackage,
        formatVersion: PersistenceFormatVersion = .supported,
        engineVersion: EngineVersion,
        metadata: [PersistenceMetadataEntry] = [],
        payload: Payload
    ) throws {
        self.envelope = try PersistenceEnvelope(
            schemaID: schemaID,
            formatVersion: formatVersion,
            engineVersion: engineVersion,
            kind: .replay,
            metadata: metadata,
            payload: payload
        )
    }

    /// Validates the wrapped envelope.
    public func validate() -> PersistenceValidationReport {
        PersistenceValidation.validate(envelope: envelope)
    }
}

/// Persistence package for diagnostic, validation, or tool report payloads.
public struct ReportPackage<Payload: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    /// Wrapped report envelope.
    public let envelope: PersistenceEnvelope<Payload>

    /// Report payload.
    public var payload: Payload {
        envelope.payload
    }

    /// Stable package hash.
    public var stableHash: StableHash {
        envelope.stableHash
    }

    /// Creates a report package.
    public init(
        schemaID: PersistenceSchemaID = .reportPackage,
        formatVersion: PersistenceFormatVersion = .supported,
        engineVersion: EngineVersion,
        metadata: [PersistenceMetadataEntry] = [],
        payload: Payload
    ) throws {
        self.envelope = try PersistenceEnvelope(
            schemaID: schemaID,
            formatVersion: formatVersion,
            engineVersion: engineVersion,
            kind: .report,
            metadata: metadata,
            payload: payload
        )
    }

    /// Validates the wrapped envelope.
    public func validate() -> PersistenceValidationReport {
        PersistenceValidation.validate(envelope: envelope)
    }
}

/// Convenience package type for simulation snapshots.
public typealias SimulationSnapshotPackage = SnapshotPackage<SimulationSnapshot>

/// Convenience package type for simulation replay input logs.
public typealias ReplayInputLogPackage = ReplayPackage<ReplayInputLog>

/// Convenience package type for diagnostic reports.
public typealias DiagnosticReportPackage = ReportPackage<DiagnosticReport>

/// Validation issue reported for persistence envelopes and packages.
public struct PersistenceValidationIssue: Codable, Equatable, Hashable, Sendable {
    /// Issue severity.
    public let severity: DiagnosticSeverity

    /// Stable machine-readable issue code.
    public let code: NamespaceID

    /// Human-readable issue message.
    public let message: String

    /// Ordered issue metadata.
    public let metadata: [PersistenceMetadataEntry]

    /// Creates a persistence validation issue.
    public init(
        severity: DiagnosticSeverity,
        code: NamespaceID,
        message: String,
        metadata: [PersistenceMetadataEntry] = []
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.metadata = metadata
    }

    /// Converts this issue to a shared diagnostic message.
    public func diagnosticMessage() -> DiagnosticMessage {
        DiagnosticMessage(
            severity: severity,
            code: code,
            message: message,
            source: "TelluricPersistence",
            metadata: metadata.enumerated().map { index, entry in
                let trimmedKey = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
                return DiagnosticMetadata(
                    key: trimmedKey.isEmpty ? "metadata.\(index)" : entry.key,
                    value: entry.value
                )
            }
        )
    }
}

/// JSON-friendly validation report for persistence packages.
public struct PersistenceValidationReport: Codable, Equatable, Hashable, Sendable {
    /// Ordered validation issues.
    public let issues: [PersistenceValidationIssue]

    /// Creates a validation report.
    public init(issues: [PersistenceValidationIssue]) {
        self.issues = issues
    }

    /// True when no error issues were reported.
    public var isValid: Bool {
        !diagnostics.hasErrors
    }

    /// Diagnostic report view of the validation issues.
    public var diagnostics: DiagnosticReport {
        DiagnosticReport(messages: issues.map { $0.diagnosticMessage() })
    }
}

/// Deterministic JSON encoder settings for persistence packages.
public enum PersistenceJSONEncoder {
    /// Creates an encoder with stable key ordering.
    public static func make() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    /// Encodes a value using persistence JSON settings.
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        try make().encode(value)
    }
}

/// JSON decoder for persistence packages.
public enum PersistenceJSONDecoder {
    /// Creates a persistence decoder.
    public static func make() -> JSONDecoder {
        JSONDecoder()
    }

    /// Decodes a value using persistence JSON settings.
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try make().decode(type, from: data)
    }
}

/// Stable hashing helpers for persistence payloads and envelopes.
public enum PersistenceHasher {
    /// Hashes deterministically encoded payload bytes.
    public static func hashPayload<Payload: Encodable>(_ payload: Payload) throws -> PersistencePayloadHash {
        try hashPayloadBytes(PersistenceJSONEncoder.encode(payload))
    }

    /// Hashes already encoded payload bytes.
    public static func hashPayloadBytes(_ data: Data) -> PersistencePayloadHash {
        var hasher = StableHasher()
        hasher.combine("Telluric.PersistencePayload.v1")
        hasher.combine(data.count)

        for byte in data {
            hasher.combine(UInt64(byte))
        }

        return PersistencePayloadHash(rawValue: hasher.finalize())
    }

    /// Hashes an envelope using ordered metadata and the stored payload hash.
    public static func hash<Payload: Codable & Equatable & Sendable>(
        envelope: PersistenceEnvelope<Payload>
    ) -> StableHash {
        var hasher = StableHasher()
        hasher.combine("Telluric.PersistenceEnvelope.v1")
        hasher.combine(envelope.schemaID)
        hasher.combine(envelope.formatVersion)
        hasher.combine(envelope.engineVersion)
        hasher.combine(envelope.kind)
        hasher.combine(envelope.payloadHash)
        hasher.combine(envelope.metadata.count)

        for entry in envelope.metadata {
            hasher.combine(entry)
        }

        return hasher.finalize()
    }
}

/// Validation rules for persistence envelopes.
public enum PersistenceValidation {
    /// Validates an envelope and returns ordered issues.
    public static func validate<Payload: Codable & Equatable & Sendable>(
        envelope: PersistenceEnvelope<Payload>
    ) -> PersistenceValidationReport {
        var issues: [PersistenceValidationIssue] = []

        if envelope.formatVersion != .supported {
            issues.append(.error(
                code: "persistence.format.unsupported_version",
                message: "Unsupported persistence format version.",
                metadata: [
                    PersistenceMetadataEntry(key: "version", value: "\(envelope.formatVersion.rawValue)"),
                    PersistenceMetadataEntry(key: "supportedVersion", value: "\(PersistenceFormatVersion.supported.rawValue)"),
                ]
            ))
        }

        if envelope.schemaID.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.error(
                code: "persistence.schema.empty",
                message: "Persistence schema id must not be empty."
            ))
        }

        if !envelope.kind.isSupported {
            issues.append(.error(
                code: "persistence.kind.unsupported",
                message: "Unsupported persistence envelope kind.",
                metadata: [
                    PersistenceMetadataEntry(key: "kind", value: envelope.kind.rawValue),
                ]
            ))
        }

        for (index, entry) in envelope.metadata.enumerated() {
            if entry.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.error(
                    code: "persistence.metadata.empty_key",
                    message: "Persistence metadata key must not be empty.",
                    metadata: [
                        PersistenceMetadataEntry(key: "index", value: "\(index)"),
                    ]
                ))
            }
        }

        do {
            let actualHash = try PersistenceHasher.hashPayload(envelope.payload)
            if actualHash != envelope.payloadHash {
                issues.append(.error(
                    code: "persistence.payload.hash_mismatch",
                    message: "Persistence payload hash does not match encoded payload bytes.",
                    metadata: [
                        PersistenceMetadataEntry(key: "expected", value: "\(envelope.payloadHash.rawValue.rawValue)"),
                        PersistenceMetadataEntry(key: "actual", value: "\(actualHash.rawValue.rawValue)"),
                    ]
                ))
            }
        } catch {
            issues.append(.error(
                code: "persistence.payload.hash_failed",
                message: "Persistence payload could not be encoded for hash verification.",
                metadata: [
                    PersistenceMetadataEntry(key: "error", value: String(describing: error)),
                ]
            ))
        }

        return PersistenceValidationReport(issues: issues)
    }
}

private extension PersistenceValidationIssue {
    static func error(
        code: String,
        message: String,
        metadata: [PersistenceMetadataEntry] = []
    ) -> PersistenceValidationIssue {
        PersistenceValidationIssue(
            severity: .error,
            code: NamespaceID(code),
            message: message,
            metadata: metadata
        )
    }
}
