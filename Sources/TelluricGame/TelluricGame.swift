import TelluricCore
import TelluricDeterminism
import TelluricDiagnostics
import TelluricECS
import TelluricMath
import TelluricRuntime
import TelluricSimulation
import TelluricStreaming

/// Stable identifier for a game-layer session.
public struct GameSessionID: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Stable session namespace.
    public let rawValue: NamespaceID

    /// Creates a game session identifier.
    public init(_ rawValue: NamespaceID) {
        self.rawValue = rawValue
    }

    /// Creates a game session identifier from a namespace string.
    public init(_ rawValue: String) {
        self.init(NamespaceID(rawValue))
    }

    public static func < (lhs: GameSessionID, rhs: GameSessionID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

/// Neutral game rule profile used while mapping game intents to simulation commands.
public struct GameRulesProfile: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Stable profile identifier.
    public let id: NamespaceID

    /// Multiplier applied to translation intents before simulation command creation.
    public let translationScale: Float

    /// Multiplier applied to desired velocity intents before simulation command creation.
    public let velocityScale: Float

    /// Baseline game-layer rules profile.
    public static let baseline = GameRulesProfile(id: NamespaceID("game.rules.baseline"))

    /// Creates a neutral game rule profile.
    public init(
        id: NamespaceID,
        translationScale: Float = 1,
        velocityScale: Float = 1
    ) {
        precondition(translationScale.isFinite && translationScale >= 0, "translationScale must be finite and non-negative")
        precondition(velocityScale.isFinite && velocityScale >= 0, "velocityScale must be finite and non-negative")
        self.id = id
        self.translationScale = translationScale
        self.velocityScale = velocityScale
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(id)
        hasher.combine(translationScale)
        hasher.combine(velocityScale)
    }
}

/// Game-layer configuration above the engine runtime.
public struct GameConfig: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Stable game session identifier.
    public let sessionID: GameSessionID

    /// Runtime configuration owned by the game session as a client.
    public let runtimeConfig: RuntimeConfig

    /// Rule profile used for intent mapping.
    public let rulesProfile: GameRulesProfile

    /// Creates a game configuration.
    public init(
        sessionID: GameSessionID,
        runtimeConfig: RuntimeConfig,
        rulesProfile: GameRulesProfile = .baseline
    ) {
        self.sessionID = sessionID
        self.runtimeConfig = runtimeConfig
        self.rulesProfile = rulesProfile
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(sessionID)
        hasher.combine(runtimeConfig)
        hasher.combine(rulesProfile)
    }
}

/// Minimal engine-neutral intent produced by future game input systems.
public enum GameIntent: Codable, Equatable, Hashable, Sendable, StableHashable {
    case spawnControllableEntity(entityID: EntityID, position: Float3, velocity: Float3?)
    case moveEntity(entityID: EntityID, translation: Float3)
    case setDesiredVelocity(entityID: EntityID, velocity: Float3)

    public func stableHash(into hasher: inout StableHasher) {
        switch self {
        case let .spawnControllableEntity(entityID, position, velocity):
            hasher.combine("spawnControllableEntity")
            hasher.combine(entityID)
            combine(position, into: &hasher)
            hasher.combine(velocity != nil)
            if let velocity {
                combine(velocity, into: &hasher)
            }

        case let .moveEntity(entityID, translation):
            hasher.combine("moveEntity")
            hasher.combine(entityID)
            combine(translation, into: &hasher)

        case let .setDesiredVelocity(entityID, velocity):
            hasher.combine("setDesiredVelocity")
            hasher.combine(entityID)
            combine(velocity, into: &hasher)
        }
    }

    fileprivate var diagnosticKind: String {
        switch self {
        case .spawnControllableEntity:
            return "spawnControllableEntity"
        case .moveEntity:
            return "moveEntity"
        case .setDesiredVelocity:
            return "setDesiredVelocity"
        }
    }
}

/// Ordered game intents for one game input frame.
public struct GameIntentBuffer: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Ordered intents.
    public let intents: [GameIntent]

    /// Empty intent buffer.
    public static let empty = GameIntentBuffer(intents: [])

    /// Creates a game intent buffer.
    public init(intents: [GameIntent] = []) {
        self.intents = intents
    }

    /// Returns a new buffer with `intent` appended.
    public func appending(_ intent: GameIntent) -> GameIntentBuffer {
        GameIntentBuffer(intents: intents + [intent])
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(intents.count)
        for intent in intents {
            hasher.combine(intent)
        }
    }
}

