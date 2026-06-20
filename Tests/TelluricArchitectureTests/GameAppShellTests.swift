import Foundation
import TelluricGameAppCore
import XCTest

final class GameAppShellTests: XCTestCase {
    func testGameAppConfigCodableRoundTrip() throws {
        let config = GameAppConfig(
            seed: 12345,
            radius: 1,
            chunkSize: 16,
            verticalScale: 8,
            tickRate: 60,
            framesPerSecond: 30,
            windowWidth: 1024,
            windowHeight: 768,
            windowTitle: "Telluric Test"
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(GameAppConfig.self, from: data)

        XCTAssertEqual(decoded, config)
    }

    func testArgumentParserSupportsDryRun() throws {
        let arguments = try GameAppArgumentParser.parse([
            "--seed", "7",
            "--radius", "0",
            "--chunk-size", "16",
            "--vertical-scale", "8",
            "--frames", "2",
            "--dry-run",
            "--verbose",
        ])

        XCTAssertEqual(arguments.config.seed, 7)
        XCTAssertEqual(arguments.config.radius, 0)
        XCTAssertEqual(arguments.config.chunkSize, 16)
        XCTAssertEqual(arguments.config.verticalScale, 8)
        XCTAssertEqual(arguments.frameLimit, 2)
        XCTAssertEqual(arguments.noWindowFrameCount, 2)
        XCTAssertTrue(arguments.dryRun)
        XCTAssertEqual(arguments.mode, .dryRun)
        XCTAssertTrue(arguments.verbose)
    }

    func testArgumentParserSupportsSmokeMode() throws {
        let arguments = try GameAppArgumentParser.parse(["--smoke", "--frames", "4"])

        XCTAssertTrue(arguments.dryRun)
        XCTAssertTrue(arguments.smoke)
        XCTAssertEqual(arguments.frameLimit, 4)
        XCTAssertEqual(arguments.mode, .smoke)
    }

    func testArgumentParserSupportsRunModeAndDiagnosticsReport() throws {
        let arguments = try GameAppArgumentParser.parse([
            "--run",
            "--frames", "120",
            "--diagnostics-report", "Tools/benchmarks/game_app_visual_report.json",
            "--quiet",
            "--log-every", "30",
            "--hide-axes",
            "--hide-origin",
            "--show-centers",
            "--hide-central-highlight",
        ])

        XCTAssertFalse(arguments.dryRun)
        XCTAssertFalse(arguments.smoke)
        XCTAssertTrue(arguments.run)
        XCTAssertEqual(arguments.frameLimit, 120)
        XCTAssertEqual(arguments.mode, .run)
        XCTAssertEqual(arguments.diagnosticsReportPath, "Tools/benchmarks/game_app_visual_report.json")
        XCTAssertTrue(arguments.quiet)
        XCTAssertFalse(arguments.verbose)
        XCTAssertEqual(arguments.logEvery, 30)
        XCTAssertFalse(arguments.debugVisualOptions.showWorldAxes)
        XCTAssertFalse(arguments.debugVisualOptions.showOriginMarker)
        XCTAssertTrue(arguments.debugVisualOptions.showChunkCenters)
        XCTAssertFalse(arguments.debugVisualOptions.showCentralChunkHighlight)
    }

    func testArgumentParserRejectsInvalidFrames() {
        XCTAssertThrowsError(try GameAppArgumentParser.parse(["--frames", "0"])) { error in
            XCTAssertEqual(
                error as? GameAppArgumentError,
                .invalidValue(option: "--frames", value: "0", reason: "Expected a positive integer.")
            )
        }
    }

    func testArgumentParserRejectsInvalidLogEvery() {
        XCTAssertThrowsError(try GameAppArgumentParser.parse(["--log-every", "0"])) { error in
            XCTAssertEqual(
                error as? GameAppArgumentError,
                .invalidValue(option: "--log-every", value: "0", reason: "Expected a positive integer.")
            )
        }
    }

    func testDebugCameraConfigCodableRoundTrip() throws {
        let config = DebugCameraConfig(
            projectionMode: .topDownOrthographic,
            minimumHalfExtent: 2,
            maximumHalfExtent: 512,
            zoomStepFactor: 1.5,
            panStepFraction: 0.25,
            fitMargin: 1.2
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(DebugCameraConfig.self, from: data)

        XCTAssertEqual(decoded, config)
    }

    func testDefaultDebugVisualOptions() throws {
        let options = DebugVisualOptions.default

        XCTAssertTrue(options.showChunkBoundaries)
        XCTAssertTrue(options.showWorldAxes)
        XCTAssertTrue(options.showOriginMarker)
        XCTAssertFalse(options.showChunkCenters)
        XCTAssertTrue(options.showCentralChunkHighlight)
        XCTAssertTrue(options.showStreamingRadiusBounds)
        XCTAssertEqual(options.enabledLayerNames, [
            "chunkBoundaries",
            "worldAxes",
            "originMarker",
            "centralChunkHighlight",
            "streamingRadiusBounds",
        ])
        XCTAssertEqual(try roundTrip(options), options)
    }

    func testDefaultDebugCameraFramesRadiusOneChunkGrid() {
        let config = GameAppConfig(seed: 1, radius: 1, chunkSize: 16, verticalScale: 8)
        let camera = DebugCameraState.focused(appConfig: config, viewportAspect: 16.0 / 9.0)
        let projection = camera.projection(
            viewportWidth: 1600,
            viewportHeight: 900,
            appConfig: config
        )

        XCTAssertTrue(projection.success)
        XCTAssertEqual(projection.state.centerX, 8, accuracy: 0.0001)
        XCTAssertEqual(projection.state.centerZ, 8, accuracy: 0.0001)
        XCTAssertEqual(projection.projection.halfExtentZ, 27.6, accuracy: 0.0001)

        let minXClip = (-16 - projection.projection.centerX) / projection.projection.halfExtentX
        let maxXClip = (32 - projection.projection.centerX) / projection.projection.halfExtentX
        let minZClip = (-16 - projection.projection.centerZ) / projection.projection.halfExtentZ
        let maxZClip = (32 - projection.projection.centerZ) / projection.projection.halfExtentZ

        XCTAssertGreaterThanOrEqual(minXClip, -1)
        XCTAssertLessThanOrEqual(maxXClip, 1)
        XCTAssertGreaterThanOrEqual(minZClip, -1)
        XCTAssertLessThanOrEqual(maxZClip, 1)
    }

    func testDebugCameraZoomPanAndResetAreDeterministic() {
        let config = GameAppConfig(seed: 1, radius: 1, chunkSize: 16, verticalScale: 8)
        let camera = DebugCameraState.focused(appConfig: config, viewportAspect: 16.0 / 9.0)

        let zoomedIn = camera.applying(.zoomIn, appConfig: config, viewportAspect: 16.0 / 9.0).state
        XCTAssertLessThan(zoomedIn.halfExtentZ, camera.halfExtentZ)

        let zoomedOut = zoomedIn.applying(.zoomOut, appConfig: config, viewportAspect: 16.0 / 9.0).state
        XCTAssertEqual(zoomedOut.halfExtentZ, camera.halfExtentZ, accuracy: 0.0001)

        let panned = camera.applying(.pan(deltaX: 1, deltaZ: -1), appConfig: config, viewportAspect: 16.0 / 9.0).state
        XCTAssertGreaterThan(panned.centerX, camera.centerX)
        XCTAssertLessThan(panned.centerZ, camera.centerZ)

        let reset = panned.applying(.reset, appConfig: config, viewportAspect: 16.0 / 9.0).state
        XCTAssertEqual(reset, camera)
    }

    func testInvalidDebugCameraExtentIsClampedWithDiagnostics() {
        let config = GameAppConfig(seed: 1, radius: 1, chunkSize: 16, verticalScale: 8)
        let invalid = DebugCameraState(centerX: .nan, centerZ: .infinity, halfExtentZ: -1)

        let result = invalid.validated(appConfig: config, viewportAspect: 16.0 / 9.0)

        XCTAssertTrue(result.success)
        XCTAssertGreaterThanOrEqual(result.diagnostics.summary.warnings, 3)
        XCTAssertTrue(result.state.centerX.isFinite)
        XCTAssertTrue(result.state.centerZ.isFinite)
        XCTAssertGreaterThan(result.state.halfExtentZ, 0)
    }

    func testDebugCameraProjectionIsDeterministicForSameState() {
        let config = GameAppConfig(seed: 1, radius: 1, chunkSize: 16, verticalScale: 8)
        let camera = DebugCameraState.focused(appConfig: config, viewportAspect: 16.0 / 9.0)

        let first = camera.projection(viewportWidth: 1600, viewportHeight: 900, appConfig: config)
        let second = camera.projection(viewportWidth: 1600, viewportHeight: 900, appConfig: config)

        XCTAssertEqual(first, second)
    }

    func testPipelineCanStepWithoutOpeningWindow() throws {
        var pipeline = try GameAppPipeline(config: GameAppConfig(
            seed: 1,
            radius: 0,
            chunkSize: 16,
            verticalScale: 8
        ))

        let result = pipeline.step()

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.preparedDebugLineCount, 16)
        XCTAssertEqual(result.preparedDebugLineVertexCount, 32)
        XCTAssertFalse(result.drawableRenderingImplemented)
        XCTAssertEqual(result.diagnosticsSummary.errors, 0)
        XCTAssertEqual(result.debugVisualOptions, .default)
    }

    func testPipelineCanProduceRenderableFrameWithoutOpeningWindow() throws {
        var pipeline = try GameAppPipeline(config: GameAppConfig(
            seed: 1,
            radius: 0,
            chunkSize: 16,
            verticalScale: 8
        ))

        let frame = pipeline.stepForRendering()

        XCTAssertEqual(frame.frameResult.preparedDebugLineCount, 16)
        XCTAssertEqual(frame.renderSnapshot.debugLines.count, 16)
        XCTAssertEqual(frame.drawableDescriptor.frameIndex, frame.frameResult.runtimeFrameIndex)
        XCTAssertEqual(frame.drawableDescriptor.viewportWidth, 1280)
        XCTAssertEqual(frame.drawableDescriptor.viewportHeight, 720)
        XCTAssertGreaterThan(frame.drawableDescriptor.debugLineProjection.halfExtentX, 0)
        XCTAssertGreaterThan(frame.drawableDescriptor.debugLineProjection.halfExtentZ, 0)
        XCTAssertEqual(frame.frameResult.debugCameraState.centerX, 8, accuracy: 0.0001)
        XCTAssertEqual(frame.frameResult.debugCameraState.centerZ, 8, accuracy: 0.0001)
    }

    func testPipelineUsesControlledViewportForDebugProjection() throws {
        var pipeline = try GameAppPipeline(config: GameAppConfig(
            seed: 1,
            radius: 1,
            chunkSize: 16,
            verticalScale: 8
        ))

        let frame = pipeline.stepForRendering(viewportWidth: 1000, viewportHeight: 500)

        XCTAssertEqual(frame.drawableDescriptor.viewportWidth, 1000)
        XCTAssertEqual(frame.drawableDescriptor.viewportHeight, 500)
        XCTAssertEqual(
            frame.drawableDescriptor.debugLineProjection.halfExtentX,
            frame.drawableDescriptor.debugLineProjection.halfExtentZ * 2,
            accuracy: 0.0001
        )
    }

    func testAppShellControlIntentsDoNotMutateRuntimeStateDirectly() throws {
        var pipeline = try GameAppPipeline(config: GameAppConfig(
            seed: 1,
            radius: 1,
            chunkSize: 16,
            verticalScale: 8
        ))
        let beforeHash = pipeline.snapshot().stableHash

        let diagnostics = pipeline.applyDebugCameraControl(.zoomIn)
        let afterHash = pipeline.snapshot().stableHash

        XCTAssertFalse(diagnostics.hasErrors)
        XCTAssertEqual(beforeHash, afterHash)
        XCTAssertLessThan(pipeline.debugCamera.halfExtentZ, DebugCameraState.focused(appConfig: pipeline.config).halfExtentZ)
    }

    func testAppShellVisualTogglesDoNotMutateRuntimeStateDirectly() throws {
        var pipeline = try GameAppPipeline(config: GameAppConfig(
            seed: 1,
            radius: 1,
            chunkSize: 16,
            verticalScale: 8
        ))
        let beforeHash = pipeline.snapshot().stableHash

        let diagnostics = pipeline.applyDebugCameraControl(.toggleWorldAxes)
        let afterHash = pipeline.snapshot().stableHash
        let frame = pipeline.stepForRendering()

        XCTAssertFalse(diagnostics.hasErrors)
        XCTAssertEqual(beforeHash, afterHash)
        XCTAssertFalse(pipeline.debugVisualLayers.showWorldAxes)
        XCTAssertEqual(frame.frameResult.preparedDebugLineCount, 46)
    }

    func testPipelineCanDisableGridButKeepAxesAndOrigin() throws {
        var pipeline = try GameAppPipeline(
            config: GameAppConfig(seed: 1, radius: 1, chunkSize: 16, verticalScale: 8),
            debugVisualOptions: DebugVisualOptions(
                showChunkBoundaries: false,
                showWorldAxes: true,
                showOriginMarker: true,
                showChunkCenters: false,
                showCentralChunkHighlight: false,
                showStreamingRadiusBounds: false
            )
        )

        let frame = pipeline.stepForRendering()

        XCTAssertEqual(frame.frameResult.preparedDebugLineCount, 4)
        XCTAssertEqual(frame.renderSnapshot.debugLines.count, 4)
        XCTAssertTrue(frame.renderSnapshot.debugLines.contains { $0.color == .debugXAxis })
        XCTAssertTrue(frame.renderSnapshot.debugLines.contains { $0.color == .debugZAxis })
        XCTAssertEqual(frame.renderSnapshot.debugLines.filter { $0.color == .debugOrigin }.count, 2)
    }

    func testDryRunUsesExistingPipelineWithoutWindow() throws {
        let result = try GameAppRuntime.dryRun(arguments: GameAppArguments(
            config: GameAppConfig(seed: 1, radius: 1, chunkSize: 16, verticalScale: 8),
            dryRun: true,
            frameLimit: 2
        ))

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.mode, .dryRun)
        XCTAssertEqual(result.framesRequested, 2)
        XCTAssertEqual(result.frames.count, 2)
        XCTAssertEqual(result.frames.last?.preparedDebugLineCount, 48)
        XCTAssertEqual(result.diagnosticsSummary.errors, 0)
    }

