import TelluricCore
import TelluricDeterminism
import TelluricMath

/// Integer coordinate for a generated chunk.
public struct ChunkCoord: Codable, Comparable, Hashable, Sendable, StableHashable {
    public let x: Int64
    public let y: Int64
    public let z: Int64

    public static let zero = ChunkCoord(x: 0, y: 0, z: 0)

    public init(x: Int64, y: Int64, z: Int64 = 0) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// Derives the containing region using integer floor division.
    public func regionCoord(regionSizeInChunks: Int64) -> RegionCoord {
        precondition(regionSizeInChunks > 0, "regionSizeInChunks must be positive")

        return RegionCoord(
            x: Self.floorDiv(x, by: regionSizeInChunks),
            y: Self.floorDiv(y, by: regionSizeInChunks),
            z: Self.floorDiv(z, by: regionSizeInChunks)
        )
    }

    /// Returns the non-negative local coordinate inside its containing region.
    public func localCoordInRegion(regionSizeInChunks: Int64) -> Int3 {
        let region = regionCoord(regionSizeInChunks: regionSizeInChunks)
        return Int3(
            x: x - region.x * regionSizeInChunks,
            y: y - region.y * regionSizeInChunks,
            z: z - region.z * regionSizeInChunks
        )
    }

    public static func < (lhs: ChunkCoord, rhs: ChunkCoord) -> Bool {
        if lhs.x != rhs.x {
            return lhs.x < rhs.x
        }

        if lhs.y != rhs.y {
            return lhs.y < rhs.y
        }

        return lhs.z < rhs.z
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(x)
        hasher.combine(y)
        hasher.combine(z)
    }

    private static func floorDiv(_ value: Int64, by divisor: Int64) -> Int64 {
        let quotient = value / divisor
        let remainder = value % divisor
        return remainder < 0 ? quotient - 1 : quotient
    }
}

/// Integer coordinate for a region containing multiple chunks.
public struct RegionCoord: Codable, Comparable, Hashable, Sendable, StableHashable {
    public let x: Int64
    public let y: Int64
    public let z: Int64

    public static let zero = RegionCoord(x: 0, y: 0, z: 0)

    public init(x: Int64, y: Int64, z: Int64 = 0) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// Returns the first chunk coordinate in this region.
    public func originChunk(regionSizeInChunks: Int64) -> ChunkCoord {
        precondition(regionSizeInChunks > 0, "regionSizeInChunks must be positive")

        return ChunkCoord(
            x: x * regionSizeInChunks,
            y: y * regionSizeInChunks,
            z: z * regionSizeInChunks
        )
    }

    public static func < (lhs: RegionCoord, rhs: RegionCoord) -> Bool {
        if lhs.x != rhs.x {
            return lhs.x < rhs.x
        }

        if lhs.y != rhs.y {
            return lhs.y < rhs.y
        }

        return lhs.z < rhs.z
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(x)
        hasher.combine(y)
        hasher.combine(z)
    }
}

/// Integer world-space bounds for a chunk's sample domain.
public struct ChunkBounds: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Inclusive minimum sample coordinate.
    public let min: Int3

    /// Exclusive maximum sample coordinate.
    public let maxExclusive: Int3

    /// Creates chunk bounds from explicit integer coordinates.
    public init(min: Int3, maxExclusive: Int3) {
        precondition(min.x < maxExclusive.x, "ChunkBounds must have positive x extent")
        precondition(min.y < maxExclusive.y, "ChunkBounds must have positive y extent")
        precondition(min.z < maxExclusive.z, "ChunkBounds must have positive z extent")
        self.min = min
        self.maxExclusive = maxExclusive
    }

    /// Creates sample bounds for a chunk and uniform chunk size.
    public init(chunkCoord: ChunkCoord, chunkSize: Int) {
        precondition(chunkSize > 0, "chunkSize must be positive")

        let size = Int64(chunkSize)
        let min = Int3(
            x: chunkCoord.x * size,
            y: chunkCoord.y * size,
            z: chunkCoord.z * size
        )
        self.init(
            min: min,
            maxExclusive: Int3(x: min.x + size, y: min.y + size, z: min.z + size)
        )
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(min)
        hasher.combine(maxExclusive)
    }
}

