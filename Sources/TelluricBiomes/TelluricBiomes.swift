import TelluricCore
import TelluricDeterminism
import TelluricMath
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

    /// Baseline deterministic biome profile.
    public static let baseline = BiomeRules(
        profile: NamespaceID("biome.baseline.v1"),
        allowsSecondaryBiome: false
    )

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

/// Stable biome IDs used by the baseline deterministic resolver.
public enum BaselineBiomeIDs {
    public static let snow = BiomeID("biome.snow")
    public static let tundra = BiomeID("biome.tundra")
    public static let mountain = BiomeID("biome.mountain")
    public static let desert = BiomeID("biome.desert")
    public static let grassland = BiomeID("biome.grassland")
    public static let temperateForest = BiomeID("biome.temperate_forest")
    public static let wetland = BiomeID("biome.wetland")
}

/// Successful deterministic biome resolution result.
public struct BiomeResolutionResult: Codable, Equatable, Hashable, Sendable {
    /// Generated renderer-independent biome payload.
    public let payload: BiomePayload

    /// Validation issues observed after resolution.
    public let validationIssues: [BiomeValidationIssue]

    /// Creates a biome resolution result.
    public init(payload: BiomePayload, validationIssues: [BiomeValidationIssue]) {
        self.payload = payload
        self.validationIssues = validationIssues
    }
}

/// Baseline deterministic biome resolver.
public struct DeterministicBiomeResolver: BiomeResolving, Sendable {
    /// Creates the baseline biome resolver.
    public init() {}

    /// Resolves valid deterministic biome payload for `chunkCoord`.
    public func resolveBiomes(
        context: WorldGenerationContext,
        chunkCoord: ChunkCoord,
        terrain: TerrainPayload,
        rules: BiomeRules
    ) -> BiomePayload {
        resolveBiomesResult(
            context: context,
            chunkCoord: chunkCoord,
            terrain: terrain,
            rules: rules
        ).payload
    }

    /// Resolves biome payload and exposes validation issues.
    public func resolveBiomesResult(
        context: WorldGenerationContext,
        chunkCoord: ChunkCoord,
        terrain: TerrainPayload,
        rules: BiomeRules
    ) -> BiomeResolutionResult {
        precondition(context.config.chunkSize > 0, "WorldConfig.chunkSize must be positive")
        precondition(terrain.chunkCoord == chunkCoord, "TerrainPayload chunk coordinate must match biome chunk coordinate")

        let width = terrain.heightField.width
        let depth = terrain.heightField.depth
        let originX = chunkCoord.x * Int64(context.config.chunkSize)
        let originZ = chunkCoord.z * Int64(context.config.chunkSize)
        var samples: [BiomeSample] = []
        samples.reserveCapacity(width * depth)

        for z in 0..<depth {
            for x in 0..<width {
                guard let heightSample = terrain.heightField.sample(x: x, z: z) else {
                    preconditionFailure("TerrainPayload has inconsistent height field dimensions")
                }

                let worldX = originX + Int64(x)
                let worldZ = originZ + Int64(z)
                samples.append(Self.sampleBiome(
                    context: context,
                    chunkY: chunkCoord.y,
                    worldX: worldX,
                    worldZ: worldZ,
                    height: heightSample.height,
                    terrain: terrain,
                    rules: rules
                ))
            }
        }

        let field = BiomeField(width: width, depth: depth, samples: samples)
        let validationIssues = BiomeValidation.validate(field: field, rules: rules, chunkCoord: chunkCoord)
        precondition(!validationIssues.contains { $0.severity == .error }, "DeterministicBiomeResolver produced invalid biome field")

        let payload = BiomePayload(chunkCoord: chunkCoord, field: field, rules: rules)
        return BiomeResolutionResult(
            payload: payload,
            validationIssues: BiomeValidation.validate(payload: payload, expectedChunkCoord: chunkCoord)
        )
    }

