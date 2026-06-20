import Foundation
import TelluricCore
import TelluricDiagnostics
import TelluricECS
import TelluricGame
import TelluricMath
import TelluricRender
import TelluricRenderExtraction
import TelluricRenderMetal
import TelluricRuntime
import TelluricSimulation
import TelluricStreaming
import TelluricWorld

/// Deterministic configuration consumed by the minimal macOS app shell.
public struct GameAppConfig: Codable, Equatable, Sendable {
    /// Root deterministic world seed.
    public let seed: UInt64

    /// Inclusive chunk streaming radius around the shell observer.
    public let radius: Int

    /// Number of world cells along one chunk axis.
    public let chunkSize: Int

    /// Vertical terrain amplitude passed into `WorldConfig`.
    public let verticalScale: Float

    /// Fixed simulation ticks per second.
    public let tickRate: UInt16

    /// Preferred view update frequency for the app shell host.
    public let framesPerSecond: UInt16

    /// Initial host window width in points.
    public let windowWidth: Int

    /// Initial host window height in points.
    public let windowHeight: Int

    /// Host window title.
    public let windowTitle: String

    /// Default deterministic app shell configuration.
    public static let `default` = GameAppConfig(
        seed: 1,
        radius: 1,
        chunkSize: 16,
        verticalScale: 8,
        tickRate: 60,
        framesPerSecond: 60,
        windowWidth: 1280,
        windowHeight: 720,
        windowTitle: "Telluric Engine Next"
    )

    /// Creates app shell configuration.
    public init(
        seed: UInt64,
        radius: Int,
        chunkSize: Int,
        verticalScale: Float,
        tickRate: UInt16 = 60,
        framesPerSecond: UInt16 = 60,
        windowWidth: Int = 1280,
        windowHeight: Int = 720,
        windowTitle: String = "Telluric Engine Next"
    ) {
        self.seed = seed
        self.radius = radius
        self.chunkSize = chunkSize
        self.verticalScale = verticalScale
        self.tickRate = tickRate
        self.framesPerSecond = framesPerSecond
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
        self.windowTitle = windowTitle
    }
}

/// Parsed command-line arguments for `telluric-game-app`.
public struct GameAppArguments: Equatable, Sendable {
    /// App shell configuration.
    public let config: GameAppConfig

    /// Runs the engine pipeline without opening a window.
    public let dryRun: Bool

    /// Runs a one-frame no-window smoke path.
    public let smoke: Bool

    /// Number of deterministic ticks to execute in dry-run mode.
    public let dryRunTicks: Int

    /// Prints per-frame summary lines.
    public let verbose: Bool

    /// True when help text was requested.
    public let help: Bool

    /// Creates parsed app arguments.
    public init(
        config: GameAppConfig = .default,
        dryRun: Bool = false,
        smoke: Bool = false,
        dryRunTicks: Int = 1,
        verbose: Bool = false,
        help: Bool = false
    ) {
        self.config = config
        self.dryRun = dryRun
        self.smoke = smoke
        self.dryRunTicks = dryRunTicks
        self.verbose = verbose
        self.help = help
    }
}

/// User-facing app shell argument parsing errors.
public enum GameAppArgumentError: Error, Equatable, CustomStringConvertible, Sendable {
    case missingValue(option: String)
    case invalidValue(option: String, value: String, reason: String)
    case unknownOption(String)

    public var description: String {
        switch self {
        case let .missingValue(option):
            return "Missing value for \(option)."
        case let .invalidValue(option, value, reason):
            return "Invalid value for \(option): \(value). \(reason)"
        case let .unknownOption(option):
            return "Unknown option \(option)."
        }
    }
}

