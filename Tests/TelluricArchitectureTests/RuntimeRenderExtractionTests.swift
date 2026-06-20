import Foundation
import TelluricCore
import TelluricMath
import TelluricRender
import TelluricRenderExtraction
import TelluricRuntime
import TelluricSimulation
import TelluricStreaming
import TelluricWorld
import XCTest

final class RuntimeRenderExtractionTests: XCTestCase {
    func testRadiusZeroExtractsOneChunkBoundaryDebugGroup() {
        let snapshot = runtimeSnapshot(radius: 0)
        let result = RuntimeRenderExtractor().extract(
            from: snapshot,
            config: makeExtractionConfig(includeLabels: true)
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.renderSnapshot.debugLines.count, 4)
        XCTAssertEqual(result.renderSnapshot.debugLabels.map(\.text), [
            "chunk(0,0,0)",
        ])
        XCTAssertEqual(result.renderSnapshot.instances, [])
    }

    func testRadiusOneExtractsNineChunkBoundaryDebugGroups() {
        let snapshot = runtimeSnapshot(radius: 1)
        let result = RuntimeRenderExtractor().extract(
            from: snapshot,
            config: makeExtractionConfig(includeLabels: true)
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.renderSnapshot.debugLines.count, 36)
        XCTAssertEqual(result.renderSnapshot.debugLabels.count, 9)
    }

    func testDefaultDebugVisualOptionsAddDeterministicPolishLines() {
        let config = RuntimeRenderExtractionConfig(camera: makeCamera())
        let result = RuntimeRenderExtractor().extract(
            from: runtimeSnapshot(radius: 1),
            config: config
        )

        XCTAssertTrue(result.success)
        XCTAssertTrue(config.includeChunkBoundaryLines)
        XCTAssertTrue(config.includeWorldAxes)
        XCTAssertTrue(config.includeOriginMarker)
        XCTAssertFalse(config.includeChunkCenterCrosses)
        XCTAssertTrue(config.includeCentralChunkHighlight)
        XCTAssertTrue(config.includeStreamingRadiusBounds)
        XCTAssertEqual(result.renderSnapshot.debugLines.count, 48)
        XCTAssertTrue(result.renderSnapshot.debugLines.contains { $0.color == .debugXAxis })
        XCTAssertTrue(result.renderSnapshot.debugLines.contains { $0.color == .debugZAxis })
        XCTAssertTrue(result.renderSnapshot.debugLines.contains { $0.color == .debugOrigin })
        XCTAssertTrue(result.renderSnapshot.debugLines.contains { $0.color == .debugCentralChunk })
        XCTAssertTrue(result.renderSnapshot.debugLines.contains { $0.color == .debugStreamingRadius })
    }

    func testTogglingAxesChangesRenderSnapshotHashAndLineCount() {
        let snapshot = runtimeSnapshot(radius: 1)
        let defaultResult = RuntimeRenderExtractor().extract(
            from: snapshot,
            config: RuntimeRenderExtractionConfig(camera: makeCamera())
        )
        let noAxesResult = RuntimeRenderExtractor().extract(
            from: snapshot,
            config: RuntimeRenderExtractionConfig(camera: makeCamera(), includeWorldAxes: false)
        )

        XCTAssertEqual(defaultResult.renderSnapshot.debugLines.count, 48)
        XCTAssertEqual(noAxesResult.renderSnapshot.debugLines.count, 46)
        XCTAssertNotEqual(defaultResult.renderSnapshot.stableHash, noAxesResult.renderSnapshot.stableHash)
    }

    func testDisablingGridLeavesAxesAndOriginWhenEnabled() {
        let result = RuntimeRenderExtractor().extract(
            from: runtimeSnapshot(radius: 1),
            config: RuntimeRenderExtractionConfig(
                camera: makeCamera(),
                includeChunkBoundaryLines: false,
                includeWorldAxes: true,
                includeOriginMarker: true,
                includeCentralChunkHighlight: false,
                includeStreamingRadiusBounds: false
            )
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.renderSnapshot.debugLines.count, 4)
        XCTAssertTrue(result.renderSnapshot.debugLines.contains { $0.color == .debugXAxis })
        XCTAssertTrue(result.renderSnapshot.debugLines.contains { $0.color == .debugZAxis })
        XCTAssertEqual(result.renderSnapshot.debugLines.filter { $0.color == .debugOrigin }.count, 2)
    }

