import TelluricBiomes
import TelluricCore
import TelluricTerrain
import TelluricWorld
import XCTest

final class DeterministicGenerationTests: XCTestCase {
    func testSameSeedConfigAndChunkProduceSameTerrainHash() {
        let chunk = ChunkCoord(x: 0, y: 0, z: 0)
        let first = terrainPayload(seed: 10, chunk: chunk)
        let second = terrainPayload(seed: 10, chunk: chunk)

        XCTAssertEqual(first.stableHash, second.stableHash)
    }

    func testSameTerrainHashRepeatsOneHundredTimes() {
        let chunk = ChunkCoord(x: -2, y: 0, z: 3)
        let expected = terrainPayload(seed: 10, chunk: chunk).stableHash

        for _ in 0..<100 {
            XCTAssertEqual(terrainPayload(seed: 10, chunk: chunk).stableHash, expected)
        }
    }

    func testDifferentSeedChangesTerrainHashInSmallGrid() {
        var changed = false

        for z in -1...1 {
            for x in -1...1 {
                let chunk = ChunkCoord(x: Int64(x), y: 0, z: Int64(z))
                let first = terrainPayload(seed: 10, chunk: chunk)
                let second = terrainPayload(seed: 11, chunk: chunk)
                changed = changed || first.stableHash != second.stableHash
            }
        }

        XCTAssertTrue(changed)
    }

    func testSameSeedConfigAndChunkProduceSameBiomeHash() {
        let chunk = ChunkCoord(x: 1, y: 0, z: -1)
        let first = biomePayload(seed: 25, chunk: chunk)
        let second = biomePayload(seed: 25, chunk: chunk)

        XCTAssertEqual(first.stableHash, second.stableHash)
    }

    func testDifferentSeedChangesBiomeHashInSmallGrid() {
        var changed = false

        for z in -1...1 {
            for x in -1...1 {
                let chunk = ChunkCoord(x: Int64(x), y: 0, z: Int64(z))
                let first = biomePayload(seed: 25, chunk: chunk)
                let second = biomePayload(seed: 26, chunk: chunk)
                changed = changed || first.stableHash != second.stableHash
            }
        }

        XCTAssertTrue(changed)
    }

    func testGeneratedTerrainHasExpectedDimensionsAndFiniteValues() {
        let payload = terrainPayload(seed: 10, chunk: .zero, chunkSize: 8)

        XCTAssertEqual(payload.heightField.width, 9)
        XCTAssertEqual(payload.heightField.depth, 9)
        XCTAssertEqual(payload.heightField.samples.count, 81)
        XCTAssertTrue(payload.heightField.samples.allSatisfy { $0.height.isFinite })
    }

    func testGeneratedBiomeFieldHasExpectedDimensionsAndValidRanges() {
        let payload = biomePayload(seed: 10, chunk: .zero, chunkSize: 8)

        XCTAssertEqual(payload.field.width, 9)
        XCTAssertEqual(payload.field.depth, 9)
        XCTAssertEqual(payload.field.samples.count, 81)
        XCTAssertTrue(payload.field.samples.allSatisfy { sample in
            sample.moisture >= 0 &&
                sample.moisture <= 1 &&
                sample.temperature >= 0 &&
                sample.temperature <= 1 &&
                sample.vegetationDensity >= 0 &&
                sample.vegetationDensity <= 1
        })
    }

    func testGeneratedChunkWorldPayloadIsStableForSameInputs() throws {
        let generator = worldGenerator()
        let context = makeContext(seed: 33)
        let chunk = ChunkCoord(x: 2, y: 0, z: 2)

        let first = try generator.generateChunk(at: chunk, context: context)
        let second = try generator.generateChunk(at: chunk, context: context)

        XCTAssertEqual(first.payload.stableHash, second.payload.stableHash)
        XCTAssertTrue(first.report.isSuccess)
    }

    func testGeneratedChunkWorldPayloadChangesWhenTerrainInputChanges() throws {
        let context = makeContext(seed: 33)
        let chunk = ChunkCoord(x: 2, y: 0, z: 2)
        let baseline = worldGenerator()
        let altered = DeterministicWorldGenerator(componentGenerator: DeterministicTerrainBiomeChunkGenerator(
            terrainSettings: TerrainGenerationSettings(
                profile: NamespaceID("terrain.baseline.v1"),
                heightScale: 0.5
            )
        ))

        let first = try baseline.generateChunk(at: chunk, context: context)
        let second = try altered.generateChunk(at: chunk, context: context)

        XCTAssertNotEqual(first.payload.stableHash, second.payload.stableHash)
    }