/// Dependency-free parser for `telluric-game-app`.
public enum GameAppArgumentParser {
    /// Parses process arguments excluding executable name.
    public static func parse(_ arguments: [String]) throws -> GameAppArguments {
        var config = GameAppConfig.default
        var dryRun = false
        var smoke = false
        var dryRunTicks = 1
        var verbose = false
        var help = false

        var index = 0
        while index < arguments.count {
            let option = arguments[index]

            switch option {
            case "--help", "-h":
                help = true
                index += 1

            case "--dry-run":
                dryRun = true
                index += 1

            case "--smoke":
                dryRun = true
                smoke = true
                dryRunTicks = 1
                index += 1

            case "--verbose":
                verbose = true
                index += 1

            case "--seed":
                let value = try value(after: option, index: index, arguments: arguments)
                guard let parsed = UInt64(value) else {
                    throw GameAppArgumentError.invalidValue(
                        option: option,
                        value: value,
                        reason: "Expected an unsigned 64-bit integer."
                    )
                }
                config = GameAppConfig(
                    seed: parsed,
                    radius: config.radius,
                    chunkSize: config.chunkSize,
                    verticalScale: config.verticalScale,
                    tickRate: config.tickRate,
                    framesPerSecond: config.framesPerSecond,
                    windowWidth: config.windowWidth,
                    windowHeight: config.windowHeight,
                    windowTitle: config.windowTitle
                )
                index += 2

            case "--radius":
                let value = try value(after: option, index: index, arguments: arguments)
                guard let parsed = Int(value), parsed >= 0 else {
                    throw GameAppArgumentError.invalidValue(
                        option: option,
                        value: value,
                        reason: "Expected a non-negative integer."
                    )
                }
                config = config.with(radius: parsed)
                index += 2

            case "--chunk-size":
                let value = try value(after: option, index: index, arguments: arguments)
                guard let parsed = Int(value), parsed > 0 else {
                    throw GameAppArgumentError.invalidValue(
                        option: option,
                        value: value,
                        reason: "Expected a positive integer."
                    )
                }
                config = config.with(chunkSize: parsed)
                index += 2

            case "--vertical-scale":
                let value = try value(after: option, index: index, arguments: arguments)
                guard let parsed = Float(value), parsed.isFinite, parsed > 0 else {
                    throw GameAppArgumentError.invalidValue(
                        option: option,
                        value: value,
                        reason: "Expected a finite positive number."
                    )
                }
                config = config.with(verticalScale: parsed)
                index += 2

            case "--ticks":
                let value = try value(after: option, index: index, arguments: arguments)
                guard let parsed = Int(value), parsed > 0 else {
                    throw GameAppArgumentError.invalidValue(
                        option: option,
                        value: value,
                        reason: "Expected a positive integer."
                    )
                }
                dryRunTicks = parsed
                index += 2

            default:
                throw GameAppArgumentError.unknownOption(option)
            }
        }

        if smoke {
            dryRunTicks = 1
        }

        return GameAppArguments(
            config: config,
            dryRun: dryRun,
            smoke: smoke,
            dryRunTicks: dryRunTicks,
            verbose: verbose,
            help: help
        )
    }

    private static func value(after option: String, index: Int, arguments: [String]) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw GameAppArgumentError.missingValue(option: option)
        }

        return arguments[valueIndex]
    }
}

/// Help text for the minimal macOS app shell executable.
public enum GameAppHelp {
    public static let text = """
    Usage:
      swift run telluric-game-app [--seed <UInt64>] [--radius <Int>] [--chunk-size <Int>] [--vertical-scale <Float>] [--dry-run|--smoke] [--ticks <Int>] [--verbose]

    Options:
      --seed <UInt64>           Root deterministic world seed. Defaults to 1.
      --radius <Int>           Inclusive square chunk streaming radius. Defaults to 1.
      --chunk-size <Int>       Positive chunk cell size. Defaults to 16.
      --vertical-scale <Float> Finite positive vertical terrain scale. Defaults to 8.
      --dry-run                Run the pipeline without opening a window.
      --smoke                  Run one no-window smoke frame.
      --ticks <Int>            Positive dry-run tick count. Defaults to 1.
      --verbose                Print ordered frame hashes.
      --help, -h               Show this help text.
    """
}

/// Error raised when app shell pipeline configuration is invalid.
public struct GameAppConfigurationError: Error, Equatable, CustomStringConvertible, Sendable {
    /// Ordered diagnostics that explain why configuration failed.
    public let diagnostics: [DiagnosticMessage]

    public var description: String {
        diagnostics.map(\.message).joined(separator: " ")
    }
}

/// Summary of Metal availability observed by the app shell.
public struct GameAppMetalSummary: Codable, Equatable, Sendable {
    public let isMetalAvailable: Bool
    public let hasCommandQueue: Bool
    public let deviceName: String?
    public let supportsDrawablePresentation: Bool
    public let supportsDebugLines: Bool
    public let supportsDebugLinePreparation: Bool
    public let unavailableReason: String?