/// Configuration that controls deterministic world contract evaluation.
public struct WorldConfig: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Root seed for all derived world streams.
    public let worldSeed: WorldSeed

    /// Horizontal chunk size in samples or world cells.
    public let chunkSize: Int

    /// Vertical scale applied by future height interpretation.
    public let verticalScale: Float

    /// Stable generation profile identifier.
    public let generationProfile: NamespaceID

    /// Creates a world configuration.
    public init(
        worldSeed: WorldSeed,
        chunkSize: Int,
        verticalScale: Float,
        generationProfile: NamespaceID
    ) {
        self.worldSeed = worldSeed
        self.chunkSize = chunkSize
        self.verticalScale = verticalScale
        self.generationProfile = generationProfile
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(worldSeed)
        hasher.combine(chunkSize)
        hasher.combine(verticalScale)
        hasher.combine(generationProfile)
    }
}

/// Context shared by deterministic world generation contracts.
public struct WorldGenerationContext: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// World configuration for this generation run.
    public let config: WorldConfig

    /// Engine contract version used by this generation run.
    public let engineVersion: EngineVersion

    /// Creates a world generation context.
    public init(config: WorldConfig, engineVersion: EngineVersion) {
        self.config = config
        self.engineVersion = engineVersion
    }

    /// Derives an isolated deterministic seed stream.
    public func derivedSeed(
        namespace: NamespaceID,
        coordinates: Int3 = .zero,
        localIndex: UInt64 = 0
    ) -> WorldSeed {
        SeedDerivation.derive(
            worldSeed: config.worldSeed,
            namespace: namespace,
            coordinates: coordinates,
            localIndex: localIndex
        )
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(config)
        hasher.combine(engineVersion)
    }
}

/// Severity for world generation contract issues.
public enum WorldGenerationIssueSeverity: String, Codable, Comparable, Sendable {
    case info
    case warning
    case error

    private var rank: UInt8 {
        switch self {
        case .info:
            return 0
        case .warning:
            return 1
        case .error:
            return 2
        }
    }

    public static func < (lhs: WorldGenerationIssueSeverity, rhs: WorldGenerationIssueSeverity) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Serializable world generation validation issue.
public struct WorldGenerationIssue: Codable, Equatable, Hashable, Sendable {
    public let severity: WorldGenerationIssueSeverity
    public let code: NamespaceID
    public let message: String
    public let chunkCoord: ChunkCoord?

    public init(
        severity: WorldGenerationIssueSeverity,
        code: NamespaceID,
        message: String,
        chunkCoord: ChunkCoord? = nil
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.chunkCoord = chunkCoord
    }
}

/// JSON-friendly world generation validation report.
public struct WorldGenerationReport: Codable, Equatable, Hashable, Sendable {
    public let issues: [WorldGenerationIssue]

    public init(issues: [WorldGenerationIssue]) {
        self.issues = issues
    }

    /// True when the report contains no errors.
    public var isSuccess: Bool {
        !hasErrors
    }

    public var hasErrors: Bool {
        issues.contains { $0.severity == .error }
    }

