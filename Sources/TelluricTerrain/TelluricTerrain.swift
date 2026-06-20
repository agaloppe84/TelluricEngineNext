import TelluricCore
import TelluricDeterminism
import TelluricMath
import TelluricWorld

/// One scalar terrain height sample.
public struct HeightSample: Codable, Equatable, Hashable, Sendable, StableHashable {
    public let height: Float

    public init(height: Float) {
        self.height = height
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(height)
    }
}

/// Rectangular ordered height field for one chunk.
public struct HeightField: Codable, Equatable, Hashable, Sendable, StableHashable {
    public let width: Int
    public let depth: Int
    public let samples: [HeightSample]

    public init(width: Int, depth: Int, samples: [HeightSample]) {
        self.width = width
        self.depth = depth
        self.samples = samples
    }

    /// Returns the sample at `x,z`, or nil if outside the field.
    public func sample(x: Int, z: Int) -> HeightSample? {
        guard x >= 0, z >= 0, x < width, z < depth else {
            return nil
        }

        let index = z * width + x
        guard index >= 0, index < samples.count else {
            return nil
        }

        return samples[index]
    }

    /// Returns min/max finite heights when all dimensions and samples are valid.
    public var summary: HeightSummary? {
        guard width > 0, depth > 0, samples.count == width * depth else {
            return nil
        }

        var minHeight = Float.infinity
        var maxHeight = -Float.infinity

        for sample in samples {
            guard sample.height.isFinite else {
                return nil
            }

            minHeight = Swift.min(minHeight, sample.height)
            maxHeight = Swift.max(maxHeight, sample.height)
        }

        return HeightSummary(minHeight: minHeight, maxHeight: maxHeight)
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(width)
        hasher.combine(depth)
        hasher.combine(samples.count)

        for sample in samples {
            hasher.combine(sample)
        }
    }
}

/// Min/max summary for a height field.
public struct HeightSummary: Codable, Equatable, Hashable, Sendable, StableHashable {
    public let minHeight: Float
    public let maxHeight: Float

    public init(minHeight: Float, maxHeight: Float) {
        precondition(minHeight.isFinite, "minHeight must be finite")
        precondition(maxHeight.isFinite, "maxHeight must be finite")
        precondition(minHeight <= maxHeight, "minHeight must be <= maxHeight")
        self.minHeight = minHeight
        self.maxHeight = maxHeight
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(minHeight)
        hasher.combine(maxHeight)
    }
}

/// Settings that shape terrain contract evaluation.
public struct TerrainGenerationSettings: Codable, Equatable, Hashable, Sendable, StableHashable {
    public let profile: NamespaceID
    public let heightScale: Float

    public init(profile: NamespaceID, heightScale: Float) {
        self.profile = profile
        self.heightScale = heightScale
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(profile)
        hasher.combine(heightScale)
    }
}

/// Severity for terrain validation issues.
public enum TerrainValidationSeverity: String, Codable, Comparable, Sendable {
    case warning
    case error

    private var rank: UInt8 {
        switch self {
        case .warning:
            return 0
        case .error:
            return 1
        }
    }

    public static func < (lhs: TerrainValidationSeverity, rhs: TerrainValidationSeverity) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Serializable terrain validation issue.
public struct TerrainValidationIssue: Codable, Equatable, Hashable, Sendable {
    public let severity: TerrainValidationSeverity
    public let code: NamespaceID
    public let message: String
    public let chunkCoord: ChunkCoord?
    public let sampleIndex: Int?