    /// Creates a Metal summary from backend capabilities.
    public init(capabilities: MetalRenderBackendCapabilities) {
        self.isMetalAvailable = capabilities.isMetalAvailable
        self.hasCommandQueue = capabilities.hasCommandQueue
        self.deviceName = capabilities.deviceName
        self.supportsDrawablePresentation = capabilities.supportsDrawablePresentation
        self.supportsDebugLines = capabilities.supportsDebugLines
        self.supportsDebugLinePreparation = capabilities.supportsDebugLinePreparation
        self.unavailableReason = capabilities.unavailableReason
    }
}

/// Result of one app-shell engine frame.
public struct GameAppFrameResult: Codable, Equatable, Sendable {
    public let tick: TickIndex
    public let runtimeFrameIndex: FrameIndex
    public let simulationTick: TickIndex
    public let gameStepHash: StableHash
    public let runtimeHash: StableHash
    public let renderSnapshotHash: StableHash
    public let preparedDebugLineCount: Int
    public let preparedDebugLineVertexCount: Int
    public let preparedDebugLineBufferByteLength: Int
    public let metalAvailable: Bool
    public let drawableRenderingImplemented: Bool
    public let diagnosticsSummary: DiagnosticSummary
    public let diagnostics: [DiagnosticMessage]
    public let success: Bool

    /// Creates an app-shell frame result.
    public init(
        tick: TickIndex,
        runtimeFrameIndex: FrameIndex,
        simulationTick: TickIndex,
        gameStepHash: StableHash,
        runtimeHash: StableHash,
        renderSnapshotHash: StableHash,
        preparedDebugLineCount: Int,
        preparedDebugLineVertexCount: Int,
        preparedDebugLineBufferByteLength: Int,
        metalAvailable: Bool,
        drawableRenderingImplemented: Bool,
        diagnosticsSummary: DiagnosticSummary,
        diagnostics: [DiagnosticMessage],
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
        self.preparedDebugLineBufferByteLength = preparedDebugLineBufferByteLength
        self.metalAvailable = metalAvailable
        self.drawableRenderingImplemented = drawableRenderingImplemented
        self.diagnosticsSummary = diagnosticsSummary
        self.diagnostics = diagnostics
        self.success = success
    }
}

/// Deterministic result from running the app shell pipeline without a window.
public struct GameAppDryRunResult: Codable, Equatable, Sendable {
    public let config: GameAppConfig
    public let tickCount: Int
    public let metalAvailability: GameAppMetalSummary
    public let frames: [GameAppFrameResult]
    public let diagnosticsSummary: DiagnosticSummary
    public let success: Bool

    /// Creates a dry-run result.
    public init(
        config: GameAppConfig,
        tickCount: Int,
        metalAvailability: GameAppMetalSummary,
        frames: [GameAppFrameResult],
        diagnosticsSummary: DiagnosticSummary,
        success: Bool
    ) {
        self.config = config
        self.tickCount = tickCount
        self.metalAvailability = metalAvailability
        self.frames = frames
        self.diagnosticsSummary = diagnosticsSummary
        self.success = success
    }
}

/// App-shell frame data needed by a drawable host.
public struct GameAppRenderableFrame: Codable, Equatable, Sendable {
    /// Summary of the deterministic game/runtime/render-preparation step.
    public let frameResult: GameAppFrameResult

    /// Backend-neutral render snapshot to pass into a render backend.
    public let renderSnapshot: RenderSnapshot

    /// Drawable pass descriptor derived from deterministic app config and runtime frame.
    public let drawableDescriptor: MetalDrawableFrameDescriptor

    /// Creates a renderable app frame.
    public init(
        frameResult: GameAppFrameResult,
        renderSnapshot: RenderSnapshot,
        drawableDescriptor: MetalDrawableFrameDescriptor
    ) {
        self.frameResult = frameResult
        self.renderSnapshot = renderSnapshot
        self.drawableDescriptor = drawableDescriptor
    }
}

/// Stateful bridge from app shell frames into the existing game/runtime/render pipeline.
public struct GameAppPipeline: Sendable {
    /// App shell configuration.
    public let config: GameAppConfig

    private var session: GameSession
    private let extractor: RuntimeRenderExtractor
    private let extractionConfig: RuntimeRenderExtractionConfig
    private let metalBackend: MetalRenderBackend
    private let controlledEntityID: EntityID
    private var nextTick: TickIndex