    func testCentralChunkHighlightAddsAccentBoundaryLines() {
        let withoutHighlight = RuntimeRenderExtractor().extract(
            from: runtimeSnapshot(radius: 1),
            config: RuntimeRenderExtractionConfig(
                camera: makeCamera(),
                includeChunkBoundaryLines: false,
                includeWorldAxes: false,
                includeOriginMarker: false,
                includeCentralChunkHighlight: false,
                includeStreamingRadiusBounds: false
            )
        )
        let withHighlight = RuntimeRenderExtractor().extract(
            from: runtimeSnapshot(radius: 1),
            config: RuntimeRenderExtractionConfig(
                camera: makeCamera(),
                includeChunkBoundaryLines: false,
                includeWorldAxes: false,
                includeOriginMarker: false,
                includeCentralChunkHighlight: true,
                includeStreamingRadiusBounds: false
            )
        )

        XCTAssertEqual(withoutHighlight.renderSnapshot.debugLines.count, 0)
        XCTAssertEqual(withHighlight.renderSnapshot.debugLines.count, 4)
        XCTAssertTrue(withHighlight.renderSnapshot.debugLines.allSatisfy { $0.color == .debugCentralChunk })
    }

    func testChunkCenterCrossesAddDeterministicLineMarkers() {
        let result = RuntimeRenderExtractor().extract(
            from: runtimeSnapshot(radius: 1),
            config: RuntimeRenderExtractionConfig(
                camera: makeCamera(),
                includeChunkBoundaryLines: false,
                includeWorldAxes: false,
                includeOriginMarker: false,
                includeChunkCenterCrosses: true,
                includeCentralChunkHighlight: false,
                includeStreamingRadiusBounds: false
            )
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.renderSnapshot.debugLines.count, 18)
        XCTAssertTrue(result.renderSnapshot.debugLines.allSatisfy { $0.color == .debugChunkCenter })
        XCTAssertEqual(result.renderSnapshot.debugLines, result.renderSnapshot.debugLines.sorted())
    }

    func testDebugVisualColorsAreFixed() {
        XCTAssertEqual(RenderColor.debugChunkBoundary, RenderColor(red: 0.46, green: 0.50, blue: 0.56, alpha: 1))
        XCTAssertEqual(RenderColor.debugXAxis, RenderColor(red: 1.0, green: 0.18, blue: 0.12, alpha: 1))
        XCTAssertEqual(RenderColor.debugZAxis, RenderColor(red: 0.12, green: 0.48, blue: 1.0, alpha: 1))
        XCTAssertEqual(RenderColor.debugOrigin, RenderColor(red: 1.0, green: 0.92, blue: 0.20, alpha: 1))
        XCTAssertEqual(RenderColor.debugCentralChunk, RenderColor(red: 0.30, green: 1.0, blue: 0.44, alpha: 1))
        XCTAssertEqual(RenderColor.debugStreamingRadius, RenderColor(red: 0.74, green: 0.48, blue: 1.0, alpha: 1))
    }

    func testSameRuntimeSnapshotProducesSameRenderSnapshotHash() {
        let snapshot = runtimeSnapshot(radius: 1)
        let config = makeExtractionConfig(includeLabels: true, includeCenterPoints: true)
        let first = RuntimeRenderExtractor().extract(from: snapshot, config: config)
        let second = RuntimeRenderExtractor().extract(from: snapshot, config: config)

        XCTAssertEqual(first.renderSnapshot.stableHash, second.renderSnapshot.stableHash)
        XCTAssertEqual(RenderSnapshotHasher.hash(snapshot: first.renderSnapshot), first.renderSnapshot.stableHash)
    }

