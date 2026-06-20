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

private extension GameAppConfig {
    var defaultViewportAspect: Float {
        Float(windowWidth) / Float(windowHeight)
    }
}

/// Debug-only projection mode for app-shell visualization.
public enum DebugProjectionMode: String, Codable, CaseIterable, Sendable {
    /// Top-down orthographic projection over world X/Z coordinates.
    case topDownOrthographic
}

/// Configuration for app-shell debug camera behavior.
public struct DebugCameraConfig: Codable, Equatable, Sendable {
    /// Projection mode used for the debug chunk grid.
    public let projectionMode: DebugProjectionMode

    /// Minimum positive vertical half extent in world units.
    public let minimumHalfExtent: Float

    /// Maximum vertical half extent in world units.
    public let maximumHalfExtent: Float

    /// Multiplicative zoom step. Values greater than one zoom out when multiplied.
    public let zoomStepFactor: Float

    /// Fraction of the current vertical half extent used for one keyboard pan step.
    public let panStepFraction: Float

    /// Margin around the generated chunk grid when fitting the camera.
    public let fitMargin: Float

    /// Default debug camera configuration.
    public static let `default` = DebugCameraConfig()

    /// Creates debug camera configuration.
    public init(
        projectionMode: DebugProjectionMode = .topDownOrthographic,
        minimumHalfExtent: Float = 1,
        maximumHalfExtent: Float = 1_000_000,
        zoomStepFactor: Float = 1.2,
        panStepFraction: Float = 0.15,
        fitMargin: Float = 1.15
    ) {
        precondition(minimumHalfExtent.isFinite && minimumHalfExtent > 0, "minimumHalfExtent must be finite and positive")
        precondition(maximumHalfExtent.isFinite && maximumHalfExtent >= minimumHalfExtent, "maximumHalfExtent must be finite and at least minimumHalfExtent")
        precondition(zoomStepFactor.isFinite && zoomStepFactor > 1, "zoomStepFactor must be finite and greater than one")
        precondition(panStepFraction.isFinite && panStepFraction > 0, "panStepFraction must be finite and positive")
        precondition(fitMargin.isFinite && fitMargin > 0, "fitMargin must be finite and positive")
        self.projectionMode = projectionMode
        self.minimumHalfExtent = minimumHalfExtent
        self.maximumHalfExtent = maximumHalfExtent
        self.zoomStepFactor = zoomStepFactor
        self.panStepFraction = panStepFraction
        self.fitMargin = fitMargin
    }
}

/// Platform-neutral debug camera controls for app-shell visualization.
public enum DebugCameraControlIntent: Codable, Equatable, Sendable {
    /// Zooms toward the focus point.
    case zoomIn

    /// Zooms away from the focus point.
    case zoomOut

    /// Pans by normalized debug-camera steps, not gameplay movement.
    case pan(deltaX: Float, deltaZ: Float)

    /// Refits the debug camera to the generated chunk grid.
    case reset
}

/// Debug-only camera state for top-down chunk-grid visualization.
public struct DebugCameraState: Codable, Equatable, Sendable {
    /// Projection mode used by this camera state.
    public let projectionMode: DebugProjectionMode

    /// World X coordinate at the center of the view.
    public let centerX: Float

    /// World Z coordinate at the center of the view.
    public let centerZ: Float

    /// Positive world Z half extent. Horizontal extent is derived from viewport aspect.
    public let halfExtentZ: Float

    /// Creates debug camera state. Invalid values can be clamped through `validated`.
    public init(
        projectionMode: DebugProjectionMode = .topDownOrthographic,
        centerX: Float,
        centerZ: Float,
        halfExtentZ: Float
    ) {
        self.projectionMode = projectionMode
        self.centerX = centerX
        self.centerZ = centerZ
        self.halfExtentZ = halfExtentZ
    }

    /// Fits the generated chunk grid for the supplied app config and viewport aspect.
    public static func focused(
        appConfig: GameAppConfig,
        cameraConfig: DebugCameraConfig = .default,
        viewportAspect: Float? = nil
    ) -> DebugCameraState {
        let aspect = validAspect(viewportAspect ?? appConfig.defaultViewportAspect, fallback: appConfig.defaultViewportAspect)
        let bounds = gridBounds(appConfig: appConfig)
        let requiredHalfExtentZ = Swift.max(bounds.halfExtentZ, bounds.halfExtentX / aspect) * cameraConfig.fitMargin
        let clampedHalfExtentZ = clamp(
            requiredHalfExtentZ,
            min: cameraConfig.minimumHalfExtent,
            max: cameraConfig.maximumHalfExtent
        )

        return DebugCameraState(
            projectionMode: cameraConfig.projectionMode,
            centerX: bounds.centerX,
            centerZ: bounds.centerZ,
            halfExtentZ: clampedHalfExtentZ
        )
    }

