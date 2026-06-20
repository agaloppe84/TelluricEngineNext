import Foundation
import TelluricCore
import TelluricDeterminism
import TelluricDiagnostics
import TelluricECS
import TelluricGame
import TelluricMath
import TelluricPersistence
import TelluricRender
import TelluricRenderExtraction
import TelluricRenderMetal
import TelluricRuntime
import TelluricSimulation
import TelluricStreaming
import TelluricWorld

/// Parsed command-line configuration for the headless end-to-end loop.
public struct HeadlessLoopArguments: Equatable, Sendable {
    /// Root deterministic world seed.
    public let seed: UInt64

    /// Inclusive chunk streaming radius around the observer.
    public let radius: Int

    /// Number of world cells along one chunk axis.
    public let chunkSize: Int

    /// Vertical terrain amplitude passed into `WorldConfig`.
    public let verticalScale: Float

    /// Number of fixed game/runtime ticks to execute.
    public let ticks: Int

    /// Optional deterministic JSON report path.
    public let reportPath: String?

    /// Prints ordered per-tick summary lines.
    public let verbose: Bool

    /// True when help text was requested.
    public let help: Bool

    /// Creates parsed headless loop arguments.
    public init(
        seed: UInt64,
        radius: Int,
        chunkSize: Int,
        verticalScale: Float,
        ticks: Int,
        reportPath: String? = nil,
        verbose: Bool = false,
        help: Bool = false
    ) {
        self.seed = seed
        self.radius = radius
        self.chunkSize = chunkSize
        self.verticalScale = verticalScale
        self.ticks = ticks
        self.reportPath = reportPath
        self.verbose = verbose
        self.help = help
    }
}

/// User-facing CLI parsing errors.
public enum HeadlessLoopArgumentError: Error, Equatable, CustomStringConvertible, Sendable {
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

/// Dependency-free parser for `telluric-headless-loop`.
public enum HeadlessLoopArgumentParser {
    /// Parses process arguments excluding executable name.
    public static func parse(_ arguments: [String]) throws -> HeadlessLoopArguments {
        var seed: UInt64?
        var radius: Int?
        var chunkSize: Int?
        var verticalScale: Float?
        var ticks: Int?
        var reportPath: String?
        var verbose = false
        var help = false

        var index = 0
        while index < arguments.count {
            let option = arguments[index]

            switch option {
            case "--help", "-h":
                help = true
                index += 1

            case "--verbose":
                verbose = true
                index += 1

            case "--seed":
                let value = try value(after: option, index: index, arguments: arguments)
                guard let parsed = UInt64(value) else {
                    throw HeadlessLoopArgumentError.invalidValue(
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
                    throw HeadlessLoopArgumentError.invalidValue(
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
                    throw HeadlessLoopArgumentError.invalidValue(
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
                    throw HeadlessLoopArgumentError.invalidValue(
                        option: option,
                        value: value,
                        reason: "Expected a finite positive number."
                    )
                }
                verticalScale = parsed
                index += 2

            case "--ticks":
                let value = try value(after: option, index: index, arguments: arguments)
                guard let parsed = Int(value), parsed > 0 else {
                    throw HeadlessLoopArgumentError.invalidValue(
                        option: option,
                        value: value,
                        reason: "Expected a positive integer."
                    )
                }
                ticks = parsed
                index += 2

            case "--report":
                reportPath = try value(after: option, index: index, arguments: arguments)
                index += 2

            default:
                throw HeadlessLoopArgumentError.unknownOption(option)
            }
        }

        if help {
            return HeadlessLoopArguments(
                seed: seed ?? 0,
                radius: radius ?? 0,
                chunkSize: chunkSize ?? 1,
                verticalScale: verticalScale ?? 1,
                ticks: ticks ?? 1,
                reportPath: reportPath,
                verbose: verbose,
                help: true
            )
        }

        guard let seed else {
            throw HeadlessLoopArgumentError.missingRequiredOption("--seed")
        }
        guard let radius else {
            throw HeadlessLoopArgumentError.missingRequiredOption("--radius")
        }
        guard let chunkSize else {
            throw HeadlessLoopArgumentError.missingRequiredOption("--chunk-size")
        }
        guard let verticalScale else {
            throw HeadlessLoopArgumentError.missingRequiredOption("--vertical-scale")
        }
        guard let ticks else {
            throw HeadlessLoopArgumentError.missingRequiredOption("--ticks")
        }

        return HeadlessLoopArguments(
            seed: seed,
            radius: radius,
            chunkSize: chunkSize,
            verticalScale: verticalScale,
            ticks: ticks,
            reportPath: reportPath,
            verbose: verbose
        )
    }

    private static func value(after option: String, index: Int, arguments: [String]) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw HeadlessLoopArgumentError.missingValue(option: option)
        }

        return arguments[valueIndex]
    }

    private static func validateGridSize(radius: Int, option: String, value: String) throws {
        let (doubled, doubledOverflow) = radius.multipliedReportingOverflow(by: 2)
        let (span, spanOverflow) = doubled.addingReportingOverflow(1)
        let (_, countOverflow) = span.multipliedReportingOverflow(by: span)
        guard !doubledOverflow, !spanOverflow, !countOverflow else {
            throw HeadlessLoopArgumentError.invalidValue(
                option: option,
                value: value,
                reason: "The resulting chunk grid is too large."
            )
        }
    }
}

/// Help text for the headless loop executable.
public enum HeadlessLoopHelp {
    public static let text = """
    Usage:
      swift run telluric-headless-loop --seed <UInt64> --radius <Int> --chunk-size <Int> --vertical-scale <Float> --ticks <Int> [--report <path>] [--verbose]

    Options:
      --seed <UInt64>           Root deterministic world seed.
      --radius <Int>           Inclusive square chunk streaming radius.
      --chunk-size <Int>       Positive chunk cell size.
      --vertical-scale <Float> Finite positive vertical terrain scale.
      --ticks <Int>            Positive number of fixed ticks to execute.
      --report <path>          Optional deterministic JSON report path inside this repository.
      --verbose                Print ordered per-tick hashes.
      --help, -h               Show this help text.
    """
}

/// Summary of one persistence package produced during the headless loop.
public struct HeadlessLoopPersistencePackageSummary: Codable, Equatable, Sendable {
    public let schemaID: PersistenceSchemaID
    public let kind: PersistenceEnvelopeKind
    public let stableHash: StableHash
    public let payloadHash: PersistencePayloadHash
    public let isValid: Bool

