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

    func testDrawableFrameDescriptorRoundTripsThroughCodable() throws {
        let descriptor = makeDrawableDescriptor()

        XCTAssertEqual(try roundTrip(descriptor), descriptor)
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
            XCTAssertTrue(context.capabilities.supportsDebugLinePreparation)
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
        XCTAssertEqual(first.preparedDebugLineCount, 0)
        XCTAssertEqual(first.preparedDebugLineVertexCount, 0)
        XCTAssertEqual(first.preparedDebugLineBufferByteLength, 0)
        XCTAssertEqual(first.unsupportedDebugPointCount, 0)
        XCTAssertEqual(first.unsupportedDebugLabelCount, 0)
        XCTAssertEqual(first.success, backend.isAvailable)
    }

    func testCPUConversionOfOneDebugLineProducesTwoVertices() {
        let line = DebugLine(
            start: Float3(x: -1, y: 2, z: 3),
            end: Float3(x: 4, y: 5, z: -6),
            color: RenderColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 1)
        )

        let batch = MetalDebugLinePipeline.makeBatch(lines: [line])

        XCTAssertTrue(batch.success)
        XCTAssertEqual(batch.sourceLineCount, 1)
        XCTAssertEqual(batch.validLineCount, 1)
        XCTAssertEqual(batch.vertexCount, 2)
        XCTAssertEqual(batch.vertices[0].positionX, -1)
        XCTAssertEqual(batch.vertices[0].positionY, 2)
        XCTAssertEqual(batch.vertices[0].positionZ, 3)
        XCTAssertEqual(batch.vertices[1].positionX, 4)
        XCTAssertEqual(batch.vertices[1].positionY, 5)
        XCTAssertEqual(batch.vertices[1].positionZ, -6)
        XCTAssertEqual(batch.vertices[0].red, 0.25)
        XCTAssertEqual(batch.vertices[0].green, 0.5)
        XCTAssertEqual(batch.vertices[0].blue, 0.75)
        XCTAssertEqual(batch.vertices[0].alpha, 1)
        XCTAssertEqual(batch.vertices[1].red, 0.25)
        XCTAssertEqual(batch.vertices[1].green, 0.5)
        XCTAssertEqual(batch.vertices[1].blue, 0.75)
        XCTAssertEqual(batch.vertices[1].alpha, 1)
    }

    func testCPUConversionOfMultipleLinesPreservesDeterministicOrder() {
        let first = DebugLine(
            start: Float3(x: 10, y: 0, z: 0),
            end: Float3(x: 11, y: 0, z: 0),
            color: .red
        )
        let second = DebugLine(
            start: Float3(x: -3, y: 1, z: 2),
            end: Float3(x: -4, y: 1, z: 2),
            color: .green
        )

        let batch = MetalDebugLinePipeline.makeBatch(lines: [first, second])

        XCTAssertTrue(batch.success)
        XCTAssertEqual(batch.vertices.map(\.positionX), [10, 11, -3, -4])
        XCTAssertEqual(batch.vertices.map(\.red), [1, 1, 0, 0])
        XCTAssertEqual(batch.vertices.map(\.green), [0, 0, 1, 1])
    }

    func testInvalidDebugLineCoordinatesProduceDiagnostics() {
        let batch = MetalDebugLinePipeline.makeBatch(lines: [
            DebugLine(start: Float3(x: .nan, y: 0, z: 0), end: Float3(x: 1, y: 0, z: 0), color: .white),
            DebugLine(start: Float3(x: 0, y: 0, z: 0), end: Float3(x: .infinity, y: 0, z: 0), color: .white),
        ])

        XCTAssertFalse(batch.success)
        XCTAssertEqual(batch.sourceLineCount, 2)
        XCTAssertEqual(batch.validLineCount, 0)
        XCTAssertEqual(batch.vertexCount, 0)
        XCTAssertEqual(batch.diagnostics.count(.error), 2)
        XCTAssertTrue(batch.diagnostics.messages.allSatisfy {
            $0.code.rawValue == "render.metal.debug_line.invalid"
        })
    }

    func testEmptyDebugLineSetProducesEmptyBatchAndSucceeds() {
        let batch = MetalDebugLinePipeline.makeBatch(lines: [])
        let buffer = MetalDebugLinePipeline.makeBuffer(batch: batch, context: nil)

        XCTAssertTrue(batch.success)
        XCTAssertEqual(batch.sourceLineCount, 0)
        XCTAssertEqual(batch.vertexCount, 0)
        XCTAssertTrue(buffer.success)
        XCTAssertFalse(buffer.hasMetalBuffer)
        XCTAssertEqual(buffer.byteLength, 0)
        XCTAssertEqual(buffer.diagnostics.messages, [])
    }

    func testDebugLineRenderPipelineBuildsOrReportsCleanly() {
        switch MetalDeviceContext.makeResult() {
        case let .success(context):
            let pipeline = MetalDebugLineRenderPipeline.make(context: context, pixelFormat: .bgra8Unorm)

            XCTAssertTrue(pipeline.success)
            XCTAssertEqual(pipeline.diagnostics.messages, [])

        case .failure:
            let pipeline = MetalDebugLineRenderPipeline.make(context: nil, pixelFormat: .bgra8Unorm)

            XCTAssertFalse(pipeline.success)
            XCTAssertTrue(pipeline.diagnostics.messages.contains {
                $0.code.rawValue == "render.metal.debug_line.pipeline_unavailable"
            })
        }
    }

    func testDebugLineBufferCreationHandlesMetalAvailability() {
        let batch = MetalDebugLinePipeline.makeBatch(lines: [
            DebugLine(start: .zero, end: Float3(x: 1, y: 0, z: 0), color: .blue),
        ])

        switch MetalDeviceContext.makeResult() {
        case let .success(context):
            let buffer = MetalDebugLinePipeline.makeBuffer(batch: batch, context: context)

            XCTAssertTrue(buffer.success)
            XCTAssertTrue(buffer.hasMetalBuffer)
            XCTAssertEqual(buffer.validLineCount, 1)
            XCTAssertEqual(buffer.vertexCount, 2)
            XCTAssertGreaterThan(buffer.byteLength, 0)

        case .failure:
            let buffer = MetalDebugLinePipeline.makeBuffer(batch: batch, context: nil)

            XCTAssertFalse(buffer.success)
            XCTAssertFalse(buffer.hasMetalBuffer)
            XCTAssertEqual(buffer.validLineCount, 1)
            XCTAssertEqual(buffer.vertexCount, 2)
            XCTAssertGreaterThan(buffer.byteLength, 0)
            XCTAssertTrue(buffer.diagnostics.messages.contains {
                $0.code.rawValue == "render.metal.debug_line.buffer_unavailable"
            })
        }
    }

    func testRenderingSnapshotWithDebugPrimitivesPreparesDebugLinesAndReportsOtherUnsupportedDiagnostics() {
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
        XCTAssertEqual(result.unsupportedDebugLineCount, 0)
        XCTAssertEqual(result.preparedDebugLineCount, 1)
        XCTAssertEqual(result.preparedDebugLineVertexCount, 2)
        XCTAssertGreaterThan(result.preparedDebugLineBufferByteLength, 0)
        XCTAssertEqual(result.unsupportedDebugPointCount, 1)
        XCTAssertEqual(result.unsupportedDebugLabelCount, 1)
        XCTAssertTrue(diagnosticCodes.contains("render.metal.unsupported.renderable_instances"))
        XCTAssertTrue(diagnosticCodes.contains("render.metal.unsupported.texture_references"))
        XCTAssertFalse(diagnosticCodes.contains("render.metal.unsupported.debug_lines"))
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

    func testDrawableRenderPathReportsMissingDrawableCleanly() {
        let backend = MetalRenderBackend()
        let snapshot = makeSnapshot(debugLines: [
            DebugLine(start: .zero, end: Float3(x: 1, y: 0, z: 0), color: .white),
        ])

        let result = backend.renderDrawable(snapshot: snapshot, descriptor: makeDrawableDescriptor())
        let diagnosticCodes = result.diagnostics.messages.map(\.code.rawValue)

        XCTAssertFalse(result.success)
        XCTAssertFalse(result.presentedDrawable)
        XCTAssertEqual(result.renderSnapshotHash, snapshot.stableHash)
        XCTAssertEqual(result.preparedDebugLineCount, 1)
        XCTAssertEqual(result.preparedDebugLineVertexCount, 2)
        XCTAssertTrue(diagnosticCodes.contains("render.metal.drawable.missing"))
        XCTAssertTrue(diagnosticCodes.contains("render.metal.render_pass_descriptor.missing"))
    }

    func testEmptyDrawableDebugLinePassReportsClearMissingDrawableResult() {
        let backend = MetalRenderBackend()
        let snapshot = makeSnapshot()

        let result = backend.renderDrawable(snapshot: snapshot, descriptor: makeDrawableDescriptor())

        XCTAssertFalse(result.success)
        XCTAssertFalse(result.presentedDrawable)
        XCTAssertEqual(result.preparedDebugLineCount, 0)
        XCTAssertEqual(result.preparedDebugLineVertexCount, 0)
        XCTAssertTrue(result.diagnostics.messages.contains {
            $0.code.rawValue == "render.metal.drawable.missing"
        })
    }

    func testRenderRuntimeAndExtractionTargetsDoNotImportMetal() throws {
        let root = try packageRoot()
        for target in ["TelluricRender", "TelluricRuntime", "TelluricRenderExtraction"] {
            let source = root.appendingPathComponent("Sources").appendingPathComponent(target)
            try assertNoSwiftSourceLine(under: source, containsAnyImportOf: ["Metal", "MetalKit", "TelluricRenderMetal"])
        }
    }

    func testRenderMetalDoesNotImportAppWindowOrMetalKitFrameworks() throws {
        let root = try packageRoot()
        let source = root.appendingPathComponent("Sources").appendingPathComponent("TelluricRenderMetal")

        try assertNoSwiftSourceLine(
            under: source,
            containsAnyImportOf: ["MetalKit", "SwiftUI", "AppKit", "AVFoundation", "CoreAudio", "GameplayKit"]
        )
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

    private func makeDrawableDescriptor() -> MetalDrawableFrameDescriptor {
        MetalDrawableFrameDescriptor(
            frameIndex: .zero,
            viewportWidth: 64,
            viewportHeight: 64,
            debugLineProjection: MetalDebugLineProjection(
                centerX: 0,
                centerZ: 0,
                halfExtentX: 16,
                halfExtentZ: 16
            )
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