    /// Returns a validated and clamped version of this debug camera state.
    public func validated(
        appConfig: GameAppConfig,
        cameraConfig: DebugCameraConfig = .default,
        viewportAspect: Float? = nil
    ) -> DebugCameraValidationResult {
        var diagnostics: [DiagnosticMessage] = []
        let focused = Self.focused(appConfig: appConfig, cameraConfig: cameraConfig, viewportAspect: viewportAspect)

        var centerX = self.centerX
        if !centerX.isFinite {
            diagnostics.append(Self.warning(
                code: "game_app.debug_camera.invalid_center_x",
                message: "Debug camera centerX was not finite and was reset to the grid focus.",
                key: "centerX",
                value: "\(self.centerX)"
            ))
            centerX = focused.centerX
        }

        var centerZ = self.centerZ
        if !centerZ.isFinite {
            diagnostics.append(Self.warning(
                code: "game_app.debug_camera.invalid_center_z",
                message: "Debug camera centerZ was not finite and was reset to the grid focus.",
                key: "centerZ",
                value: "\(self.centerZ)"
            ))
            centerZ = focused.centerZ
        }

        var halfExtentZ = self.halfExtentZ
        if !halfExtentZ.isFinite || halfExtentZ <= 0 {
            diagnostics.append(Self.warning(
                code: "game_app.debug_camera.invalid_half_extent",
                message: "Debug camera halfExtentZ was invalid and was reset to the grid fit.",
                key: "halfExtentZ",
                value: "\(self.halfExtentZ)"
            ))
            halfExtentZ = focused.halfExtentZ
        }

        let clampedHalfExtentZ = Self.clamp(
            halfExtentZ,
            min: cameraConfig.minimumHalfExtent,
            max: cameraConfig.maximumHalfExtent
        )
        if clampedHalfExtentZ != halfExtentZ {
            diagnostics.append(Self.warning(
                code: "game_app.debug_camera.clamped_half_extent",
                message: "Debug camera halfExtentZ was clamped to the configured range.",
                key: "halfExtentZ",
                value: "\(halfExtentZ)"
            ))
        }

        return DebugCameraValidationResult(
            state: DebugCameraState(
                projectionMode: cameraConfig.projectionMode,
                centerX: centerX,
                centerZ: centerZ,
                halfExtentZ: clampedHalfExtentZ
            ),
            diagnostics: DiagnosticReport(messages: diagnostics)
        )
    }

    /// Applies a platform-neutral debug camera control.
    public func applying(
        _ intent: DebugCameraControlIntent,
        appConfig: GameAppConfig,
        cameraConfig: DebugCameraConfig = .default,
        viewportAspect: Float? = nil
    ) -> DebugCameraValidationResult {
        let validState = validated(appConfig: appConfig, cameraConfig: cameraConfig, viewportAspect: viewportAspect).state

        switch intent {
        case .zoomIn:
            return DebugCameraState(
                projectionMode: validState.projectionMode,
                centerX: validState.centerX,
                centerZ: validState.centerZ,
                halfExtentZ: validState.halfExtentZ / cameraConfig.zoomStepFactor
            ).validated(appConfig: appConfig, cameraConfig: cameraConfig, viewportAspect: viewportAspect)

        case .zoomOut:
            return DebugCameraState(
                projectionMode: validState.projectionMode,
                centerX: validState.centerX,
                centerZ: validState.centerZ,
                halfExtentZ: validState.halfExtentZ * cameraConfig.zoomStepFactor
            ).validated(appConfig: appConfig, cameraConfig: cameraConfig, viewportAspect: viewportAspect)

        case let .pan(deltaX, deltaZ):
            let panScale = validState.halfExtentZ * cameraConfig.panStepFraction
            return DebugCameraState(
                projectionMode: validState.projectionMode,
                centerX: validState.centerX + deltaX * panScale,
                centerZ: validState.centerZ + deltaZ * panScale,
                halfExtentZ: validState.halfExtentZ
            ).validated(appConfig: appConfig, cameraConfig: cameraConfig, viewportAspect: viewportAspect)

        case .reset:
            return DebugCameraValidationResult(
                state: Self.focused(appConfig: appConfig, cameraConfig: cameraConfig, viewportAspect: viewportAspect),
                diagnostics: DiagnosticReport(messages: [])
            )
        }
    }