    func testSmokeConfigDoesNotRequireUIInTests() throws {
        let result = try GameAppRuntime.dryRun(arguments: GameAppArguments(
            config: GameAppConfig(seed: 1, radius: 0, chunkSize: 16, verticalScale: 8),
            dryRun: true,
            smoke: true,
            frameLimit: 3
        ))

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.mode, .smoke)
        XCTAssertEqual(result.framesRequested, 3)
        XCTAssertEqual(result.frames.count, 3)
    }

    func testDiagnosticsReportEncodesAndDecodes() throws {
        let result = try GameAppRuntime.dryRun(arguments: GameAppArguments(
            config: GameAppConfig(seed: 1, radius: 0, chunkSize: 16, verticalScale: 8),
            dryRun: true,
            frameLimit: 1
        ))
        let report = GameAppRuntime.diagnosticsReport(for: result)

        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(GameAppDiagnosticsReport.self, from: data)

        XCTAssertEqual(decoded, report)
        XCTAssertEqual(decoded.framesRequested, 1)
        XCTAssertEqual(decoded.framesSimulated, 1)
        XCTAssertEqual(decoded.framesRendered, 0)
        XCTAssertEqual(decoded.debugLinesExtracted, 16)
        XCTAssertEqual(decoded.debugVerticesPrepared, 32)
        XCTAssertEqual(decoded.drawnDebugLines, 0)
        XCTAssertEqual(decoded.drawnDebugLineVertices, 0)
        XCTAssertEqual(decoded.debugVisualOptions, .default)
        XCTAssertEqual(decoded.debugVisualLayersEnabled, DebugVisualOptions.default.enabledLayerNames)
        XCTAssertEqual(decoded.debugProjectionMode, .topDownOrthographic)
        XCTAssertEqual(decoded.debugCameraCenterX, 8)
        XCTAssertEqual(decoded.debugCameraCenterZ, 8)
        XCTAssertNotNil(decoded.debugCameraHalfExtentZ)
        XCTAssertEqual(decoded.debugViewportWidth, 1280)
        XCTAssertEqual(decoded.debugViewportHeight, 720)
        XCTAssertEqual(decoded.drawCallsAttempted, 0)
        XCTAssertEqual(decoded.drawCallsSucceeded, 0)
    }

    func testInvalidConfigReportsDiagnostics() {
        XCTAssertThrowsError(try GameAppPipeline(config: GameAppConfig(
            seed: 1,
            radius: -1,
            chunkSize: 0,
            verticalScale: 0
        ))) { error in
            guard let configError = error as? GameAppConfigurationError else {
                XCTFail("Expected GameAppConfigurationError, got \(error)")
                return
            }

            XCTAssertGreaterThanOrEqual(configError.diagnostics.count, 3)
        }
    }

    func testAppShellImportBoundaries() throws {
        let root = try packageRoot()
        let sources = root.appendingPathComponent("Sources")
        let appSource = sources.appendingPathComponent("TelluricGameApp")

        XCTAssertTrue(FileManager.default.fileExists(atPath: appSource.path))

        for sourceFile in try swiftFiles(under: sources) {
            let relativePath = sourceFile.path.replacingOccurrences(of: root.path + "/", with: "")
            let isAppShellSource = relativePath.hasPrefix("Sources/TelluricGameApp/")
            let isRenderMetalSource = relativePath.hasPrefix("Sources/TelluricRenderMetal/")
            let contents = try String(contentsOf: sourceFile, encoding: .utf8)

            for sourceLine in contents.components(separatedBy: .newlines) {
                let trimmedLine = sourceLine.trimmingCharacters(in: .whitespaces)

                if trimmedLine == "import AppKit" || trimmedLine == "import MetalKit" {
                    XCTAssertTrue(
                        isAppShellSource,
                        "AppKit/MetalKit must stay isolated to TelluricGameApp: \(sourceFile.path)"
                    )
                }

                if trimmedLine == "import Metal" {
                    XCTAssertTrue(
                        isAppShellSource || isRenderMetalSource,
                        "Metal import must stay in TelluricRenderMetal or app shell glue: \(sourceFile.path)"
                    )
                }

                if trimmedLine == "import SwiftUI"
                    || trimmedLine == "import AVFoundation"
                    || trimmedLine == "import CoreAudio"
                    || trimmedLine == "import GameplayKit" {
                    XCTFail("Forbidden framework import found in \(sourceFile.path)")
                }
            }

            if !isAppShellSource {
                XCTAssertFalse(contents.contains("MTKView"), "MTKView must stay isolated to TelluricGameApp: \(sourceFile.path)")
                XCTAssertFalse(contents.contains("NSWindow"), "NSWindow must stay isolated to TelluricGameApp: \(sourceFile.path)")
            }
        }
    }

    private func packageRoot() throws -> URL {
        var current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        while current.path != "/" {
            if FileManager.default.fileExists(atPath: current.appendingPathComponent("Package.swift").path) {
                return current
            }

            current.deleteLastPathComponent()
        }

        throw XCTSkip("Package.swift was not found from the current test directory.")
    }

    private func swiftFiles(under root: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: root.path) else {
            return []
        }

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            files.append(fileURL)
        }

        return files.sorted { $0.path < $1.path }
    }

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