    /// Creates a validated app-shell pipeline.
    public init(config: GameAppConfig) throws {
        let diagnostics = Self.configurationDiagnostics(config)
        guard !DiagnosticReport(messages: diagnostics).hasErrors else {
            throw GameAppConfigurationError(diagnostics: diagnostics)
        }

        self.config = config
        self.session = GameSession(config: Self.makeGameConfig(config))
        self.extractor = RuntimeRenderExtractor()
        self.extractionConfig = Self.extractionConfig(config: config)
        self.metalBackend = MetalRenderBackend(config: MetalRenderBackendConfig(label: "telluric.render.metal.game_app"))
        self.controlledEntityID = EntityID(index: 1)
        self.nextTick = .zero
    }

    /// Metal capabilities available to the current host process.
    public var metalCapabilities: MetalRenderBackendCapabilities {
        metalBackend.capabilities
    }

    /// Metal backend owned by this app-shell pipeline.
    public var metalRenderBackend: MetalRenderBackend {
        metalBackend
    }

    /// Current runtime snapshot before the next frame is stepped.
    public func snapshot() -> RuntimeSnapshot {
        session.snapshot()
    }

    /// Steps one deterministic game/runtime/render-preparation frame.
    public mutating func step() -> GameAppFrameResult {
        stepForRendering().frameResult
    }

    /// Steps one deterministic frame and returns the render snapshot for drawable hosts.
    public mutating func stepForRendering() -> GameAppRenderableFrame {
        let tick = nextTick
        let gameStep = session.step(GameStepInput(
            gameInputFrame: Self.gameInputFrame(tick: tick, entityID: controlledEntityID)
        ))
        let runtimeSnapshot = gameStep.runtimeSnapshot
        let extraction = extractor.extract(from: runtimeSnapshot, config: extractionConfig)
        let metalFrame = metalBackend.render(
            snapshot: extraction.renderSnapshot,
            descriptor: MetalRenderFrameDescriptor(
                frameIndex: runtimeSnapshot.state.frameIndex,
                label: "telluric.render.metal.game_app.frame",
                requiresDrawable: false
            )
        )

        var diagnostics = gameStep.diagnostics.messages
            + extraction.diagnostics.messages
            + Self.normalizedMetalDiagnostics(from: metalFrame.diagnostics.messages)
        diagnostics.append(Self.drawableNotImplementedDiagnostic())

        let diagnosticReport = DiagnosticReport(messages: diagnostics)
        let metalAccepted = Self.hasNoFatalMetalDiagnostics(metalFrame.diagnostics.messages)
        let success = gameStep.success && extraction.success && metalAccepted && !diagnosticReport.hasErrors

        nextTick = nextTick.advanced(by: 1)

        let frameResult = GameAppFrameResult(
            tick: tick,
            runtimeFrameIndex: runtimeSnapshot.state.frameIndex,
            simulationTick: runtimeSnapshot.state.simulationSnapshot.tick,
            gameStepHash: gameStep.stableHash,
            runtimeHash: runtimeSnapshot.stableHash,
            renderSnapshotHash: extraction.renderSnapshot.stableHash,
            preparedDebugLineCount: metalFrame.preparedDebugLineCount,
            preparedDebugLineVertexCount: metalFrame.preparedDebugLineVertexCount,
            preparedDebugLineBufferByteLength: metalFrame.preparedDebugLineBufferByteLength,
            metalAvailable: metalBackend.isAvailable,
            drawableRenderingImplemented: false,
            diagnosticsSummary: diagnosticReport.summary,
            diagnostics: diagnostics,
            success: success
        )

        return GameAppRenderableFrame(
            frameResult: frameResult,
            renderSnapshot: extraction.renderSnapshot,
            drawableDescriptor: Self.drawableDescriptor(
                frameIndex: runtimeSnapshot.state.frameIndex,
                config: config
            )
        )
    }