    /// Builds a Metal debug-line projection for this camera state and viewport.
    public func projection(
        viewportWidth: Int,
        viewportHeight: Int,
        appConfig: GameAppConfig,
        cameraConfig: DebugCameraConfig = .default
    ) -> DebugCameraProjectionResult {
        var diagnostics: [DiagnosticMessage] = []
        var width = viewportWidth
        var height = viewportHeight

        if width <= 0 {
            diagnostics.append(Self.warning(
                code: "game_app.debug_camera.invalid_viewport_width",
                message: "Debug camera viewport width was invalid and was reset to the configured window width.",
                key: "viewportWidth",
                value: "\(viewportWidth)"
            ))
            width = Swift.max(appConfig.windowWidth, 1)
        }

        if height <= 0 {
            diagnostics.append(Self.warning(
                code: "game_app.debug_camera.invalid_viewport_height",
                message: "Debug camera viewport height was invalid and was reset to the configured window height.",
                key: "viewportHeight",
                value: "\(viewportHeight)"
            ))
            height = Swift.max(appConfig.windowHeight, 1)
        }

        let aspect = Self.validAspect(Float(width) / Float(height), fallback: appConfig.defaultViewportAspect)
        let validation = validated(appConfig: appConfig, cameraConfig: cameraConfig, viewportAspect: aspect)
        diagnostics.append(contentsOf: validation.diagnostics.messages)
        let state = validation.state
        let halfExtentX = Swift.max(state.halfExtentZ * aspect, cameraConfig.minimumHalfExtent)

        return DebugCameraProjectionResult(
            state: state,
            projection: MetalDebugLineProjection(
                centerX: state.centerX,
                centerZ: state.centerZ,
                halfExtentX: halfExtentX,
                halfExtentZ: state.halfExtentZ
            ),
            viewportWidth: width,
            viewportHeight: height,
            viewportAspect: aspect,
            diagnostics: DiagnosticReport(messages: diagnostics)
        )
    }

    private static func gridBounds(appConfig: GameAppConfig) -> GridBounds {
        let radius = Swift.max(appConfig.radius, 0)
        let chunkSize = Swift.max(appConfig.chunkSize, 1)
        let min = Float(-radius * chunkSize)
        let max = Float((radius + 1) * chunkSize)
        let center = (min + max) * 0.5
        let halfExtent = Swift.max((max - min) * 0.5, 1)

        return GridBounds(
            centerX: center,
            centerZ: center,
            halfExtentX: halfExtent,
            halfExtentZ: halfExtent
        )
    }

    private static func validAspect(_ value: Float, fallback: Float) -> Float {
        value.isFinite && value > 0 ? value : Swift.max(fallback, 1)
    }

    private static func clamp(_ value: Float, min: Float, max: Float) -> Float {
        Swift.max(min, Swift.min(max, value))
    }

    private static func warning(
        code: String,
        message: String,
        key: String,
        value: String
    ) -> DiagnosticMessage {
        DiagnosticMessage(
            severity: .warning,
            code: NamespaceID(code),
            message: message,
            source: "TelluricGameAppCore",
            metadata: [
                DiagnosticMetadata(key: key, value: value),
            ]
        )
    }

    private struct GridBounds {
        let centerX: Float
        let centerZ: Float
        let halfExtentX: Float
        let halfExtentZ: Float
    }
}

/// Result of validating debug camera state.
public struct DebugCameraValidationResult: Codable, Equatable, Sendable {
    /// Validated and clamped camera state.
    public let state: DebugCameraState

    /// Ordered validation diagnostics.
    public let diagnostics: DiagnosticReport

    /// True when validation produced no errors.
    public var success: Bool {
        !diagnostics.hasErrors
    }
}

/// Result of deriving Metal projection uniforms from debug camera state.
public struct DebugCameraProjectionResult: Codable, Equatable, Sendable {
    /// Validated state used for the projection.
    public let state: DebugCameraState

    /// Metal backend projection uniforms.
    public let projection: MetalDebugLineProjection

    /// Viewport width in pixels.
    public let viewportWidth: Int

    /// Viewport height in pixels.
    public let viewportHeight: Int

    /// Viewport aspect ratio.
    public let viewportAspect: Float

    /// Ordered projection diagnostics.
    public let diagnostics: DiagnosticReport

