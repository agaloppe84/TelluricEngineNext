import Foundation
import TelluricCore
import TelluricECS
import TelluricMath
import TelluricRuntime
import TelluricSimulation
import TelluricStreaming
import TelluricWorld
import XCTest

final class RuntimeOrchestrationTests: XCTestCase {
    func testRuntimeInitializesWithValidConfig() {
        let runtime = TelluricRuntime(config: makeConfig(radius: 0))

        XCTAssertEqual(runtime.frameIndex, .zero)
        XCTAssertEqual(runtime.state().chunkRecords, [])
        XCTAssertEqual(runtime.state().simulationSnapshot.tick, .zero)
    }

    func testRuntimeReportsInvalidConfig() {
        var runtime = TelluricRuntime(config: makeConfig(chunkSize: 0, streamingChunkSize: 0))
        let result = runtime.step(RuntimeStepInput(simulationInputFrame: SimulationInputFrame(tick: .zero)))

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.diagnostics.hasErrors)
        XCTAssertTrue(result.diagnostics.messages.contains { $0.code.rawValue == "world.config.invalid_chunk_size" })
        XCTAssertTrue(result.diagnostics.messages.contains { $0.code.rawValue == "streaming.config.invalid_chunk_size" })
        XCTAssertEqual(runtime.state().chunkRecords, [])
    }

    func testInitialRuntimeStepWithRadiusZeroGeneratesOneResidentChunk() {
        var runtime = TelluricRuntime(config: makeConfig(radius: 0))
        let result = runtime.step(RuntimeStepInput(simulationInputFrame: SimulationInputFrame(tick: .zero)))

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.generatedChunkRecords.count, 1)
        XCTAssertEqual(result.runtimeSnapshot.state.chunkRecords.map(\.chunkCoord), [.zero])
        XCTAssertEqual(result.runtimeSnapshot.state.chunkRecords.map(\.residency), [.resident])
    }

    func testInitialRuntimeStepWithRadiusOneGeneratesNineResidentChunks() {
        var runtime = TelluricRuntime(config: makeConfig(radius: 1))
        let result = runtime.step(RuntimeStepInput(simulationInputFrame: SimulationInputFrame(tick: .zero)))

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.generatedChunkRecords.count, 9)
        XCTAssertEqual(result.runtimeSnapshot.state.chunkRecords.count, 9)
    }

    func testSameRuntimeConfigAndInputsProduceSameRuntimeHash() {
        let first = firstStep(seed: 7, radius: 1).stableHash
        let second = firstStep(seed: 7, radius: 1).stableHash

        XCTAssertEqual(first, second)
    }

    func testDifferentSeedChangesRuntimeHashForSameStepInput() {
        let first = firstStep(seed: 7, radius: 1).stableHash
        let second = firstStep(seed: 8, radius: 1).stableHash

        XCTAssertNotEqual(first, second)
    }

    func testMovingObserverChangesRequestKeepAndEvictBehavior() {
        var runtime = TelluricRuntime(config: makeConfig(radius: 0))
        XCTAssertTrue(runtime.step(RuntimeStepInput(simulationInputFrame: SimulationInputFrame(tick: .zero))).success)

        let movedObserver = StreamingObserver(
            id: StreamingObserverID("observer.main"),
            worldPosition: Int3(x: 16, y: 0, z: 0)
        )
        let result = runtime.step(RuntimeStepInput(
            simulationInputFrame: SimulationInputFrame(tick: TickIndex(rawValue: 1)),
            observers: [movedObserver]
        ))

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.streamingPlan.chunksToRequest.map(\.chunkCoord), [
            ChunkCoord(x: 1, y: 0, z: 0),
        ])
        XCTAssertEqual(result.streamingPlan.chunksToKeep, [])
        XCTAssertEqual(result.streamingPlan.chunksToEvict.map(\.chunkCoord), [.zero])
        XCTAssertEqual(result.evictedChunkCoords, [.zero])
        XCTAssertEqual(result.runtimeSnapshot.state.chunkRecords.map(\.chunkCoord), [
            ChunkCoord(x: 1, y: 0, z: 0),
        ])
    }

    func testResidentDesiredChunksAreKeptAcrossSteps() {
        var runtime = TelluricRuntime(config: makeConfig(radius: 0))
        XCTAssertTrue(runtime.step(RuntimeStepInput(simulationInputFrame: SimulationInputFrame(tick: .zero))).success)

        let result = runtime.step(RuntimeStepInput(
            simulationInputFrame: SimulationInputFrame(tick: TickIndex(rawValue: 1))
        ))

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.streamingPlan.chunksToRequest, [])
        XCTAssertEqual(result.streamingPlan.chunksToKeep.map(\.chunkCoord), [.zero])
        XCTAssertEqual(result.streamingPlan.chunksToEvict, [])
        XCTAssertEqual(result.generatedChunkRecords, [])
        XCTAssertEqual(result.runtimeSnapshot.state.chunkRecords.map(\.chunkCoord), [.zero])
    }

    func testUndesiredChunksAreEvictedAfterObserverMovement() {
        var runtime = TelluricRuntime(config: makeConfig(radius: 0))
        XCTAssertTrue(runtime.step(RuntimeStepInput(simulationInputFrame: SimulationInputFrame(tick: .zero))).success)

        let movedObserver = StreamingObserver(
            id: StreamingObserverID("observer.main"),
            worldPosition: Int3(x: 16, y: 0, z: 0)
        )
        let result = runtime.step(RuntimeStepInput(
            simulationInputFrame: SimulationInputFrame(tick: TickIndex(rawValue: 1)),
            observers: [movedObserver]
        ))

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.evictedChunkCoords, [.zero])
        XCTAssertEqual(runtime.state().chunkRecords.map(\.chunkCoord), [
            ChunkCoord(x: 1, y: 0, z: 0),
        ])
    }

    func testSimulationStepIsIncludedInRuntimeStepResult() {
        let entityID = EntityID(index: 1)
        var runtime = TelluricRuntime(config: makeConfig(radius: 0))
        let result = runtime.step(RuntimeStepInput(
            simulationInputFrame: SimulationInputFrame(tick: .zero, commands: [
                .createEntity(entityID: entityID, components: [
                    .position(PositionComponent(.zero)),
                ]),
            ])
        ))

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.simulationSnapshot.tick, TickIndex(rawValue: 1))
        XCTAssertNotNil(result.simulationSnapshot.entities.record(for: entityID))
        XCTAssertEqual(runtime.state().simulationSnapshot, result.simulationSnapshot)
    }

    func testInvalidSimulationTickOrderIsReportedAndDoesNotAdvanceRuntime() {
        var runtime = TelluricRuntime(config: makeConfig(radius: 0))
        let result = runtime.step(RuntimeStepInput(
            simulationInputFrame: SimulationInputFrame(tick: TickIndex(rawValue: 1))
        ))

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.diagnostics.messages.contains { $0.code.rawValue == "simulation.input.invalid_tick" })
        XCTAssertEqual(result.runtimeSnapshot.state.frameIndex, .zero)
        XCTAssertEqual(result.runtimeSnapshot.state.simulationSnapshot.tick, .zero)
        XCTAssertEqual(runtime.state().frameIndex, .zero)
        XCTAssertEqual(runtime.state().chunkRecords, [])
    }

    func testRuntimeSnapshotEncodesAndDecodesJSON() throws {
        let snapshot = firstStep(seed: 7, radius: 1).runtimeSnapshot

        XCTAssertEqual(try roundTrip(snapshot), snapshot)
    }

    func testRuntimeChunkRecordsAreOrderedDeterministically() {
        let result = firstStep(seed: 7, radius: 1)
        let coords = result.runtimeSnapshot.state.chunkRecords.map(\.chunkCoord)

        XCTAssertEqual(coords, coords.sorted())
    }

    private func firstStep(seed: UInt64, radius: Int) -> RuntimeStepResult {
        var runtime = TelluricRuntime(config: makeConfig(seed: seed, radius: radius))
        return runtime.step(RuntimeStepInput(simulationInputFrame: SimulationInputFrame(tick: .zero)))
    }

    private func makeConfig(
        seed: UInt64 = 1,
        radius: Int = 0,
        chunkSize: Int = 16,
        streamingChunkSize: Int? = nil
    ) -> RuntimeConfig {
        let engineVersion = EngineVersion(major: 1, minor: 0, patch: 0)
        let worldConfig = WorldConfig(
            worldSeed: WorldSeed(rawValue: seed),
            chunkSize: chunkSize,
            verticalScale: 8,
            generationProfile: NamespaceID("world.profile.runtime.tests")
        )
        let simulationConfig = SimulationConfig(
            engineVersion: engineVersion,
            tickRate: SimulationTickRate(ticksPerSecond: 1),
            initialTick: .zero,
            profile: NamespaceID("simulation.profile.runtime.tests")
        )

        return RuntimeConfig(
            worldConfig: worldConfig,
            engineVersion: engineVersion,
            simulationConfig: simulationConfig,
            streamingConfig: ChunkStreamingConfig(
                chunkSize: streamingChunkSize ?? chunkSize,
                radius: radius
            ),
            initialObservers: [
                StreamingObserver(
                    id: StreamingObserverID("observer.main"),
                    worldPosition: .zero
                ),
            ]
        )
    }

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