    /// Creates a package summary.
    public init(
        schemaID: PersistenceSchemaID,
        kind: PersistenceEnvelopeKind,
        stableHash: StableHash,
        payloadHash: PersistencePayloadHash,
        isValid: Bool
    ) {
        self.schemaID = schemaID
        self.kind = kind
        self.stableHash = stableHash
        self.payloadHash = payloadHash
        self.isValid = isValid
    }
}

/// Summary of Metal availability observed by the headless loop.
public struct HeadlessLoopMetalSummary: Codable, Equatable, Sendable {
    public let isMetalAvailable: Bool
    public let hasCommandQueue: Bool
    public let deviceName: String?
    public let supportsDebugLinePreparation: Bool
    public let unavailableReason: String?

    /// Creates a Metal summary from backend capabilities.
    public init(capabilities: MetalRenderBackendCapabilities) {
        self.isMetalAvailable = capabilities.isMetalAvailable
        self.hasCommandQueue = capabilities.hasCommandQueue
        self.deviceName = capabilities.deviceName
        self.supportsDebugLinePreparation = capabilities.supportsDebugLinePreparation
        self.unavailableReason = capabilities.unavailableReason
    }
}

/// Ordered summary for one executed headless tick.
public struct HeadlessLoopTickSummary: Codable, Equatable, Sendable {
    public let tick: TickIndex
    public let runtimeFrameIndex: FrameIndex
    public let simulationTick: TickIndex
    public let gameStepHash: StableHash
    public let runtimeHash: StableHash
    public let renderSnapshotHash: StableHash
    public let preparedDebugLineCount: Int
    public let preparedDebugLineVertexCount: Int
    public let metalAvailable: Bool
    public let diagnosticsSummary: DiagnosticSummary
    public let success: Bool

