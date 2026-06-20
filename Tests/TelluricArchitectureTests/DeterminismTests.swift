import TelluricCore
import TelluricDeterminism
import TelluricMath
import XCTest

final class DeterminismTests: XCTestCase {
    func testDeterministicRNGSameSeedProducesSameSequence() {
        XCTAssertEqual(sequence(seed: 100), sequence(seed: 100))
    }

    func testDeterministicRNGDifferentSeedsDiverge() {
        XCTAssertNotEqual(sequence(seed: 100), sequence(seed: 101))
    }

    func testSeedDerivationIsStableForSameInputs() {
        let seedA = SeedDerivation.derive(
            worldSeed: WorldSeed(rawValue: 42),
            namespace: NamespaceID("terrain.height"),
            coordinates: Int3(x: -4, y: 0, z: 9),
            localIndex: 7
        )
        let seedB = SeedDerivation.derive(
            worldSeed: WorldSeed(rawValue: 42),
            namespace: NamespaceID("terrain.height"),
            coordinates: Int3(x: -4, y: 0, z: 9),
            localIndex: 7
        )

        XCTAssertEqual(seedA, seedB)
    }

    func testDifferentNamespacesDeriveDifferentSeeds() {
        let worldSeed = WorldSeed(rawValue: 42)
        let coordinates = Int3(x: -4, y: 0, z: 9)

        let terrainSeed = SeedDerivation.derive(
            worldSeed: worldSeed,
            namespace: NamespaceID("terrain.height"),
            coordinates: coordinates,
            localIndex: 7
        )
        let biomeSeed = SeedDerivation.derive(
            worldSeed: worldSeed,
            namespace: NamespaceID("biome.selection"),
            coordinates: coordinates,
            localIndex: 7
        )

        XCTAssertNotEqual(terrainSeed, biomeSeed)
    }

    func testStableHasherProducesIdenticalHashForIdenticalOrderedInput() {
        XCTAssertEqual(hash(values: [1, 2, 3]), hash(values: [1, 2, 3]))
    }

    func testStableHasherProducesDifferentHashWhenInputDiffers() {
        XCTAssertNotEqual(hash(values: [1, 2, 3]), hash(values: [1, 2, 4]))
    }

    private func sequence(seed: UInt64) -> [UInt64] {
        var rng = DeterministicRNG(seed: seed)
        var values: [UInt64] = []

        for _ in 0..<8 {
            values.append(rng.nextUInt64())
        }

        return values
    }

    private func hash(values: [UInt64]) -> StableHash {
        var hasher = StableHasher()

        for value in values {
            hasher.combine(value)
        }

        return hasher.finalize()
    }
}
