import Foundation
import TelluricCore
import XCTest

final class CorePrimitivesTests: XCTestCase {
    func testEngineVersionFrameIndexTickIndexAndWorldSeedRoundTripThroughCodable() throws {
        XCTAssertEqual(try roundTrip(EngineVersion(major: 1, minor: 2, patch: 3)), EngineVersion(major: 1, minor: 2, patch: 3))
        XCTAssertEqual(try roundTrip(FrameIndex(rawValue: 42)), FrameIndex(rawValue: 42))
        XCTAssertEqual(try roundTrip(TickIndex(rawValue: 84)), TickIndex(rawValue: 84))
        XCTAssertEqual(try roundTrip(WorldSeed(rawValue: 0x1234_5678_9abc_def0)), WorldSeed(rawValue: 0x1234_5678_9abc_def0))
    }

    func testStableHashRoundTripsThroughCodable() throws {
        let hash = StableHash(rawValue: 0xfedc_ba98_7654_3210)
        XCTAssertEqual(try roundTrip(hash), hash)
    }

    func testCorePrimitivesCompareAndAdvance() {
        XCTAssertLessThan(EngineVersion(major: 1, minor: 2, patch: 3), EngineVersion(major: 1, minor: 3, patch: 0))
        XCTAssertEqual(FrameIndex.zero.advanced(by: 3), FrameIndex(rawValue: 3))
        XCTAssertEqual(TickIndex.zero.advanced(by: 5), TickIndex(rawValue: 5))
        XCTAssertEqual(NamespaceID("telluric.core").description, "telluric.core")
    }

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