    /// Creates a tick summary from ordered step outputs.
    public init(
        tick: TickIndex,
        runtimeFrameIndex: FrameIndex,
        simulationTick: TickIndex,
        gameStepHash: StableHash,
        runtimeHash: StableHash,
        renderSnapshotHash: StableHash,
        preparedDebugLineCount: Int,
        preparedDebugLineVertexCount: Int,
        metalAvailable: Bool,
        diagnosticsSummary: DiagnosticSummary,
        success: Bool
    ) {
        self.tick = tick
        self.runtimeFrameIndex = runtimeFrameIndex
        self.simulationTick = simulationTick
        self.gameStepHash = gameStepHash
        self.runtimeHash = runtimeHash
        self.renderSnapshotHash = renderSnapshotHash
        self.preparedDebugLineCount = preparedDebugLineCount
        self.preparedDebugLineVertexCount = preparedDebugLineVertexCount
        self.metalAvailable = metalAvailable
        self.diagnosticsSummary = diagnosticsSummary
        self.success = success
    }
}

/// Deterministic JSON report emitted by `telluric-headless-loop`.
public struct HeadlessLoopReport: Codable, Equatable, Sendable {
    public let toolName: String
    public let toolVersion: EngineVersion
    public let engineVersion: EngineVersion
    public let seed: WorldSeed
    public let radius: Int
    public let chunkSize: Int
    public let verticalScale: Float
    public let tickCount: Int
    public let finalRuntimeHash: StableHash
    public let finalRenderSnapshotHash: StableHash
    public let finalPreparedDebugLineCount: Int
    public let finalPreparedDebugLineVertexCount: Int
    public let finalPreparedDebugLineBufferByteLength: Int
    public let metalAvailability: HeadlessLoopMetalSummary
    public let persistencePackages: [HeadlessLoopPersistencePackageSummary]
    public let tickSummaries: [HeadlessLoopTickSummary]
    public let diagnosticsSummary: DiagnosticSummary
    public let diagnostics: [DiagnosticMessage]
    public let rootHash: StableHash?
    public let success: Bool

    /// Creates a deterministic headless loop report.
    public init(
        toolName: String,
        toolVersion: EngineVersion,
        engineVersion: EngineVersion,
        seed: WorldSeed,
        radius: Int,
        chunkSize: Int,
        verticalScale: Float,
        tickCount: Int,
        finalRuntimeHash: StableHash,
        finalRenderSnapshotHash: StableHash,
        finalPreparedDebugLineCount: Int,
        finalPreparedDebugLineVertexCount: Int,
        finalPreparedDebugLineBufferByteLength: Int,
        metalAvailability: HeadlessLoopMetalSummary,
        persistencePackages: [HeadlessLoopPersistencePackageSummary],
        tickSummaries: [HeadlessLoopTickSummary],
        diagnosticsSummary: DiagnosticSummary,
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
        self.tickCount = tickCount
        self.finalRuntimeHash = finalRuntimeHash
        self.finalRenderSnapshotHash = finalRenderSnapshotHash
        self.finalPreparedDebugLineCount = finalPreparedDebugLineCount
        self.finalPreparedDebugLineVertexCount = finalPreparedDebugLineVertexCount
        self.finalPreparedDebugLineBufferByteLength = finalPreparedDebugLineBufferByteLength
        self.metalAvailability = metalAvailability
        self.persistencePackages = persistencePackages
        self.tickSummaries = tickSummaries
        self.diagnosticsSummary = diagnosticsSummary
        self.diagnostics = diagnostics
        self.rootHash = rootHash
        self.success = success
    }
}

/// Result from a headless loop CLI run.
public struct HeadlessLoopRunResult: Equatable, Sendable {
    public let report: HeadlessLoopReport
    public let summary: String
    public let exitCode: Int32

    /// Creates a run result.
    public init(report: HeadlessLoopReport, summary: String, exitCode: Int32) {
        self.report = report
        self.summary = summary
        self.exitCode = exitCode
    }
}

/// Error raised when the headless loop would write outside the repository.
public struct HeadlessLoopPathError: Error, Equatable, CustomStringConvertible, Sendable {
    public let path: String
    public let reason: String

    public var description: String {
        "Unsafe report path \(path): \(reason)"
    }
}

/// Headless end-to-end game/runtime/render/Metal-preparation validation runner.
public struct HeadlessLoopRunner: Sendable {
    public static let toolName = "telluric-headless-loop"
    public static let toolVersion = EngineVersion(major: 0, minor: 15, patch: 0)
    public static let engineVersion = EngineVersion(major: 1, minor: 0, patch: 0)

    /// Creates a headless loop runner.
    public init() {}

