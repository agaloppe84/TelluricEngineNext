import Foundation
import TelluricCore
import TelluricMath
import TelluricRender
import TelluricRenderMetal
import XCTest

final class MetalBackendTests: XCTestCase {
    func testTelluricRenderMetalCompiles() {
        let backend = MetalRenderBackend()

        XCTAssertEqual(backend.config.label, "telluric.render.metal")
    }

    func testBackendConfigRoundTripsThroughCodable() throws {
        let config = MetalRenderBackendConfig(
            label: "telluric.render.metal.tests",
            createsCommandQueue: false
        )

        XCTAssertEqual(try roundTrip(config), config)
    }

    func testCapabilitiesReportCanBeCreated() throws {
        let capabilities = MetalRenderBackendCapabilities.unavailable(reason: "No Metal device in test environment.")

        XCTAssertFalse(capabilities.isMetalAvailable)
        XCTAssertFalse(capabilities.hasCommandQueue)
        XCTAssertEqual(capabilities.unavailableReason, "No Metal device in test environment.")
        XCTAssertEqual(try roundTrip(capabilities), capabilities)
    }

    func testBackendReportsUnavailableGracefullyIfNoDeviceExists() {
        let backend = MetalRenderBackend()

        if backend.capabilities.isMetalAvailable {
            XCTAssertNotNil(backend.capabilities.deviceName)
            XCTAssertEqual(backend.initializationDiagnostics.messages, [])
        } else {
            XCTAssertFalse(backend.isAvailable)
            XCTAssertTrue(backend.initializationDiagnostics.hasErrors)
            XCTAssertTrue(backend.initializationDiagnostics.messages.contains {
                $0.code.rawValue == "render.metal.unavailable"
                    || $0.code.rawValue == "render.metal.command_queue_unavailable"
            })
        }
    }

    func testDeviceContextInitializesOrReturnsClearError() {
        let result = MetalDeviceContext.makeResult()

        switch result {
        case let .success(context):
            XCTAssertTrue(context.capabilities.isMetalAvailable)
            XCTAssertTrue(context.capabilities.hasCommandQueue)
            XCTAssertNotNil(context.capabilities.deviceName)

        case let .failure(error):
            XCTAssertTrue(
                error.code.rawValue == "render.metal.unavailable"
                    || error.code.rawValue == "render.metal.command_queue_unavailable"
            )
            XCTAssertFalse(error.message.isEmpty)
        }
    }

    func testRenderingEmptySnapshotProducesDeterministicExplicitResult() {
        let backend = MetalRenderBackend()
        let snapshot = makeSnapshot()

        let first = backend.render(snapshot: snapshot)
        let second = backend.render(snapshot: snapshot)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.renderSnapshotHash, snapshot.stableHash)
        XCTAssertEqual(first.unsupportedRenderableInstanceCount, 0)
        XCTAssertEqual(first.unsupportedTextureReferenceCount, 0)
        XCTAssertEqual(first.unsupportedDebugLineCount, 0)
        XCTAssertEqual(first.unsupportedDebugPointCount, 0)
        XCTAssertEqual(first.unsupportedDebugLabelCount, 0)
        XCTAssertEqual(first.success, backend.isAvailable)
    }

    func testRenderingSnapshotWithDebugPrimitivesReturnsUnsupportedDiagnostics() {
        let backend = MetalRenderBackend()
        let snapshot = makeSnapshot(
            instances: [
                RenderableInstance(
                    id: RenderableInstanceID("render.instance.metal.tests"),
                    mesh: MeshResourceID("mesh.debug.unit"),
                    material: MaterialResourceID("material.debug.unit"),
                    textures: [
                        TextureResourceID("texture.debug.albedo"),
                        TextureResourceID("texture.debug.normal"),
                    ],
                    transform: .identity
                ),
            ],
            debugLines: [
                DebugLine(start: .zero, end: Float3(x: 1, y: 0, z: 0), color: .red),
            ],
            debugPoints: [
                DebugPoint(position: .zero, color: .green),
            ],
            debugLabels: [
                DebugLabel(id: NamespaceID("debug.label.metal.tests"), text: "origin", position: .zero, color: .blue),
            ]
        )

        let result = backend.render(snapshot: snapshot)
        let diagnosticCodes = result.diagnostics.messages.map(\.code.rawValue)

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.unsupportedRenderableInstanceCount, 1)
        XCTAssertEqual(result.unsupportedTextureReferenceCount, 2)
        XCTAssertEqual(result.unsupportedDebugLineCount, 1)
        XCTAssertEqual(result.unsupportedDebugPointCount, 1)
        XCTAssertEqual(result.unsupportedDebugLabelCount, 1)
        XCTAssertTrue(diagnosticCodes.contains("render.metal.unsupported.renderable_instances"))
        XCTAssertTrue(diagnosticCodes.contains("render.metal.unsupported.texture_references"))
        XCTAssertTrue(diagnosticCodes.contains("render.metal.unsupported.debug_lines"))
        XCTAssertTrue(diagnosticCodes.contains("render.metal.unsupported.debug_points"))
        XCTAssertTrue(diagnosticCodes.contains("render.metal.unsupported.debug_labels"))
    }

    func testDrawablePresentationRequestReturnsUnsupportedDiagnostic() {
        let backend = MetalRenderBackend()
        let snapshot = makeSnapshot()
        let descriptor = MetalRenderFrameDescriptor(frameIndex: snapshot.frameIndex, requiresDrawable: true)

        let result = backend.render(snapshot: snapshot, descriptor: descriptor)

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.diagnostics.messages.contains {
            $0.code.rawValue == "render.metal.unsupported.drawable_presentation"
        })
    }

    func testRenderRuntimeAndExtractionTargetsDoNotImportMetal() throws {
        let root = try packageRoot()
        for target in ["TelluricRender", "TelluricRuntime", "TelluricRenderExtraction"] {
            let source = root.appendingPathComponent("Sources").appendingPathComponent(target)
            try assertNoSwiftSourceLine(under: source, containsAnyImportOf: ["Metal", "MetalKit", "TelluricRenderMetal"])
        }
    }

    private func makeSnapshot(
        instances: [RenderableInstance] = [],
        debugLines: [DebugLine] = [],
        debugPoints: [DebugPoint] = [],
        debugLabels: [DebugLabel] = []
    ) -> RenderSnapshot {
        RenderSnapshot(
            engineVersion: EngineVersion(major: 1, minor: 0, patch: 0),
            frameIndex: .zero,
            camera: CameraSnapshot(
                id: NamespaceID("render.camera.metal.tests"),
                transform: Transform(
                    translation: Float3(x: 0, y: 4, z: -8),
                    rotationRadians: Float3(x: 0.2, y: 0, z: 0),
                    scale: .one
                ),
                projection: .perspective(
                    verticalFieldOfViewRadians: 1.1,
                    nearClip: 0.1,
                    farClip: 1_000
                ),
                aspectRatio: 16 / 9
            ),
            instances: instances,
            debugLines: debugLines,
            debugPoints: debugPoints,
            debugLabels: debugLabels
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
