import Foundation
import TelluricBiomes
import TelluricCore
import TelluricDeterminism
import TelluricDiagnostics
import TelluricWorld

/// Parsed command-line configuration for the seed validator.
public struct SeedValidatorArguments: Equatable, Sendable {
    /// Root deterministic world seed.
    public let seed: UInt64

    /// Inclusive chunk radius around the origin.
    public let radius: Int

    /// Number of terrain cells along one chunk axis.
    public let chunkSize: Int

    /// Vertical terrain amplitude passed into `WorldConfig`.
    public let verticalScale: Float

    /// Optional JSON report path.
    public let reportPath: String?

    /// Stops chunk validation after the first invalid chunk or generation error.
    public let failFast: Bool

    /// Prints per-chunk summary lines.
    public let verbose: Bool

    /// True when help text was requested.
    public let help: Bool

    /// Creates parsed seed validator arguments.
    public init(
        seed: UInt64,
        radius: Int,
        chunkSize: Int,
        verticalScale: Float,
        reportPath: String? = nil,
        failFast: Bool = false,
        verbose: Bool = false,
        help: Bool = false
    ) {
        self.seed = seed
        self.radius = radius
        self.chunkSize = chunkSize
        self.verticalScale = verticalScale
        self.reportPath = reportPath
        self.failFast = failFast
        self.verbose = verbose
        self.help = help
    }
}

/// User-facing CLI parsing errors.
public enum SeedValidatorArgumentError: Error, Equatable, CustomStringConvertible, Sendable {
    case missingRequiredOption(String)
    case missingValue(option: String)
    case invalidValue(option: String, value: String, reason: String)
    case unknownOption(String)

    public var description: String {
        switch self {
        case let .missingRequiredOption(option):
            return "Missing required option \(option)."
        case let .missingValue(option):
            return "Missing value for \(option)."
        case let .invalidValue(option, value, reason):
            return "Invalid value for \(option): \(value). \(reason)"
        case let .unknownOption(option):
            return "Unknown option \(option)."
        }
    }
}

/// Dependency-free parser for `telluric-seed-validator`.
public enum SeedValidatorArgumentParser {
    /// Parses process arguments excluding executable name.
    public static func parse(_ arguments: [String]) throws -> SeedValidatorArguments {
        var seed: UInt64?
        var radius: Int?
        var chunkSize: Int?
        var verticalScale: Float?
        var reportPath: String?
        var failFast = false
        var verbose = false
        var help = false

        var index = 0
        while index < arguments.count {
            let option = arguments[index]

            switch option {
            case "--help", "-h":
                help = true
                index += 1

            case "--fail-fast":
                failFast = true
                index += 1

            case "--verbose":
                verbose = true
                index += 1

            case "--seed":
                let value = try value(after: option, index: index, arguments: arguments)
                guard let parsed = UInt64(value) else {
                    throw SeedValidatorArgumentError.invalidValue(
                        option: option,
                        value: value,
                        reason: "Expected an unsigned 64-bit integer."
                    )
                }
                seed = parsed
                index += 2

            case "--radius":
                let value = try value(after: option, index: index, arguments: arguments)
                guard let parsed = Int(value), parsed >= 0 else {
                    throw SeedValidatorArgumentError.invalidValue(
                        option: option,
                        value: value,
                        reason: "Expected a non-negative integer."
                    )
                }
                try validateGridSize(radius: parsed, option: option, value: value)
                radius = parsed
                index += 2

            case "--chunk-size":
                let value = try value(after: option, index: index, arguments: arguments)
                guard let parsed = Int(value), parsed > 0 else {
                    throw SeedValidatorArgumentError.invalidValue(
                        option: option,
                        value: value,
                        reason: "Expected a positive integer."
                    )
                }
                chunkSize = parsed
                index += 2

            case "--vertical-scale":
                let value = try value(after: option, index: index, arguments: arguments)
                guard let parsed = Float(value), parsed.isFinite, parsed > 0 else {
                    throw SeedValidatorArgumentError.invalidValue(
                        option: option,
                        value: value,
                        reason: "Expected a finite positive number."
                    )
                }
                verticalScale = parsed
                index += 2

            case "--report":
                reportPath = try value(after: option, index: index, arguments: arguments)
                index += 2

            default:
                throw SeedValidatorArgumentError.unknownOption(option)
            }
        }

        if help {
            return SeedValidatorArguments(
                seed: seed ?? 0,
                radius: radius ?? 0,
                chunkSize: chunkSize ?? 1,
                verticalScale: verticalScale ?? 1,
                reportPath: reportPath,
                failFast: failFast,
                verbose: verbose,
                help: true
            )
        }

        guard let seed else {
            throw SeedValidatorArgumentError.missingRequiredOption("--seed")
        }
        guard let radius else {
            throw SeedValidatorArgumentError.missingRequiredOption("--radius")
        }
        guard let chunkSize else {
            throw SeedValidatorArgumentError.missingRequiredOption("--chunk-size")
        }
        guard let verticalScale else {
            throw SeedValidatorArgumentError.missingRequiredOption("--vertical-scale")
        }

        return SeedValidatorArguments(
            seed: seed,
            radius: radius,
            chunkSize: chunkSize,
            verticalScale: verticalScale,
            reportPath: reportPath,
            failFast: failFast,
            verbose: verbose
        )
    }

