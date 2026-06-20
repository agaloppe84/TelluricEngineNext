import AppKit
import Darwin
import Metal
import MetalKit
import TelluricDiagnostics
import TelluricGameAppCore
import TelluricRenderMetal

@main
enum TelluricGameAppMain {
    @MainActor
    static func main() {
        do {
            let arguments = try GameAppArgumentParser.parse(Array(CommandLine.arguments.dropFirst()))

            if arguments.help {
                print(GameAppHelp.text)
                Darwin.exit(EXIT_SUCCESS)
            }

            if arguments.dryRun {
                let result = try GameAppRuntime.dryRun(arguments: arguments)
                print(GameAppRuntime.summary(for: result, verbose: arguments.verbose))
                if let reportPath = arguments.diagnosticsReportPath {
                    let report = GameAppRuntime.diagnosticsReport(for: result)
                    try GameAppReportWriter.write(report, to: reportPath)
                    print("diagnostics report: \(reportPath)")
                }
                Darwin.exit(result.success ? EXIT_SUCCESS : EXIT_FAILURE)
            }

            let pipeline = try GameAppPipeline(config: arguments.config)
            let delegate = GameAppDelegate(arguments: arguments, pipeline: pipeline)
            let app = NSApplication.shared
            app.setActivationPolicy(.regular)
            app.delegate = delegate
            app.run()
        } catch {
            fputs("telluric-game-app: \(error)\n", stderr)
            Darwin.exit(EXIT_FAILURE)
        }
    }
}

@MainActor
private final class GameAppDelegate: NSObject, NSApplicationDelegate {
    private let arguments: GameAppArguments
    private var pipeline: GameAppPipeline
    private var window: NSWindow?
    private var loopDriver: GameAppLoopDriver?

