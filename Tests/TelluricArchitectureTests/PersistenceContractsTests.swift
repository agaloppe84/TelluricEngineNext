import Foundation
import TelluricAssetCookerCore
import TelluricCore
import TelluricDiagnostics
import TelluricECS
import TelluricMath
import TelluricPersistence
import TelluricRender
import TelluricRuntime
import TelluricSeedValidatorCore
import TelluricSimulation
import TelluricStreaming
import TelluricWorld
import XCTest

final class PersistenceContractsTests: XCTestCase {
    func testPersistenceFormatVersionRoundTripsThroughCodable() throws {
        let version = PersistenceFormatVersion(rawValue: 1)

        XCTAssertEqual(try roundTrip(version), version)
    }

    func testEnvelopeRoundTripsThroughCodable() throws {
        let snapshot = makeSimulationSnapshot()
        let envelope = try PersistenceEnvelope(
            schemaID: PersistenceSchemaID("telluric.tests.simulation.snapshot"),
            engineVersion: engineVersion,
            kind: .snapshot,
            metadata: [
                PersistenceMetadataEntry(key: "profile", value: "persistence.tests"),
            ],
            payload: snapshot
        )

        let decoded: PersistenceEnvelope<SimulationSnapshot> = try roundTrip(envelope)

        XCTAssertEqual(decoded, envelope)
        XCTAssertTrue(PersistenceValidation.validate(envelope: decoded).isValid)
    }

    func testRuntimeSnapshotCanBeWrappedInSnapshotPackageAndDecoded() throws {
        let snapshot = makeRuntimeSnapshot()
        let package = try SnapshotPackage(
            schemaID: PersistenceSchemaID("telluric.tests.runtime.snapshot"),
            engineVersion: engineVersion,
            payload: snapshot
        )

        let decoded: SnapshotPackage<RuntimeSnapshot> = try roundTrip(package)

        XCTAssertEqual(decoded.payload, snapshot)
        XCTAssertEqual(decoded, package)
        XCTAssertTrue(decoded.validate().isValid)
    }

    func testSimulationSnapshotCanBeWrappedAndDecoded() throws {
        let snapshot = makeSimulationSnapshot()
        let package = try SimulationSnapshotPackage(
            engineVersion: engineVersion,
            payload: snapshot
        )

        let decoded: SimulationSnapshotPackage = try roundTrip(package)

        XCTAssertEqual(decoded.payload, snapshot)
        XCTAssertTrue(decoded.validate().isValid)
    }

    func testReplayInputLogCanBeWrappedAndDecoded() throws {
        let log = ReplayInputLog(frames: [
            SimulationInputFrame(tick: .zero),
            SimulationInputFrame(
                tick: TickIndex(rawValue: 1),
                commands: [
                    .createEntity(entityID: EntityID(index: 1), components: []),
                ]
            ),
        ])
        let package = try ReplayInputLogPackage(
            engineVersion: engineVersion,
            payload: log
        )

        let decoded: ReplayInputLogPackage = try roundTrip(package)

        XCTAssertEqual(decoded.payload, log)
        XCTAssertTrue(decoded.validate().isValid)
    }

    func testRenderSnapshotCanBeWrappedAndDecoded() throws {
        let snapshot = makeRenderSnapshot()
        let package = try SnapshotPackage(
            schemaID: PersistenceSchemaID("telluric.tests.render.snapshot"),
            engineVersion: engineVersion,
            payload: snapshot
        )

        let decoded: SnapshotPackage<RenderSnapshot> = try roundTrip(package)

        XCTAssertEqual(decoded.payload, snapshot)
        XCTAssertTrue(decoded.validate().isValid)
    }

    func testSeedValidationReportCanBeWrappedAndDecoded() throws {
        let report = SeedValidator().validate(arguments: SeedValidatorArguments(
            seed: 1,
            radius: 0,
            chunkSize: 8,
            verticalScale: 16
        ))
        let package = try ReportPackage(
            schemaID: PersistenceSchemaID("telluric.tests.seed.validation.report"),
            engineVersion: engineVersion,
            payload: report
        )

        let decoded: ReportPackage<SeedValidationReport> = try roundTrip(package)

        XCTAssertEqual(decoded.payload, report)
        XCTAssertTrue(decoded.validate().isValid)
    }

    func testAssetCookerReportCanBeWrappedAndDecoded() throws {
        let report = AssetCooker().cook(
            arguments: AssetCookerArguments(
                manifestPath: "Assets/Manifests/assets.json",
                outputPath: "Assets/Cooked"
            ),
            repoRoot: try packageRoot()
        )
        let package = try ReportPackage(
            schemaID: PersistenceSchemaID("telluric.tests.asset.cooker.report"),
            engineVersion: engineVersion,
            payload: report
        )

        let decoded: ReportPackage<AssetCookerReport> = try roundTrip(package)

        XCTAssertEqual(decoded.payload, report)
        XCTAssertTrue(decoded.validate().isValid)
    }

    func testSamePackageProducesSameHash() throws {
        let payload = makeSimulationSnapshot()
        let first = try SimulationSnapshotPackage(engineVersion: engineVersion, payload: payload)
        let second = try SimulationSnapshotPackage(engineVersion: engineVersion, payload: payload)

        XCTAssertEqual(first.stableHash, second.stableHash)
        XCTAssertEqual(first.envelope.payloadHash, second.envelope.payloadHash)
    }