    private static func value(after option: String, index: Int, arguments: [String]) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw SeedValidatorArgumentError.missingValue(option: option)
        }

        return arguments[valueIndex]
    }

    private static func validateGridSize(radius: Int, option: String, value: String) throws {
        let (doubled, doubledOverflow) = radius.multipliedReportingOverflow(by: 2)
        let (span, spanOverflow) = doubled.addingReportingOverflow(1)
        let (_, countOverflow) = span.multipliedReportingOverflow(by: span)
        guard !doubledOverflow, !spanOverflow, !countOverflow else {
            throw SeedValidatorArgumentError.invalidValue(
                option: option,
                value: value,
                reason: "The resulting chunk grid is too large."
            )
        }
    }
}

/// Help text for the seed validator executable.
public enum SeedValidatorHelp {
    public static let text = """
    Usage:
      swift run telluric-seed-validator --seed <UInt64> --radius <Int> --chunk-size <Int> --vertical-scale <Float> [--report <path>] [--fail-fast] [--verbose]

    Options:
      --seed <UInt64>          Root deterministic world seed.
      --radius <Int>          Inclusive square chunk radius around the origin.
      --chunk-size <Int>      Positive chunk cell size.
      --vertical-scale <Float> Finite positive vertical terrain scale.
      --report <path>         Optional deterministic JSON report path.
      --fail-fast             Stop after the first invalid chunk or generation error.
      --verbose               Print ordered per-chunk hashes.
      --help, -h              Show this help text.
    """
}

/// Ordered result for one generated chunk.
public struct SeedValidationChunkResult: Codable, Equatable, Sendable {
    /// Chunk coordinate validated by the tool.
    public let chunkCoord: ChunkCoord

    /// True when generation and validation succeeded for this chunk.
    public let isValid: Bool

    /// Aggregate chunk payload hash when generation produced a payload.
    public let stableHash: StableHash?

    /// Ordered component hashes included in the aggregate payload.
    public let componentHashes: [ChunkPayloadComponentHash]

    /// Ordered diagnostics specific to this chunk.
    public let diagnostics: [DiagnosticMessage]

    /// Creates a chunk result.
    public init(
        chunkCoord: ChunkCoord,
        isValid: Bool,
        stableHash: StableHash?,
        componentHashes: [ChunkPayloadComponentHash],
        diagnostics: [DiagnosticMessage]
    ) {
        self.chunkCoord = chunkCoord
        self.isValid = isValid
        self.stableHash = stableHash
        self.componentHashes = componentHashes
        self.diagnostics = diagnostics
    }
}

/// Deterministic JSON report emitted by `telluric-seed-validator`.
public struct SeedValidationReport: Codable, Equatable, Sendable {
    public let toolName: String
    public let toolVersion: EngineVersion
    public let engineVersion: EngineVersion
    public let seed: WorldSeed
    public let radius: Int
    public let chunkSize: Int
    public let verticalScale: Float
    public let totalChunks: Int
    public let chunksGenerated: Int
    public let validChunks: Int
    public let invalidChunks: Int
    public let diagnosticsSummary: DiagnosticSummary
    public let chunkResults: [SeedValidationChunkResult]
    public let diagnostics: [DiagnosticMessage]
    public let rootHash: StableHash?
    public let success: Bool