    func testNeighboringChunksShareWorldSpaceTerrainAndBiomeEdges() {
        let leftChunk = ChunkCoord(x: 0, y: 0, z: 0)
        let rightChunk = ChunkCoord(x: 1, y: 0, z: 0)
        let context = makeContext(seed: 99, chunkSize: 8)
        let terrainGenerator = DeterministicTerrainGenerator()
        let biomeResolver = DeterministicBiomeResolver()
        let leftTerrain = terrainGenerator.generateTerrain(context: context, chunkCoord: leftChunk, settings: .baseline)
        let rightTerrain = terrainGenerator.generateTerrain(context: context, chunkCoord: rightChunk, settings: .baseline)
        let leftBiome = biomeResolver.resolveBiomes(context: context, chunkCoord: leftChunk, terrain: leftTerrain, rules: .baseline)
        let rightBiome = biomeResolver.resolveBiomes(context: context, chunkCoord: rightChunk, terrain: rightTerrain, rules: .baseline)

        for z in 0...context.config.chunkSize {
            XCTAssertEqual(
                leftTerrain.heightField.sample(x: context.config.chunkSize, z: z)?.height,
                rightTerrain.heightField.sample(x: 0, z: z)?.height
            )
            XCTAssertEqual(
                leftBiome.field.sample(x: context.config.chunkSize, z: z),
                rightBiome.field.sample(x: 0, z: z)
            )
        }
    }

    func testWorldGenerationReportCapturesSuccessAndValidationDiagnostics() throws {
        let generator = worldGenerator()
        let success = try generator.generateChunk(at: .zero, context: makeContext(seed: 44))

        XCTAssertTrue(success.report.isSuccess)
        XCTAssertFalse(success.report.hasErrors)

        let invalidContext = WorldGenerationContext(
            config: WorldConfig(
                worldSeed: WorldSeed(rawValue: 44),
                chunkSize: 0,
                verticalScale: 64,
                generationProfile: NamespaceID("world.profile.baseline")
            ),
            engineVersion: EngineVersion(major: 1, minor: 0, patch: 0)
        )

        do {
            _ = try generator.generateChunk(at: .zero, context: invalidContext)
            XCTFail("Expected invalid world config to throw")
        } catch let error as WorldGenerationError {
            XCTAssertTrue(error.report.hasErrors)
            XCTAssertTrue(error.report.issues.contains { $0.code == NamespaceID("world.config.invalid_chunk_size") })
        }
    }

    private func terrainPayload(seed: UInt64, chunk: ChunkCoord, chunkSize: Int = 8) -> TerrainPayload {
        DeterministicTerrainGenerator().generateTerrain(
            context: makeContext(seed: seed, chunkSize: chunkSize),
            chunkCoord: chunk,
            settings: .baseline
        )
    }

    private func biomePayload(seed: UInt64, chunk: ChunkCoord, chunkSize: Int = 8) -> BiomePayload {
        let context = makeContext(seed: seed, chunkSize: chunkSize)
        let terrain = DeterministicTerrainGenerator().generateTerrain(
            context: context,
            chunkCoord: chunk,
            settings: .baseline
        )
        return DeterministicBiomeResolver().resolveBiomes(
            context: context,
            chunkCoord: chunk,
            terrain: terrain,
            rules: .baseline
        )
    }

    private func worldGenerator() -> DeterministicWorldGenerator {
        DeterministicWorldGenerator(
            componentGenerator: DeterministicTerrainBiomeChunkGenerator()
        )
    }

    private func makeContext(seed: UInt64, chunkSize: Int = 8) -> WorldGenerationContext {
        WorldGenerationContext(
            config: WorldConfig(
                worldSeed: WorldSeed(rawValue: seed),
                chunkSize: chunkSize,
                verticalScale: 64,
                generationProfile: NamespaceID("world.profile.baseline")
            ),
            engineVersion: EngineVersion(major: 1, minor: 0, patch: 0)
        )
    }
}
