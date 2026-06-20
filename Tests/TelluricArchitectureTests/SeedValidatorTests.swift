import Foundation
import TelluricSeedValidatorCore
import XCTest

final class SeedValidatorTests: XCTestCase {
    func testCLIParserAcceptsValidArguments() throws {
        let arguments = try SeedValidatorArgumentParser.parse([
            "--seed", "12345",
            "--radius", "2",
            "--chunk-size", "32",
            "--vertical-scale", "12",
            "--report", "Tools/benchmarks/seed_12345.json",
            "--fail-fast",
            "--verbose",
        ])

        XCTAssertEqual(arguments.seed, 12345)
        XCTAssertEqual(arguments.radius, 2)
        XCTAssertEqual(arguments.chunkSize, 32)
        XCTAssertEqual(arguments.verticalScale, 12)
        XCTAssertEqual(arguments.reportPath, "Tools/benchmarks/seed_12345.json")
        XCTAssertTrue(arguments.failFast)
        XCTAssertTrue(arguments.verbose)
    }

    func testCLIParserRejectsInvalidRadius() {
        XCTAssertThrowsError(try SeedValidatorArgumentParser.parse([
            "--seed", "1",
            "--radius", "-1",
            "--chunk-size", "16",
            "--vertical-scale", "8",
        ])) { error in
            guard let parserError = error as? SeedValidatorArgumentError else {
                XCTFail("Expected invalid radius error, got \(error)")
                return
            }

            guard case .invalidValue(option: "--radius", value: "-1", reason: _) = parserError else {
                XCTFail("Expected invalid radius error, got \(parserError)")
                return
            }
        }
    }

    func testCLIParserRejectsInvalidChunkSize() {
        XCTAssertThrowsError(try SeedValidatorArgumentParser.parse([
            "--seed", "1",
            "--radius", "1",
            "--chunk-size", "0",
            "--vertical-scale", "8",
        ])) { error in
            guard let parserError = error as? SeedValidatorArgumentError else {
                XCTFail("Expected invalid chunk size error, got \(error)")
                return
            }

            guard case .invalidValue(option: "--chunk-size", value: "0", reason: _) = parserError else {
                XCTFail("Expected invalid chunk size error, got \(parserError)")
                return
            }
        }
    }

    func testCLIParserSupportsHelpWithoutRequiredArguments() throws {
        let arguments = try SeedValidatorArgumentParser.parse(["--help"])

        XCTAssertTrue(arguments.help)
        XCTAssertTrue(SeedValidatorHelp.text.contains("telluric-seed-validator"))
    }

    func testReportEncodesAndDecodesJSON() throws {
        let report = SeedValidator().validate(arguments: makeArguments(seed: 1, radius: 1))
        let data = try SeedValidator.jsonEncoder().encode(report)
        let decoded = try JSONDecoder().decode(SeedValidationReport.self, from: data)

        XCTAssertEqual(decoded, report)
    }

    func testSameSeedConfigAndRadiusProduceSameOrderedChunkHashes() {
        let first = SeedValidator().validate(arguments: makeArguments(seed: 7, radius: 1))
        let second = SeedValidator().validate(arguments: makeArguments(seed: 7, radius: 1))

        XCTAssertEqual(first.chunkResults.map(\.chunkCoord), second.chunkResults.map(\.chunkCoord))
        XCTAssertEqual(first.chunkResults.map(\.stableHash), second.chunkResults.map(\.stableHash))
        XCTAssertEqual(first.rootHash, second.rootHash)
    }

    func testDifferentSeedChangesAtLeastOneChunkHashInSmallGrid() {
        let first = SeedValidator().validate(arguments: makeArguments(seed: 7, radius: 1))
        let second = SeedValidator().validate(arguments: makeArguments(seed: 8, radius: 1))
        let changed = zip(first.chunkResults, second.chunkResults).contains { lhs, rhs in
            lhs.stableHash != rhs.stableHash
        }

        XCTAssertTrue(changed)
    }

    func testValidatorSucceedsForSmallValidGrid() {
        let report = SeedValidator().validate(arguments: makeArguments(seed: 1, radius: 1))

        XCTAssertTrue(report.success)
        XCTAssertEqual(report.totalChunks, 9)
        XCTAssertEqual(report.chunksGenerated, 9)
        XCTAssertEqual(report.validChunks, 9)
        XCTAssertEqual(report.invalidChunks, 0)
        XCTAssertNotNil(report.rootHash)
        XCTAssertTrue(report.chunkResults.allSatisfy(\.isValid))
    }

    func testFailFastStopsAfterFirstGenerationFailure() {
        let report = SeedValidator().validate(arguments: SeedValidatorArguments(
            seed: 1,
            radius: 2,
            chunkSize: 0,
            verticalScale: 8,
            failFast: true
        ))

        XCTAssertFalse(report.success)
        XCTAssertEqual(report.totalChunks, 25)
        XCTAssertEqual(report.chunksGenerated, 0)
        XCTAssertEqual(report.invalidChunks, 1)
        XCTAssertEqual(report.chunkResults.count, 1)
        XCTAssertEqual(report.diagnosticsSummary.errors, 1)
    }

    private func makeArguments(seed: UInt64, radius: Int) -> SeedValidatorArguments {
        SeedValidatorArguments(
            seed: seed,
            radius: radius,
            chunkSize: 8,
            verticalScale: 16
        )
    }
}
