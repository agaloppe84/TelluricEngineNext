import Foundation
import TelluricMath
import XCTest

final class MathPrimitivesTests: XCTestCase {
    func testIntVectorsHaveBasicValueBehavior() {
        XCTAssertEqual(Int2(x: 1, y: 2) + Int2(x: 3, y: 4), Int2(x: 4, y: 6))
        XCTAssertEqual(Int3(x: 4, y: 5, z: 6) - Int3(x: 1, y: 2, z: 3), Int3(x: 3, y: 3, z: 3))
    }

    func testFloatVectorsHaveBasicValueBehavior() {
        XCTAssertEqual(Float2(x: 1, y: 2) + Float2(x: 3, y: 4), Float2(x: 4, y: 6))
        XCTAssertEqual(Float3(x: 1, y: 2, z: 3) * 2, Float3(x: 2, y: 4, z: 6))
    }

    func testAABBContainsPoints() {
        let bounds = AABB(
            min: Float3(x: -1, y: -2, z: -3),
            max: Float3(x: 1, y: 2, z: 3)
        )

        XCTAssertTrue(bounds.contains(Float3(x: 0, y: 0, z: 0)))
        XCTAssertTrue(bounds.contains(Float3(x: 1, y: 2, z: 3)))
        XCTAssertFalse(bounds.contains(Float3(x: 1.1, y: 0, z: 0)))
    }

    func testAABBUnionAndExpansion() {
        let a = AABB(min: Float3(x: 0, y: 0, z: 0), max: Float3(x: 1, y: 1, z: 1))
        let b = AABB(min: Float3(x: -2, y: 0.5, z: -1), max: Float3(x: 0.5, y: 3, z: 2))

        XCTAssertEqual(
            a.union(b),
            AABB(min: Float3(x: -2, y: 0, z: -1), max: Float3(x: 1, y: 3, z: 2))
        )

        XCTAssertEqual(
            a.expanded(toInclude: Float3(x: 4, y: -5, z: 0.5)),
            AABB(min: Float3(x: 0, y: -5, z: 0), max: Float3(x: 4, y: 1, z: 1))
        )
    }

    func testTransformRoundTripsThroughCodable() throws {
        let transform = Transform(
            translation: Float3(x: 1, y: 2, z: 3),
            rotationRadians: Float3(x: 0.1, y: 0.2, z: 0.3),
            scale: Float3(x: 2, y: 2, z: 2)
        )

        XCTAssertEqual(try roundTrip(transform), transform)
    }

    func testMathUtilities() {
        XCTAssertEqual(clamp(7, min: 0, max: 5), 5)
        XCTAssertEqual(saturate(-0.25), 0)
        XCTAssertEqual(lerp(10, 20, t: 0.25), 12.5)
        XCTAssertEqual(lerp(Float2(x: 0, y: 10), Float2(x: 10, y: 20), t: 0.5), Float2(x: 5, y: 15))
        XCTAssertEqual(lerp(Float3(x: 0, y: 10, z: 20), Float3(x: 10, y: 20, z: 30), t: 0.5), Float3(x: 5, y: 15, z: 25))
        XCTAssertEqual(Angle.degrees(180).radians, Float.pi, accuracy: 0.0001)
    }

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
