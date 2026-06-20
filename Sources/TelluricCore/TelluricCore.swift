/// Semantic version for engine-owned data formats and deterministic contracts.
public struct EngineVersion: Codable, Comparable, CustomStringConvertible, Hashable, Sendable {
    /// Major version, incremented for incompatible contract changes.
    public let major: UInt16

    /// Minor version, incremented for backward-compatible additions.
    public let minor: UInt16

    /// Patch version, incremented for compatible fixes.
    public let patch: UInt16

    /// Creates an engine version from explicit semantic components.
    public init(major: UInt16, minor: UInt16, patch: UInt16) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public static func < (lhs: EngineVersion, rhs: EngineVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }

        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }

        return lhs.patch < rhs.patch
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }
}

/// Monotonic rendered-frame index.
public struct FrameIndex: Codable, Comparable, Hashable, Sendable {
    /// The raw zero-based frame value.
    public let rawValue: UInt64

    /// The first frame index.
    public static let zero = FrameIndex(rawValue: 0)

    /// Creates a frame index from its raw value.
    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    /// Returns a new frame index advanced by `delta`.
    public func advanced(by delta: UInt64) -> FrameIndex {
        let (value, overflow) = rawValue.addingReportingOverflow(delta)
        precondition(!overflow, "FrameIndex overflow")
        return FrameIndex(rawValue: value)
    }

    public static func < (lhs: FrameIndex, rhs: FrameIndex) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Monotonic fixed-simulation tick index.
public struct TickIndex: Codable, Comparable, Hashable, Sendable {
    /// The raw zero-based tick value.
    public let rawValue: UInt64

    /// The first tick index.
    public static let zero = TickIndex(rawValue: 0)

    /// Creates a tick index from its raw value.
    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    /// Returns a new tick index advanced by `delta`.
    public func advanced(by delta: UInt64) -> TickIndex {
        let (value, overflow) = rawValue.addingReportingOverflow(delta)
        precondition(!overflow, "TickIndex overflow")
        return TickIndex(rawValue: value)
    }

    public static func < (lhs: TickIndex, rhs: TickIndex) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Root seed for deterministic world and stream derivation.
public struct WorldSeed: Codable, Comparable, Hashable, Sendable {
    /// Raw seed bits. All `UInt64` values are valid seeds.
    public let rawValue: UInt64

    /// Creates a world seed from raw bits.
    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public static func < (lhs: WorldSeed, rhs: WorldSeed) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Stable 64-bit hash value produced by Telluric deterministic hashing.
public struct StableHash: Codable, Comparable, CustomStringConvertible, Hashable, Sendable {
    /// Raw hash bits.
    public let rawValue: UInt64

    /// Creates a stable hash from raw bits.
    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public static func < (lhs: StableHash, rhs: StableHash) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String {
        "0x" + String(rawValue, radix: 16, uppercase: false)
    }
}

/// Deterministic domain identifier used to separate seed and hash streams.
public struct NamespaceID: Codable, Comparable, CustomStringConvertible, Hashable, Sendable {
    /// Stable textual namespace. Empty namespaces are rejected.
    public let rawValue: String

    /// Creates a namespace identifier.
    public init(_ rawValue: String) {
        precondition(!rawValue.isEmpty, "NamespaceID must not be empty")
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        guard !value.isEmpty else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "NamespaceID must not be empty"
            )
        }

        self.rawValue = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: NamespaceID, rhs: NamespaceID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String {
        rawValue
    }
}

/// Engine-level error payload that can cross module and CLI boundaries.
public struct TelluricError: Codable, Error, Hashable, Sendable {
    /// Stable machine-readable error domain or code.
    public let code: NamespaceID

    /// Human-readable explanation.
    public let message: String

    /// Creates an engine error.
    public init(code: NamespaceID, message: String) {
        self.code = code
        self.message = message
    }
}