    public func count(_ severity: WorldGenerationIssueSeverity) -> Int {
        issues.reduce(0) { partialResult, issue in
            partialResult + (issue.severity == severity ? 1 : 0)
        }
    }
}

/// World-level validation helpers.
public enum WorldGenerationValidation {
    /// Validates a world configuration.
    public static func validate(config: WorldConfig) -> WorldGenerationReport {
        var issues: [WorldGenerationIssue] = []

        if config.chunkSize <= 0 {
            issues.append(WorldGenerationIssue(
                severity: .error,
                code: NamespaceID("world.config.invalid_chunk_size"),
                message: "WorldConfig.chunkSize must be positive."
            ))
        }

        if !config.verticalScale.isFinite || config.verticalScale <= 0 {
            issues.append(WorldGenerationIssue(
                severity: .error,
                code: NamespaceID("world.config.invalid_vertical_scale"),
                message: "WorldConfig.verticalScale must be finite and positive."
            ))
        }

        return WorldGenerationReport(issues: issues)
    }
}

/// Component kinds that can contribute to a chunk payload hash.
public enum ChunkPayloadComponentKind: String, Codable, Comparable, Sendable {
    case terrain
    case biomes

    public static func < (lhs: ChunkPayloadComponentKind, rhs: ChunkPayloadComponentKind) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Stable hash contribution from one chunk payload component.
public struct ChunkPayloadComponentHash: Codable, Equatable, Hashable, Sendable, StableHashable {
    public let kind: ChunkPayloadComponentKind
    public let stableHash: StableHash

    public init(kind: ChunkPayloadComponentKind, stableHash: StableHash) {
        self.kind = kind
        self.stableHash = stableHash
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(kind.rawValue)
        hasher.combine(stableHash)
    }
}

/// Deterministic aggregate payload signature for one chunk.
public struct ChunkWorldPayload: Codable, Equatable, Hashable, Sendable {
    public let chunkCoord: ChunkCoord
    public let componentHashes: [ChunkPayloadComponentHash]
    public let stableHash: StableHash

    public init(chunkCoord: ChunkCoord, componentHashes: [ChunkPayloadComponentHash]) {
        self.chunkCoord = chunkCoord
        self.componentHashes = componentHashes.sorted { lhs, rhs in
            if lhs.kind != rhs.kind {
                return lhs.kind < rhs.kind
            }

            return lhs.stableHash < rhs.stableHash
        }
        self.stableHash = ChunkPayloadHasher.hash(
            chunkCoord: chunkCoord,
            componentHashes: self.componentHashes
        )
    }
}

/// Stable hashing helper for world-level chunk payloads.
public enum ChunkPayloadHasher {
    /// Hashes a chunk coordinate and ordered component hashes.
    public static func hash(
        chunkCoord: ChunkCoord,
        componentHashes: [ChunkPayloadComponentHash]
    ) -> StableHash {
        var hasher = StableHasher()
        hasher.combine("Telluric.ChunkWorldPayload.v1")
        hasher.combine(chunkCoord)

        let sortedComponents = componentHashes.sorted { lhs, rhs in
            if lhs.kind != rhs.kind {
                return lhs.kind < rhs.kind
            }

            return lhs.stableHash < rhs.stableHash
        }

        hasher.combine(sortedComponents.count)
        for component in sortedComponents {
            hasher.combine(component)
        }

        return hasher.finalize()
    }
}

/// Result from a component generator participating in chunk generation.
public struct WorldChunkComponentGeneration: Codable, Equatable, Hashable, Sendable {
    /// Stable component hashes produced by the component generator.
    public let componentHashes: [ChunkPayloadComponentHash]

    /// Validation report for this component generation step.
    public let report: WorldGenerationReport

    /// Creates a component generation result.
    public init(
        componentHashes: [ChunkPayloadComponentHash],
        report: WorldGenerationReport = WorldGenerationReport(issues: [])
    ) {
        self.componentHashes = componentHashes
        self.report = report
    }
}

/// Type-erased protocol boundary for deterministic chunk component generation.
public protocol WorldChunkComponentGenerating: Sendable {
    /// Generates one or more component hashes for `chunkCoord`.
    func generateChunkComponents(
        context: WorldGenerationContext,
        chunkCoord: ChunkCoord
    ) throws -> WorldChunkComponentGeneration
}

/// Successful deterministic chunk generation result.
public struct WorldChunkGenerationResult: Codable, Equatable, Hashable, Sendable {
    /// Aggregated chunk payload.
    public let payload: ChunkWorldPayload