    func testSameRuntimeConfigInputsAndExtractionConfigProduceSameRenderSnapshot() {
        let first = RuntimeRenderExtractor().extract(
            from: runtimeSnapshot(radius: 1),
            config: makeExtractionConfig(includeLabels: true)
        )
        let second = RuntimeRenderExtractor().extract(
            from: runtimeSnapshot(radius: 1),
            config: makeExtractionConfig(includeLabels: true)
        )

        XCTAssertEqual(first.renderSnapshot, second.renderSnapshot)
    }

    func testMovingObserverChangesExtractedDebugChunkSet() {
        var runtime = TelluricRuntime(config: makeRuntimeConfig(radius: 0))
        let initial = runtime.step(RuntimeStepInput(simulationInputFrame: SimulationInputFrame(tick: .zero)))
        let initialExtraction = RuntimeRenderExtractor().extract(
            from: initial.runtimeSnapshot,
            config: makeExtractionConfig(includeLabels: true)
        )

        let movedObserver = StreamingObserver(
            id: StreamingObserverID("observer.main"),
            worldPosition: Int3(x: 16, y: 0, z: 0)
        )
        let moved = runtime.step(RuntimeStepInput(
            simulationInputFrame: SimulationInputFrame(tick: TickIndex(rawValue: 1)),
            observers: [movedObserver]
        ))
        let movedExtraction = RuntimeRenderExtractor().extract(
            from: moved.runtimeSnapshot,
            config: makeExtractionConfig(includeLabels: true)
        )

        XCTAssertEqual(initialExtraction.renderSnapshot.debugLabels.map(\.text), [
            "chunk(0,0,0)",
        ])
        XCTAssertEqual(movedExtraction.renderSnapshot.debugLabels.map(\.text), [
            "chunk(1,0,0)",
        ])
        XCTAssertNotEqual(initialExtraction.renderSnapshot.stableHash, movedExtraction.renderSnapshot.stableHash)
    }