    init(arguments: GameAppArguments, pipeline: GameAppPipeline) {
        self.arguments = arguments
        self.pipeline = pipeline
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentRect = NSRect(
            x: 0,
            y: 0,
            width: arguments.config.windowWidth,
            height: arguments.config.windowHeight
        )
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = arguments.config.windowTitle
        let loopDriver = GameAppLoopDriver(
            arguments: arguments,
            pipeline: pipeline,
            verbose: arguments.verbose
        )

        let contentView = makeContentView(frame: contentRect, loopDriver: loopDriver)
        window.contentView = contentView
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(contentView)

        self.window = window
        self.loopDriver = loopDriver

        if !loopDriver.mtkViewAvailable {
            loopDriver.runWithoutDrawableFallback()
            if arguments.frameLimit != nil {
                loopDriver.writeReportIfRequested()
                NSApplication.shared.terminate(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        loopDriver?.writeReportIfRequested()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func makeContentView(frame: NSRect, loopDriver: GameAppLoopDriver) -> NSView {
        if let device = pipeline.metalRenderBackend.metalDevice {
            let view = GameAppMetalView(frame: frame, device: device)
            let clearColor = MetalDrawableClearColor.debugBackground
            view.colorPixelFormat = .bgra8Unorm
            view.clearColor = MTLClearColorMake(clearColor.red, clearColor.green, clearColor.blue, clearColor.alpha)
            view.isPaused = false
            view.enableSetNeedsDisplay = false
            view.preferredFramesPerSecond = Int(arguments.config.framesPerSecond)
            view.delegate = loopDriver
            view.debugControlHandler = { [weak loopDriver] intent in
                loopDriver?.handleDebugCameraControl(intent)
            }
            loopDriver.setMTKViewAvailable(true)
            return view
        }

        let view = NSView(frame: frame)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedRed: 0.02, green: 0.025, blue: 0.03, alpha: 1).cgColor
        loopDriver.setMTKViewAvailable(false)
        return view
    }
}

private final class GameAppLoopDriver: NSObject, MTKViewDelegate {
    private let arguments: GameAppArguments
    private var pipeline: GameAppPipeline
    private let verbose: Bool
    private var emittedInitialSummary = false
    private var frameSummaries: [GameAppVisualFrameSummary] = []
    private var diagnostics: [DiagnosticMessage] = []
    private var reportWritten = false
    private(set) var mtkViewAvailable = false
    private var drawableEverAvailable = false
    private var viewportWidth: Int
    private var viewportHeight: Int

    init(arguments: GameAppArguments, pipeline: GameAppPipeline, verbose: Bool) {
        self.arguments = arguments
        self.pipeline = pipeline
        self.verbose = verbose
        self.viewportWidth = arguments.config.windowWidth
        self.viewportHeight = arguments.config.windowHeight
        super.init()
    }

    func setMTKViewAvailable(_ available: Bool) {
        mtkViewAvailable = available
    }

    func draw(in view: MTKView) {
        let drawable = view.currentDrawable
        let renderPassDescriptor = view.currentRenderPassDescriptor
        let drawableAvailable = drawable != nil && renderPassDescriptor != nil
        updateViewport(width: Int(view.drawableSize.width), height: Int(view.drawableSize.height))
        let frame = pipeline.stepForRendering(
            drawableRequested: true,
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight
        )
        let descriptor = frame.drawableDescriptor
        let drawableResult = pipeline.metalRenderBackend.renderDrawable(
            snapshot: frame.renderSnapshot,
            descriptor: descriptor,
            drawable: drawable,
            renderPassDescriptor: renderPassDescriptor
        )
        drawableEverAvailable = drawableEverAvailable || drawableAvailable

        record(
            frame: frame.frameResult,
            mtkViewAvailable: true,
            drawableAvailable: drawableAvailable,
            drawCallAttempted: true,
            drawCallSucceeded: drawableResult.success && drawableResult.presentedDrawable,
            extraDiagnostics: drawableResult.diagnostics.messages
        )

        log(frame: frame.frameResult, drawableResult: drawableResult)

        if let frameLimit = arguments.frameLimit, frameSummaries.count >= frameLimit {
            writeReportIfRequested()
            NSApplication.shared.terminate(nil)
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        updateViewport(width: Int(size.width), height: Int(size.height))
    }

    func handleDebugCameraControl(_ intent: DebugCameraControlIntent) {
        let diagnosticsReport = pipeline.applyDebugCameraControl(
            intent,
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight
        )
        diagnostics.append(contentsOf: diagnosticsReport.messages)

        if verbose {
            let camera = pipeline.debugCamera
            print(
                "telluric-game-app debug camera: "
                    + "mode \(camera.projectionMode.rawValue), "
                    + "center \(camera.centerX),\(camera.centerZ), "
                    + "halfZ \(camera.halfExtentZ), "
                    + "diagnostics error \(diagnosticsReport.summary.errors)"
            )
        }
    }

    func runWithoutDrawableFallback() {
        let frames = Swift.max(arguments.frameLimit ?? 1, 1)
        for _ in 0..<frames {
            let frame = pipeline.stepForRendering(drawableRequested: false)
            record(
                frame: frame.frameResult,
                mtkViewAvailable: false,
                drawableAvailable: false,
                drawCallAttempted: false,
                drawCallSucceeded: false,
                extraDiagnostics: []
            )
        }

        if let finalFrame = frameSummaries.last {
            print(
                "telluric-game-app: Metal unavailable; opened fallback view. "
                    + "frames simulated \(frameSummaries.count), "
                    + "debug lines \(finalFrame.debugLinesExtracted), "
                    + "camera center \(finalFrame.debugCameraCenterX),\(finalFrame.debugCameraCenterZ), "
                    + "halfZ \(finalFrame.debugCameraHalfExtentZ), "
                    + "diagnostics info \(finalFrame.diagnosticsSummary.infos) "
                    + "warning \(finalFrame.diagnosticsSummary.warnings) "
                    + "error \(finalFrame.diagnosticsSummary.errors)"
            )
        }
    }

    func writeReportIfRequested() {
        guard let reportPath = arguments.diagnosticsReportPath, !reportWritten else {
            return
        }

        do {
            let report = GameAppDiagnosticsReport(
                mode: arguments.mode,
                config: arguments.config,
                framesRequested: arguments.frameLimit,
                metalAvailability: GameAppMetalSummary(capabilities: pipeline.metalCapabilities),
                mtkViewAvailable: mtkViewAvailable,
                drawableAvailable: drawableEverAvailable,
                frames: frameSummaries,
                diagnostics: diagnostics
            )
            try GameAppReportWriter.write(report, to: reportPath)
            reportWritten = true
            print("telluric-game-app diagnostics report: \(reportPath)")
        } catch {
            fputs("telluric-game-app diagnostics report failed: \(error)\n", stderr)
        }
    }

    private func record(
        frame: GameAppFrameResult,
        mtkViewAvailable: Bool,
        drawableAvailable: Bool,
        drawCallAttempted: Bool,
        drawCallSucceeded: Bool,
        extraDiagnostics: [DiagnosticMessage]
    ) {
        diagnostics.append(contentsOf: frame.diagnostics)
        diagnostics.append(contentsOf: extraDiagnostics)
        frameSummaries.append(GameAppVisualFrameSummary(
            frameNumber: frameSummaries.count,
            frameResult: frame,
            mtkViewAvailable: mtkViewAvailable,
            drawableAvailable: drawableAvailable,
            drawCallAttempted: drawCallAttempted,
            drawCallSucceeded: drawCallSucceeded,
            extraDiagnostics: extraDiagnostics
        ))
    }

    private func updateViewport(width: Int, height: Int) {
        viewportWidth = Swift.max(width, 1)
        viewportHeight = Swift.max(height, 1)
    }

    private func log(frame: GameAppFrameResult, drawableResult: MetalDrawableRenderResult) {
        guard verbose || !emittedInitialSummary || !frame.success || !drawableResult.success else {
            return
        }

        emittedInitialSummary = true
        print(
            "telluric-game-app frame \(frame.runtimeFrameIndex.rawValue): "
                + "runtime \(frame.runtimeHash), "
                + "render \(frame.renderSnapshotHash), "
                + "prepared debug lines \(frame.preparedDebugLineCount), "
                + "drawn debug lines \(drawableResult.drawnDebugLineCount), "
                + "presented \(drawableResult.presentedDrawable), "
                + "drawable success \(drawableResult.success), "
                + "camera center \(frame.debugCameraState.centerX),\(frame.debugCameraState.centerZ), "
                + "halfZ \(frame.debugCameraState.halfExtentZ), "
                + "viewport \(frame.debugViewportWidth)x\(frame.debugViewportHeight), "
                + "diagnostics info \(drawableResult.diagnostics.summary.infos) "
                + "warning \(drawableResult.diagnostics.summary.warnings) "
                + "error \(drawableResult.diagnostics.summary.errors)"
        )
    }
}

private final class GameAppMetalView: MTKView {
    var debugControlHandler: ((DebugCameraControlIntent) -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if let intent = Self.intent(for: event) {
            debugControlHandler?(intent)
            return
        }

        super.keyDown(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        guard event.scrollingDeltaY != 0 else {
            super.scrollWheel(with: event)
            return
        }

        debugControlHandler?(event.scrollingDeltaY > 0 ? .zoomIn : .zoomOut)
    }

    private static func intent(for event: NSEvent) -> DebugCameraControlIntent? {
        switch event.keyCode {
        case 123:
            return .pan(deltaX: -1, deltaZ: 0)
        case 124:
            return .pan(deltaX: 1, deltaZ: 0)
        case 125:
            return .pan(deltaX: 0, deltaZ: -1)
        case 126:
            return .pan(deltaX: 0, deltaZ: 1)
        default:
            break
        }

        guard let character = event.charactersIgnoringModifiers?.lowercased() else {
            return nil
        }

        switch character {
        case "+", "=":
            return .zoomIn
        case "-", "_":
            return .zoomOut
        case "0", "r":
            return .reset
        case "a":
            return .pan(deltaX: -1, deltaZ: 0)
        case "d":
            return .pan(deltaX: 1, deltaZ: 0)
        case "s":
            return .pan(deltaX: 0, deltaZ: -1)
        case "w":
            return .pan(deltaX: 0, deltaZ: 1)
        default:
            return nil
        }
    }
}