    /// True when projection derivation produced no errors.
    public var success: Bool {
        !diagnostics.hasErrors
    }
}

/// App-shell execution mode selected by command-line arguments.
public enum GameAppRunMode: String, Codable, CaseIterable, Sendable {
    /// Runs the engine pipeline without creating a window.
    case dryRun

    /// Runs a bounded no-window smoke pass.
    case smoke

    /// Runs the macOS window host.
    case run
}

/// Parsed command-line arguments for `telluric-game-app`.
public struct GameAppArguments: Equatable, Sendable {
    /// App shell configuration.
    public let config: GameAppConfig

    /// Runs the engine pipeline without opening a window.
    public let dryRun: Bool

    /// Runs a one-frame no-window smoke path.
    public let smoke: Bool

    /// True when the macOS window host was explicitly requested.
    public let run: Bool

    /// Optional bounded frame count for dry-run, smoke, or app run modes.
    public let frameLimit: Int?

    /// Optional repo-relative JSON diagnostics report path.
    public let diagnosticsReportPath: String?

    /// Prints per-frame summary lines.
    public let verbose: Bool

    /// True when help text was requested.
    public let help: Bool

    /// Creates parsed app arguments.
    public init(
        config: GameAppConfig = .default,
        dryRun: Bool = false,
        smoke: Bool = false,
        run: Bool = false,
        frameLimit: Int? = nil,
        diagnosticsReportPath: String? = nil,
        verbose: Bool = false,
        help: Bool = false
    ) {
        self.config = config
        self.dryRun = dryRun
        self.smoke = smoke
        self.run = run
        self.frameLimit = frameLimit
        self.diagnosticsReportPath = diagnosticsReportPath
        self.verbose = verbose
        self.help = help
    }

    /// Selected execution mode.
    public var mode: GameAppRunMode {
        if smoke {
            return .smoke
        }

        if dryRun {
            return .dryRun
        }

        return .run
    }

    /// Number of frames to run in no-window modes.
    public var noWindowFrameCount: Int {
        frameLimit ?? 1
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
        var run = false
        var frameLimit: Int?
        var diagnosticsReportPath: String?
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
                smoke = false
                run = false
                index += 1

            case "--smoke":
                dryRun = true
                smoke = true
                run = false
                if frameLimit == nil {
                    frameLimit = 1
                }
                index += 1

            case "--run":
                dryRun = false
                smoke = false
                run = true
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

            case "--frames", "--ticks":
                let value = try value(after: option, index: index, arguments: arguments)
                guard let parsed = Int(value), parsed > 0 else {
                    throw GameAppArgumentError.invalidValue(
                        option: option,
                        value: value,
                        reason: "Expected a positive integer."
                    )
                }
                frameLimit = parsed
                index += 2

            case "--diagnostics-report":
                diagnosticsReportPath = try value(after: option, index: index, arguments: arguments)
                index += 2

            default:
                throw GameAppArgumentError.unknownOption(option)
            }
        }

        return GameAppArguments(
            config: config,
            dryRun: dryRun,
            smoke: smoke,
            run: run,
            frameLimit: frameLimit,
            diagnosticsReportPath: diagnosticsReportPath,
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
      swift run telluric-game-app [--seed <UInt64>] [--radius <Int>] [--chunk-size <Int>] [--vertical-scale <Float>] [--dry-run|--smoke|--run] [--frames <Int>] [--diagnostics-report <path>] [--verbose]

    Options:
      --seed <UInt64>           Root deterministic world seed. Defaults to 1.
      --radius <Int>           Inclusive square chunk streaming radius. Defaults to 1.
      --chunk-size <Int>       Positive chunk cell size. Defaults to 16.
      --vertical-scale <Float> Finite positive vertical terrain scale. Defaults to 8.
      --dry-run                Run the pipeline without opening a window.
      --smoke                  Run a bounded no-window smoke pass.
      --run                    Open the minimal macOS app window.
      --frames <Int>           Positive bounded frame count. Defaults to 1 for dry-run/smoke; app run is unbounded unless set.
      --diagnostics-report <path>
                                Write a repo-relative JSON diagnostics report.
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
    public let debugCameraState: DebugCameraState
    public let debugProjection: MetalDebugLineProjection
    public let debugViewportWidth: Int
    public let debugViewportHeight: Int
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
        debugCameraState: DebugCameraState,
        debugProjection: MetalDebugLineProjection,
        debugViewportWidth: Int,
        debugViewportHeight: Int,
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
        self.debugCameraState = debugCameraState
        self.debugProjection = debugProjection
        self.debugViewportWidth = debugViewportWidth
        self.debugViewportHeight = debugViewportHeight
        self.metalAvailable = metalAvailable
        self.drawableRenderingImplemented = drawableRenderingImplemented
        self.diagnosticsSummary = diagnosticsSummary
        self.diagnostics = diagnostics
        self.success = success
    }
}