/// Ordered game input for one fixed simulation tick.
public struct GameInputFrame: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Simulation tick targeted by this game input frame.
    public let tick: TickIndex

    /// Ordered game intents.
    public let intentBuffer: GameIntentBuffer

    /// Creates a game input frame.
    public init(tick: TickIndex, intentBuffer: GameIntentBuffer = .empty) {
        self.tick = tick
        self.intentBuffer = intentBuffer
    }

    /// Creates a game input frame from ordered intents.
    public init(tick: TickIndex, intents: [GameIntent]) {
        self.init(tick: tick, intentBuffer: GameIntentBuffer(intents: intents))
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(tick)
        hasher.combine(intentBuffer)
    }
}

/// Result of mapping one game input frame to one simulation input frame.
public struct GameIntentMappingResult: Codable, Equatable, Sendable {
    /// Source game input frame.
    public let gameInputFrame: GameInputFrame

    /// Engine-neutral simulation input frame produced by the mapper.
    public let simulationInputFrame: SimulationInputFrame

    /// Ordered mapping diagnostics.
    public let diagnostics: DiagnosticReport

    /// True when no mapping diagnostics are errors.
    public let success: Bool

    /// Stable hash of ordered mapping contents.
    public let stableHash: StableHash

    /// Creates an intent mapping result.
    public init(
        gameInputFrame: GameInputFrame,
        simulationInputFrame: SimulationInputFrame,
        diagnostics: DiagnosticReport
    ) {
        self.gameInputFrame = gameInputFrame
        self.simulationInputFrame = simulationInputFrame
        self.diagnostics = diagnostics
        self.success = !diagnostics.hasErrors
        self.stableHash = GameHasher.hash(
            gameInputFrame: gameInputFrame,
            simulationInputFrame: simulationInputFrame,
            diagnostics: diagnostics,
            success: self.success
        )
    }
}

/// Deterministic mapper from game-layer intents to simulation commands.
public struct GameIntentMapper: Sendable {
    /// Rule profile used while mapping intents.
    public let rulesProfile: GameRulesProfile

    /// Creates a game intent mapper.
    public init(rulesProfile: GameRulesProfile = .baseline) {
        self.rulesProfile = rulesProfile
    }

    /// Maps ordered game intents to ordered simulation commands.
    public func map(inputFrame: GameInputFrame) -> GameIntentMappingResult {
        var commands: [SimulationCommand] = []
        var collector = DiagnosticCollector()

        for (index, intent) in inputFrame.intentBuffer.intents.enumerated() {
            switch intent {
            case let .spawnControllableEntity(entityID, position, velocity):
                guard Self.isFinite(position) else {
                    recordInvalidVector(intent: intent, index: index, vectorName: "position", entityID: entityID, collector: &collector)
                    continue
                }

                var components: [ComponentValue] = [
                    .position(PositionComponent(position)),
                ]

                if let velocity {
                    let scaledVelocity = Self.scaled(velocity, by: rulesProfile.velocityScale)
                    guard Self.isFinite(scaledVelocity) else {
                        recordInvalidVector(intent: intent, index: index, vectorName: "velocity", entityID: entityID, collector: &collector)
                        continue
                    }
                    components.append(.velocity(VelocityComponent(scaledVelocity)))
                }

                commands.append(.createEntity(entityID: entityID, components: components))

            case let .moveEntity(entityID, translation):
                let scaledTranslation = Self.scaled(translation, by: rulesProfile.translationScale)
                guard Self.isFinite(scaledTranslation) else {
                    recordInvalidVector(intent: intent, index: index, vectorName: "translation", entityID: entityID, collector: &collector)
                    continue
                }

                commands.append(.applyTranslation(entityID: entityID, translation: scaledTranslation))

            case let .setDesiredVelocity(entityID, velocity):
                let scaledVelocity = Self.scaled(velocity, by: rulesProfile.velocityScale)
                guard Self.isFinite(scaledVelocity) else {
                    recordInvalidVector(intent: intent, index: index, vectorName: "velocity", entityID: entityID, collector: &collector)
                    continue
                }

                commands.append(.setVelocity(entityID: entityID, velocity: VelocityComponent(scaledVelocity)))
            }
        }

        return GameIntentMappingResult(
            gameInputFrame: inputFrame,
            simulationInputFrame: SimulationInputFrame(tick: inputFrame.tick, commands: commands),
            diagnostics: collector.report()
        )
    }

