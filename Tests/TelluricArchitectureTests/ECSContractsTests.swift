import Foundation
import TelluricECS
import TelluricMath
import XCTest

final class ECSContractsTests: XCTestCase {
    func testEntityIDRoundTripsThroughCodable() throws {
        let entityID = EntityID(index: 42, generation: EntityGeneration(rawValue: 3))

        XCTAssertEqual(try roundTrip(entityID), entityID)
    }

    func testEntityCreationProducesDeterministicOrderedSnapshots() {
        let high = EntityRecord(id: EntityID(index: 5))
        let low = EntityRecord(id: EntityID(index: 1))

        let first = EntitySnapshot(entities: [high, low])
        let second = EntitySnapshot(entities: [low, high])

        XCTAssertEqual(first.entities.map(\.id), [
            EntityID(index: 1),
            EntityID(index: 5),
        ])
        XCTAssertEqual(first, second)
    }

    func testEntityDestructionRemovesEntityDeterministically() {
        let removed = EntityID(index: 1)
        let kept = EntityID(index: 2)
        let storage = ComponentStorage(records: [
            EntityRecord(id: removed),
            EntityRecord(id: kept),
        ]).removing(entityID: removed)

        XCTAssertNil(storage.record(for: removed))
        XCTAssertEqual(storage.snapshot.entities.map(\.id), [kept])
    }

    func testPositionComponentCanBeSetAndRead() {
        let entityID = EntityID(index: 1)
        let position = PositionComponent(Float3(x: 1, y: 2, z: 3))
        let storage = ComponentStorage.empty.setting(.position(position), for: entityID)

        XCTAssertEqual(storage.record(for: entityID)?.position, position)
    }

    func testVelocityComponentCanBeSetAndRead() {
        let entityID = EntityID(index: 1)
        let velocity = VelocityComponent(Float3(x: 3, y: 2, z: 1))
        let storage = ComponentStorage.empty.setting(.velocity(velocity), for: entityID)

        XCTAssertEqual(storage.record(for: entityID)?.velocity, velocity)
    }

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