    /// Creates a seed validation report from ordered records.
    public init(
        toolName: String,
        toolVersion: EngineVersion,
        engineVersion: EngineVersion,
        seed: WorldSeed,
        radius: Int,
        chunkSize: Int,
        verticalScale: Float,
        totalChunks: Int,
        chunksGenerated: Int,
        validChunks: Int,
        invalidChunks: Int,
        diagnosticsSummary: DiagnosticSummary,
        chunkResults: [SeedValidationChunkResult],
        diagnostics: [DiagnosticMessage],
        rootHash: StableHash?,
        success: Bool
    ) {
        self.toolName = toolName
        self.toolVersion = toolVersion
        self.engineVersion = engineVersion
        self.seed = seed
        self.radius = radius
        self.chunkSize = chunkSize
        self.verticalScale = verticalScale
        self.totalChunks = totalChunks
        self.chunksGenerated = chunksGenerated
        self.validChunks = validChunks
        self.invalidChunks = invalidChunks
        self.diagnosticsSummary = diagnosticsSummary
        self.chunkResults = chunkResults
        self.diagnostics = diagnostics
        self.rootHash = rootHash
        self.success = success
    }
}

/// Result from a seed validator CLI run.
public struct SeedValidatorRunResult: Equatable, Sendable {
    public let report: SeedValidationReport
    public let summary: String
    public let exitCode: Int32

    /// Creates a run result.
    public init(report: SeedValidationReport, summary: String, exitCode: Int32) {
        self.report = report
        self.summary = summary
        self.exitCode = exitCode
    }
}

/// Deterministic seed validation runner.
public struct SeedValidator: Sendable {
    public static let toolName = "telluric-seed-validator"
    public static let toolVersion = EngineVersion(major: 0, minor: 4, patch: 0)
    public static let engineVersion = EngineVersion(major: 1, minor: 0, patch: 0)

    private let generator: DeterministicWorldGenerator

    /// Creates a validator using the baseline deterministic world generator.
    public init(
        generator: DeterministicWorldGenerator = DeterministicWorldGenerator(
            componentGenerator: DeterministicTerrainBiomeChunkGenerator()
        )
    ) {
        self.generator = generator
    }

    /// Validates the configured chunk grid and optionally writes a JSON report.
    public func run(arguments: SeedValidatorArguments) throws -> SeedValidatorRunResult {
        let report = validate(arguments: arguments)

        if let reportPath = arguments.reportPath {
            try Self.write(report: report, to: reportPath)
        }

        return SeedValidatorRunResult(
            report: report,
            summary: Self.summary(for: report, verbose: arguments.verbose),
            exitCode: report.success ? 0 : 1
        )
    }