    /// Ordered validation and generation report.
    public let report: WorldGenerationReport

    /// Creates a chunk generation result.
    public init(payload: ChunkWorldPayload, report: WorldGenerationReport) {
        self.payload = payload
        self.report = report
    }
}

/// Error thrown when deterministic world generation cannot produce a valid chunk payload.
public struct WorldGenerationError: Error, Equatable, Sendable {
    /// Report describing the generation failure.
    public let report: WorldGenerationReport

    /// Creates a generation error from a report.
    public init(report: WorldGenerationReport) {
        self.report = report
    }
}

/// Deterministic world-level chunk orchestrator.
public struct DeterministicWorldGenerator: Sendable {
    private let componentGenerators: [any WorldChunkComponentGenerating]
    private let requiredComponentKinds: [ChunkPayloadComponentKind]

    /// Creates a generator from one component generator.
    public init(
        componentGenerator: any WorldChunkComponentGenerating,
        requiredComponentKinds: [ChunkPayloadComponentKind] = [.terrain, .biomes]
    ) {
        self.init(
            componentGenerators: [componentGenerator],
            requiredComponentKinds: requiredComponentKinds
        )
    }

    /// Creates a generator from ordered component generators.
    public init(
        componentGenerators: [any WorldChunkComponentGenerating],
        requiredComponentKinds: [ChunkPayloadComponentKind] = [.terrain, .biomes]
    ) {
        precondition(!componentGenerators.isEmpty, "DeterministicWorldGenerator requires at least one component generator")
        self.componentGenerators = componentGenerators
        self.requiredComponentKinds = requiredComponentKinds
    }

    /// Generates an aggregate chunk payload and report.
    public func generateChunk(
        at chunkCoord: ChunkCoord,
        context: WorldGenerationContext
    ) throws -> WorldChunkGenerationResult {
        var issues = WorldGenerationValidation.validate(config: context.config).issues
        if issues.contains(where: { $0.severity == .error }) {
            throw WorldGenerationError(report: WorldGenerationReport(issues: issues))
        }

        var componentHashes: [ChunkPayloadComponentHash] = []
        for componentGenerator in componentGenerators {
            let generation = try componentGenerator.generateChunkComponents(
                context: context,
                chunkCoord: chunkCoord
            )
            componentHashes.append(contentsOf: generation.componentHashes)
            issues.append(contentsOf: generation.report.issues)
        }

        issues.append(contentsOf: missingComponentIssues(
            componentHashes: componentHashes,
            chunkCoord: chunkCoord
        ))

        let report = WorldGenerationReport(issues: issues)
        if report.hasErrors {
            throw WorldGenerationError(report: report)
        }

        return WorldChunkGenerationResult(
            payload: ChunkWorldPayload(chunkCoord: chunkCoord, componentHashes: componentHashes),
            report: report
        )
    }

    /// Generates only the aggregate payload, throwing if validation fails.
    public func generateChunkPayload(
        at chunkCoord: ChunkCoord,
        context: WorldGenerationContext
    ) throws -> ChunkWorldPayload {
        try generateChunk(at: chunkCoord, context: context).payload
    }

    private func missingComponentIssues(
        componentHashes: [ChunkPayloadComponentHash],
        chunkCoord: ChunkCoord
    ) -> [WorldGenerationIssue] {
        var issues: [WorldGenerationIssue] = []

        for requiredKind in requiredComponentKinds {
            let hasKind = componentHashes.contains { $0.kind == requiredKind }
            if !hasKind {
                issues.append(WorldGenerationIssue(
                    severity: .error,
                    code: NamespaceID("world.generator.missing_component"),
                    message: "Required chunk component is missing: \(requiredKind.rawValue).",
                    chunkCoord: chunkCoord
                ))
            }
        }

        return issues
    }
}