    private func recordInvalidVector(
        intent: GameIntent,
        index: Int,
        vectorName: String,
        entityID: EntityID,
        collector: inout DiagnosticCollector
    ) {
        collector.record(
            severity: .error,
            code: NamespaceID("game.intent.invalid_vector"),
            message: "Game intent vector values must be finite after rule-profile scaling.",
            source: "TelluricGame",
            metadata: [
                DiagnosticMetadata(key: "intent.index", value: "\(index)"),
                DiagnosticMetadata(key: "intent.kind", value: intent.diagnosticKind),
                DiagnosticMetadata(key: "vector", value: vectorName),
                DiagnosticMetadata(key: "entity.index", value: "\(entityID.index)"),
                DiagnosticMetadata(key: "entity.generation", value: "\(entityID.generation.rawValue)"),
            ]
        )
    }

    private static func scaled(_ vector: Float3, by scale: Float) -> Float3 {
        Float3(x: vector.x * scale, y: vector.y * scale, z: vector.z * scale)
    }

    private static func isFinite(_ vector: Float3) -> Bool {
        vector.x.isFinite && vector.y.isFinite && vector.z.isFinite
    }
}

/// Game-layer input consumed by one game session step.
public struct GameStepInput: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Ordered game input frame.
    public let gameInputFrame: GameInputFrame

    /// Optional replacement streaming observers. Nil preserves the runtime's current observers.
    public let observers: [StreamingObserver]?

    /// Creates a game step input.
    public init(gameInputFrame: GameInputFrame, observers: [StreamingObserver]? = nil) {
        self.gameInputFrame = gameInputFrame
        self.observers = observers.map(Self.sortedObservers)
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(gameInputFrame)
        hasher.combine(observers != nil)

        if let observers {
            hasher.combine(observers.count)
            for observer in observers {
                hasher.combine(observer)
            }
        }
    }

    private static func sortedObservers(_ observers: [StreamingObserver]) -> [StreamingObserver] {
        observers.sorted { lhs, rhs in
            if lhs.id != rhs.id {
                return lhs.id < rhs.id
            }

            if lhs.worldPosition.x != rhs.worldPosition.x {
                return lhs.worldPosition.x < rhs.worldPosition.x
            }

            if lhs.worldPosition.y != rhs.worldPosition.y {
                return lhs.worldPosition.y < rhs.worldPosition.y
            }

            return lhs.worldPosition.z < rhs.worldPosition.z
        }
    }
}

/// Result of one game session step.
public struct GameStepResult: Codable, Equatable, Sendable {
    /// Input consumed by the game session.
    public let input: GameStepInput

    /// Intent mapping result produced before runtime stepping.
    public let mappingResult: GameIntentMappingResult

    /// Runtime step result when mapping succeeded.
    public let runtimeStepResult: RuntimeStepResult?

    /// Runtime snapshot after the step, or the unchanged current snapshot when mapping failed.
    public let runtimeSnapshot: RuntimeSnapshot

    /// Ordered game and runtime diagnostics.
    public let diagnostics: DiagnosticReport

    /// True when mapping and runtime stepping both succeeded.
    public let success: Bool

    /// Stable hash over ordered game step result contents.
    public let stableHash: StableHash

    /// Creates a game step result.
    public init(
        input: GameStepInput,
        mappingResult: GameIntentMappingResult,
        runtimeStepResult: RuntimeStepResult?,
        runtimeSnapshot: RuntimeSnapshot,
        diagnostics: DiagnosticReport
    ) {
        self.input = input
        self.mappingResult = mappingResult
        self.runtimeStepResult = runtimeStepResult
        self.runtimeSnapshot = runtimeSnapshot
        self.diagnostics = diagnostics
        self.success = mappingResult.success
            && (runtimeStepResult?.success ?? false)
            && !diagnostics.hasErrors
        self.stableHash = GameHasher.hash(
            input: input,
            mappingResult: mappingResult,
            runtimeStepResult: runtimeStepResult,
            runtimeSnapshot: runtimeSnapshot,
            diagnostics: diagnostics,
            success: self.success
        )
    }
}

/// Game-layer session that owns a runtime as a client and feeds it mapped intents.
public struct GameSession: Sendable {
    /// Game configuration.
    public let config: GameConfig

    private var runtime: TelluricRuntime
    private let mapper: GameIntentMapper

    /// Creates a game session with a fresh runtime.
    public init(config: GameConfig) {
        self.config = config
        self.runtime = TelluricRuntime(config: config.runtimeConfig)
        self.mapper = GameIntentMapper(rulesProfile: config.rulesProfile)
    }

