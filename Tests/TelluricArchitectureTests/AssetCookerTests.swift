import Foundation
import TelluricAssetCookerCore
import XCTest

final class AssetCookerTests: XCTestCase {
    func testCLIParserAcceptsValidArguments() throws {
        let arguments = try AssetCookerArgumentParser.parse([
            "--manifest", "Assets/Manifests/assets.json",
            "--output", "Assets/Cooked",
            "--report", "Tools/benchmarks/asset_cook_report.json",
            "--strict",
            "--verbose",
        ])

        XCTAssertEqual(arguments.manifestPath, "Assets/Manifests/assets.json")
        XCTAssertEqual(arguments.outputPath, "Assets/Cooked")
        XCTAssertEqual(arguments.reportPath, "Tools/benchmarks/asset_cook_report.json")
        XCTAssertTrue(arguments.strict)
        XCTAssertTrue(arguments.verbose)
    }

    func testCLIParserSupportsHelpWithoutRequiredArguments() throws {
        let arguments = try AssetCookerArgumentParser.parse(["--help"])

        XCTAssertTrue(arguments.help)
        XCTAssertTrue(AssetCookerHelp.text.contains("telluric-asset-cooker"))
    }

    func testCLIParserRejectsMissingManifestPath() {
        XCTAssertThrowsError(try AssetCookerArgumentParser.parse([
            "--output", "Assets/Cooked",
        ])) { error in
            guard let parserError = error as? AssetCookerArgumentError else {
                XCTFail("Expected asset cooker parser error, got \(error)")
                return
            }

            XCTAssertEqual(parserError, .missingRequiredOption("--manifest"))
        }
    }

    func testAssetCookerReportEncodesAndDecodesJSON() throws {
        let report = AssetCooker().cook(
            arguments: makeArguments(),
            repoRoot: try packageRoot()
        )
        let data = try AssetCooker.jsonEncoder().encode(report)
        let decoded = try JSONDecoder().decode(AssetCookerReport.self, from: data)

        XCTAssertEqual(decoded, report)
    }

    func testAssetCookerValidatesExampleManifest() throws {
        let report = AssetCooker().cook(
            arguments: makeArguments(),
            repoRoot: try packageRoot()
        )

        XCTAssertTrue(report.success)
        XCTAssertEqual(report.entriesRequested, 2)
        XCTAssertEqual(report.descriptorsProduced, 2)
        XCTAssertEqual(report.unsupportedConversions, 0)
        XCTAssertNotNil(report.rootHash)
    }

    func testStrictModeReportsUnsupportedConversions() throws {
        let report = AssetCooker().cook(
            arguments: makeArguments(strict: true),
            repoRoot: try packageRoot()
        )

        XCTAssertFalse(report.success)
        XCTAssertEqual(report.unsupportedConversions, 2)
        XCTAssertEqual(report.diagnosticsSummary.errors, 2)
        XCTAssertTrue(report.diagnostics.allSatisfy { $0.code.rawValue == "asset_cooker.conversion.unsupported" })
    }

    func testNonStrictValidationModeSucceedsOnExampleManifest() throws {
        let report = AssetCooker().cook(
            arguments: makeArguments(strict: false),
            repoRoot: try packageRoot()
        )

        XCTAssertTrue(report.success)
        XCTAssertEqual(report.diagnosticsSummary.errors, 0)
        XCTAssertEqual(report.descriptors.map(\.id.rawValue), [
            "debug.material.grid",
            "debug.mesh.grid",
        ])
    }

    private func makeArguments(strict: Bool = false) -> AssetCookerArguments {
        AssetCookerArguments(
            manifestPath: "Assets/Manifests/assets.json",
            outputPath: "Assets/Cooked",
            strict: strict
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
}