    func testNegativeChunkCoordinatesProduceCorrectBoundaryPositions() {
        let snapshot = runtimeSnapshot(radius: 0, observerPosition: Int3(x: -1, y: 0, z: -1))
        let result = RuntimeRenderExtractor().extract(
            from: snapshot,
            config: makeExtractionConfig(includeLabels: true)
        )
        let endpoints = result.renderSnapshot.debugLines.flatMap { [$0.start, $0.end] }

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.renderSnapshot.debugLabels.map(\.text), [
            "chunk(-1,0,-1)",
        ])
        XCTAssertTrue(endpoints.contains(Float3(x: -16, y: 0, z: -16)))
        XCTAssertTrue(endpoints.contains(Float3(x: 0, y: 0, z: -16)))
        XCTAssertTrue(endpoints.contains(Float3(x: 0, y: 0, z: 0)))
        XCTAssertTrue(endpoints.contains(Float3(x: -16, y: 0, z: 0)))
    }

    func testDebugPrimitivesAreOrderedDeterministically() {
        let snapshot = runtimeSnapshot(radius: 1)
        let result = RuntimeRenderExtractor().extract(
            from: snapshot,
            config: makeExtractionConfig(includeLabels: true, includeCenterPoints: true)
        )

        XCTAssertEqual(result.renderSnapshot.debugLines, result.renderSnapshot.debugLines.sorted())
        XCTAssertEqual(result.renderSnapshot.debugPoints, result.renderSnapshot.debugPoints.sorted())
        XCTAssertEqual(result.renderSnapshot.debugLabels, result.renderSnapshot.debugLabels.sorted())
    }

    func testExtractionDoesNotMutateRuntimeState() {
        var runtime = TelluricRuntime(config: makeRuntimeConfig(radius: 0))
        XCTAssertTrue(runtime.step(RuntimeStepInput(simulationInputFrame: SimulationInputFrame(tick: .zero))).success)

        let before = runtime.snapshot().stableHash
        _ = RuntimeRenderExtractor().extract(
            from: runtime.snapshot(),
            config: makeExtractionConfig(includeLabels: true)
        )
        let after = runtime.snapshot().stableHash

        XCTAssertEqual(before, after)
    }

    func testRenderSnapshotFromExtractionEncodesAndDecodesJSON() throws {
        let result = RuntimeRenderExtractor().extract(
            from: runtimeSnapshot(radius: 1),
            config: makeExtractionConfig(includeLabels: true, includeCenterPoints: true)
        )

        XCTAssertEqual(try roundTrip(result.renderSnapshot), result.renderSnapshot)
    }

    func testTelluricRenderExtractionForbiddenImportsAreAbsent() throws {
        let root = try packageRoot()
        let source = root
            .appendingPathComponent("Sources")
            .appendingPathComponent("TelluricRenderExtraction")
        let forbiddenImports = [
            "TelluricRenderMetal",
            "Metal",
            "MetalKit",
            "SwiftUI",
            "AppKit",
            "AVFoundation",
            "CoreAudio",
            "GameplayKit",
        ]

        for sourceFile in try swiftFiles(under: source) {
            let contents = try String(contentsOf: sourceFile, encoding: .utf8)
            for sourceLine in contents.components(separatedBy: .newlines) {
                let trimmedLine = sourceLine.trimmingCharacters(in: .whitespaces)
                for module in forbiddenImports where trimmedLine == "import \(module)" {
                    XCTFail("Forbidden TelluricRenderExtraction import \(module) found in \(sourceFile.path)")
                }
            }
        }
    }

    private func runtimeSnapshot(
        radius: Int,
        observerPosition: Int3 = .zero,
        seed: UInt64 = 1
    ) -> RuntimeSnapshot {
        var runtime = TelluricRuntime(config: makeRuntimeConfig(
            seed: seed,
            radius: radius,
            observerPosition: observerPosition
        ))
        let result = runtime.step(RuntimeStepInput(simulationInputFrame: SimulationInputFrame(tick: .zero)))
        XCTAssertTrue(result.success)
        return result.runtimeSnapshot
    }

    private func makeRuntimeConfig(
        seed: UInt64 = 1,
        radius: Int = 0,
        chunkSize: Int = 16,
        observerPosition: Int3 = .zero
    ) -> RuntimeConfig {
        let engineVersion = EngineVersion(major: 1, minor: 0, patch: 0)
        let worldConfig = WorldConfig(
            worldSeed: WorldSeed(rawValue: seed),
            chunkSize: chunkSize,
            verticalScale: 8,
            generationProfile: NamespaceID("world.profile.render.extraction.tests")
        )
        let simulationConfig = SimulationConfig(
            engineVersion: engineVersion,
            tickRate: SimulationTickRate(ticksPerSecond: 1),
            initialTick: .zero,
            profile: NamespaceID("simulation.profile.render.extraction.tests")
        )

        return RuntimeConfig(
            worldConfig: worldConfig,
            engineVersion: engineVersion,
            simulationConfig: simulationConfig,
            streamingConfig: ChunkStreamingConfig(worldConfig: worldConfig, radius: radius),
            initialObservers: [
                StreamingObserver(
                    id: StreamingObserverID("observer.main"),
                    worldPosition: observerPosition
                ),
            ]
        )
    }

    private func makeExtractionConfig(
        includeLabels: Bool = false,
        includeCenterPoints: Bool = false
    ) -> RuntimeRenderExtractionConfig {
        RuntimeRenderExtractionConfig(
            camera: makeCamera(),
            includeChunkLabels: includeLabels,
            includeChunkCenterPoints: includeCenterPoints,
            includeWorldAxes: false,
            includeOriginMarker: false,
            includeChunkCenterCrosses: false,
            includeCentralChunkHighlight: false,
            includeStreamingRadiusBounds: false,
            boundaryColor: .white
        )
    }

    private func makeCamera() -> CameraSnapshot {
        CameraSnapshot(
            id: NamespaceID("render.camera.extraction.tests"),
            transform: Transform(
                translation: Float3(x: 0, y: 48, z: -48),
                rotationRadians: Float3(x: 0.7, y: 0, z: 0),
                scale: .one
            ),
            projection: .perspective(
                verticalFieldOfViewRadians: 1,
                nearClip: 0.1,
                farClip: 1_000
            ),
            aspectRatio: 16 / 9
        )
    }

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
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
