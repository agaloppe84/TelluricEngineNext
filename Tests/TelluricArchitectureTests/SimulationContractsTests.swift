import Foundation
import TelluricCore
import TelluricECS
import TelluricMath
import TelluricSimulation
import XCTest

final class SimulationContractsTests: XCTestCase {
    func testSameInputSequenceProducesIdenticalSimulationHashes() {
        let first = run(log: baselineLog())
        let second = run(log: baselineLog())

        XCTAssertEqual(first.map(\.snapshot.stableHash), second.map(\.snapshot.stableHash))
        XCTAssertEqual(first.last?.snapshot.stableHash, second.last?.snapshot.stableHash)
    }

    func testDifferentInputSequenceChangesSimulationHash() {
        let baseline = run(log: baselineLog()).last!.snapshot.stableHash
        let changed = run(log: ReplayInputLog(frames: [
            SimulationInputFrame(tick: .zero, commands: [
                .createEntity(entityID: entityA, components: [
                    .position(PositionComponent(.zero)),
                ]),
                .applyTranslation(entityID: entityA, translation: Float3(x: 2, y: 0, z: 0)),
            ]),
        ])).last!.snapshot.stableHash

        XCTAssertNotEqual(baseline, changed)
    }

    func testCommandOrderingIsStableAndMeaningful() {
        let setThenTranslate = run(log: ReplayInputLog(frames: [
            SimulationInputFrame(tick: .zero, commands: [
                .createEntity(entityID: entityA, components: []),
                .setPosition(entityID: entityA, position: PositionComponent(.zero)),
                .applyTranslation(entityID: entityA, translation: Float3(x: 1, y: 0, z: 0)),
            ]),
        ])).last!.snapshot
        let translateThenSet = run(log: ReplayInputLog(frames: [
            SimulationInputFrame(tick: .zero, commands: [
                .createEntity(entityID: entityA, components: []),
                .applyTranslation(entityID: entityA, translation: Float3(x: 1, y: 0, z: 0)),
                .setPosition(entityID: entityA, position: PositionComponent(.zero)),
            ]),
        ])).last!.snapshot

        XCTAssertNotEqual(setThenTranslate.stableHash, translateThenSet.stableHash)
        XCTAssertEqual(position(of: entityA, in: setThenTranslate), Float3(x: 1, y: 0, z: 0))
        XCTAssertEqual(position(of: entityA, in: translateThenSet), .zero)
    }

    func testSnapshotEntityOrderIsDeterministic() {
        let snapshot = run(log: ReplayInputLog(frames: [
            SimulationInputFrame(tick: .zero, commands: [
                .createEntity(entityID: EntityID(index: 10), components: []),
                .createEntity(entityID: EntityID(index: 2), components: []),
                .createEntity(entityID: EntityID(index: 7), components: []),
            ]),
        ])).last!.snapshot

        XCTAssertEqual(snapshot.entities.entities.map(\.id), [
            EntityID(index: 2),
            EntityID(index: 7),
            EntityID(index: 10),
        ])
    }

    func testReplayInputLogEncodesAndDecodesJSON() throws {
        let log = baselineLog()

        XCTAssertEqual(try roundTrip(log), log)
    }

    func testSimulationRejectsInvalidTickOrder() {
        var world = SimulationWorld(config: testConfig())
        let result = world.step(inputFrame: SimulationInputFrame(
            tick: TickIndex(rawValue: 1),
            commands: []
        ))

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.snapshot.tick, .zero)
        XCTAssertTrue(result.diagnostics.messages.contains { $0.code.rawValue == "simulation.input.invalid_tick" })
    }

    func testSimulationSnapshotEncodesAndDecodesJSON() throws {
        let snapshot = run(log: baselineLog()).last!.snapshot

        XCTAssertEqual(try roundTrip(snapshot), snapshot)
    }

    func testVelocityIntegratesOnFixedTick() {
        let snapshot = run(log: ReplayInputLog(frames: [
            SimulationInputFrame(tick: .zero, commands: [
                .createEntity(entityID: entityA, components: [
                    .position(PositionComponent(.zero)),
                    .velocity(VelocityComponent(Float3(x: 2, y: 0, z: 0))),
                ]),
            ]),
        ])).last!.snapshot

        XCTAssertEqual(position(of: entityA, in: snapshot), Float3(x: 2, y: 0, z: 0))
    }

    private let entityA = EntityID(index: 1)

    private func baselineLog() -> ReplayInputLog {
        ReplayInputLog(frames: [
            SimulationInputFrame(tick: .zero, commands: [
                .createEntity(entityID: entityA, components: [
                    .position(PositionComponent(.zero)),
                ]),
                .applyTranslation(entityID: entityA, translation: Float3(x: 1, y: 0, z: 0)),
            ]),
            SimulationInputFrame(tick: TickIndex(rawValue: 1), commands: [
                .applyTranslation(entityID: entityA, translation: Float3(x: 0, y: 0, z: 1)),
            ]),
        ])
    }

    private func run(log: ReplayInputLog) -> [SimulationStepResult] {
        var world = SimulationWorld(config: testConfig())
        return world.step(replayLog: log)
    }

    private func testConfig() -> SimulationConfig {
        SimulationConfig(tickRate: SimulationTickRate(ticksPerSecond: 1))
    }

    private func position(of entityID: EntityID, in snapshot: SimulationSnapshot) -> Float3? {
        snapshot.entities.record(for: entityID)?.position?.value
    }

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