    /// Creates ordered diagnostics for invalid app shell configuration.
    public static func configurationDiagnostics(_ config: GameAppConfig) -> [DiagnosticMessage] {
        var diagnostics: [DiagnosticMessage] = []

        if config.radius < 0 {
            diagnostics.append(error(
                code: "game_app.config.invalid_radius",
                message: "Radius must be non-negative.",
                key: "radius",
                value: "\(config.radius)"
            ))
        }

        if config.chunkSize <= 0 {
            diagnostics.append(error(
                code: "game_app.config.invalid_chunk_size",
                message: "Chunk size must be positive.",
                key: "chunkSize",
                value: "\(config.chunkSize)"
            ))
        }

        if !config.verticalScale.isFinite || config.verticalScale <= 0 {
            diagnostics.append(error(
                code: "game_app.config.invalid_vertical_scale",
                message: "Vertical scale must be finite and positive.",
                key: "verticalScale",
                value: "\(config.verticalScale)"
            ))
        }

        if config.tickRate == 0 {
            diagnostics.append(error(
                code: "game_app.config.invalid_tick_rate",
                message: "Tick rate must be positive.",
                key: "tickRate",
                value: "\(config.tickRate)"
            ))
        }

        if config.framesPerSecond == 0 {
            diagnostics.append(error(
                code: "game_app.config.invalid_frame_rate",
                message: "Frame rate must be positive.",
                key: "framesPerSecond",
                value: "\(config.framesPerSecond)"
            ))
        }

        if config.windowWidth <= 0 {
            diagnostics.append(error(
                code: "game_app.config.invalid_window_width",
                message: "Window width must be positive.",
                key: "windowWidth",
                value: "\(config.windowWidth)"
            ))
        }

        if config.windowHeight <= 0 {
            diagnostics.append(error(
                code: "game_app.config.invalid_window_height",
                message: "Window height must be positive.",
                key: "windowHeight",
                value: "\(config.windowHeight)"
            ))
        }

        if config.windowTitle.isEmpty {
            diagnostics.append(error(
                code: "game_app.config.invalid_window_title",
                message: "Window title must not be empty.",
                key: "windowTitle",
                value: config.windowTitle
            ))
        }

        return diagnostics
    }

    private static func makeGameConfig(_ config: GameAppConfig) -> GameConfig {
        let worldConfig = WorldConfig(
            worldSeed: WorldSeed(rawValue: config.seed),
            chunkSize: config.chunkSize,
            verticalScale: config.verticalScale,
            generationProfile: NamespaceID("world.profile.game_app")
        )
        let simulationConfig = SimulationConfig(
            engineVersion: GameAppRuntime.engineVersion,
            tickRate: SimulationTickRate(ticksPerSecond: config.tickRate),
            initialTick: .zero,
            profile: NamespaceID("simulation.profile.game_app")
        )
        let runtimeConfig = RuntimeConfig(
            worldConfig: worldConfig,
            engineVersion: GameAppRuntime.engineVersion,
            simulationConfig: simulationConfig,
            streamingConfig: ChunkStreamingConfig(worldConfig: worldConfig, radius: config.radius),
            initialObservers: [
                StreamingObserver(
                    id: StreamingObserverID("game_app.observer.main"),
                    worldPosition: .zero
                ),
            ]
        )

        return GameConfig(
            sessionID: GameSessionID("game.session.app_shell"),
            runtimeConfig: runtimeConfig,
            rulesProfile: .baseline
        )
    }

    private static func extractionConfig(config: GameAppConfig) -> RuntimeRenderExtractionConfig {
        RuntimeRenderExtractionConfig(
            camera: CameraSnapshot(
                id: NamespaceID("render.camera.game_app"),
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
                aspectRatio: Float(config.windowWidth) / Float(config.windowHeight)
            ),
            includeChunkBoundaryLines: true,
            includeChunkLabels: false,
            includeChunkCenterPoints: false,
            boundaryColor: .white
        )
    }

    private static func drawableDescriptor(frameIndex: FrameIndex, config: GameAppConfig) -> MetalDrawableFrameDescriptor {
        let radius = Swift.max(config.radius, 0)
        let chunkSize = Swift.max(config.chunkSize, 1)
        let chunkSpan = Float((radius * 2 + 1) * chunkSize)
        let center = Float(chunkSize) * 0.5
        let margin: Float = 1.15
        let aspect = Float(config.windowWidth) / Float(config.windowHeight)
        let halfExtentZ = Swift.max(chunkSpan * 0.5 * margin, 1)
        let halfExtentX = Swift.max(halfExtentZ * aspect, 1)

        return MetalDrawableFrameDescriptor(
            frameIndex: frameIndex,
            label: "telluric.render.metal.game_app.drawable",
            viewportWidth: config.windowWidth,
            viewportHeight: config.windowHeight,
            debugLineProjection: MetalDebugLineProjection(
                centerX: center,
                centerZ: center,
                halfExtentX: halfExtentX,
                halfExtentZ: halfExtentZ
            )
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

    private static func drawableNotImplementedDiagnostic() -> DiagnosticMessage {
        DiagnosticMessage(
            severity: .info,
            code: NamespaceID("game_app.drawable_rendering_not_requested"),
            message: "No drawable was requested for this app-shell dry-run frame; debug line data was prepared only.",
            source: "TelluricGameAppCore",
            metadata: []
        )
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
            source: "TelluricGameAppCore",
            metadata: [
                DiagnosticMetadata(key: key, value: value),
            ]
        )
    }
}

/// Dry-run entry point for exercising the app-shell pipeline without AppKit.
public enum GameAppRuntime {
    public static let engineVersion = EngineVersion(major: 1, minor: 0, patch: 0)

