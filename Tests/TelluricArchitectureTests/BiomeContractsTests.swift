import TelluricBiomes
import TelluricCore
import TelluricWorld
import XCTest

final class BiomeContractsTests: XCTestCase {
    func testBiomeSampleValidationCatchesOutOfRangeValues() {
        let sample = BiomeSample(
            primaryBiome: BiomeID("biome.desert"),
            moisture: -0.1,
            temperature: 1.2,
            vegetationDensity: .infinity
        )

        let issues = BiomeValidation.validate(sample: sample)

        XCTAssertTrue(issues.contains { $0.code == NamespaceID("biome.sample.invalid_moisture") })
        XCTAssertTrue(issues.contains { $0.code == NamespaceID("biome.sample.invalid_temperature") })
        XCTAssertTrue(issues.contains { $0.code == NamespaceID("biome.sample.invalid_vegetation_density") })
    }

    func testBiomePayloadStableHashIsSameForSameInput() {
        let payloadA = makePayload(moisture: 0.5)
        let payloadB = makePayload(moisture: 0.5)

        XCTAssertEqual(payloadA.stableHash, payloadB.stableHash)
    }

    func testBiomePayloadStableHashChangesWhenBiomeDataChanges() {
        let payloadA = makePayload(moisture: 0.5)
        let payloadB = makePayload(moisture: 0.6)

        XCTAssertNotEqual(payloadA.stableHash, payloadB.stableHash)
    }

    private func makePayload(moisture: Float) -> BiomePayload {
        BiomePayload(
            chunkCoord: ChunkCoord(x: -2, y: 0, z: 5),
            field: BiomeField(width: 2, depth: 2, samples: Array(repeating: BiomeSample(
                primaryBiome: BiomeID("biome.temperate_forest"),
                secondaryBiome: BiomeID("biome.grassland"),
                secondaryWeight: 0.25,
                moisture: moisture,
                temperature: 0.55,
                vegetationDensity: 0.75
            ), count: 4)),
            rules: BiomeRules(profile: NamespaceID("biome.rules.contract"), allowsSecondaryBiome: true)
        )
    }
}