    /// Current runtime snapshot from the wrapped runtime.
    public func snapshot(diagnostics: DiagnosticReport = DiagnosticReport(messages: [])) -> RuntimeSnapshot {
        runtime.snapshot(diagnostics: diagnostics)
    }

    /// Maps game intents and steps the wrapped runtime when mapping succeeds.
    @discardableResult
    public mutating func step(_ input: GameStepInput) -> GameStepResult {
        let mappingResult = mapper.map(inputFrame: input.gameInputFrame)

        guard mappingResult.success else {
            let snapshot = runtime.snapshot(diagnostics: mappingResult.diagnostics)
            return GameStepResult(
                input: input,
                mappingResult: mappingResult,
                runtimeStepResult: nil,
                runtimeSnapshot: snapshot,
                diagnostics: mappingResult.diagnostics
            )
        }

        let runtimeStepResult = runtime.step(RuntimeStepInput(
            simulationInputFrame: mappingResult.simulationInputFrame,
            observers: input.observers
        ))
        let diagnostics = Self.combined(
            mappingDiagnostics: mappingResult.diagnostics,
            runtimeDiagnostics: runtimeStepResult.diagnostics
        )

        return GameStepResult(
            input: input,
            mappingResult: mappingResult,
            runtimeStepResult: runtimeStepResult,
            runtimeSnapshot: runtimeStepResult.runtimeSnapshot,
            diagnostics: diagnostics
        )
    }

    private static func combined(
        mappingDiagnostics: DiagnosticReport,
        runtimeDiagnostics: DiagnosticReport
    ) -> DiagnosticReport {
        DiagnosticReport(messages: mappingDiagnostics.messages + runtimeDiagnostics.messages)
    }
}

/// Stable hashing helper for game-layer contracts.
public enum GameHasher {
    /// Hashes one game input frame.
    public static func hash(inputFrame: GameInputFrame) -> StableHash {
        var hasher = StableHasher()
        hasher.combine("Telluric.GameInputFrame.v1")
        hasher.combine(inputFrame)
        return hasher.finalize()
    }

    /// Hashes one intent mapping result from ordered contents.
    public static func hash(
        gameInputFrame: GameInputFrame,
        simulationInputFrame: SimulationInputFrame,
        diagnostics: DiagnosticReport,
        success: Bool
    ) -> StableHash {
        var hasher = StableHasher()
        hasher.combine("Telluric.GameIntentMappingResult.v1")
        hasher.combine(gameInputFrame)
        hasher.combine(simulationInputFrame)
        combine(diagnostics: diagnostics, into: &hasher)
        hasher.combine(success)
        return hasher.finalize()
    }

    /// Hashes one game step result from ordered contents.
    public static func hash(
        input: GameStepInput,
        mappingResult: GameIntentMappingResult,
        runtimeStepResult: RuntimeStepResult?,
        runtimeSnapshot: RuntimeSnapshot,
        diagnostics: DiagnosticReport,
        success: Bool
    ) -> StableHash {
        var hasher = StableHasher()
        hasher.combine("Telluric.GameStepResult.v1")
        hasher.combine(input)
        hasher.combine(mappingResult.stableHash)
        hasher.combine(runtimeStepResult != nil)

        if let runtimeStepResult {
            hasher.combine(runtimeStepResult.frameIndex)
            hasher.combine(runtimeStepResult.simulationSnapshot.tick)
            hasher.combine(runtimeStepResult.simulationSnapshot.stableHash)
            hasher.combine(runtimeStepResult.stableHash)
            hasher.combine(runtimeStepResult.success)
        }

        hasher.combine(runtimeSnapshot.stableHash)
        combine(diagnostics: diagnostics, into: &hasher)
        hasher.combine(success)
        return hasher.finalize()
    }

    private static func combine(diagnostics: DiagnosticReport, into hasher: inout StableHasher) {
        hasher.combine(diagnostics.messages.count)
        for message in diagnostics.messages {
            hasher.combine(message.severity.rawValue)
            hasher.combine(message.code)
            hasher.combine(message.message)
            hasher.combine(message.source ?? "")
            hasher.combine(message.metadata.count)
            for metadata in message.metadata {
                hasher.combine(metadata.key)
                hasher.combine(metadata.value)
            }
        }
    }
}

private func combine(_ vector: Float3, into hasher: inout StableHasher) {
    hasher.combine(vector.x)
    hasher.combine(vector.y)
    hasher.combine(vector.z)
}