    /// Runs the app-shell pipeline without opening a window.
    public static func dryRun(arguments: GameAppArguments) throws -> GameAppDryRunResult {
        var pipeline = try GameAppPipeline(config: arguments.config)
        var frames: [GameAppFrameResult] = []

        for _ in 0..<arguments.dryRunTicks {
            frames.append(pipeline.step())
        }

        let diagnostics = frames.flatMap(\.diagnostics)
        let diagnosticReport = DiagnosticReport(messages: diagnostics)

        return GameAppDryRunResult(
            config: arguments.config,
            tickCount: arguments.dryRunTicks,
            metalAvailability: GameAppMetalSummary(capabilities: pipeline.metalCapabilities),
            frames: frames,
            diagnosticsSummary: diagnosticReport.summary,
            success: frames.allSatisfy(\.success) && !diagnosticReport.hasErrors
        )
    }

    /// Creates a human-readable app-shell dry-run summary.
    public static func summary(for result: GameAppDryRunResult, verbose: Bool = false) -> String {
        var lines = [
            "telluric-game-app dry-run",
            "seed: \(result.config.seed)",
            "radius: \(result.config.radius)",
            "chunk size: \(result.config.chunkSize)",
            "vertical scale: \(result.config.verticalScale)",
            "ticks: \(result.tickCount)",
            "metal available: \(result.metalAvailability.isMetalAvailable)",
            "drawable rendering implemented: false",
            "diagnostics: info \(result.diagnosticsSummary.infos), warning \(result.diagnosticsSummary.warnings), error \(result.diagnosticsSummary.errors)",
            "success: \(result.success)",
        ]

        if let finalFrame = result.frames.last {
            lines.append("final runtime hash: \(finalFrame.runtimeHash)")
            lines.append("final render hash: \(finalFrame.renderSnapshotHash)")
            lines.append("debug lines: \(finalFrame.preparedDebugLineCount)")
            lines.append("debug line vertices: \(finalFrame.preparedDebugLineVertexCount)")
        }

        if verbose {
            for frame in result.frames {
                lines.append(
                    "tick \(frame.tick.rawValue): runtime \(frame.runtimeHash), render \(frame.renderSnapshotHash), debug lines \(frame.preparedDebugLineCount)"
                )
            }
        }

        return lines.joined(separator: "\n")
    }
}

private extension GameAppConfig {
    func with(radius: Int) -> GameAppConfig {
        GameAppConfig(
            seed: seed,
            radius: radius,
            chunkSize: chunkSize,
            verticalScale: verticalScale,
            tickRate: tickRate,
            framesPerSecond: framesPerSecond,
            windowWidth: windowWidth,
            windowHeight: windowHeight,
            windowTitle: windowTitle
        )
    }

    func with(chunkSize: Int) -> GameAppConfig {
        GameAppConfig(
            seed: seed,
            radius: radius,
            chunkSize: chunkSize,
            verticalScale: verticalScale,
            tickRate: tickRate,
            framesPerSecond: framesPerSecond,
            windowWidth: windowWidth,
            windowHeight: windowHeight,
            windowTitle: windowTitle
        )
    }

    func with(verticalScale: Float) -> GameAppConfig {
        GameAppConfig(
            seed: seed,
            radius: radius,
            chunkSize: chunkSize,
            verticalScale: verticalScale,
            tickRate: tickRate,
            framesPerSecond: framesPerSecond,
            windowWidth: windowWidth,
            windowHeight: windowHeight,
            windowTitle: windowTitle
        )
    }
}
