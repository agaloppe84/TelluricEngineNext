import TelluricCore
import TelluricTerrain
import TelluricWorld
import XCTest

final class TerrainContractsTests: XCTestCase {
    func testHeightFieldValidDimensionsPassValidation() {
        let field = HeightField(width: 2, depth: 2, samples: [
            HeightSample(height: 0),
            HeightSample(height: 1),
            HeightSample(height: 2),
            HeightSample(height: 3),
        ])

        XCTAssertTrue(TerrainValidation.validate(heightField: field).isEmpty)
        XCTAssertEqual(field.summary, HeightSummary(minHeight: 0, maxHeight: 3))
    }

    func testHeightFieldInvalidSampleCountFailsValidation() {
        let field = HeightField(width: 2, depth: 2, samples: [
            HeightSample(height: 0),
            HeightSample(height: 1),
            HeightSample(height: 2),
        ])

        let issues = TerrainValidation.validate(heightField: field)

        XCTAssertTrue(issues.contains { $0.code == NamespaceID("terrain.height_field.invalid_sample_count") })
    }

    func testHeightFieldReportsNaNAndInfiniteHeights() {
        let field = HeightField(width: 2, depth: 2, samples: [
            HeightSample(height: 0),
            HeightSample(height: .nan),
            HeightSample(height: .infinity),
            HeightSample(height: 3),
        ])

        let issues = TerrainValidation.validate(heightField: field)
        let nonFiniteIssues = issues.filter { $0.code == NamespaceID("terrain.height_field.non_finite_height") }

        XCTAssertEqual(nonFiniteIssues.count, 2)
    }

    func testTerrainPayloadStableHashIsSameForSameInput() {
        let payloadA = makePayload(heights: [0, 1, 2, 3])
        let payloadB = makePayload(heights: [0, 1, 2, 3])

        XCTAssertEqual(payloadA.stableHash, payloadB.stableHash)
    }

    func testTerrainPayloadStableHashChangesWhenHeightDataChanges() {
        let payloadA = makePayload(heights: [0, 1, 2, 3])
        let payloadB = makePayload(heights: [0, 1, 2, 4])

        XCTAssertNotEqual(payloadA.stableHash, payloadB.stableHash)
    }

    private func makePayload(heights: [Float]) -> TerrainPayload {
        TerrainPayload(
            chunkCoord: ChunkCoord(x: 3, y: 0, z: -1),
            heightField: HeightField(
                width: 2,
                depth: 2,
                samples: heights.map(HeightSample.init(height:))
            ),
            settings: TerrainGenerationSettings(
                profile: NamespaceID("terrain.profile.contract"),
                heightScale: 1
            )
        )
    }
}