    /// Validates the configured chunk grid.
    public func validate(arguments: SeedValidatorArguments) -> SeedValidationReport {
        if arguments.radius < 0 {
            let diagnostics = [
                DiagnosticMessage(
                    severity: .error,
                    code: NamespaceID("seed_validator.invalid_radius"),
                    message: "Radius must be non-negative.",
                    source: "TelluricSeedValidator"
                ),
            ]
            return Self.makeReport(
                arguments: arguments,
                totalChunks: 0,
                chunksGenerated: 0,
                validChunks: 0,
                invalidChunks: 0,
                chunkResults: [],
                diagnostics: diagnostics
            )
        }

        let totalChunks = Self.totalChunkCount(radius: arguments.radius)
        let config = WorldConfig(
            worldSeed: WorldSeed(rawValue: arguments.seed),
            chunkSize: arguments.chunkSize,
            verticalScale: arguments.verticalScale,
            generationProfile: NamespaceID("world.profile.baseline")
        )
        let context = WorldGenerationContext(
            config: config,
            engineVersion: Self.engineVersion
        )

        var chunkResults: [SeedValidationChunkResult] = []
        var diagnostics: [DiagnosticMessage] = []
        var chunksGenerated = 0
        var validChunks = 0
        var invalidChunks = 0

        for z in (-arguments.radius)...arguments.radius {
            for x in (-arguments.radius)...arguments.radius {
                let chunkCoord = ChunkCoord(x: Int64(x), y: 0, z: Int64(z))

                do {
                    let generation = try generator.generateChunk(at: chunkCoord, context: context)
                    let chunkDiagnostics = Self.diagnostics(from: generation.report)
                    let isValid = generation.report.isSuccess

                    chunksGenerated += 1
                    validChunks += isValid ? 1 : 0
                    invalidChunks += isValid ? 0 : 1
                    diagnostics.append(contentsOf: chunkDiagnostics)
                    chunkResults.append(SeedValidationChunkResult(
                        chunkCoord: chunkCoord,
                        isValid: isValid,
                        stableHash: generation.payload.stableHash,
                        componentHashes: generation.payload.componentHashes,
                        diagnostics: chunkDiagnostics
                    ))
                } catch let error as WorldGenerationError {
                    let chunkDiagnostics = Self.diagnostics(from: error.report)
                    invalidChunks += 1
                    diagnostics.append(contentsOf: chunkDiagnostics)
                    chunkResults.append(SeedValidationChunkResult(
                        chunkCoord: chunkCoord,
                        isValid: false,
                        stableHash: nil,
                        componentHashes: [],
                        diagnostics: chunkDiagnostics
                    ))
                } catch {
                    let chunkDiagnostics = [
                        DiagnosticMessage(
                            severity: .error,
                            code: NamespaceID("seed_validator.generation_failed"),
                            message: "Chunk generation failed: \(String(describing: error))",
                            source: "TelluricSeedValidator",
                            metadata: Self.metadata(for: chunkCoord)
                        ),
                    ]
                    invalidChunks += 1
                    diagnostics.append(contentsOf: chunkDiagnostics)
                    chunkResults.append(SeedValidationChunkResult(
                        chunkCoord: chunkCoord,
                        isValid: false,
                        stableHash: nil,
                        componentHashes: [],
                        diagnostics: chunkDiagnostics
                    ))
                }

                if arguments.failFast && invalidChunks > 0 {
                    return Self.makeReport(
                        arguments: arguments,
                        totalChunks: totalChunks,
                        chunksGenerated: chunksGenerated,
                        validChunks: validChunks,
                        invalidChunks: invalidChunks,
                        chunkResults: chunkResults,
                        diagnostics: diagnostics
                    )
                }
            }
        }

        return Self.makeReport(
            arguments: arguments,
            totalChunks: totalChunks,
            chunksGenerated: chunksGenerated,
            validChunks: validChunks,
            invalidChunks: invalidChunks,
            chunkResults: chunkResults,
            diagnostics: diagnostics
        )
    }

    /// Writes a deterministic JSON report to disk.
    public static func write(report: SeedValidationReport, to path: String) throws {
        let url = URL(fileURLWithPath: path)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try jsonEncoder().encode(report)
        try data.write(to: url, options: [.atomic])
    }

