import TelluricCore
import TelluricDeterminism
import TelluricTerrain
import TelluricWorld

/// Stable identifier for a biome definition.
public struct BiomeID: Codable, Comparable, Hashable, Sendable, StableHashable {
    public let rawValue: NamespaceID

    public init(_ rawValue: NamespaceID) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.init(NamespaceID(rawValue))
    }

    public static func < (lhs: BiomeID, rhs: BiomeID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

/// One biome field sample.
public struct BiomeSample: Codable, Equatable, Hashable, Sendable, StableHashable {
    public let primaryBiome: BiomeID
    public let secondaryBiome: BiomeID?
    public let secondaryWeight: Float
    public let moisture: Float
    public let temperature: Float
    public let vegetationDensity: Float

    public init(
        primaryBiome: BiomeID,
        secondaryBiome: BiomeID? = nil,
        secondaryWeight: Float = 0,
        moisture: Float,
        temperature: Float,
        vegetationDensity: Float
    ) {
        self.primaryBiome = primaryBiome
        self.secondaryBiome = secondaryBiome
        self.secondaryWeight = secondaryWeight
        self.moisture = moisture
        self.temperature = temperature
        self.vegetationDensity = vegetationDensity
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(primaryBiome)
        hasher.combine(secondaryBiome != nil)
        if let secondaryBiome {
            hasher.combine(secondaryBiome)
        }

        hasher.combine(secondaryWeight)
        hasher.combine(moisture)
        hasher.combine(temperature)
        hasher.combine(vegetationDensity)
    }
}

/// Rectangular ordered biome field for one chunk.
public struct BiomeField: Codable, Equatable, Hashable, Sendable, StableHashable {
    public let width: Int
    public let depth: Int
    public let samples: [BiomeSample]

    public init(width: Int, depth: Int, samples: [BiomeSample]) {
        self.width = width
        self.depth = depth
        self.samples = samples
    }

    /// Returns the sample at `x,z`, or nil if outside the field.
    public func sample(x: Int, z: Int) -> BiomeSample? {
        guard x >= 0, z >= 0, x < width, z < depth else {
            return nil
        }

        let index = z * width + x
        guard index >= 0, index < samples.count else {
            return nil
        }

        return samples[index]
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

/// Rule identifiers and constraints used by a biome resolver.
public struct BiomeRules: Codable, Equatable, Hashable, Sendable, StableHashable {
    public let profile: NamespaceID
    public let allowsSecondaryBiome: Bool

    public init(profile: NamespaceID, allowsSecondaryBiome: Bool) {
        self.profile = profile
        self.allowsSecondaryBiome = allowsSecondaryBiome
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(profile)
        hasher.combine(allowsSecondaryBiome)
    }
}

/// Severity for biome validation issues.
public enum BiomeValidationSeverity: String, Codable, Comparable, Sendable {
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

    public static func < (lhs: BiomeValidationSeverity, rhs: BiomeValidationSeverity) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Serializable biome validation issue.
public struct BiomeValidationIssue: Codable, Equatable, Hashable, Sendable {
    public let severity: BiomeValidationSeverity
    public let code: NamespaceID
    public let message: String
    public let chunkCoord: ChunkCoord?
    public let sampleIndex: Int?

    public init(
        severity: BiomeValidationSeverity,
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

/// Biome validation helpers.
public enum BiomeValidation {
    /// Validates a biome field and returns ordered issues.
    public static func validate(field: BiomeField, rules: BiomeRules? = nil, chunkCoord: ChunkCoord? = nil) -> [BiomeValidationIssue] {
        var issues: [BiomeValidationIssue] = []

        if field.width <= 0 || field.depth <= 0 {
            issues.append(BiomeValidationIssue(
                severity: .error,
                code: NamespaceID("biome.field.invalid_dimensions"),
                message: "BiomeField dimensions must be positive.",
                chunkCoord: chunkCoord
            ))
        }

        let expectedSampleCount = field.width > 0 && field.depth > 0 ? field.width * field.depth : 0
        if field.samples.count != expectedSampleCount {
            issues.append(BiomeValidationIssue(
                severity: .error,
                code: NamespaceID("biome.field.invalid_sample_count"),
                message: "BiomeField sample count must equal width * depth.",
                chunkCoord: chunkCoord
            ))
        }

        if field.samples.isEmpty {
            issues.append(BiomeValidationIssue(
                severity: .error,
                code: NamespaceID("biome.field.empty"),
                message: "BiomeField must contain samples.",
                chunkCoord: chunkCoord
            ))
        }

        for (index, sample) in field.samples.enumerated() {
            validate(sample: sample, rules: rules, chunkCoord: chunkCoord, sampleIndex: index, issues: &issues)
        }

        return issues
    }

    /// Validates one biome sample and returns ordered issues.
    public static func validate(sample: BiomeSample, rules: BiomeRules? = nil) -> [BiomeValidationIssue] {
        var issues: [BiomeValidationIssue] = []
        validate(sample: sample, rules: rules, chunkCoord: nil, sampleIndex: nil, issues: &issues)
        return issues
    }

    /// Validates a biome payload and optionally checks it against an expected chunk.
    public static func validate(payload: BiomePayload, expectedChunkCoord: ChunkCoord? = nil) -> [BiomeValidationIssue] {
        var issues = validate(field: payload.field, rules: payload.rules, chunkCoord: payload.chunkCoord)

        if let expectedChunkCoord, payload.chunkCoord != expectedChunkCoord {
            issues.append(BiomeValidationIssue(
                severity: .error,
                code: NamespaceID("biome.payload.chunk_mismatch"),
                message: "BiomePayload chunk coordinate does not match the expected chunk.",
                chunkCoord: payload.chunkCoord
            ))
        }

        let expectedHash = BiomeHasher.hash(
            chunkCoord: payload.chunkCoord,
            field: payload.field,
            rules: payload.rules
        )

        if payload.stableHash != expectedHash {
            issues.append(BiomeValidationIssue(
                severity: .error,
                code: NamespaceID("biome.payload.hash_mismatch"),
                message: "BiomePayload stable hash does not match its contents.",
                chunkCoord: payload.chunkCoord
            ))
        }

        return issues
    }

    private static func validate(
        sample: BiomeSample,
        rules: BiomeRules?,
        chunkCoord: ChunkCoord?,
        sampleIndex: Int?,
        issues: inout [BiomeValidationIssue]
    ) {
        validateUnitInterval(sample.moisture, code: "biome.sample.invalid_moisture", label: "moisture", chunkCoord: chunkCoord, sampleIndex: sampleIndex, issues: &issues)
        validateUnitInterval(sample.temperature, code: "biome.sample.invalid_temperature", label: "temperature", chunkCoord: chunkCoord, sampleIndex: sampleIndex, issues: &issues)
        validateUnitInterval(sample.vegetationDensity, code: "biome.sample.invalid_vegetation_density", label: "vegetationDensity", chunkCoord: chunkCoord, sampleIndex: sampleIndex, issues: &issues)
        validateUnitInterval(sample.secondaryWeight, code: "biome.sample.invalid_secondary_weight", label: "secondaryWeight", chunkCoord: chunkCoord, sampleIndex: sampleIndex, issues: &issues)

        if sample.secondaryBiome == nil && sample.secondaryWeight != 0 {
            issues.append(BiomeValidationIssue(
                severity: .error,
                code: NamespaceID("biome.sample.secondary_weight_without_biome"),
                message: "BiomeSample.secondaryWeight must be zero when no secondary biome is present.",
                chunkCoord: chunkCoord,
                sampleIndex: sampleIndex
            ))
        }

        if let rules, !rules.allowsSecondaryBiome, sample.secondaryBiome != nil {
            issues.append(BiomeValidationIssue(
                severity: .error,
                code: NamespaceID("biome.sample.secondary_biome_not_allowed"),
                message: "BiomeRules disallow secondary biome blending.",
                chunkCoord: chunkCoord,
                sampleIndex: sampleIndex
            ))
        }
    }

    private static func validateUnitInterval(
        _ value: Float,
        code: String,
        label: String,
        chunkCoord: ChunkCoord?,
        sampleIndex: Int?,
        issues: inout [BiomeValidationIssue]
    ) {
        if !value.isFinite || value < 0 || value > 1 {
            issues.append(BiomeValidationIssue(
                severity: .error,
                code: NamespaceID(code),
                message: "BiomeSample.\(label) must be finite and within 0...1.",
                chunkCoord: chunkCoord,
                sampleIndex: sampleIndex
            ))
        }
    }
}

/// Renderer-independent biome payload for one chunk.
public struct BiomePayload: Codable, Equatable, Hashable, Sendable {
    public let chunkCoord: ChunkCoord
    public let field: BiomeField
    public let rules: BiomeRules
    public let validationIssues: [BiomeValidationIssue]
    public let stableHash: StableHash

    public init(chunkCoord: ChunkCoord, field: BiomeField, rules: BiomeRules) {
        let validationIssues = BiomeValidation.validate(field: field, rules: rules, chunkCoord: chunkCoord)
        precondition(!validationIssues.contains { $0.severity == .error }, "BiomePayload requires a valid biome field")

        self.chunkCoord = chunkCoord
        self.field = field
        self.rules = rules
        self.validationIssues = validationIssues
        self.stableHash = BiomeHasher.hash(chunkCoord: chunkCoord, field: field, rules: rules)
    }
}

/// Protocol boundary for deterministic biome resolvers.
public protocol BiomeResolving: Sendable {
    /// Builds a biome payload for `chunkCoord` from explicit terrain and rules.
    func resolveBiomes(
        context: WorldGenerationContext,
        chunkCoord: ChunkCoord,
        terrain: TerrainPayload,
        rules: BiomeRules
    ) -> BiomePayload
}

/// Stable hashing helper for biome payload contracts.
public enum BiomeHasher {
    /// Hashes the stable contents of a biome payload.
    public static func hash(chunkCoord: ChunkCoord, field: BiomeField, rules: BiomeRules) -> StableHash {
        var hasher = StableHasher()
        hasher.combine("Telluric.BiomePayload.v1")
        hasher.combine(chunkCoord)
        hasher.combine(rules)
        hasher.combine(field)
        return hasher.finalize()
    }
}
