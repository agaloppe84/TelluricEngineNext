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
        ])

        XCTAssertFalse(arguments.dryRun)
        XCTAssertFalse(arguments.smoke)
        XCTAssertTrue(arguments.run)
        XCTAssertEqual(arguments.frameLimit, 120)
        XCTAssertEqual(arguments.mode, .run)
        XCTAssertEqual(arguments.diagnosticsReportPath, "Tools/benchmarks/game_app_visual_report.json")
    }

    func testArgumentParserRejectsInvalidFrames() {
        XCTAssertThrowsError(try GameAppArgumentParser.parse(["--frames", "0"])) { error in
            XCTAssertEqual(
                error as? GameAppArgumentError,
                .invalidValue(option: "--frames", value: "0", reason: "Expected a positive integer.")
            )
        }
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
        XCTAssertEqual(result.preparedDebugLineCount, 4)
        XCTAssertEqual(result.preparedDebugLineVertexCount, 8)
        XCTAssertFalse(result.drawableRenderingImplemented)
        XCTAssertEqual(result.diagnosticsSummary.errors, 0)
    }

    func testPipelineCanProduceRenderableFrameWithoutOpeningWindow() throws {
        var pipeline = try GameAppPipeline(config: GameAppConfig(
            seed: 1,
            radius: 0,
            chunkSize: 16,
            verticalScale: 8
        ))

        let frame = pipeline.stepForRendering()

        XCTAssertEqual(frame.frameResult.preparedDebugLineCount, 4)
        XCTAssertEqual(frame.renderSnapshot.debugLines.count, 4)
        XCTAssertEqual(frame.drawableDescriptor.frameIndex, frame.frameResult.runtimeFrameIndex)
        XCTAssertEqual(frame.drawableDescriptor.viewportWidth, 1280)
        XCTAssertEqual(frame.drawableDescriptor.viewportHeight, 720)
        XCTAssertGreaterThan(frame.drawableDescriptor.debugLineProjection.halfExtentX, 0)
        XCTAssertGreaterThan(frame.drawableDescriptor.debugLineProjection.halfExtentZ, 0)
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
        XCTAssertEqual(result.frames.last?.preparedDebugLineCount, 36)
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
        XCTAssertEqual(decoded.debugLinesExtracted, 4)
        XCTAssertEqual(decoded.debugVerticesPrepared, 8)
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
}