    public init(
        severity: TerrainValidationSeverity,
        code: NamespaceID,
        message: String,
        chunkCoord: ChunkCoord? = nil,
        sampleIndex: Int? = nil
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.chunkCoord = chunkCoord
        self.sampleIndex = sampleIndex
    }
}

/// Terrain validation helpers.
public enum TerrainValidation {
    /// Validates a height field and returns ordered issues.
    public static func validate(heightField: HeightField, chunkCoord: ChunkCoord? = nil) -> [TerrainValidationIssue] {
        var issues: [TerrainValidationIssue] = []

        if heightField.width <= 0 || heightField.depth <= 0 {
            issues.append(TerrainValidationIssue(
                severity: .error,
                code: NamespaceID("terrain.height_field.invalid_dimensions"),
                message: "HeightField dimensions must be positive.",
                chunkCoord: chunkCoord
            ))
        }

        let expectedSampleCount = heightField.width > 0 && heightField.depth > 0 ? heightField.width * heightField.depth : 0
        if heightField.samples.count != expectedSampleCount {
            issues.append(TerrainValidationIssue(
                severity: .error,
                code: NamespaceID("terrain.height_field.invalid_sample_count"),
                message: "HeightField sample count must equal width * depth.",
                chunkCoord: chunkCoord
            ))
        }

        if heightField.samples.isEmpty {
            issues.append(TerrainValidationIssue(
                severity: .error,
                code: NamespaceID("terrain.height_field.empty"),
                message: "HeightField must contain samples.",
                chunkCoord: chunkCoord
            ))
        }

        for (index, sample) in heightField.samples.enumerated() where !sample.height.isFinite {
            issues.append(TerrainValidationIssue(
                severity: .error,
                code: NamespaceID("terrain.height_field.non_finite_height"),
                message: "HeightField samples must be finite.",
                chunkCoord: chunkCoord,
                sampleIndex: index
            ))
        }

        return issues
    }

    /// Validates a terrain payload and optionally checks it against an expected chunk.
    public static func validate(payload: TerrainPayload, expectedChunkCoord: ChunkCoord? = nil) -> [TerrainValidationIssue] {
        var issues = validate(heightField: payload.heightField, chunkCoord: payload.chunkCoord)

        if let expectedChunkCoord, payload.chunkCoord != expectedChunkCoord {
            issues.append(TerrainValidationIssue(
                severity: .error,
                code: NamespaceID("terrain.payload.chunk_mismatch"),
                message: "TerrainPayload chunk coordinate does not match the expected chunk.",
                chunkCoord: payload.chunkCoord
            ))
        }

        let expectedHash = TerrainHasher.hash(
            chunkCoord: payload.chunkCoord,
            heightField: payload.heightField,
            heightSummary: payload.heightSummary,
            settings: payload.settings
        )

        if payload.stableHash != expectedHash {
            issues.append(TerrainValidationIssue(
                severity: .error,
                code: NamespaceID("terrain.payload.hash_mismatch"),
                message: "TerrainPayload stable hash does not match its contents.",
                chunkCoord: payload.chunkCoord
            ))
        }

        return issues
    }
}

/// Renderer-independent terrain payload for one chunk.
public struct TerrainPayload: Codable, Equatable, Hashable, Sendable {
    public let chunkCoord: ChunkCoord
    public let heightField: HeightField
    public let heightSummary: HeightSummary
    public let settings: TerrainGenerationSettings
    public let validationIssues: [TerrainValidationIssue]
    public let stableHash: StableHash

    public init(
        chunkCoord: ChunkCoord,
        heightField: HeightField,
        settings: TerrainGenerationSettings
    ) {
        let validationIssues = TerrainValidation.validate(heightField: heightField, chunkCoord: chunkCoord)
        precondition(!validationIssues.contains { $0.severity == .error }, "TerrainPayload requires a valid height field")
        guard let heightSummary = heightField.summary else {
            preconditionFailure("TerrainPayload requires finite height summary")
        }

        self.chunkCoord = chunkCoord
        self.heightField = heightField
        self.heightSummary = heightSummary
        self.settings = settings
        self.validationIssues = validationIssues
        self.stableHash = TerrainHasher.hash(
            chunkCoord: chunkCoord,
            heightField: heightField,
            heightSummary: heightSummary,
            settings: settings
        )
    }
}

/// Protocol boundary for deterministic terrain generators.
public protocol TerrainGenerating: Sendable {
    /// Builds a terrain payload for `chunkCoord` using explicit context and settings.
    func generateTerrain(
        context: WorldGenerationContext,
        chunkCoord: ChunkCoord,
        settings: TerrainGenerationSettings
    ) -> TerrainPayload
}

/// Stable hashing helper for terrain payload contracts.
public enum TerrainHasher {
    /// Hashes the stable contents of a terrain payload.
    public static func hash(
        chunkCoord: ChunkCoord,
        heightField: HeightField,
        heightSummary: HeightSummary,
        settings: TerrainGenerationSettings
    ) -> StableHash {
        var hasher = StableHasher()
        hasher.combine("Telluric.TerrainPayload.v1")
        hasher.combine(chunkCoord)
        hasher.combine(settings)
        hasher.combine(heightSummary)
        hasher.combine(heightField)
        return hasher.finalize()
    }
}
