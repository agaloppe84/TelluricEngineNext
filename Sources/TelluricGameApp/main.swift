import AppKit
import Darwin
import Metal
import MetalKit
import TelluricGameAppCore

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
        window.contentView = makeContentView(frame: contentRect)
        window.center()
        window.makeKeyAndOrderFront(nil)

        let loopDriver = GameAppLoopDriver(
            pipeline: pipeline,
            verbose: arguments.verbose
        )
        loopDriver.start(framesPerSecond: arguments.config.framesPerSecond)

        self.window = window
        self.loopDriver = loopDriver
    }

    func applicationWillTerminate(_ notification: Notification) {
        loopDriver?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func makeContentView(frame: NSRect) -> NSView {
        if let device = MTLCreateSystemDefaultDevice() {
            let view = MTKView(frame: frame, device: device)
            view.clearColor = MTLClearColorMake(0.02, 0.025, 0.03, 1)
            view.isPaused = true
            view.enableSetNeedsDisplay = false
            view.preferredFramesPerSecond = Int(arguments.config.framesPerSecond)
            return view
        }

        let view = NSView(frame: frame)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedRed: 0.02, green: 0.025, blue: 0.03, alpha: 1).cgColor
        return view
    }
}

@MainActor
private final class GameAppLoopDriver: NSObject {
    private var pipeline: GameAppPipeline
    private let verbose: Bool
    private var timer: Timer?
    private var emittedInitialSummary = false

    init(pipeline: GameAppPipeline, verbose: Bool) {
        self.pipeline = pipeline
        self.verbose = verbose
        super.init()
    }

    func start(framesPerSecond: UInt16) {
        let interval = 1 / Double(framesPerSecond)
        timer = Timer.scheduledTimer(
            timeInterval: interval,
            target: self,
            selector: #selector(stepFrame),
            userInfo: nil,
            repeats: true
        )
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func stepFrame() {
        let result = pipeline.step()
        guard verbose || !emittedInitialSummary || !result.success else {
            return
        }

        emittedInitialSummary = true
        print(
            "telluric-game-app frame \(result.runtimeFrameIndex.rawValue): "
                + "runtime \(result.runtimeHash), "
                + "render \(result.renderSnapshotHash), "
                + "debug lines \(result.preparedDebugLineCount), "
                + "drawable rendering implemented \(result.drawableRenderingImplemented), "
                + "diagnostics info \(result.diagnosticsSummary.infos) "
                + "warning \(result.diagnosticsSummary.warnings) "
                + "error \(result.diagnosticsSummary.errors)"
        )
    }
}