/// Deterministic result from running the app shell pipeline without a window.
public struct GameAppDryRunResult: Codable, Equatable, Sendable {
    public let mode: GameAppRunMode
    public let config: GameAppConfig
    public let framesRequested: Int
    public let metalAvailability: GameAppMetalSummary
    public let frames: [GameAppFrameResult]
    public let diagnosticsSummary: DiagnosticSummary
    public let success: Bool

    /// Creates a dry-run result.
    public init(
        mode: GameAppRunMode,
        config: GameAppConfig,
        framesRequested: Int,
        metalAvailability: GameAppMetalSummary,
        frames: [GameAppFrameResult],
        diagnosticsSummary: DiagnosticSummary,
        success: Bool
    ) {
        self.mode = mode
        self.config = config
        self.framesRequested = framesRequested
        self.metalAvailability = metalAvailability
        self.frames = frames
        self.diagnosticsSummary = diagnosticsSummary
        self.success = success
    }
}

/// One ordered frame entry in an app-shell diagnostics report.
public struct GameAppVisualFrameSummary: Codable, Equatable, Sendable {
    public let frameNumber: Int
    public let runtimeFrameIndex: FrameIndex
    public let simulationTick: TickIndex
    public let runtimeHash: StableHash
    public let renderSnapshotHash: StableHash
    public let debugLinesExtracted: Int
    public let debugVerticesPrepared: Int
    public let debugProjectionMode: DebugProjectionMode
    public let debugCameraCenterX: Float
    public let debugCameraCenterZ: Float
    public let debugCameraHalfExtentZ: Float
    public let debugProjectionHalfExtentX: Float
    public let debugProjectionHalfExtentZ: Float
    public let debugViewportWidth: Int
    public let debugViewportHeight: Int
    public let mtkViewAvailable: Bool
    public let drawableAvailable: Bool
    public let drawCallAttempted: Bool
    public let drawCallSucceeded: Bool
    public let diagnosticsSummary: DiagnosticSummary
    public let success: Bool

    /// Creates an ordered app-shell frame summary.
    public init(
        frameNumber: Int,
        frameResult: GameAppFrameResult,
        mtkViewAvailable: Bool,
        drawableAvailable: Bool,
        drawCallAttempted: Bool,
        drawCallSucceeded: Bool,
        extraDiagnostics: [DiagnosticMessage] = []
    ) {
        precondition(frameNumber >= 0, "frameNumber must be non-negative")
        let diagnostics = frameResult.diagnostics + extraDiagnostics
        let report = DiagnosticReport(messages: diagnostics)

        self.frameNumber = frameNumber
        self.runtimeFrameIndex = frameResult.runtimeFrameIndex
        self.simulationTick = frameResult.simulationTick
        self.runtimeHash = frameResult.runtimeHash
        self.renderSnapshotHash = frameResult.renderSnapshotHash
        self.debugLinesExtracted = frameResult.preparedDebugLineCount
        self.debugVerticesPrepared = frameResult.preparedDebugLineVertexCount
        self.debugProjectionMode = frameResult.debugCameraState.projectionMode
        self.debugCameraCenterX = frameResult.debugCameraState.centerX
        self.debugCameraCenterZ = frameResult.debugCameraState.centerZ
        self.debugCameraHalfExtentZ = frameResult.debugCameraState.halfExtentZ
        self.debugProjectionHalfExtentX = frameResult.debugProjection.halfExtentX
        self.debugProjectionHalfExtentZ = frameResult.debugProjection.halfExtentZ
        self.debugViewportWidth = frameResult.debugViewportWidth
        self.debugViewportHeight = frameResult.debugViewportHeight
        self.mtkViewAvailable = mtkViewAvailable
        self.drawableAvailable = drawableAvailable
        self.drawCallAttempted = drawCallAttempted
        self.drawCallSucceeded = drawCallSucceeded
        self.diagnosticsSummary = report.summary
        self.success = frameResult.success && drawCallSucceeded == drawCallAttempted && !report.hasErrors
    }
}