    /// Creates the stable JSON encoder used for seed validation reports.
    public static func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    /// Creates a human-readable validation summary.
    public static func summary(for report: SeedValidationReport, verbose: Bool = false) -> String {
        var lines = [
            "\(report.toolName) \(report.toolVersion)",
            "seed: \(report.seed.rawValue)",
            "radius: \(report.radius)",
            "chunk size: \(report.chunkSize)",
            "vertical scale: \(report.verticalScale)",
            "chunks: requested \(report.totalChunks), generated \(report.chunksGenerated), valid \(report.validChunks), invalid \(report.invalidChunks)",
            "diagnostics: info \(report.diagnosticsSummary.infos), warning \(report.diagnosticsSummary.warnings), error \(report.diagnosticsSummary.errors)",
            "root hash: \(report.rootHash?.description ?? "unavailable")",
            "success: \(report.success)",
        ]

        if verbose {
            for chunk in report.chunkResults {
                lines.append(
                    "chunk (\(chunk.chunkCoord.x), \(chunk.chunkCoord.y), \(chunk.chunkCoord.z)): \(chunk.stableHash?.description ?? "invalid")"
                )
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func makeReport(
        arguments: SeedValidatorArguments,
        totalChunks: Int,
        chunksGenerated: Int,
        validChunks: Int,
        invalidChunks: Int,
        chunkResults: [SeedValidationChunkResult],
        diagnostics: [DiagnosticMessage]
    ) -> SeedValidationReport {
        let diagnosticReport = DiagnosticReport(messages: diagnostics)
        let success = invalidChunks == 0 && !diagnosticReport.hasErrors
        let reportWithoutHash = SeedValidationReport(
            toolName: toolName,
            toolVersion: toolVersion,
            engineVersion: engineVersion,
            seed: WorldSeed(rawValue: arguments.seed),
            radius: arguments.radius,
            chunkSize: arguments.chunkSize,
            verticalScale: arguments.verticalScale,
            totalChunks: totalChunks,
            chunksGenerated: chunksGenerated,
            validChunks: validChunks,
            invalidChunks: invalidChunks,
            diagnosticsSummary: diagnosticReport.summary,
            chunkResults: chunkResults,
            diagnostics: diagnostics,
            rootHash: nil,
            success: success
        )

        return SeedValidationReport(
            toolName: reportWithoutHash.toolName,
            toolVersion: reportWithoutHash.toolVersion,
            engineVersion: reportWithoutHash.engineVersion,
            seed: reportWithoutHash.seed,
            radius: reportWithoutHash.radius,
            chunkSize: reportWithoutHash.chunkSize,
            verticalScale: reportWithoutHash.verticalScale,
            totalChunks: reportWithoutHash.totalChunks,
            chunksGenerated: reportWithoutHash.chunksGenerated,
            validChunks: reportWithoutHash.validChunks,
            invalidChunks: reportWithoutHash.invalidChunks,
            diagnosticsSummary: reportWithoutHash.diagnosticsSummary,
            chunkResults: reportWithoutHash.chunkResults,
            diagnostics: reportWithoutHash.diagnostics,
            rootHash: rootHash(for: reportWithoutHash),
            success: reportWithoutHash.success
        )
    }

    private static func totalChunkCount(radius: Int) -> Int {
        guard radius >= 0 else {
            return 0
        }

        let span = radius * 2 + 1
        return span * span
    }

    private static func diagnostics(from report: WorldGenerationReport) -> [DiagnosticMessage] {
        report.issues.map { issue in
            DiagnosticMessage(
                severity: diagnosticSeverity(from: issue.severity),
                code: issue.code,
                message: issue.message,
                source: "TelluricWorld",
                metadata: issue.chunkCoord.map(metadata(for:)) ?? []
            )
        }
    }

    private static func diagnosticSeverity(from severity: WorldGenerationIssueSeverity) -> DiagnosticSeverity {
        switch severity {
        case .info:
            return .info
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }

    private static func metadata(for chunkCoord: ChunkCoord) -> [DiagnosticMetadata] {
        [
            DiagnosticMetadata(key: "chunk.x", value: "\(chunkCoord.x)"),
            DiagnosticMetadata(key: "chunk.y", value: "\(chunkCoord.y)"),
            DiagnosticMetadata(key: "chunk.z", value: "\(chunkCoord.z)"),
        ]
    }

    private static func rootHash(for report: SeedValidationReport) -> StableHash {
        var hasher = StableHasher()
        hasher.combine("Telluric.SeedValidationReport.v1")
        hasher.combine(report.toolName)
        hasher.combine(report.toolVersion)
        hasher.combine(report.engineVersion)
        hasher.combine(report.seed)
        hasher.combine(report.radius)
        hasher.combine(report.chunkSize)
        hasher.combine(report.verticalScale)
        hasher.combine(report.totalChunks)
        hasher.combine(report.chunksGenerated)
        hasher.combine(report.validChunks)
        hasher.combine(report.invalidChunks)
        hasher.combine(report.success)
        hasher.combine(report.chunkResults.count)

        for chunk in report.chunkResults {
            hasher.combine(chunk.chunkCoord)
            hasher.combine(chunk.isValid)
            hasher.combine(chunk.stableHash != nil)
            if let stableHash = chunk.stableHash {
                hasher.combine(stableHash)
            }
            hasher.combine(chunk.componentHashes.count)
            for componentHash in chunk.componentHashes {
                hasher.combine(componentHash)
            }
            combineDiagnostics(chunk.diagnostics, into: &hasher)
        }

        combineDiagnostics(report.diagnostics, into: &hasher)
        return hasher.finalize()
    }

    private static func combineDiagnostics(_ diagnostics: [DiagnosticMessage], into hasher: inout StableHasher) {
        hasher.combine(diagnostics.count)
        for diagnostic in diagnostics {
            hasher.combine(diagnostic.severity.rawValue)
            hasher.combine(diagnostic.code)
            hasher.combine(diagnostic.message)
            hasher.combine(diagnostic.source ?? "")
            hasher.combine(diagnostic.metadata.count)
            for metadata in diagnostic.metadata {
                hasher.combine(metadata.key)
                hasher.combine(metadata.value)
            }
        }
    }
}
