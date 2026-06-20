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
            "--hide-terrain",
            "--terrain-stride", "8",
            "--terrain-height-scale", "0.5",
            "--projection", "top-down",
            "--height-exaggeration", "2.5",
            "--oblique-strength", "1.5",
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
        XCTAssertFalse(arguments.debugVisualOptions.showTerrainHeightWireframe)
        XCTAssertEqual(arguments.debugVisualOptions.terrainWireframeStride, 8)
        XCTAssertEqual(arguments.debugVisualOptions.terrainHeightScale, 2.5)
        XCTAssertEqual(arguments.debugVisualOptions.terrainObliqueStrength, 1.5)
        XCTAssertEqual(arguments.debugCameraConfig.projectionMode, .topDownOrthographic)
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

    func testArgumentParserRejectsInvalidTerrainOptions() {
        XCTAssertThrowsError(try GameAppArgumentParser.parse(["--terrain-stride", "0"])) { error in
            XCTAssertEqual(
                error as? GameAppArgumentError,
                .invalidValue(option: "--terrain-stride", value: "0", reason: "Expected a positive integer.")
            )
        }

        XCTAssertThrowsError(try GameAppArgumentParser.parse(["--terrain-height-scale", "0"])) { error in
            XCTAssertEqual(
                error as? GameAppArgumentError,
                .invalidValue(option: "--terrain-height-scale", value: "0", reason: "Expected a finite positive number.")
            )
        }

        XCTAssertThrowsError(try GameAppArgumentParser.parse(["--height-exaggeration", "nan"])) { error in
            XCTAssertEqual(
                error as? GameAppArgumentError,
                .invalidValue(option: "--height-exaggeration", value: "nan", reason: "Expected a finite positive number.")
            )
        }

        XCTAssertThrowsError(try GameAppArgumentParser.parse(["--oblique-strength", "5"])) { error in
            XCTAssertEqual(
                error as? GameAppArgumentError,
                .invalidValue(option: "--oblique-strength", value: "5", reason: "Expected a finite number from 0 through 4.0.")
            )
        }

        XCTAssertThrowsError(try GameAppArgumentParser.parse(["--projection", "sideways"])) { error in
            XCTAssertEqual(
                error as? GameAppArgumentError,
                .invalidValue(option: "--projection", value: "sideways", reason: "Expected top-down or oblique.")
            )
        }
    }

    func testProjectionModeCodableParsingAndCycling() throws {
        XCTAssertEqual(DebugProjectionMode.parse("top-down"), .topDownOrthographic)
        XCTAssertEqual(DebugProjectionMode.parse("oblique"), .obliqueHeight)
        XCTAssertEqual(DebugProjectionMode.topDownOrthographic.cliName, "top-down")
        XCTAssertEqual(DebugProjectionMode.obliqueHeight.cliName, "oblique")
        XCTAssertEqual(DebugProjectionMode.topDownOrthographic.next, .obliqueHeight)
        XCTAssertEqual(DebugProjectionMode.obliqueHeight.next, .topDownOrthographic)
        XCTAssertEqual(try roundTrip(DebugProjectionMode.obliqueHeight), .obliqueHeight)
    }

    func testDebugCameraConfigCodableRoundTrip() throws {
        let config = DebugCameraConfig(
            projectionMode: .obliqueHeight,
            minimumHalfExtent: 2,
            maximumHalfExtent: 512,
            zoomStepFactor: 1.5,
            panStepFraction: 0.25,
            fitMargin: 1.35
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
        XCTAssertTrue(options.showTerrainHeightWireframe)
        XCTAssertEqual(options.terrainWireframeStride, 4)
        XCTAssertEqual(options.terrainHeightScale, 2)
        XCTAssertEqual(options.terrainObliqueStrength, 1)
        XCTAssertEqual(options.terrainHeightProjectionShearX, 0.22)
        XCTAssertEqual(options.terrainHeightProjectionShearZ, 0.45)
        XCTAssertEqual(options.enabledLayerNames, [
            "chunkBoundaries",
            "worldAxes",
            "originMarker",
            "centralChunkHighlight",
            "streamingRadiusBounds",
            "terrainHeightWireframe",
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
        XCTAssertEqual(projection.state.projectionMode, .obliqueHeight)
        XCTAssertEqual(projection.state.centerX, 8, accuracy: 0.0001)
        XCTAssertEqual(projection.state.centerZ, 8, accuracy: 0.0001)
        XCTAssertEqual(projection.projection.halfExtentZ, 32.4, accuracy: 0.0001)

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

        let cycled = camera.applying(.cycleProjectionMode, appConfig: config, viewportAspect: 16.0 / 9.0).state
        XCTAssertEqual(cycled.projectionMode, .topDownOrthographic)
        XCTAssertEqual(cycled.centerX, camera.centerX)
        XCTAssertEqual(cycled.halfExtentZ, camera.halfExtentZ)
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
        XCTAssertEqual(result.preparedDebugLineCount, 56)
        XCTAssertEqual(result.preparedDebugLineVertexCount, 112)
        XCTAssertEqual(result.terrainDebugLineCount, 40)
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

        XCTAssertEqual(frame.frameResult.preparedDebugLineCount, 56)
        XCTAssertEqual(frame.frameResult.terrainDebugLineCount, 40)
        XCTAssertEqual(frame.renderSnapshot.debugLines.count, 56)
        XCTAssertEqual(frame.drawableDescriptor.frameIndex, frame.frameResult.runtimeFrameIndex)
        XCTAssertEqual(frame.drawableDescriptor.viewportWidth, 1280)
        XCTAssertEqual(frame.drawableDescriptor.viewportHeight, 720)
        XCTAssertGreaterThan(frame.drawableDescriptor.debugLineProjection.halfExtentX, 0)
        XCTAssertGreaterThan(frame.drawableDescriptor.debugLineProjection.halfExtentZ, 0)
        XCTAssertEqual(frame.frameResult.debugCameraState.projectionMode, .obliqueHeight)
        XCTAssertEqual(frame.drawableDescriptor.debugLineProjection.heightShearX, 0.22)
        XCTAssertEqual(frame.drawableDescriptor.debugLineProjection.heightShearZ, 0.45)
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

    func testTopDownProjectionKeepsTerrainHeightOutOfProjectionUniforms() throws {
        var pipeline = try GameAppPipeline(
            config: GameAppConfig(seed: 1, radius: 1, chunkSize: 16, verticalScale: 8),
            debugCameraConfig: DebugCameraConfig(projectionMode: .topDownOrthographic)
        )

        let frame = pipeline.stepForRendering()

        XCTAssertEqual(frame.frameResult.preparedDebugLineCount, 408)
        XCTAssertEqual(frame.frameResult.terrainDebugLineCount, 360)
        XCTAssertEqual(frame.frameResult.debugCameraState.projectionMode, .topDownOrthographic)
        XCTAssertEqual(frame.drawableDescriptor.debugLineProjection.heightShearX, 0)
        XCTAssertEqual(frame.drawableDescriptor.debugLineProjection.heightShearZ, 0)
    }

    func testHeightExaggerationChangesTerrainRenderSnapshotDeterministically() throws {
        let config = GameAppConfig(seed: 1, radius: 1, chunkSize: 16, verticalScale: 8)
        var base = try GameAppPipeline(
            config: config,
            debugVisualOptions: DebugVisualOptions(terrainHeightScale: 1)
        )
        var exaggerated = try GameAppPipeline(
            config: config,
            debugVisualOptions: DebugVisualOptions(terrainHeightScale: 3)
        )

        let baseFrame = base.stepForRendering()
        let exaggeratedFrame = exaggerated.stepForRendering()

        XCTAssertEqual(baseFrame.frameResult.preparedDebugLineCount, 408)
        XCTAssertEqual(exaggeratedFrame.frameResult.preparedDebugLineCount, 408)
        XCTAssertNotEqual(baseFrame.frameResult.renderSnapshotHash, exaggeratedFrame.frameResult.renderSnapshotHash)
        XCTAssertEqual(exaggeratedFrame.frameResult.debugVisualOptions.terrainHeightScale, 3)
    }

    func testRadiusOneTerrainStaysWithinDefaultObliqueProjectionBounds() throws {
        var pipeline = try GameAppPipeline(config: GameAppConfig(
            seed: 1,
            radius: 1,
            chunkSize: 16,
            verticalScale: 8
        ))

        let frame = pipeline.stepForRendering(viewportWidth: 1600, viewportHeight: 900)
        let projection = frame.drawableDescriptor.debugLineProjection
        let points = frame.renderSnapshot.debugLines.flatMap { [$0.start, $0.end] }

        XCTAssertEqual(frame.frameResult.preparedDebugLineCount, 408)
        XCTAssertEqual(frame.frameResult.terrainDebugLineCount, 360)
        XCTAssertTrue(points.allSatisfy { point in
            let clipX = ((point.x - projection.centerX) + point.y * projection.heightShearX) / projection.halfExtentX
            let clipY = ((point.z - projection.centerZ) + point.y * projection.heightShearZ) / projection.halfExtentZ
            return abs(clipX) <= 1.0 && abs(clipY) <= 1.0
        })
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

    func testProjectionAndHeightControlsDoNotMutateRuntimeStateDirectly() throws {
        var pipeline = try GameAppPipeline(config: GameAppConfig(
            seed: 1,
            radius: 1,
            chunkSize: 16,
            verticalScale: 8
        ))
        let beforeHash = pipeline.snapshot().stableHash

        XCTAssertFalse(pipeline.applyDebugCameraControl(.cycleProjectionMode).hasErrors)
        XCTAssertFalse(pipeline.applyDebugCameraControl(.increaseHeightExaggeration).hasErrors)
        let afterHash = pipeline.snapshot().stableHash

        XCTAssertEqual(beforeHash, afterHash)
        XCTAssertEqual(pipeline.debugCamera.projectionMode, .topDownOrthographic)
        XCTAssertGreaterThan(pipeline.debugVisualLayers.terrainHeightScale, DebugVisualOptions.default.terrainHeightScale)
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
        XCTAssertEqual(frame.frameResult.preparedDebugLineCount, 406)
    }

    func testAppShellTerrainToggleDoesNotMutateRuntimeStateDirectly() throws {
        var pipeline = try GameAppPipeline(config: GameAppConfig(
            seed: 1,
            radius: 1,
            chunkSize: 16,
            verticalScale: 8
        ))
        let beforeHash = pipeline.snapshot().stableHash

        let diagnostics = pipeline.applyDebugCameraControl(.toggleTerrainHeightWireframe)
        let afterHash = pipeline.snapshot().stableHash
        let frame = pipeline.stepForRendering()

        XCTAssertFalse(diagnostics.hasErrors)
        XCTAssertEqual(beforeHash, afterHash)
        XCTAssertFalse(pipeline.debugVisualLayers.showTerrainHeightWireframe)
        XCTAssertEqual(frame.frameResult.preparedDebugLineCount, 48)
        XCTAssertEqual(frame.frameResult.terrainDebugLineCount, 0)
        XCTAssertEqual(frame.drawableDescriptor.debugLineProjection.heightShearX, 0)
        XCTAssertEqual(frame.drawableDescriptor.debugLineProjection.heightShearZ, 0)
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
                showStreamingRadiusBounds: false,
                showTerrainHeightWireframe: false
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
        XCTAssertEqual(result.frames.last?.preparedDebugLineCount, 408)
        XCTAssertEqual(result.frames.last?.terrainDebugLineCount, 360)
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
        XCTAssertEqual(decoded.debugLinesExtracted, 56)
        XCTAssertEqual(decoded.debugVerticesPrepared, 112)
        XCTAssertEqual(decoded.terrainDebugLinesExtracted, 40)
        XCTAssertEqual(decoded.drawnDebugLines, 0)
        XCTAssertEqual(decoded.drawnDebugLineVertices, 0)
        XCTAssertEqual(decoded.debugVisualOptions, .default)
        XCTAssertEqual(decoded.debugVisualLayersEnabled, DebugVisualOptions.default.enabledLayerNames)
        XCTAssertEqual(decoded.debugProjectionMode, .obliqueHeight)
        XCTAssertEqual(decoded.terrainHeightExaggeration, 2)
        XCTAssertEqual(decoded.terrainObliqueStrength, 1)
        XCTAssertEqual(decoded.debugCameraCenterX, 8)
        XCTAssertEqual(decoded.debugCameraCenterZ, 8)
        XCTAssertNotNil(decoded.debugCameraHalfExtentZ)
        XCTAssertEqual(decoded.debugProjectionHeightShearX, 0.22)
        XCTAssertEqual(decoded.debugProjectionHeightShearZ, 0.45)
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