    /// Runs the loop, writes an optional JSON report, and returns a CLI result.
    public func run(
        arguments: HeadlessLoopArguments,
        repoRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) throws -> HeadlessLoopRunResult {
        let report = validate(arguments: arguments)

        if let reportPath = arguments.reportPath {
            try Self.write(report: report, to: reportPath, repoRoot: repoRoot)
        }

        return HeadlessLoopRunResult(
            report: report,
            summary: Self.summary(for: report, verbose: arguments.verbose),
            exitCode: report.success ? 0 : 1
        )
    }

    /// Executes the headless loop and returns a deterministic report.
    public func validate(arguments: HeadlessLoopArguments) -> HeadlessLoopReport {
        var diagnostics = Self.argumentDiagnostics(arguments)
        var tickSummaries: [HeadlessLoopTickSummary] = []

        let gameConfig = Self.makeGameConfig(arguments: arguments)
        var session = GameSession(config: gameConfig)
        let extractor = RuntimeRenderExtractor()
        let metalBackend = MetalRenderBackend(config: MetalRenderBackendConfig(label: "telluric.render.metal.headless_loop"))
        let extractionConfig = Self.extractionConfig(arguments: arguments)
        let entityID = EntityID(index: 1)

        var finalRuntimeSnapshot = session.snapshot()
        var finalExtraction = extractor.extract(from: finalRuntimeSnapshot, config: extractionConfig)
        var finalMetalFrame = metalBackend.render(snapshot: finalExtraction.renderSnapshot)
        var allTicksSucceeded = diagnostics.isEmpty

        let executableTicks = Swift.max(arguments.ticks, 0)
        for tickRaw in 0..<executableTicks {
            let tick = TickIndex(rawValue: UInt64(tickRaw))
            let gameStep = session.step(GameStepInput(
                gameInputFrame: Self.gameInputFrame(tick: tick, entityID: entityID)
            ))
            finalRuntimeSnapshot = gameStep.runtimeSnapshot
            finalExtraction = extractor.extract(from: finalRuntimeSnapshot, config: extractionConfig)
            finalMetalFrame = metalBackend.render(snapshot: finalExtraction.renderSnapshot)

            let normalizedMetalDiagnostics = Self.normalizedMetalDiagnostics(from: finalMetalFrame.diagnostics.messages)
            let tickDiagnostics = gameStep.diagnostics.messages
                + finalExtraction.diagnostics.messages
                + normalizedMetalDiagnostics
            diagnostics.append(contentsOf: tickDiagnostics)

            let metalAccepted = Self.hasNoFatalMetalDiagnostics(finalMetalFrame.diagnostics.messages)
            let tickSucceeded = gameStep.success && finalExtraction.success && metalAccepted
            allTicksSucceeded = allTicksSucceeded && tickSucceeded

            tickSummaries.append(HeadlessLoopTickSummary(
                tick: tick,
                runtimeFrameIndex: finalRuntimeSnapshot.state.frameIndex,
                simulationTick: finalRuntimeSnapshot.state.simulationSnapshot.tick,
                gameStepHash: gameStep.stableHash,
                runtimeHash: finalRuntimeSnapshot.stableHash,
                renderSnapshotHash: finalExtraction.renderSnapshot.stableHash,
                preparedDebugLineCount: finalMetalFrame.preparedDebugLineCount,
                preparedDebugLineVertexCount: finalMetalFrame.preparedDebugLineVertexCount,
                metalAvailable: metalBackend.isAvailable,
                diagnosticsSummary: DiagnosticReport(messages: tickDiagnostics).summary,
                success: tickSucceeded
            ))
        }

        var persistenceSummaries = Self.persistencePackageSummaries(
            runtimeSnapshot: finalRuntimeSnapshot,
            renderSnapshot: finalExtraction.renderSnapshot,
            diagnostics: &diagnostics
        )
        persistenceSummaries.sort { lhs, rhs in
            if lhs.kind != rhs.kind {
                return lhs.kind < rhs.kind
            }

            return lhs.schemaID < rhs.schemaID
        }

        let normalizedFinalMetalDiagnostics = Self.normalizedMetalDiagnostics(from: finalMetalFrame.diagnostics.messages)
        if executableTicks == 0 {
            diagnostics.append(contentsOf: finalExtraction.diagnostics.messages)
            diagnostics.append(contentsOf: normalizedFinalMetalDiagnostics)
        }

        let diagnosticReport = DiagnosticReport(messages: diagnostics)
        let success = allTicksSucceeded && !diagnosticReport.hasErrors && persistenceSummaries.allSatisfy(\.isValid)

        return Self.makeReport(
            arguments: arguments,
            finalRuntimeSnapshot: finalRuntimeSnapshot,
            finalRenderSnapshot: finalExtraction.renderSnapshot,
            finalMetalFrame: finalMetalFrame,
            metalSummary: HeadlessLoopMetalSummary(capabilities: metalBackend.capabilities),
            persistencePackages: persistenceSummaries,
            tickSummaries: tickSummaries,
            diagnostics: diagnostics,
            success: success
        )
    }