/// Deterministic-friendly diagnostics report for app-shell dry, smoke, and run paths.
public struct GameAppDiagnosticsReport: Codable, Equatable, Sendable {
    public let toolName: String
    public let engineVersion: EngineVersion
    public let mode: GameAppRunMode
    public let seed: UInt64
    public let radius: Int
    public let chunkSize: Int
    public let verticalScale: Float
    public let framesRequested: Int?
    public let framesSimulated: Int
    public let framesRendered: Int
    public let metalAvailability: GameAppMetalSummary
    public let mtkViewAvailable: Bool
    public let drawableAvailable: Bool
    public let debugLinesExtracted: Int
    public let debugVerticesPrepared: Int
    public let debugProjectionMode: DebugProjectionMode?
    public let debugCameraCenterX: Float?
    public let debugCameraCenterZ: Float?
    public let debugCameraHalfExtentZ: Float?
    public let debugProjectionHalfExtentX: Float?
    public let debugProjectionHalfExtentZ: Float?
    public let debugViewportWidth: Int?
    public let debugViewportHeight: Int?
    public let drawCallsAttempted: Int
    public let drawCallsSucceeded: Int
    public let diagnosticsSummary: DiagnosticSummary
    public let diagnostics: [DiagnosticMessage]
    public let frames: [GameAppVisualFrameSummary]
    public let success: Bool

    /// Creates an app-shell diagnostics report.
    public init(
        toolName: String = "telluric-game-app",
        engineVersion: EngineVersion = GameAppRuntime.engineVersion,
        mode: GameAppRunMode,
        config: GameAppConfig,
        framesRequested: Int?,
        metalAvailability: GameAppMetalSummary,
        mtkViewAvailable: Bool,
        drawableAvailable: Bool,
        frames: [GameAppVisualFrameSummary],
        diagnostics: [DiagnosticMessage]
    ) {
        let diagnosticReport = DiagnosticReport(messages: diagnostics)
        self.toolName = toolName
        self.engineVersion = engineVersion
        self.mode = mode
        self.seed = config.seed
        self.radius = config.radius
        self.chunkSize = config.chunkSize
        self.verticalScale = config.verticalScale
        self.framesRequested = framesRequested
        self.framesSimulated = frames.count
        self.framesRendered = frames.filter(\.drawCallSucceeded).count
        self.metalAvailability = metalAvailability
        self.mtkViewAvailable = mtkViewAvailable
        self.drawableAvailable = drawableAvailable
        self.debugLinesExtracted = frames.last?.debugLinesExtracted ?? 0
        self.debugVerticesPrepared = frames.last?.debugVerticesPrepared ?? 0
        self.debugProjectionMode = frames.last?.debugProjectionMode
        self.debugCameraCenterX = frames.last?.debugCameraCenterX
        self.debugCameraCenterZ = frames.last?.debugCameraCenterZ
        self.debugCameraHalfExtentZ = frames.last?.debugCameraHalfExtentZ
        self.debugProjectionHalfExtentX = frames.last?.debugProjectionHalfExtentX
        self.debugProjectionHalfExtentZ = frames.last?.debugProjectionHalfExtentZ
        self.debugViewportWidth = frames.last?.debugViewportWidth
        self.debugViewportHeight = frames.last?.debugViewportHeight
        self.drawCallsAttempted = frames.filter(\.drawCallAttempted).count
        self.drawCallsSucceeded = frames.filter(\.drawCallSucceeded).count
        self.diagnosticsSummary = diagnosticReport.summary
        self.diagnostics = diagnostics
        self.frames = frames
        self.success = !diagnosticReport.hasErrors && frames.allSatisfy(\.success)
    }
}

/// Report path or write failure.
public struct GameAppReportError: Error, Equatable, CustomStringConvertible, Sendable {
    public let message: String

    public var description: String {
        message
    }

    public init(_ message: String) {
        self.message = message
    }
}

