import Foundation
import TelluricCore
import TelluricECS
import TelluricGame
import TelluricMath
import TelluricRuntime
import TelluricSimulation
import TelluricStreaming
import TelluricWorld
import XCTest

final class GameContractsTests: XCTestCase {
    func testGameConfigRoundTripsThroughCodable() throws {
        let config = makeGameConfig()

        XCTAssertEqual(try roundTrip(config), config)
    }

    func testGameIntentRoundTripsThroughCodable() throws {
        let intent = GameIntent.spawnControllableEntity(
            entityID: EntityID(index: 7),
            position: Float3(x: 1, y: 2, z: 3),
            velocity: Float3(x: 0, y: 1, z: 0)
        )

        XCTAssertEqual(try roundTrip(intent), intent)
    }

    func testOrderedGameIntentsConvertToOrderedSimulationCommands() {
        let entityID = EntityID(index: 1)
        let mapper = GameIntentMapper(rulesProfile: GameRulesProfile(
            id: NamespaceID("game.rules.tests"),
            translationScale: 2,
            velocityScale: 3
        ))
        let input = GameInputFrame(tick: .zero, intents: [
            .spawnControllableEntity(entityID: entityID, position: .zero, velocity: nil),
            .moveEntity(entityID: entityID, translation: Float3(x: 1, y: 0, z: -1)),
            .setDesiredVelocity(entityID: entityID, velocity: Float3(x: 0, y: 2, z: 0)),
        ])

        let result = mapper.map(inputFrame: input)

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.simulationInputFrame.commandBuffer.commands, [
            .createEntity(entityID: entityID, components: [
                .position(PositionComponent(.zero)),
            ]),
            .applyTranslation(entityID: entityID, translation: Float3(x: 2, y: 0, z: -2)),
            .setVelocity(entityID: entityID, velocity: VelocityComponent(Float3(x: 0, y: 6, z: 0))),
        ])
    }

    func testSameGameInputProducesSameCommandSequence() {
        let entityID = EntityID(index: 2)
        let input = GameInputFrame(tick: .zero, intents: [
            .spawnControllableEntity(
                entityID: entityID,
                position: Float3(x: 4, y: 0, z: 4),
                velocity: Float3(x: 1, y: 0, z: 0)
            ),
            .moveEntity(entityID: entityID, translation: Float3(x: 0, y: 0, z: 1)),
        ])
        let mapper = GameIntentMapper()

        let first = mapper.map(inputFrame: input)
        let second = mapper.map(inputFrame: input)

        XCTAssertEqual(first.simulationInputFrame, second.simulationInputFrame)
        XCTAssertEqual(first.stableHash, second.stableHash)
        XCTAssertEqual(GameHasher.hash(inputFrame: input), GameHasher.hash(inputFrame: input))
    }

    func testInvalidGameIntentProducesDiagnostics() {
        let entityID = EntityID(index: 3)
        let input = GameInputFrame(tick: .zero, intents: [
            .moveEntity(entityID: entityID, translation: Float3(x: .nan, y: 0, z: 0)),
        ])

        let result = GameIntentMapper().map(inputFrame: input)

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.simulationInputFrame.commandBuffer.commands, [])
        XCTAssertEqual(result.diagnostics.count(.error), 1)
        XCTAssertEqual(result.diagnostics.messages.first?.code.rawValue, "game.intent.invalid_vector")
    }

    func testGameSessionSameConfigAndInputsProduceSameRuntimeHash() {
        let config = makeGameConfig()
        let input = makeSpawnStepInput(entityID: EntityID(index: 10))
        var firstSession = GameSession(config: config)
        var secondSession = GameSession(config: config)

        let first = firstSession.step(input)
        let second = secondSession.step(input)

        XCTAssertTrue(first.success)
        XCTAssertTrue(second.success)
        XCTAssertEqual(first.runtimeSnapshot.stableHash, second.runtimeSnapshot.stableHash)
        XCTAssertEqual(first.runtimeStepResult?.simulationSnapshot.stableHash, second.runtimeStepResult?.simulationSnapshot.stableHash)
    }

    func testGameSessionDifferentInputsChangeRuntimeAndSimulationHashes() {
        let config = makeGameConfig()
        let entityID = EntityID(index: 11)
        var firstSession = GameSession(config: config)
        var secondSession = GameSession(config: config)

        let first = firstSession.step(makeSpawnStepInput(entityID: entityID))
        let second = secondSession.step(GameStepInput(gameInputFrame: GameInputFrame(tick: .zero, intents: [
            .spawnControllableEntity(entityID: entityID, position: .zero, velocity: nil),
            .moveEntity(entityID: entityID, translation: Float3(x: 1, y: 0, z: 0)),
        ])))

        XCTAssertTrue(first.success)
        XCTAssertTrue(second.success)
        XCTAssertNotEqual(first.runtimeSnapshot.stableHash, second.runtimeSnapshot.stableHash)
        XCTAssertNotEqual(first.runtimeStepResult?.simulationSnapshot.stableHash, second.runtimeStepResult?.simulationSnapshot.stableHash)
    }

    func testInvalidIntentDoesNotSilentlyMutateSimulation() {
        var session = GameSession(config: makeGameConfig())
        let before = session.snapshot()
        let invalidInput = GameStepInput(gameInputFrame: GameInputFrame(tick: .zero, intents: [
            .setDesiredVelocity(entityID: EntityID(index: 12), velocity: Float3(x: .infinity, y: 0, z: 0)),
        ]))

        let result = session.step(invalidInput)
        let after = session.snapshot()

        XCTAssertFalse(result.success)
        XCTAssertNil(result.runtimeStepResult)
        XCTAssertEqual(result.runtimeSnapshot.state.frameIndex, before.state.frameIndex)
        XCTAssertEqual(result.runtimeSnapshot.state.simulationSnapshot.stableHash, before.state.simulationSnapshot.stableHash)
        XCTAssertEqual(after.state.frameIndex, before.state.frameIndex)
        XCTAssertEqual(after.state.simulationSnapshot.stableHash, before.state.simulationSnapshot.stableHash)
    }

    func testTelluricGameDoesNotImportUIOrRenderBackendFrameworks() throws {
        let root = try packageRoot()
        let source = root.appendingPathComponent("Sources").appendingPathComponent("TelluricGame")

        try assertNoSwiftSourceLine(
            under: source,
            containsAnyImportOf: ["Metal", "MetalKit", "SwiftUI", "AppKit", "AVFoundation", "CoreAudio", "GameplayKit", "TelluricRenderMetal"]
        )
    }

    private func makeSpawnStepInput(entityID: EntityID) -> GameStepInput {
        GameStepInput(gameInputFrame: GameInputFrame(tick: .zero, intents: [
            .spawnControllableEntity(entityID: entityID, position: .zero, velocity: nil),
        ]))
    }

    private func makeGameConfig(seed: UInt64 = 42) -> GameConfig {
        let engineVersion = EngineVersion(major: 1, minor: 0, patch: 0)
        let worldConfig = WorldConfig(
            worldSeed: WorldSeed(rawValue: seed),
            chunkSize: 16,
            verticalScale: 8,
            generationProfile: NamespaceID("world.profile.game.tests")
        )
        let simulationConfig = SimulationConfig(
            engineVersion: engineVersion,
            tickRate: SimulationTickRate(ticksPerSecond: 60),
            initialTick: .zero,
            profile: NamespaceID("simulation.profile.game.tests")
        )
        let runtimeConfig = RuntimeConfig(
            worldConfig: worldConfig,
            engineVersion: engineVersion,
            simulationConfig: simulationConfig,
            streamingConfig: ChunkStreamingConfig(worldConfig: worldConfig, radius: 0),
            initialObservers: [
                StreamingObserver(
                    id: StreamingObserverID("game.observer.tests"),
                    worldPosition: .zero
                ),
            ]
        )

        return GameConfig(
            sessionID: GameSessionID("game.session.tests"),
            runtimeConfig: runtimeConfig,
            rulesProfile: .baseline
        )
    }

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func packageRoot() throws -> URL {
        var current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        while current.path != "/" {
            if FileManager.default.fileExists(atPath: current.appendingPathComponent("Package.swift").path) {
                return current
            }

            current.deleteLastPathComponent()
        }

        throw XCTSkip("Package.swift was not found from the current test directory.")
    }

    private func assertNoSwiftSourceLine(
        under root: URL,
        containsAnyImportOf modules: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        for sourceFile in try swiftFiles(under: root) {
            let contents = try String(contentsOf: sourceFile, encoding: .utf8)
            for sourceLine in contents.components(separatedBy: .newlines) {
                let trimmedLine = sourceLine.trimmingCharacters(in: .whitespaces)
                for module in modules where trimmedLine == "import \(module)" {
                    XCTFail("Forbidden import \(module) found in \(sourceFile.path)", file: file, line: line)
                }
            }
        }
    }

    private func swiftFiles(under root: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: root.path) else {
            return []
        }

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            files.append(fileURL)
        }

        return files.sorted { $0.path < $1.path }
    }
}
