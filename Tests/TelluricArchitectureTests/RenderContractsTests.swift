import Foundation
import TelluricCore
import TelluricMath
import TelluricRender
import XCTest

final class RenderContractsTests: XCTestCase {
    func testResourceIDsRoundTripThroughCodable() throws {
        XCTAssertEqual(try roundTrip(RenderResourceID("render.resource.base")), RenderResourceID("render.resource.base"))
        XCTAssertEqual(try roundTrip(MeshResourceID("mesh.terrain.chunk")), MeshResourceID("mesh.terrain.chunk"))
        XCTAssertEqual(try roundTrip(MaterialResourceID("material.terrain.base")), MaterialResourceID("material.terrain.base"))
        XCTAssertEqual(try roundTrip(TextureResourceID("texture.terrain.albedo")), TextureResourceID("texture.terrain.albedo"))
    }

    func testCameraSnapshotRoundTripsThroughCodable() throws {
        let camera = makeCamera()

        XCTAssertEqual(try roundTrip(camera), camera)
    }

    func testRenderableInstanceRoundTripsThroughCodable() throws {
        let instance = makeInstance(id: "instance.a")

        XCTAssertEqual(try roundTrip(instance), instance)
    }

    func testDebugPrimitivesRoundTripThroughCodable() throws {
        let line = DebugLine(
            start: Float3(x: 0, y: 0, z: 0),
            end: Float3(x: 1, y: 0, z: 0),
            color: .red
        )
        let point = DebugPoint(
            position: Float3(x: 0, y: 1, z: 0),
            size: 2,
            color: .green
        )
        let label = DebugLabel(
            id: NamespaceID("debug.label.origin"),
            text: "origin",
            position: .zero,
            color: .blue
        )

        XCTAssertEqual(try roundTrip(line), line)
        XCTAssertEqual(try roundTrip(point), point)
        XCTAssertEqual(try roundTrip(label), label)
    }

    func testRenderSnapshotRoundTripsThroughCodable() throws {
        let snapshot = makeSnapshot()

        XCTAssertEqual(try roundTrip(snapshot), snapshot)
    }

    func testSameRenderSnapshotProducesSameStableHash() {
        let first = makeSnapshot()
        let second = makeSnapshot()

        XCTAssertEqual(first.stableHash, second.stableHash)
        XCTAssertEqual(RenderSnapshotHasher.hash(snapshot: first), first.stableHash)
    }

    func testMeaningfullyDifferentRenderSnapshotChangesHash() {
        let first = makeSnapshot()
        let second = RenderSnapshot(
            engineVersion: EngineVersion(major: 1, minor: 0, patch: 0),
            frameIndex: .zero,
            camera: makeCamera(),
            instances: [
                makeInstance(id: "instance.a", transform: Transform(translation: Float3(x: 2, y: 0, z: 0))),
            ],
            debugLines: [],
            debugPoints: [],
            debugLabels: []
        )

        XCTAssertNotEqual(first.stableHash, second.stableHash)
    }

    func testRenderSnapshotOrderingIsDeterministic() {
        let a = makeInstance(id: "instance.a")
        let b = makeInstance(id: "instance.b")
        let c = makeInstance(id: "instance.c")

        let snapshot = RenderSnapshot(
            engineVersion: EngineVersion(major: 1, minor: 0, patch: 0),
            frameIndex: .zero,
            camera: makeCamera(),
            instances: [c, a, b],
            debugLines: [
                DebugLine(start: Float3(x: 2, y: 0, z: 0), end: Float3(x: 3, y: 0, z: 0)),
                DebugLine(start: .zero, end: Float3(x: 1, y: 0, z: 0)),
            ],
            debugPoints: [
                DebugPoint(position: Float3(x: 2, y: 0, z: 0)),
                DebugPoint(position: Float3(x: 1, y: 0, z: 0)),
            ],
            debugLabels: [
                DebugLabel(id: NamespaceID("debug.label.b"), text: "b", position: .zero),
                DebugLabel(id: NamespaceID("debug.label.a"), text: "a", position: .zero),
            ]
        )

        XCTAssertEqual(snapshot.instances.map(\.id), [
            RenderableInstanceID("instance.a"),
            RenderableInstanceID("instance.b"),
            RenderableInstanceID("instance.c"),
        ])
        XCTAssertEqual(snapshot.debugLines.first?.start, .zero)
        XCTAssertEqual(snapshot.debugPoints.map(\.position), [
            Float3(x: 1, y: 0, z: 0),
            Float3(x: 2, y: 0, z: 0),
        ])
        XCTAssertEqual(snapshot.debugLabels.map(\.id.rawValue), [
            "debug.label.a",
            "debug.label.b",
        ])
    }

    func testTelluricRenderForbiddenImportsAreAbsent() throws {
        let root = try packageRoot()
        let renderSource = root
            .appendingPathComponent("Sources")
            .appendingPathComponent("TelluricRender")
        let forbiddenImports = [
            "TelluricRuntime",
            "TelluricRenderMetal",
            "Metal",
            "MetalKit",
            "SwiftUI",
            "AppKit",
        ]

        for sourceFile in try swiftFiles(under: renderSource) {
            let contents = try String(contentsOf: sourceFile, encoding: .utf8)
            for sourceLine in contents.components(separatedBy: .newlines) {
                let trimmedLine = sourceLine.trimmingCharacters(in: .whitespaces)
                for module in forbiddenImports where trimmedLine == "import \(module)" {
                    XCTFail("Forbidden TelluricRender import \(module) found in \(sourceFile.path)")
                }
            }
        }
    }

    private func makeSnapshot() -> RenderSnapshot {
        RenderSnapshot(
            engineVersion: EngineVersion(major: 1, minor: 0, patch: 0),
            frameIndex: .zero,
            camera: makeCamera(),
            instances: [makeInstance(id: "instance.a")],
            debugLines: [
                DebugLine(start: .zero, end: Float3(x: 1, y: 0, z: 0), color: .red),
            ],
            debugPoints: [
                DebugPoint(position: Float3(x: 0, y: 1, z: 0), color: .green),
            ],
            debugLabels: [
                DebugLabel(id: NamespaceID("debug.label.origin"), text: "origin", position: .zero, color: .blue),
            ]
        )
    }

    private func makeCamera() -> CameraSnapshot {
        CameraSnapshot(
            id: NamespaceID("render.camera.main"),
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
        )
    }

    private func makeInstance(
        id: String,
        transform: Transform = .identity
    ) -> RenderableInstance {
        RenderableInstance(
            id: RenderableInstanceID(id),
            mesh: MeshResourceID("mesh.terrain.chunk"),
            material: MaterialResourceID("material.terrain.base"),
            textures: [
                TextureResourceID("texture.terrain.normal"),
                TextureResourceID("texture.terrain.albedo"),
            ],
            transform: transform
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
