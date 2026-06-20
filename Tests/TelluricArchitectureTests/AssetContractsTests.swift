import Foundation
import TelluricAssets
import XCTest

final class AssetContractsTests: XCTestCase {
    func testAssetIDRoundTripsThroughCodable() throws {
        let id = AssetID("debug.mesh.grid")

        XCTAssertEqual(try roundTrip(id), id)
    }

    func testAssetManifestValidJSONDecodesAndEncodes() throws {
        let json = """
        {
          "version": 1,
          "entries": [
            {
              "id": "debug.mesh.grid",
              "kind": "mesh",
              "sourcePath": "Assets/Source/debug/debug_mesh.mesh.json",
              "cookedPath": "Assets/Cooked/debug/debug_mesh.mesh.cooked.json"
            }
          ]
        }
        """
        let manifest = try JSONDecoder().decode(AssetManifest.self, from: Data(json.utf8))
        let encoded = try AssetCookerTestJSON.encoder.encode(manifest)
        let decoded = try JSONDecoder().decode(AssetManifest.self, from: encoded)

        XCTAssertEqual(decoded, manifest)
        XCTAssertTrue(AssetManifestValidation.validate(manifest: manifest).isSuccess)
    }

    func testDuplicateAssetIDsAreDetected() {
        let manifest = AssetManifest(version: .supported, entries: [
            makeEntry(id: "debug.mesh.grid"),
            makeEntry(id: "debug.mesh.grid", sourcePath: "Assets/Source/debug/other.mesh.json"),
        ])
        let report = AssetManifestValidation.validate(manifest: manifest)

        XCTAssertTrue(report.issues.contains { $0.code.rawValue == "assets.entry.duplicate_id" })
        XCTAssertTrue(report.hasErrors)
    }

    func testEmptyAssetIDIsDetected() {
        let manifest = AssetManifest(version: .supported, entries: [
            makeEntry(id: ""),
        ])
        let report = AssetManifestValidation.validate(manifest: manifest)

        XCTAssertTrue(report.issues.contains { $0.code.rawValue == "assets.entry.empty_id" })
        XCTAssertTrue(report.hasErrors)
    }

    func testAbsoluteSourcePathIsRejected() {
        let manifest = AssetManifest(version: .supported, entries: [
            makeEntry(sourcePath: "/Assets/Source/debug/debug_mesh.mesh.json"),
        ])
        let report = AssetManifestValidation.validate(manifest: manifest)

        XCTAssertTrue(report.issues.contains { $0.code.rawValue == "assets.path.source.absolute" })
        XCTAssertTrue(report.hasErrors)
    }

    func testPathTraversalIsRejected() {
        let manifest = AssetManifest(version: .supported, entries: [
            makeEntry(sourcePath: "Assets/Source/../debug/debug_mesh.mesh.json"),
        ])
        let report = AssetManifestValidation.validate(manifest: manifest)

        XCTAssertTrue(report.issues.contains { $0.code.rawValue == "assets.path.source.traversal" })
        XCTAssertTrue(report.hasErrors)
    }

    func testSourcePathOutsideAssetsSourceIsRejected() {
        let manifest = AssetManifest(version: .supported, entries: [
            makeEntry(sourcePath: "Assets/Other/debug_mesh.mesh.json"),
        ])
        let report = AssetManifestValidation.validate(manifest: manifest)

        XCTAssertTrue(report.issues.contains { $0.code.rawValue == "assets.path.source.outside_root" })
        XCTAssertTrue(report.hasErrors)
    }

    func testCookedPathOutsideAssetsCookedIsRejected() {
        let manifest = AssetManifest(version: .supported, entries: [
            makeEntry(cookedPath: "Assets/Output/debug_mesh.mesh.cooked.json"),
        ])
        let report = AssetManifestValidation.validate(manifest: manifest)

        XCTAssertTrue(report.issues.contains { $0.code.rawValue == "assets.path.cooked.outside_root" })
        XCTAssertTrue(report.hasErrors)
    }

    func testUnsupportedAssetKindIsDetected() {
        let manifest = AssetManifest(version: .supported, entries: [
            makeEntry(kind: AssetKind("unsupportedKind")),
        ])
        let report = AssetManifestValidation.validate(manifest: manifest)

        XCTAssertTrue(report.issues.contains { $0.code.rawValue == "assets.entry.unsupported_kind" })
        XCTAssertTrue(report.hasErrors)
    }

    func testAssetValidationReportEncodesAndDecodes() throws {
        let report = AssetManifestValidation.validate(manifest: AssetManifest(version: .supported, entries: [
            makeEntry(sourcePath: "Assets/Other/debug_mesh.mesh.json"),
        ]))

        XCTAssertEqual(try roundTrip(report), report)
    }

    private func makeEntry(
        id: String = "debug.mesh.grid",
        kind: AssetKind = .mesh,
        sourcePath: String = "Assets/Source/debug/debug_mesh.mesh.json",
        cookedPath: String = "Assets/Cooked/debug/debug_mesh.mesh.cooked.json"
    ) -> AssetManifestEntry {
        AssetManifestEntry(
            id: AssetID(id),
            kind: kind,
            sourcePath: AssetPath(sourcePath),
            cookedPath: AssetPath(cookedPath)
        )
    }

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try AssetCookerTestJSON.encoder.encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum AssetCookerTestJSON {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
