import AppKit
import Darwin
import Metal
import MetalKit
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
            pipeline: pipeline,
            verbose: arguments.verbose
        )

        window.contentView = makeContentView(frame: contentRect, loopDriver: loopDriver)
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.window = window
        self.loopDriver = loopDriver
    }

    func applicationWillTerminate(_ notification: Notification) {
        loopDriver?.stop()
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
            return view
        }

        let view = NSView(frame: frame)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedRed: 0.02, green: 0.025, blue: 0.03, alpha: 1).cgColor
        return view
    }
}

private final class GameAppLoopDriver: NSObject, MTKViewDelegate {
    private var pipeline: GameAppPipeline
    private let verbose: Bool
    private var emittedInitialSummary = false

    init(pipeline: GameAppPipeline, verbose: Bool) {
        self.pipeline = pipeline
        self.verbose = verbose
        super.init()
    }

    func draw(in view: MTKView) {
        let frame = pipeline.stepForRendering()
        let descriptor = frame.drawableDescriptor.withViewport(
            width: Swift.max(Int(view.drawableSize.width), 1),
            height: Swift.max(Int(view.drawableSize.height), 1)
        )
        let drawableResult = pipeline.metalRenderBackend.renderDrawable(
            snapshot: frame.renderSnapshot,
            descriptor: descriptor,
            drawable: view.currentDrawable,
            renderPassDescriptor: view.currentRenderPassDescriptor
        )

        log(frame: frame.frameResult, drawableResult: drawableResult)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        _ = size
    }

    func stop() {
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
