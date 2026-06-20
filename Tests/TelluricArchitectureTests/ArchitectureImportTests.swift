import Foundation
import TelluricAssetCookerCore
import TelluricAssets
import TelluricBiomes
import TelluricCore
import TelluricDeterminism
import TelluricDiagnostics
import TelluricECS
import TelluricMath
import TelluricPersistence
import TelluricRender
import TelluricRenderExtraction
import TelluricRuntime
import TelluricSeedValidatorCore
import TelluricSimulation
import TelluricStreaming
import TelluricTerrain
import TelluricWorld
import XCTest

final class ArchitectureImportTests: XCTestCase {
    func testPhase0LibraryTargetsImportTogether() {
        XCTAssertTrue(true)
    }

    func testForbiddenSourceImportsAreAbsent() throws {
        let root = try packageRoot()
        let sources = root.appendingPathComponent("Sources")
        let forbiddenImports = [
            "SwiftUI",
            "AppKit",
            "Metal",
            "MetalKit",
            "AVFoundation",
            "CoreAudio",
            "GameplayKit",
        ]

        try assertNoSwiftSourceLine(
            under: sources,
            containsAnyImportOf: forbiddenImports
        )
    }

    func testDeterministicAndProceduralModulesDoNotUseUnstableApis() throws {
        let root = try packageRoot()
        let moduleNames = [
            "TelluricDeterminism",
            "TelluricECS",
            "TelluricSimulation",
            "TelluricWorld",
            "TelluricTerrain",
            "TelluricBiomes",
            "TelluricStreaming",
            "TelluricRuntime",
            "TelluricRender",
            "TelluricRenderExtraction",
        ]
        let forbiddenTokens = [
            "random(in:",
            "UUID()",
            "Date()",
        ]

        for moduleName in moduleNames {
            let moduleURL = root.appendingPathComponent("Sources").appendingPathComponent(moduleName)
            try assertNoSwiftSourceLine(under: moduleURL, containsAny: forbiddenTokens)
        }
    }

    func testEngineModulesDoNotImportRenderExtractionBridge() throws {
        let root = try packageRoot()
        let moduleNames = [
            "TelluricCore",
            "TelluricMath",
            "TelluricDeterminism",
            "TelluricDiagnostics",
            "TelluricECS",
            "TelluricSimulation",
            "TelluricWorld",
            "TelluricTerrain",
            "TelluricBiomes",
            "TelluricStreaming",
            "TelluricAssets",
            "TelluricPersistence",
            "TelluricRuntime",
            "TelluricRender",
        ]

        for moduleName in moduleNames {
            let moduleURL = root.appendingPathComponent("Sources").appendingPathComponent(moduleName)
            try assertNoSwiftSourceLine(under: moduleURL, containsAnyImportOf: ["TelluricRenderExtraction"])
        }
    }

    func testEngineModulesDoNotImportAssetCookerTargets() throws {
        let root = try packageRoot()
        let moduleNames = [
            "TelluricCore",
            "TelluricMath",
            "TelluricDeterminism",
            "TelluricDiagnostics",
            "TelluricECS",
            "TelluricSimulation",
            "TelluricWorld",
            "TelluricTerrain",
            "TelluricBiomes",
            "TelluricStreaming",
            "TelluricAssets",
            "TelluricPersistence",
            "TelluricRuntime",
            "TelluricRender",
            "TelluricRenderExtraction",
        ]

        for moduleName in moduleNames {
            let moduleURL = root.appendingPathComponent("Sources").appendingPathComponent(moduleName)
            try assertNoSwiftSourceLine(
                under: moduleURL,
                containsAnyImportOf: ["TelluricAssetCooker", "TelluricAssetCookerCore"]
            )
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

    private func assertNoSwiftSourceLine(under root: URL, containsAny tokens: [String], file: StaticString = #filePath, line: UInt = #line) throws {
        for sourceFile in try swiftFiles(under: root) {
            let contents = try String(contentsOf: sourceFile, encoding: .utf8)
            for sourceLine in contents.components(separatedBy: .newlines) {
                for token in tokens where sourceLine.contains(token) {
                    XCTFail("Forbidden token \(token) found in \(sourceFile.path)", file: file, line: line)
                }
            }
        }
    }

    private func assertNoSwiftSourceLine(under root: URL, containsAnyImportOf modules: [String], file: StaticString = #filePath, line: UInt = #line) throws {
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