    private static func sampleBiome(
        context: WorldGenerationContext,
        chunkY: Int64,
        worldX: Int64,
        worldZ: Int64,
        height: Float,
        terrain: TerrainPayload,
        rules: BiomeRules
    ) -> BiomeSample {
        let chunkSize = context.config.chunkSize
        let moistureNoise = BiomeValueNoise.sample(
            context: context,
            namespace: NamespaceID("biome.baseline.moisture"),
            chunkY: chunkY,
            worldX: worldX,
            worldZ: worldZ,
            cellSize: max(4, chunkSize * 3)
        )
        let temperatureNoise = BiomeValueNoise.sample(
            context: context,
            namespace: NamespaceID("biome.baseline.temperature"),
            chunkY: chunkY,
            worldX: worldX,
            worldZ: worldZ,
            cellSize: max(4, chunkSize * 4)
        )
        let vegetationNoise = BiomeValueNoise.sample(
            context: context,
            namespace: NamespaceID("biome.baseline.vegetation"),
            chunkY: chunkY,
            worldX: worldX,
            worldZ: worldZ,
            cellSize: max(2, chunkSize * 2)
        )

        let amplitude = max(context.config.verticalScale * terrain.settings.heightScale, 0.0001)
        let elevation = saturate((height / amplitude + 1) * 0.5)
        let moisture = saturate(moistureNoise * 0.78 + (1 - elevation) * 0.12 + (vegetationNoise - 0.5) * 0.10)
        let temperature = saturate(0.95 - elevation * 0.75 + (temperatureNoise - 0.5) * 0.35)
        let climateFitness = saturate(1 - abs(temperature - 0.55) * 1.4)
        let vegetationDensity = saturate((moisture * 0.75 + vegetationNoise * 0.25) * climateFitness * (1 - elevation * 0.30))

        return BiomeSample(
            primaryBiome: primaryBiome(
                elevation: elevation,
                moisture: moisture,
                temperature: temperature,
                vegetationDensity: vegetationDensity
            ),
            secondaryBiome: nil,
            secondaryWeight: 0,
            moisture: moisture,
            temperature: temperature,
            vegetationDensity: vegetationDensity
        )
    }

    private static func primaryBiome(
        elevation: Float,
        moisture: Float,
        temperature: Float,
        vegetationDensity: Float
    ) -> BiomeID {
        if elevation > 0.86 {
            return temperature < 0.42 ? BaselineBiomeIDs.snow : BaselineBiomeIDs.mountain
        }

        if temperature < 0.24 {
            return BaselineBiomeIDs.tundra
        }

        if moisture < 0.20 && temperature > 0.55 {
            return BaselineBiomeIDs.desert
        }

        if moisture > 0.72 && elevation < 0.55 {
            return BaselineBiomeIDs.wetland
        }

        if vegetationDensity > 0.42 && moisture > 0.46 {
            return BaselineBiomeIDs.temperateForest
        }

        return BaselineBiomeIDs.grassland
    }
}

/// Concrete chunk component generator that runs terrain generation then biome resolution.
public struct DeterministicTerrainBiomeChunkGenerator: WorldChunkComponentGenerating, Sendable {
    public let terrainGenerator: DeterministicTerrainGenerator
    public let terrainSettings: TerrainGenerationSettings
    public let biomeResolver: DeterministicBiomeResolver
    public let biomeRules: BiomeRules

    /// Creates the baseline terrain+biome component generator.
    public init(
        terrainGenerator: DeterministicTerrainGenerator = DeterministicTerrainGenerator(),
        terrainSettings: TerrainGenerationSettings = .baseline,
        biomeResolver: DeterministicBiomeResolver = DeterministicBiomeResolver(),
        biomeRules: BiomeRules = .baseline
    ) {
        self.terrainGenerator = terrainGenerator
        self.terrainSettings = terrainSettings
        self.biomeResolver = biomeResolver
        self.biomeRules = biomeRules
    }