    func testMeaningfulPayloadChangeChangesHash() throws {
        let first = try SimulationSnapshotPackage(
            engineVersion: engineVersion,
            payload: makeSimulationSnapshot(tick: .zero)
        )
        let second = try SimulationSnapshotPackage(
            engineVersion: engineVersion,
            payload: makeSimulationSnapshot(tick: TickIndex(rawValue: 1))
        )

        XCTAssertNotEqual(first.stableHash, second.stableHash)
        XCTAssertNotEqual(first.envelope.payloadHash, second.envelope.payloadHash)
    }

    func testInvalidVersionIsReported() throws {
        let envelope = try PersistenceEnvelope(
            schemaID: .snapshotPackage,
            formatVersion: PersistenceFormatVersion(rawValue: 99),
            engineVersion: engineVersion,
            kind: .snapshot,
            payload: makeSimulationSnapshot()
        )

        let report = PersistenceValidation.validate(envelope: envelope)

        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.issues.contains { $0.code.rawValue == "persistence.format.unsupported_version" })
    }

    func testEmptySchemaIDIsReported() throws {
        let envelope = try PersistenceEnvelope(
            schemaID: PersistenceSchemaID(""),
            engineVersion: engineVersion,
            kind: .snapshot,
            payload: makeSimulationSnapshot()
        )

        let report = PersistenceValidation.validate(envelope: envelope)

        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.issues.contains { $0.code.rawValue == "persistence.schema.empty" })
    }

    func testMetadataOrderingIsPreserved() throws {
        let metadata = [
            PersistenceMetadataEntry(key: "z", value: "last"),
            PersistenceMetadataEntry(key: "a", value: "first"),
        ]
        let package = try SimulationSnapshotPackage(
            engineVersion: engineVersion,
            metadata: metadata,
            payload: makeSimulationSnapshot()
        )

        let decoded: SimulationSnapshotPackage = try roundTrip(package)

        XCTAssertEqual(decoded.envelope.metadata, metadata)
        XCTAssertEqual(decoded.envelope.metadata.map(\.key), ["z", "a"])
    }

    func testValidationReportEncodesAndDecodesJSON() throws {
        let report = PersistenceValidationReport(issues: [
            PersistenceValidationIssue(
                severity: .error,
                code: NamespaceID("persistence.tests.invalid"),
                message: "Invalid persistence package.",
                metadata: [
                    PersistenceMetadataEntry(key: "field", value: "schemaID"),
                ]
            ),
        ])

        XCTAssertEqual(try roundTrip(report), report)
        XCTAssertFalse(report.isValid)
    }

    func testDeterministicJSONOutputIsStableForSamePackage() throws {
        let package = try SimulationSnapshotPackage(
            engineVersion: engineVersion,
            metadata: [
                PersistenceMetadataEntry(key: "profile", value: "json.stability"),
            ],
            payload: makeSimulationSnapshot()
        )

        let first = try PersistenceJSONEncoder.encode(package)
        let second = try PersistenceJSONEncoder.encode(package)

        XCTAssertEqual(first, second)
    }

    private var engineVersion: EngineVersion {
        EngineVersion(major: 1, minor: 0, patch: 0)
    }

    private func makeSimulationSnapshot(tick: TickIndex = .zero) -> SimulationSnapshot {
        SimulationSnapshot(tick: tick, entities: EntitySnapshot(entities: []))
    }

    private func makeRuntimeSnapshot() -> RuntimeSnapshot {
        var runtime = TelluricRuntime(config: makeRuntimeConfig())
        let result = runtime.step(RuntimeStepInput(simulationInputFrame: SimulationInputFrame(tick: .zero)))
        XCTAssertTrue(result.success)
        return result.runtimeSnapshot
    }

    private func makeRuntimeConfig() -> RuntimeConfig {
        let worldConfig = WorldConfig(
            worldSeed: WorldSeed(rawValue: 1),
            chunkSize: 16,
            verticalScale: 8,
            generationProfile: NamespaceID("world.profile.persistence.tests")
        )
        let simulationConfig = SimulationConfig(
            engineVersion: engineVersion,
            tickRate: SimulationTickRate(ticksPerSecond: 1),
            initialTick: .zero,
            profile: NamespaceID("simulation.profile.persistence.tests")
        )

        return RuntimeConfig(
            worldConfig: worldConfig,
            engineVersion: engineVersion,
            simulationConfig: simulationConfig,
            streamingConfig: ChunkStreamingConfig(worldConfig: worldConfig, radius: 0),
            initialObservers: [
                StreamingObserver(
                    id: StreamingObserverID("observer.persistence.tests"),
                    worldPosition: .zero
                ),
            ]
        )
    }

    private func makeRenderSnapshot() -> RenderSnapshot {
        RenderSnapshot(
            engineVersion: engineVersion,
            frameIndex: .zero,
            camera: CameraSnapshot(
                id: NamespaceID("render.camera.persistence.tests"),
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
            debugLines: [
                DebugLine(start: .zero, end: Float3(x: 16, y: 0, z: 0), color: .red),
            ]
        )
    }

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try PersistenceJSONEncoder.encode(value)
        return try PersistenceJSONDecoder.decode(T.self, from: data)
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
