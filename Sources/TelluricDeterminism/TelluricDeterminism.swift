import TelluricCore
import TelluricMath

/// Fixed deterministic hash mixing functions.
public enum Hashing {
    /// Default seed for stable Telluric hashes.
    public static let defaultSeed: UInt64 = 0xcbf29ce484222325

    private static let fnvPrime: UInt64 = 0x100000001b3

    /// Mixes one `UInt64` into a running hash state.
    public static func mix(_ state: UInt64, _ value: UInt64) -> UInt64 {
        avalanche((state ^ value) &* fnvPrime)
    }

    /// Applies the SplitMix64 final avalanche.
    public static func avalanche(_ value: UInt64) -> UInt64 {
        var result = value
        result ^= result >> 30
        result &*= 0xbf58476d1ce4e5b9
        result ^= result >> 27
        result &*= 0x94d049bb133111eb
        result ^= result >> 31
        return result
    }
}

/// Protocol for types that can feed deterministic stable hashes.
public protocol StableHashable {
    /// Adds this value to `hasher` in a deterministic order.
    func stableHash(into hasher: inout StableHasher)
}

/// Ordered stable hasher that never uses Swift's process-randomized `Hasher`.
public struct StableHasher: Sendable {
    private var state: UInt64
    private var count: UInt64

    /// Creates a hasher with an explicit seed.
    public init(seed: UInt64 = Hashing.defaultSeed) {
        self.state = seed
        self.count = 0
    }

    /// Adds raw unsigned bits to the hash stream.
    public mutating func combine(_ value: UInt64) {
        state = Hashing.mix(state, value)
        count &+= 1
    }

    /// Adds signed integer bits to the hash stream.
    public mutating func combine(_ value: Int64) {
        combine(UInt64(bitPattern: value))
    }

    /// Adds platform integer bits to the hash stream.
    public mutating func combine(_ value: Int) {
        combine(Int64(value))
    }

    /// Adds boolean bits to the hash stream.
    public mutating func combine(_ value: Bool) {
        combine(value ? 1 : 0)
    }

    /// Adds single-precision floating-point bits to the hash stream.
    public mutating func combine(_ value: Float) {
        combine(UInt64(value.bitPattern))
    }

    /// Adds UTF-8 string bytes to the hash stream in byte order.
    public mutating func combine(_ value: String) {
        combine(UInt64(value.utf8.count))

        for byte in value.utf8 {
            combine(UInt64(byte))
        }
    }

    /// Adds a stable-hashable value to the hash stream.
    public mutating func combine<T: StableHashable>(_ value: T) {
        value.stableHash(into: &self)
    }

    /// Finalizes the current hash stream.
    public func finalize() -> StableHash {
        StableHash(rawValue: Hashing.avalanche(state ^ count))
    }
}

/// Deterministic pseudo-random generator based on SplitMix64.
public struct DeterministicRNG: Codable, Sendable {
    private var state: UInt64

    /// Creates a deterministic generator from raw seed bits.
    public init(seed: UInt64) {
        self.state = seed
    }

    /// Creates a deterministic generator from a world seed.
    public init(seed: WorldSeed) {
        self.init(seed: seed.rawValue)
    }

    /// Returns the next deterministic `UInt64`.
    public mutating func nextUInt64() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        return Hashing.avalanche(state)
    }

    /// Returns the next deterministic `UInt32`.
    public mutating func nextUInt32() -> UInt32 {
        UInt32(truncatingIfNeeded: nextUInt64() >> 32)
    }

    /// Returns a deterministic integer in `0..<upperBound`.
    public mutating func nextInt(upperBound: Int) -> Int {
        precondition(upperBound > 0, "upperBound must be positive")

        let bound = UInt64(upperBound)
        let threshold = (0 &- bound) % bound

        while true {
            let value = nextUInt64()
            if value >= threshold {
                return Int(value % bound)
            }
        }
    }

    /// Returns a deterministic scalar in `0..<1` with 24 bits of precision.
    public mutating func nextUnitFloat() -> Float {
        Float(nextUInt64() >> 40) / Float(1 << 24)
    }
}

/// Deterministic seed derivation for isolated generation streams.
public enum SeedDerivation {
    /// Derives a stream seed from a world seed, namespace, integer coordinates, and local index.
    public static func derive(
        worldSeed: WorldSeed,
        namespace: NamespaceID,
        coordinates: Int3 = .zero,
        localIndex: UInt64 = 0
    ) -> WorldSeed {
        var hasher = StableHasher()
        hasher.combine("Telluric.SeedDerivation.v1")
        hasher.combine(worldSeed)
        hasher.combine(namespace)
        hasher.combine(coordinates)
        hasher.combine(localIndex)
        return WorldSeed(rawValue: hasher.finalize().rawValue)
    }
}

extension StableHash: StableHashable {
    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

extension WorldSeed: StableHashable {
    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

extension NamespaceID: StableHashable {
    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

extension EngineVersion: StableHashable {
    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(UInt64(major))
        hasher.combine(UInt64(minor))
        hasher.combine(UInt64(patch))
    }
}

extension FrameIndex: StableHashable {
    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

extension TickIndex: StableHashable {
    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

extension Int2: StableHashable {
    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}

extension Int3: StableHashable {
    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(x)
        hasher.combine(y)
        hasher.combine(z)
    }
}
