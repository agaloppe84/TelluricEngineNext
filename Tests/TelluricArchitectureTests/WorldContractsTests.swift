import Foundation
import TelluricBiomes
import TelluricCore
import TelluricDeterminism
import TelluricMath
import TelluricTerrain
import TelluricWorld
import XCTest

final class WorldContractsTests: XCTestCase {
    func testChunkCoordRoundTripsThroughCodable() throws {
        let coord = ChunkCoord(x: -7, y: 2, z: 9)
        XCTAssertEqual(try roundTrip(coord), coord)
    }

    func testChunkCoordEqualityAndStableHashing() {
        let coordA = ChunkCoord(x: -1, y: 0, z: 3)
        let coordB = ChunkCoord(x: -1, y: 0, z: 3)
        let coordC = ChunkCoord(x: -1, y: 0, z: 4)

        XCTAssertEqual(coordA, coordB)
        XCTAssertNotEqual(coordA, coordC)
        XCTAssertEqual(stableHash(coordA), stableHash(coordB))
        XCTAssertNotEqual(stableHash(coordA), stableHash(coordC))
    }

    func testRegionCoordDerivationUsesFloorDivisionForNegativeChunks() {
        let coord = ChunkCoord(x: -1, y: 0, z: -5)

        XCTAssertEqual(coord.regionCoord(regionSizeInChunks: 4), RegionCoord(x: -1, y: 0, z: -2))
        XCTAssertEqual(coord.localCoordInRegion(regionSizeInChunks: 4), Int3(x: 3, y: 0, z: 3))
    }

    func testWorldConfigRoundTripsThroughCodable() throws {
        let config = WorldConfig(
            worldSeed: WorldSeed(rawValue: 123),
            chunkSize: 32,
            verticalScale: 128,
            generationProfile: NamespaceID("world.profile.default")
        )

        XCTAssertEqual(try roundTrip(config), config)
    }

    func testWorldConfigValidationCatchesInvalidChunkSize() {
        let config = WorldConfig(
            worldSeed: WorldSeed(rawValue: 123),
            chunkSize: 0,
            verticalScale: 128,
            generationProfile: NamespaceID("world.profile.default")
        )

        let report = WorldGenerationValidation.validate(config: config)

        XCTAssertTrue(report.hasErrors)
        XCTAssertEqual(report.count(.error), 1)
    }

    func testWorldGenerationContextCreationAndSeedDerivation() {
        let context = WorldGenerationContext(
            config: WorldConfig(
                worldSeed: WorldSeed(rawValue: 123),
                chunkSize: 32,
                verticalScale: 128,
                generationProfile: NamespaceID("world.profile.default")
            ),
            engineVersion: EngineVersion(major: 1, minor: 0, patch: 0)
        )

        let derivedA = context.derivedSeed(
            namespace: NamespaceID("terrain.height"),
            coordinates: Int3(x: 2, y: 0, z: -3),
            localIndex: 4
        )
        let derivedB = context.derivedSeed(
            namespace: NamespaceID("terrain.height"),
            coordinates: Int3(x: 2, y: 0, z: -3),
            localIndex: 4
        )

        XCTAssertEqual(context.config.chunkSize, 32)
        XCTAssertEqual(derivedA, derivedB)
    }

    func testChunkWorldPayloadAggregatesTerrainAndBiomeHashesDeterministically() {
        let chunkCoord = ChunkCoord(x: 1, y: 0, z: 2)
        let terrainPayload = makeTerrainPayload(chunkCoord: chunkCoord)
        let biomePayload = makeBiomePayload(chunkCoord: chunkCoord)

        let forward = ChunkWorldPayload(chunkCoord: chunkCoord, componentHashes: [
            ChunkPayloadComponentHash(kind: .terrain, stableHash: terrainPayload.stableHash),
            ChunkPayloadComponentHash(kind: .biomes, stableHash: biomePayload.stableHash),
        ])
        let reversed = ChunkWorldPayload(chunkCoord: chunkCoord, componentHashes: [
            ChunkPayloadComponentHash(kind: .biomes, stableHash: biomePayload.stableHash),
            ChunkPayloadComponentHash(kind: .terrain, stableHash: terrainPayload.stableHash),
        ])

        XCTAssertEqual(forward.stableHash, reversed.stableHash)
        XCTAssertEqual(forward.componentHashes.map(\.kind), [.biomes, .terrain])
    }

    func testWorldGenerationReportRoundTripsThroughJSON() throws {
        let report = WorldGenerationReport(issues: [
            WorldGenerationIssue(
                severity: .error,
                code: NamespaceID("world.config.invalid_chunk_size"),
                message: "WorldConfig.chunkSize must be positive.",
                chunkCoord: ChunkCoord(x: 0, y: 0, z: 0)
            ),
        ])

        XCTAssertEqual(try roundTrip(report), report)
    }

    private func makeTerrainPayload(chunkCoord: ChunkCoord) -> TerrainPayload {
        TerrainPayload(
            chunkCoord: chunkCoord,
            heightField: HeightField(width: 2, depth: 2, samples: [
                HeightSample(height: 1),
                HeightSample(height: 2),
                HeightSample(height: 3),
                HeightSample(height: 4),
            ]),
            settings: TerrainGenerationSettings(
                profile: NamespaceID("terrain.profile.contract"),
                heightScale: 1
            )
        )
    }

    private func makeBiomePayload(chunkCoord: ChunkCoord) -> BiomePayload {
        BiomePayload(
            chunkCoord: chunkCoord,
            field: BiomeField(width: 2, depth: 2, samples: Array(repeating: BiomeSample(
                primaryBiome: BiomeID("biome.temperate_forest"),
                moisture: 0.6,
                temperature: 0.5,
                vegetationDensity: 0.8
            ), count: 4)),
            rules: BiomeRules(profile: NamespaceID("biome.rules.contract"), allowsSecondaryBiome: true)
        )
    }

    private func stableHash<T: StableHashable>(_ value: T) -> StableHash {
        var hasher = StableHasher()
        hasher.combine(value)
        return hasher.finalize()
    }

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
