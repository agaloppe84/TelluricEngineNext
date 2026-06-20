import Foundation
import TelluricHeadlessLoopCore
import XCTest

final class HeadlessLoopTests: XCTestCase {
    func testCLIParserAcceptsValidArguments() throws {
        let arguments = try HeadlessLoopArgumentParser.parse([
            "--seed", "12345",
            "--radius", "1",
            "--chunk-size", "16",
            "--vertical-scale", "8",
            "--ticks", "3",
            "--report", "Tools/benchmarks/headless_loop_report.json",
            "--verbose",
        ])

        XCTAssertEqual(arguments.seed, 12345)
        XCTAssertEqual(arguments.radius, 1)
        XCTAssertEqual(arguments.chunkSize, 16)
        XCTAssertEqual(arguments.verticalScale, 8)
        XCTAssertEqual(arguments.ticks, 3)
        XCTAssertEqual(arguments.reportPath, "Tools/benchmarks/headless_loop_report.json")
        XCTAssertTrue(arguments.verbose)
    }

    func testCLIParserRejectsInvalidTickCount() {
        XCTAssertThrowsError(try HeadlessLoopArgumentParser.parse([
            "--seed", "1",
            "--radius", "1",
            "--chunk-size", "16",
            "--vertical-scale", "8",
            "--ticks", "0",
        ])) { error in
            guard let parserError = error as? HeadlessLoopArgumentError else {
                XCTFail("Expected invalid tick count error, got \(error)")
                return
            }

            guard case .invalidValue(option: "--ticks", value: "0", reason: _) = parserError else {
                XCTFail("Expected invalid tick count error, got \(parserError)")
                return
            }
        }
    }

    func testCLIParserSupportsHelpWithoutRequiredArguments() throws {
        let arguments = try HeadlessLoopArgumentParser.parse(["--help"])

        XCTAssertTrue(arguments.help)
        XCTAssertTrue(HeadlessLoopHelp.text.contains("telluric-headless-loop"))
    }

    func testSameConfigProducesSameFinalRuntimeHash() {
        let first = HeadlessLoopRunner().validate(arguments: makeArguments(seed: 7))
        let second = HeadlessLoopRunner().validate(arguments: makeArguments(seed: 7))

        XCTAssertTrue(first.success)
        XCTAssertTrue(second.success)
        XCTAssertEqual(first.finalRuntimeHash, second.finalRuntimeHash)
        XCTAssertEqual(first.rootHash, second.rootHash)
    }

    func testSameConfigProducesSameFinalRenderSnapshotHash() {
        let first = HeadlessLoopRunner().validate(arguments: makeArguments(seed: 7))
        let second = HeadlessLoopRunner().validate(arguments: makeArguments(seed: 7))

        XCTAssertEqual(first.finalRenderSnapshotHash, second.finalRenderSnapshotHash)
        XCTAssertEqual(first.tickSummaries.map(\.renderSnapshotHash), second.tickSummaries.map(\.renderSnapshotHash))
    }

    func testDifferentSeedChangesFinalRuntimeOrRenderHash() {
        let first = HeadlessLoopRunner().validate(arguments: makeArguments(seed: 7))
        let second = HeadlessLoopRunner().validate(arguments: makeArguments(seed: 8))

        XCTAssertTrue(
            first.finalRuntimeHash != second.finalRuntimeHash
                || first.finalRenderSnapshotHash != second.finalRenderSnapshotHash
        )
    }

    func testRadiusOneProducesExpectedChunkDebugExtractionCount() {
        let report = HeadlessLoopRunner().validate(arguments: makeArguments(seed: 1, radius: 1, ticks: 1))

        XCTAssertTrue(report.success)
        XCTAssertEqual(report.finalPreparedDebugLineCount, 48)
        XCTAssertEqual(report.finalPreparedDebugLineVertexCount, 96)
        XCTAssertEqual(report.tickSummaries.last?.preparedDebugLineCount, 48)
    }

    func testHeadlessLoopSucceedsWithMetalUnavailableOrAvailable() {
        let report = HeadlessLoopRunner().validate(arguments: makeArguments(seed: 1, radius: 1, ticks: 2))

        XCTAssertTrue(report.success)
        XCTAssertEqual(report.diagnosticsSummary.errors, 0)

        if !report.metalAvailability.isMetalAvailable {
            XCTAssertTrue(report.diagnostics.contains { message in
                message.severity == .warning
                    && (
                        message.code.rawValue == "render.metal.unavailable"
                            || message.code.rawValue == "render.metal.command_queue_unavailable"
                            || message.code.rawValue == "render.metal.debug_line.buffer_unavailable"
                    )
            })
        }
    }

    func testReportEncodesAndDecodesJSON() throws {
        let report = HeadlessLoopRunner().validate(arguments: makeArguments(seed: 1, radius: 1, ticks: 2))
        let data = try HeadlessLoopRunner.jsonEncoder().encode(report)
        let decoded = try JSONDecoder().decode(HeadlessLoopReport.self, from: data)

        XCTAssertEqual(decoded, report)
    }

    func testReportWriteRejectsPathTraversal() {
        let report = HeadlessLoopRunner().validate(arguments: makeArguments(seed: 1))

        XCTAssertThrowsError(try HeadlessLoopRunner.write(
            report: report,
            to: "../headless_loop_report.json",
            repoRoot: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        )) { error in
            XCTAssertTrue(error is HeadlessLoopPathError)
        }
    }

    func testHeadlessLoopSourceDoesNotImportAppWindowOrMetalFrameworks() throws {
        let root = try packageRoot()
        let forbiddenImports = [
            "Metal",
            "MetalKit",
            "SwiftUI",
            "AppKit",
            "AVFoundation",
            "CoreAudio",
            "GameplayKit",
        ]

        for target in ["TelluricHeadlessLoopCore", "TelluricHeadlessLoop"] {
            let source = root.appendingPathComponent("Sources").appendingPathComponent(target)
            try assertNoSwiftSourceLine(under: source, containsAnyImportOf: forbiddenImports)
            try assertNoSwiftSourceLine(under: source, containsAny: ["MTKView"])
        }
    }

    private func makeArguments(seed: UInt64, radius: Int = 1, ticks: Int = 3) -> HeadlessLoopArguments {
        HeadlessLoopArguments(
            seed: seed,
            radius: radius,
            chunkSize: 16,
            verticalScale: 8,
            ticks: ticks
        )
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

    private func assertNoSwiftSourceLine(
        under root: URL,
        containsAny tokens: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        for sourceFile in try swiftFiles(under: root) {
            let contents = try String(contentsOf: sourceFile, encoding: .utf8)
            for sourceLine in contents.components(separatedBy: .newlines) {
                for token in tokens where sourceLine.contains(token) {
                    XCTFail("Forbidden token \(token) found in \(sourceFile.path)", file: file, line: line)
                }
            }
        }
    }

    private func assertNoSwiftSourceLine(
        under root: URL,
        containsAnyImportOf modules: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        for sourceFile in try swiftFiles(under: root) {
            let contents = try String(contentsOf: sourceFile, encoding: .utf8)
            for sourceLine in contents.components(separatedBy: .newlines) {
                let trimmedLine = sourceLine.trimmingCharacters(in: .whitespaces)
                for module in modules where trimmedLine == "import \(module)" {
                    XCTFail("Forbidden import \(module) found in \(sourceFile.path)", file: file, line: line)
                }
            }
        }
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