/// JSON report writer for repo-local app-shell diagnostics.
public enum GameAppReportWriter {
    /// Writes a deterministic-friendly JSON diagnostics report to a repo-relative path.
    public static func write(_ report: GameAppDiagnosticsReport, to path: String) throws {
        let url = try reportURL(for: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var data = try encoder.encode(report)
        data.append(0x0A)
        try data.write(to: url, options: [.atomic])
    }

    private static func reportURL(for path: String) throws -> URL {
        guard !path.isEmpty else {
            throw GameAppReportError("Diagnostics report path must not be empty.")
        }

        guard !path.hasPrefix("/") && !path.hasPrefix("~") else {
            throw GameAppReportError("Diagnostics report path must be repo-relative.")
        }

        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.contains(where: { $0 == ".." }) else {
            throw GameAppReportError("Diagnostics report path must not contain '..'.")
        }

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        return root.appendingPathComponent(path, isDirectory: false)
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
    private let debugCameraConfig: DebugCameraConfig
    private var debugCameraState: DebugCameraState
    private let controlledEntityID: EntityID
    private var nextTick: TickIndex

    /// Creates a validated app-shell pipeline.
    public init(
        config: GameAppConfig,
        debugCameraConfig: DebugCameraConfig = .default
    ) throws {
        let diagnostics = Self.configurationDiagnostics(config)
        guard !DiagnosticReport(messages: diagnostics).hasErrors else {
            throw GameAppConfigurationError(diagnostics: diagnostics)
        }

        self.config = config
        self.session = GameSession(config: Self.makeGameConfig(config))
        self.extractor = RuntimeRenderExtractor()
        self.extractionConfig = Self.extractionConfig(config: config)
        self.metalBackend = MetalRenderBackend(config: MetalRenderBackendConfig(label: "telluric.render.metal.game_app"))
        self.debugCameraConfig = debugCameraConfig
        self.debugCameraState = DebugCameraState.focused(
            appConfig: config,
            cameraConfig: debugCameraConfig,
            viewportAspect: config.defaultViewportAspect
        )
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

    /// Current app-shell debug camera state.
    public var debugCamera: DebugCameraState {
        debugCameraState
    }

    /// Current runtime snapshot before the next frame is stepped.
    public func snapshot() -> RuntimeSnapshot {
        session.snapshot()
    }

    /// Applies a platform-neutral debug camera control without stepping game or runtime state.
    @discardableResult
    public mutating func applyDebugCameraControl(
        _ intent: DebugCameraControlIntent,
        viewportWidth: Int? = nil,
        viewportHeight: Int? = nil
    ) -> DiagnosticReport {
        let aspect = Self.viewportAspect(
            width: viewportWidth ?? config.windowWidth,
            height: viewportHeight ?? config.windowHeight,
            fallback: config.defaultViewportAspect
        )
        let result = debugCameraState.applying(
            intent,
            appConfig: config,
            cameraConfig: debugCameraConfig,
            viewportAspect: aspect
        )
        debugCameraState = result.state
        return result.diagnostics
    }

    /// Steps one deterministic game/runtime/render-preparation frame.
    public mutating func step() -> GameAppFrameResult {
        stepForRendering().frameResult
    }

    /// Steps one deterministic frame and returns the render snapshot for drawable hosts.
    public mutating func stepForRendering(
        drawableRequested: Bool = false,
        viewportWidth: Int? = nil,
        viewportHeight: Int? = nil
    ) -> GameAppRenderableFrame {
        let tick = nextTick
        let gameStep = session.step(GameStepInput(
            gameInputFrame: Self.gameInputFrame(tick: tick, entityID: controlledEntityID)
        ))
        let runtimeSnapshot = gameStep.runtimeSnapshot
        let extraction = extractor.extract(from: runtimeSnapshot, config: extractionConfig)
        let projection = debugCameraState.projection(
            viewportWidth: viewportWidth ?? config.windowWidth,
            viewportHeight: viewportHeight ?? config.windowHeight,
            appConfig: config,
            cameraConfig: debugCameraConfig
        )
        debugCameraState = projection.state
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
            + projection.diagnostics.messages
            + Self.normalizedMetalDiagnostics(from: metalFrame.diagnostics.messages)
        if !drawableRequested {
            diagnostics.append(Self.drawableNotRequestedDiagnostic())
        }

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
            debugCameraState: projection.state,
            debugProjection: projection.projection,
            debugViewportWidth: projection.viewportWidth,
            debugViewportHeight: projection.viewportHeight,
            metalAvailable: metalBackend.isAvailable,
            drawableRenderingImplemented: drawableRequested,
            diagnosticsSummary: diagnosticReport.summary,
            diagnostics: diagnostics,
            success: success
        )

        return GameAppRenderableFrame(
            frameResult: frameResult,
            renderSnapshot: extraction.renderSnapshot,
            drawableDescriptor: Self.drawableDescriptor(
                frameIndex: runtimeSnapshot.state.frameIndex,
                config: config,
                projection: projection.projection,
                viewportWidth: projection.viewportWidth,
                viewportHeight: projection.viewportHeight
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

    private static func drawableDescriptor(
        frameIndex: FrameIndex,
        config: GameAppConfig,
        projection: MetalDebugLineProjection,
        viewportWidth: Int,
        viewportHeight: Int
    ) -> MetalDrawableFrameDescriptor {
        return MetalDrawableFrameDescriptor(
            frameIndex: frameIndex,
            label: "telluric.render.metal.game_app.drawable",
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight,
            debugLineProjection: projection
        )
    }

    private static func viewportAspect(width: Int, height: Int, fallback: Float) -> Float {
        guard width > 0, height > 0 else {
            return Swift.max(fallback, 1)
        }

        let aspect = Float(width) / Float(height)
        return aspect.isFinite && aspect > 0 ? aspect : Swift.max(fallback, 1)
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

    private static func drawableNotRequestedDiagnostic() -> DiagnosticMessage {
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
        let frameCount = arguments.noWindowFrameCount

        for _ in 0..<frameCount {
            frames.append(pipeline.step())
        }

        let diagnostics = frames.flatMap(\.diagnostics)
        let diagnosticReport = DiagnosticReport(messages: diagnostics)

        return GameAppDryRunResult(
            mode: arguments.mode,
            config: arguments.config,
            framesRequested: frameCount,
            metalAvailability: GameAppMetalSummary(capabilities: pipeline.metalCapabilities),
            frames: frames,
            diagnosticsSummary: diagnosticReport.summary,
            success: frames.allSatisfy(\.success) && !diagnosticReport.hasErrors
        )
    }

    /// Builds a deterministic-friendly report for a no-window app-shell run.
    public static func diagnosticsReport(for result: GameAppDryRunResult) -> GameAppDiagnosticsReport {
        let frames = result.frames.enumerated().map { index, frame in
            GameAppVisualFrameSummary(
                frameNumber: index,
                frameResult: frame,
                mtkViewAvailable: false,
                drawableAvailable: false,
                drawCallAttempted: false,
                drawCallSucceeded: false
            )
        }

        return GameAppDiagnosticsReport(
            mode: result.mode,
            config: result.config,
            framesRequested: result.framesRequested,
            metalAvailability: result.metalAvailability,
            mtkViewAvailable: false,
            drawableAvailable: false,
            frames: frames,
            diagnostics: result.frames.flatMap(\.diagnostics)
        )
    }

    /// Creates a human-readable app-shell dry-run summary.
    public static func summary(for result: GameAppDryRunResult, verbose: Bool = false) -> String {
        var lines = [
            "telluric-game-app \(result.mode.rawValue)",
            "seed: \(result.config.seed)",
            "radius: \(result.config.radius)",
            "chunk size: \(result.config.chunkSize)",
            "vertical scale: \(result.config.verticalScale)",
            "frames requested: \(result.framesRequested)",
            "frames simulated: \(result.frames.count)",
            "metal available: \(result.metalAvailability.isMetalAvailable)",
            "drawable rendering requested: false",
            "diagnostics: info \(result.diagnosticsSummary.infos), warning \(result.diagnosticsSummary.warnings), error \(result.diagnosticsSummary.errors)",
            "success: \(result.success)",
        ]

        if let finalFrame = result.frames.last {
            lines.append("final runtime hash: \(finalFrame.runtimeHash)")
            lines.append("final render hash: \(finalFrame.renderSnapshotHash)")
            lines.append("debug lines: \(finalFrame.preparedDebugLineCount)")
            lines.append("debug line vertices: \(finalFrame.preparedDebugLineVertexCount)")
            lines.append("debug camera center: \(finalFrame.debugCameraState.centerX), \(finalFrame.debugCameraState.centerZ)")
            lines.append("debug camera half extent z: \(finalFrame.debugCameraState.halfExtentZ)")
            lines.append("debug projection half extent x: \(finalFrame.debugProjection.halfExtentX)")
            lines.append("debug projection mode: \(finalFrame.debugCameraState.projectionMode.rawValue)")
            lines.append("debug viewport: \(finalFrame.debugViewportWidth)x\(finalFrame.debugViewportHeight)")
        }

        if verbose {
            for frame in result.frames {
                lines.append(
                    "tick \(frame.tick.rawValue): runtime \(frame.runtimeHash), render \(frame.renderSnapshotHash), debug lines \(frame.preparedDebugLineCount), camera center \(frame.debugCameraState.centerX),\(frame.debugCameraState.centerZ), halfZ \(frame.debugCameraState.halfExtentZ)"
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