    public func generateChunkComponents(
        context: WorldGenerationContext,
        chunkCoord: ChunkCoord
    ) throws -> WorldChunkComponentGeneration {
        let terrainResult = terrainGenerator.generateTerrainResult(
            context: context,
            chunkCoord: chunkCoord,
            settings: terrainSettings
        )
        let biomeResult = biomeResolver.resolveBiomesResult(
            context: context,
            chunkCoord: chunkCoord,
            terrain: terrainResult.payload,
            rules: biomeRules
        )
        let issues = Self.worldIssues(from: terrainResult.validationIssues) +
            Self.worldIssues(from: biomeResult.validationIssues)
        let report = WorldGenerationReport(issues: issues)

        if report.hasErrors {
            throw WorldGenerationError(report: report)
        }

        return WorldChunkComponentGeneration(
            componentHashes: [
                ChunkPayloadComponentHash(kind: .terrain, stableHash: terrainResult.payload.stableHash),
                ChunkPayloadComponentHash(kind: .biomes, stableHash: biomeResult.payload.stableHash),
            ],
            report: report
        )
    }

    private static func worldIssues(from issues: [TerrainValidationIssue]) -> [WorldGenerationIssue] {
        issues.map { issue in
            WorldGenerationIssue(
                severity: issue.severity == .error ? .error : .warning,
                code: issue.code,
                message: issue.message,
                chunkCoord: issue.chunkCoord
            )
        }
    }

    private static func worldIssues(from issues: [BiomeValidationIssue]) -> [WorldGenerationIssue] {
        issues.map { issue in
            WorldGenerationIssue(
                severity: issue.severity == .error ? .error : .warning,
                code: issue.code,
                message: issue.message,
                chunkCoord: issue.chunkCoord
            )
        }
    }
}

private enum BiomeValueNoise {
    static func sample(
        context: WorldGenerationContext,
        namespace: NamespaceID,
        chunkY: Int64,
        worldX: Int64,
        worldZ: Int64,
        cellSize: Int
    ) -> Float {
        precondition(cellSize > 0, "cellSize must be positive")

        let size = Int64(cellSize)
        let cellX = floorDiv(worldX, by: size)
        let cellZ = floorDiv(worldZ, by: size)
        let localX = Float(floorMod(worldX, by: size)) / Float(cellSize)
        let localZ = Float(floorMod(worldZ, by: size)) / Float(cellSize)
        let tx = smooth(localX)
        let tz = smooth(localZ)

        let v00 = latticeValue(context: context, namespace: namespace, x: cellX, y: chunkY, z: cellZ)
        let v10 = latticeValue(context: context, namespace: namespace, x: cellX + 1, y: chunkY, z: cellZ)
        let v01 = latticeValue(context: context, namespace: namespace, x: cellX, y: chunkY, z: cellZ + 1)
        let v11 = latticeValue(context: context, namespace: namespace, x: cellX + 1, y: chunkY, z: cellZ + 1)

        let a = lerp(v00, v10, t: tx)
        let b = lerp(v01, v11, t: tx)
        return lerp(a, b, t: tz)
    }

    private static func latticeValue(
        context: WorldGenerationContext,
        namespace: NamespaceID,
        x: Int64,
        y: Int64,
        z: Int64
    ) -> Float {
        let seed = context.derivedSeed(
            namespace: namespace,
            coordinates: Int3(x: x, y: y, z: z)
        )
        var rng = DeterministicRNG(seed: seed)
        return rng.nextUnitFloat()
    }

    private static func smooth(_ t: Float) -> Float {
        t * t * (3 - 2 * t)
    }

    private static func floorDiv(_ value: Int64, by divisor: Int64) -> Int64 {
        let quotient = value / divisor
        let remainder = value % divisor
        return remainder < 0 ? quotient - 1 : quotient
    }

    private static func floorMod(_ value: Int64, by divisor: Int64) -> Int64 {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}