    /// Writes a deterministic JSON report to a repo-local path.
    public static func write(report: HeadlessLoopReport, to path: String, repoRoot: URL) throws {
        _ = try ReportPackage(
            schemaID: PersistenceSchemaID("telluric.headless_loop.report"),
            engineVersion: engineVersion,
            metadata: packageMetadata(payloadName: "headless_loop_report"),
            payload: report
        )

        let url = try safeRepoRelativeURL(path: path, repoRoot: repoRoot)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try jsonEncoder().encode(report)
        try data.write(to: url, options: [.atomic])
    }

    /// Creates the stable JSON encoder used for headless loop reports.
    public static func jsonEncoder() -> JSONEncoder {
        let encoder = PersistenceJSONEncoder.make()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    /// Creates a human-readable headless loop summary.
    public static func summary(for report: HeadlessLoopReport, verbose: Bool = false) -> String {
        var lines = [
            "\(report.toolName) \(report.toolVersion)",
            "seed: \(report.seed.rawValue)",
            "radius: \(report.radius)",
            "chunk size: \(report.chunkSize)",
            "vertical scale: \(report.verticalScale)",
            "ticks: \(report.tickCount)",
            "final runtime hash: \(report.finalRuntimeHash)",
            "final render hash: \(report.finalRenderSnapshotHash)",
            "debug lines: \(report.finalPreparedDebugLineCount)",
            "debug line vertices: \(report.finalPreparedDebugLineVertexCount)",
            "metal available: \(report.metalAvailability.isMetalAvailable)",
            "diagnostics: info \(report.diagnosticsSummary.infos), warning \(report.diagnosticsSummary.warnings), error \(report.diagnosticsSummary.errors)",
            "root hash: \(report.rootHash?.description ?? "unavailable")",
            "success: \(report.success)",
        ]

        if verbose {
            for tick in report.tickSummaries {
                lines.append(
                    "tick \(tick.tick.rawValue): runtime \(tick.runtimeHash), render \(tick.renderSnapshotHash), debug lines \(tick.preparedDebugLineCount)"
                )
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func makeReport(
        arguments: HeadlessLoopArguments,
        finalRuntimeSnapshot: RuntimeSnapshot,
        finalRenderSnapshot: RenderSnapshot,
        finalMetalFrame: MetalRenderFrameResult,
        metalSummary: HeadlessLoopMetalSummary,
        persistencePackages: [HeadlessLoopPersistencePackageSummary],
        tickSummaries: [HeadlessLoopTickSummary],
        diagnostics: [DiagnosticMessage],
        success: Bool
    ) -> HeadlessLoopReport {
        let diagnosticSummary = DiagnosticReport(messages: diagnostics).summary
        let reportWithoutHash = HeadlessLoopReport(
            toolName: toolName,
            toolVersion: toolVersion,
            engineVersion: engineVersion,
            seed: WorldSeed(rawValue: arguments.seed),
            radius: arguments.radius,
            chunkSize: arguments.chunkSize,
            verticalScale: arguments.verticalScale,
            tickCount: arguments.ticks,
            finalRuntimeHash: finalRuntimeSnapshot.stableHash,
            finalRenderSnapshotHash: finalRenderSnapshot.stableHash,
            finalPreparedDebugLineCount: finalMetalFrame.preparedDebugLineCount,
            finalPreparedDebugLineVertexCount: finalMetalFrame.preparedDebugLineVertexCount,
            finalPreparedDebugLineBufferByteLength: finalMetalFrame.preparedDebugLineBufferByteLength,
            metalAvailability: metalSummary,
            persistencePackages: persistencePackages,
            tickSummaries: tickSummaries,
            diagnosticsSummary: diagnosticSummary,
            diagnostics: diagnostics,
            rootHash: nil,
            success: success
        )

        return HeadlessLoopReport(
            toolName: reportWithoutHash.toolName,
            toolVersion: reportWithoutHash.toolVersion,
            engineVersion: reportWithoutHash.engineVersion,
            seed: reportWithoutHash.seed,
            radius: reportWithoutHash.radius,
            chunkSize: reportWithoutHash.chunkSize,
            verticalScale: reportWithoutHash.verticalScale,
            tickCount: reportWithoutHash.tickCount,
            finalRuntimeHash: reportWithoutHash.finalRuntimeHash,
            finalRenderSnapshotHash: reportWithoutHash.finalRenderSnapshotHash,
            finalPreparedDebugLineCount: reportWithoutHash.finalPreparedDebugLineCount,
            finalPreparedDebugLineVertexCount: reportWithoutHash.finalPreparedDebugLineVertexCount,
            finalPreparedDebugLineBufferByteLength: reportWithoutHash.finalPreparedDebugLineBufferByteLength,
            metalAvailability: reportWithoutHash.metalAvailability,
            persistencePackages: reportWithoutHash.persistencePackages,
            tickSummaries: reportWithoutHash.tickSummaries,
            diagnosticsSummary: reportWithoutHash.diagnosticsSummary,
            diagnostics: reportWithoutHash.diagnostics,
            rootHash: rootHash(for: reportWithoutHash),
            success: reportWithoutHash.success
        )
    }

    private static func makeGameConfig(arguments: HeadlessLoopArguments) -> GameConfig {
        let worldConfig = WorldConfig(
            worldSeed: WorldSeed(rawValue: arguments.seed),
            chunkSize: arguments.chunkSize,
            verticalScale: arguments.verticalScale,
            generationProfile: NamespaceID("world.profile.headless_loop")
        )
        let simulationConfig = SimulationConfig(
            engineVersion: engineVersion,
            tickRate: SimulationTickRate(ticksPerSecond: 60),
            initialTick: .zero,
            profile: NamespaceID("simulation.profile.headless_loop")
        )
        let runtimeConfig = RuntimeConfig(
            worldConfig: worldConfig,
            engineVersion: engineVersion,
            simulationConfig: simulationConfig,
            streamingConfig: ChunkStreamingConfig(worldConfig: worldConfig, radius: arguments.radius),
            initialObservers: [
                StreamingObserver(
                    id: StreamingObserverID("headless.observer.main"),
                    worldPosition: .zero
                ),
            ]
        )

        return GameConfig(
            sessionID: GameSessionID("game.session.headless_loop"),
            runtimeConfig: runtimeConfig,
            rulesProfile: .baseline
        )
    }

    private static func extractionConfig(arguments: HeadlessLoopArguments) -> RuntimeRenderExtractionConfig {
        RuntimeRenderExtractionConfig(
            camera: CameraSnapshot(
                id: NamespaceID("render.camera.headless_loop"),
                transform: Transform(
                    translation: Float3(x: 0, y: 64, z: -64),
                    rotationRadians: Float3(x: 0.7, y: 0, z: 0),
                    scale: .one
                ),
                projection: .perspective(
                    verticalFieldOfViewRadians: 1,
                    nearClip: 0.1,
                    farClip: 2_000
                ),
                aspectRatio: 16 / 9
            ),
            includeChunkBoundaryLines: true,
            includeChunkLabels: false,
            includeChunkCenterPoints: false,
            boundaryColor: .white
        )
    }

    private static func gameInputFrame(tick: TickIndex, entityID: EntityID) -> GameInputFrame {
        if tick == .zero {
            return GameInputFrame(tick: tick, intents: [
                .spawnControllableEntity(entityID: entityID, position: .zero, velocity: nil),
            ])
        }

        return GameInputFrame(tick: tick, intents: [
            .moveEntity(entityID: entityID, translation: Float3(x: 1, y: 0, z: 0)),
        ])
    }

    private static func argumentDiagnostics(_ arguments: HeadlessLoopArguments) -> [DiagnosticMessage] {
        var diagnostics: [DiagnosticMessage] = []

        if arguments.radius < 0 {
            diagnostics.append(error(
                code: "headless_loop.arguments.invalid_radius",
                message: "Radius must be non-negative.",
                key: "radius",
                value: "\(arguments.radius)"
            ))
        }

        if arguments.chunkSize <= 0 {
            diagnostics.append(error(
                code: "headless_loop.arguments.invalid_chunk_size",
                message: "Chunk size must be positive.",
                key: "chunkSize",
                value: "\(arguments.chunkSize)"
            ))
        }

        if !arguments.verticalScale.isFinite || arguments.verticalScale <= 0 {
            diagnostics.append(error(
                code: "headless_loop.arguments.invalid_vertical_scale",
                message: "Vertical scale must be finite and positive.",
                key: "verticalScale",
                value: "\(arguments.verticalScale)"
            ))
        }

        if arguments.ticks <= 0 {
            diagnostics.append(error(
                code: "headless_loop.arguments.invalid_ticks",
                message: "Tick count must be positive.",
                key: "ticks",
                value: "\(arguments.ticks)"
            ))
        }

        if gridWouldOverflow(radius: arguments.radius) {
            diagnostics.append(error(
                code: "headless_loop.arguments.grid_too_large",
                message: "Radius produces a chunk grid that is too large.",
                key: "radius",
                value: "\(arguments.radius)"
            ))
        }

        return diagnostics
    }

    private static func persistencePackageSummaries(
        runtimeSnapshot: RuntimeSnapshot,
        renderSnapshot: RenderSnapshot,
        diagnostics: inout [DiagnosticMessage]
    ) -> [HeadlessLoopPersistencePackageSummary] {
        var summaries: [HeadlessLoopPersistencePackageSummary] = []

        do {
            let runtimePackage = try SnapshotPackage(
                schemaID: PersistenceSchemaID("telluric.headless_loop.runtime_snapshot"),
                engineVersion: engineVersion,
                metadata: packageMetadata(payloadName: "runtime_snapshot"),
                payload: runtimeSnapshot
            )
            let validation = runtimePackage.validate()
            diagnostics.append(contentsOf: validation.diagnostics.messages)
            summaries.append(HeadlessLoopPersistencePackageSummary(
                schemaID: runtimePackage.envelope.schemaID,
                kind: runtimePackage.envelope.kind,
                stableHash: runtimePackage.stableHash,
                payloadHash: runtimePackage.envelope.payloadHash,
                isValid: validation.isValid
            ))
        } catch {
            diagnostics.append(packageFailureDiagnostic(payloadName: "runtime_snapshot", error: error))
        }

        do {
            let renderPackage = try SnapshotPackage(
                schemaID: PersistenceSchemaID("telluric.headless_loop.render_snapshot"),
                engineVersion: engineVersion,
                metadata: packageMetadata(payloadName: "render_snapshot"),
                payload: renderSnapshot
            )
            let validation = renderPackage.validate()
            diagnostics.append(contentsOf: validation.diagnostics.messages)
            summaries.append(HeadlessLoopPersistencePackageSummary(
                schemaID: renderPackage.envelope.schemaID,
                kind: renderPackage.envelope.kind,
                stableHash: renderPackage.stableHash,
                payloadHash: renderPackage.envelope.payloadHash,
                isValid: validation.isValid
            ))
        } catch {
            diagnostics.append(packageFailureDiagnostic(payloadName: "render_snapshot", error: error))
        }

        return summaries
    }

    private static func packageMetadata(payloadName: String) -> [PersistenceMetadataEntry] {
        [
            PersistenceMetadataEntry(key: "tool", value: toolName),
            PersistenceMetadataEntry(key: "payload", value: payloadName),
        ]
    }

    private static func normalizedMetalDiagnostics(from diagnostics: [DiagnosticMessage]) -> [DiagnosticMessage] {
        diagnostics.map { message in
            guard message.severity == .error, isNonFatalMetalAvailabilityDiagnostic(message) else {
                return message
            }

            return DiagnosticMessage(
                severity: .warning,
                code: message.code,
                message: message.message,
                source: message.source,
                metadata: message.metadata
            )
        }
    }

    private static func hasNoFatalMetalDiagnostics(_ diagnostics: [DiagnosticMessage]) -> Bool {
        !diagnostics.contains { message in
            message.severity == .error && !isNonFatalMetalAvailabilityDiagnostic(message)
        }
    }

    private static func isNonFatalMetalAvailabilityDiagnostic(_ message: DiagnosticMessage) -> Bool {
        switch message.code.rawValue {
        case "render.metal.unavailable",
             "render.metal.command_queue_unavailable",
             "render.metal.debug_line.buffer_unavailable":
            return true
        default:
            return false
        }
    }

    private static func safeRepoRelativeURL(path: String, repoRoot: URL) throws -> URL {
        guard !path.isEmpty else {
            throw HeadlessLoopPathError(path: path, reason: "Path must not be empty.")
        }

        guard !path.hasPrefix("/") else {
            throw HeadlessLoopPathError(path: path, reason: "Absolute paths are not allowed.")
        }

        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.contains("..") else {
            throw HeadlessLoopPathError(path: path, reason: "Path traversal is not allowed.")
        }

        let root = repoRoot.standardizedFileURL
        let url = root.appendingPathComponent(path).standardizedFileURL
        guard url.path == root.path || url.path.hasPrefix(root.path + "/") else {
            throw HeadlessLoopPathError(path: path, reason: "Resolved path is outside this repository.")
        }

        return url
    }

    private static func gridWouldOverflow(radius: Int) -> Bool {
        guard radius >= 0 else {
            return false
        }

        let (doubled, doubledOverflow) = radius.multipliedReportingOverflow(by: 2)
        let (span, spanOverflow) = doubled.addingReportingOverflow(1)
        let (_, countOverflow) = span.multipliedReportingOverflow(by: span)
        return doubledOverflow || spanOverflow || countOverflow
    }

    private static func rootHash(for report: HeadlessLoopReport) -> StableHash {
        var hasher = StableHasher()
        hasher.combine("Telluric.HeadlessLoopReport.v1")
        hasher.combine(report.toolName)
        hasher.combine(report.toolVersion)
        hasher.combine(report.engineVersion)
        hasher.combine(report.seed)
        hasher.combine(report.radius)
        hasher.combine(report.chunkSize)
        hasher.combine(report.verticalScale)
        hasher.combine(report.tickCount)
        hasher.combine(report.finalRuntimeHash)
        hasher.combine(report.finalRenderSnapshotHash)
        hasher.combine(report.finalPreparedDebugLineCount)
        hasher.combine(report.finalPreparedDebugLineVertexCount)
        hasher.combine(report.finalPreparedDebugLineBufferByteLength)
        hasher.combine(report.metalAvailability.isMetalAvailable)
        hasher.combine(report.metalAvailability.hasCommandQueue)
        hasher.combine(report.metalAvailability.deviceName ?? "")
        hasher.combine(report.metalAvailability.supportsDebugLinePreparation)
        hasher.combine(report.metalAvailability.unavailableReason ?? "")
        hasher.combine(report.persistencePackages.count)
        for package in report.persistencePackages {
            hasher.combine(package.schemaID)
            hasher.combine(package.kind)
            hasher.combine(package.stableHash)
            hasher.combine(package.payloadHash)
            hasher.combine(package.isValid)
        }
        hasher.combine(report.tickSummaries.count)
        for tick in report.tickSummaries {
            hasher.combine(tick.tick)
            hasher.combine(tick.runtimeFrameIndex)
            hasher.combine(tick.simulationTick)
            hasher.combine(tick.gameStepHash)
            hasher.combine(tick.runtimeHash)
            hasher.combine(tick.renderSnapshotHash)
            hasher.combine(tick.preparedDebugLineCount)
            hasher.combine(tick.preparedDebugLineVertexCount)
            hasher.combine(tick.metalAvailable)
            hasher.combine(tick.diagnosticsSummary.infos)
            hasher.combine(tick.diagnosticsSummary.warnings)
            hasher.combine(tick.diagnosticsSummary.errors)
            hasher.combine(tick.success)
        }
        combineDiagnostics(report.diagnostics, into: &hasher)
        hasher.combine(report.success)
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

    private static func error(
        code: String,
        message: String,
        key: String,
        value: String
    ) -> DiagnosticMessage {
        DiagnosticMessage(
            severity: .error,
            code: NamespaceID(code),
            message: message,
            source: "TelluricHeadlessLoop",
            metadata: [
                DiagnosticMetadata(key: key, value: value),
            ]
        )
    }

    private static func packageFailureDiagnostic(payloadName: String, error: Error) -> DiagnosticMessage {
        DiagnosticMessage(
            severity: .error,
            code: NamespaceID("headless_loop.persistence.package_failed"),
            message: "Persistence package creation failed.",
            source: "TelluricHeadlessLoop",
            metadata: [
                DiagnosticMetadata(key: "payload", value: payloadName),
                DiagnosticMetadata(key: "error", value: String(describing: error)),
            ]
        )
    }
}
