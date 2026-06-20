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

        window.contentView = makeContentView(frame: contentRect, loopDriver: loopDriver)
        window.center()
        window.makeKeyAndOrderFront(nil)

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
            let view = MTKView(frame: frame, device: device)
            let clearColor = MetalDrawableClearColor.debugBackground
            view.colorPixelFormat = .bgra8Unorm
            view.clearColor = MTLClearColorMake(clearColor.red, clearColor.green, clearColor.blue, clearColor.alpha)
            view.isPaused = false
            view.enableSetNeedsDisplay = false
            view.preferredFramesPerSecond = Int(arguments.config.framesPerSecond)
            view.delegate = loopDriver
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

    init(arguments: GameAppArguments, pipeline: GameAppPipeline, verbose: Bool) {
        self.arguments = arguments
        self.pipeline = pipeline
        self.verbose = verbose
        super.init()
    }

    func setMTKViewAvailable(_ available: Bool) {
        mtkViewAvailable = available
    }

    func draw(in view: MTKView) {
        let drawable = view.currentDrawable
        let renderPassDescriptor = view.currentRenderPassDescriptor
        let drawableAvailable = drawable != nil && renderPassDescriptor != nil
        let frame = pipeline.stepForRendering(drawableRequested: true)
        let descriptor = frame.drawableDescriptor.withViewport(
            width: Swift.max(Int(view.drawableSize.width), 1),
            height: Swift.max(Int(view.drawableSize.height), 1)
        )
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
        _ = size
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
                + "diagnostics info \(drawableResult.diagnostics.summary.infos) "
                + "warning \(drawableResult.diagnostics.summary.warnings) "
                + "error \(drawableResult.diagnostics.summary.errors)"
        )
    }
}
