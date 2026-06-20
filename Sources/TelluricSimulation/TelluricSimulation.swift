import TelluricCore
import TelluricDeterminism
import TelluricDiagnostics
import TelluricECS
import TelluricMath

/// Fixed simulation tick rate.
public struct SimulationTickRate: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Ticks per simulated second.
    public let ticksPerSecond: UInt16

    /// Creates a tick rate.
    public init(ticksPerSecond: UInt16) {
        precondition(ticksPerSecond > 0, "ticksPerSecond must be positive")
        self.ticksPerSecond = ticksPerSecond
    }

    /// Fixed delta in seconds for one tick.
    public var fixedDeltaSeconds: Float {
        1 / Float(ticksPerSecond)
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(UInt64(ticksPerSecond))
    }
}

/// Configuration for deterministic simulation stepping.
public struct SimulationConfig: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Semantic engine version for simulation snapshots and hashes.
    public let engineVersion: EngineVersion

    /// Fixed tick rate.
    public let tickRate: SimulationTickRate

    /// Tick used for a newly created simulation world.
    public let initialTick: TickIndex

    /// Stable simulation profile identifier.
    public let profile: NamespaceID

    /// Creates simulation config.
    public init(
        engineVersion: EngineVersion = EngineVersion(major: 1, minor: 0, patch: 0),
        tickRate: SimulationTickRate = SimulationTickRate(ticksPerSecond: 60),
        initialTick: TickIndex = .zero,
        profile: NamespaceID = NamespaceID("simulation.profile.baseline")
    ) {
        self.engineVersion = engineVersion
        self.tickRate = tickRate
        self.initialTick = initialTick
        self.profile = profile
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(engineVersion)
        hasher.combine(tickRate)
        hasher.combine(initialTick)
        hasher.combine(profile)
    }
}

/// Engine-neutral command applied during one fixed simulation tick.
public enum SimulationCommand: Codable, Equatable, Hashable, Sendable, StableHashable {
    case createEntity(entityID: EntityID, components: [ComponentValue])
    case destroyEntity(entityID: EntityID)
    case setPosition(entityID: EntityID, position: PositionComponent)
    case setVelocity(entityID: EntityID, velocity: VelocityComponent)
    case applyTranslation(entityID: EntityID, translation: Float3)

    public func stableHash(into hasher: inout StableHasher) {
        switch self {
        case let .createEntity(entityID, components):
            hasher.combine("createEntity")
            hasher.combine(entityID)
            let orderedComponents = EntityRecord(id: entityID, components: components).components
            hasher.combine(orderedComponents.count)
            for component in orderedComponents {
                hasher.combine(component)
            }

        case let .destroyEntity(entityID):
            hasher.combine("destroyEntity")
            hasher.combine(entityID)

        case let .setPosition(entityID, position):
            hasher.combine("setPosition")
            hasher.combine(entityID)
            hasher.combine(position)

        case let .setVelocity(entityID, velocity):
            hasher.combine("setVelocity")
            hasher.combine(entityID)
            hasher.combine(velocity)

        case let .applyTranslation(entityID, translation):
            hasher.combine("applyTranslation")
            hasher.combine(entityID)
            hasher.combine(translation.x)
            hasher.combine(translation.y)
            hasher.combine(translation.z)
        }
    }
}

/// Ordered commands for one simulation tick.
public struct SimulationCommandBuffer: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Ordered commands.
    public let commands: [SimulationCommand]

    /// Empty command buffer.
    public static let empty = SimulationCommandBuffer(commands: [])

    /// Creates a command buffer.
    public init(commands: [SimulationCommand] = []) {
        self.commands = commands
    }

    /// Returns a new buffer with `command` appended.
    public func appending(_ command: SimulationCommand) -> SimulationCommandBuffer {
        SimulationCommandBuffer(commands: commands + [command])
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(commands.count)
        for command in commands {
            hasher.combine(command)
        }
    }
}

/// Replay-friendly ordered input for one simulation tick.
public struct SimulationInputFrame: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Tick this frame is intended to advance.
    public let tick: TickIndex

    /// Ordered command buffer.
    public let commandBuffer: SimulationCommandBuffer

    /// Creates an input frame.
    public init(tick: TickIndex, commandBuffer: SimulationCommandBuffer = .empty) {
        self.tick = tick
        self.commandBuffer = commandBuffer
    }

    /// Creates an input frame from ordered commands.
    public init(tick: TickIndex, commands: [SimulationCommand]) {
        self.init(tick: tick, commandBuffer: SimulationCommandBuffer(commands: commands))
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(tick)
        hasher.combine(commandBuffer)
    }
}

/// Ordered replay input log.
public struct ReplayInputLog: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Ordered input frames.
    public let frames: [SimulationInputFrame]

    /// Creates a replay input log sorted by tick.
    public init(frames: [SimulationInputFrame]) {
        self.frames = frames.sorted { lhs, rhs in
            lhs.tick < rhs.tick
        }
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(frames.count)
        for frame in frames {
            hasher.combine(frame)
        }
    }
}

/// Ordered simulation snapshot.
public struct SimulationSnapshot: Codable, Equatable, Sendable {
    /// Tick represented by this snapshot.
    public let tick: TickIndex

    /// Ordered entity snapshot.
    public let entities: EntitySnapshot

    /// Stable hash of snapshot contents.
    public let stableHash: StableHash

    /// Creates a simulation snapshot.
    public init(tick: TickIndex, entities: EntitySnapshot) {
        self.tick = tick
        self.entities = entities
        self.stableHash = SimulationHasher.hash(tick: tick, entities: entities)
    }
}

/// Result of one simulation step.
public struct SimulationStepResult: Codable, Equatable, Sendable {
    /// Input frame consumed by this step.
    public let inputFrame: SimulationInputFrame

    /// Snapshot after the step.
    public let snapshot: SimulationSnapshot

    /// Ordered diagnostics produced while applying the frame.
    public let diagnostics: DiagnosticReport

    /// True when the frame was accepted and produced no error diagnostics.
    public let success: Bool

    /// Creates a step result.
    public init(
        inputFrame: SimulationInputFrame,
        snapshot: SimulationSnapshot,
        diagnostics: DiagnosticReport
    ) {
        self.inputFrame = inputFrame
        self.snapshot = snapshot
        self.diagnostics = diagnostics
        self.success = !diagnostics.hasErrors
    }
}

/// Protocol boundary for future engine-neutral simulation systems.
public protocol SimulationSystem: Sendable {
    /// Applies system behavior for one accepted tick.
    func apply(world: inout SimulationWorld, tick: TickIndex) -> DiagnosticReport
}

/// Mutable deterministic simulation world.
public struct SimulationWorld: Sendable {
    /// Simulation config.
    public let config: SimulationConfig

    /// Current tick. The next accepted input frame must match this tick.
    public private(set) var currentTick: TickIndex

    /// Current component storage.
    public private(set) var storage: ComponentStorage

    /// Creates a simulation world.
    public init(
        config: SimulationConfig = SimulationConfig(),
        storage: ComponentStorage = .empty
    ) {
        self.config = config
        self.currentTick = config.initialTick
        self.storage = storage
    }

    /// Current ordered simulation snapshot.
    public func snapshot() -> SimulationSnapshot {
        SimulationSnapshot(tick: currentTick, entities: storage.snapshot)
    }

    /// Applies one input frame, advances one fixed tick when accepted, and returns the resulting snapshot.
    @discardableResult
    public mutating func step(inputFrame: SimulationInputFrame) -> SimulationStepResult {
        var collector = DiagnosticCollector()

        guard inputFrame.tick == currentTick else {
            collector.record(
                severity: .error,
                code: NamespaceID("simulation.input.invalid_tick"),
                message: "SimulationInputFrame.tick must match the simulation world's current tick.",
                source: "TelluricSimulation",
                metadata: [
                    DiagnosticMetadata(key: "expectedTick", value: "\(currentTick.rawValue)"),
                    DiagnosticMetadata(key: "actualTick", value: "\(inputFrame.tick.rawValue)"),
                ]
            )

            return SimulationStepResult(
                inputFrame: inputFrame,
                snapshot: snapshot(),
                diagnostics: collector.report()
            )
        }

        for command in inputFrame.commandBuffer.commands {
            apply(command, diagnostics: &collector)
        }

        integrateVelocities()
        currentTick = currentTick.advanced(by: 1)

        return SimulationStepResult(
            inputFrame: inputFrame,
            snapshot: snapshot(),
            diagnostics: collector.report()
        )
    }

    /// Applies a replay log in ordered frame order.
    @discardableResult
    public mutating func step(replayLog: ReplayInputLog) -> [SimulationStepResult] {
        var results: [SimulationStepResult] = []
        results.reserveCapacity(replayLog.frames.count)

        for frame in replayLog.frames {
            results.append(step(inputFrame: frame))
        }

        return results
    }

    private mutating func apply(_ command: SimulationCommand, diagnostics collector: inout DiagnosticCollector) {
        switch command {
        case let .createEntity(entityID, components):
            guard storage.record(for: entityID) == nil else {
                recordCommandError(
                    code: NamespaceID("simulation.command.entity_exists"),
                    message: "Cannot create an entity that already exists.",
                    entityID: entityID,
                    collector: &collector
                )
                return
            }

            storage = storage.setting(EntityRecord(id: entityID, components: components))

        case let .destroyEntity(entityID):
            guard storage.record(for: entityID) != nil else {
                recordCommandError(
                    code: NamespaceID("simulation.command.entity_missing"),
                    message: "Cannot destroy an entity that does not exist.",
                    entityID: entityID,
                    collector: &collector
                )
                return
            }

            storage = storage.removing(entityID: entityID)

        case let .setPosition(entityID, position):
            guard storage.record(for: entityID) != nil else {
                recordCommandError(
                    code: NamespaceID("simulation.command.entity_missing"),
                    message: "Cannot set position on an entity that does not exist.",
                    entityID: entityID,
                    collector: &collector
                )
                return
            }

            storage = storage.setting(.position(position), for: entityID)

        case let .setVelocity(entityID, velocity):
            guard storage.record(for: entityID) != nil else {
                recordCommandError(
                    code: NamespaceID("simulation.command.entity_missing"),
                    message: "Cannot set velocity on an entity that does not exist.",
                    entityID: entityID,
                    collector: &collector
                )
                return
            }

            storage = storage.setting(.velocity(velocity), for: entityID)

        case let .applyTranslation(entityID, translation):
            guard let record = storage.record(for: entityID) else {
                recordCommandError(
                    code: NamespaceID("simulation.command.entity_missing"),
                    message: "Cannot translate an entity that does not exist.",
                    entityID: entityID,
                    collector: &collector
                )
                return
            }

            let currentPosition = record.position?.value ?? .zero
            let translated = Float3(
                x: currentPosition.x + translation.x,
                y: currentPosition.y + translation.y,
                z: currentPosition.z + translation.z
            )
            storage = storage.setting(.position(PositionComponent(translated)), for: entityID)
        }
    }

    private mutating func integrateVelocities() {
        let delta = config.tickRate.fixedDeltaSeconds

        for record in storage.records {
            guard let position = record.position, let velocity = record.velocity else {
                continue
            }

            let integrated = Float3(
                x: position.value.x + velocity.value.x * delta,
                y: position.value.y + velocity.value.y * delta,
                z: position.value.z + velocity.value.z * delta
            )
            storage = storage.setting(.position(PositionComponent(integrated)), for: record.id)
        }
    }

    private func recordCommandError(
        code: NamespaceID,
        message: String,
        entityID: EntityID,
        collector: inout DiagnosticCollector
    ) {
        collector.record(
            severity: .error,
            code: code,
            message: message,
            source: "TelluricSimulation",
            metadata: [
                DiagnosticMetadata(key: "entity.index", value: "\(entityID.index)"),
                DiagnosticMetadata(key: "entity.generation", value: "\(entityID.generation.rawValue)"),
            ]
        )
    }
}

/// Stable hashing helper for simulation contracts.
public enum SimulationHasher {
    /// Hashes a simulation snapshot from ordered contents.
    public static func hash(snapshot: SimulationSnapshot) -> StableHash {
        hash(tick: snapshot.tick, entities: snapshot.entities)
    }

    /// Hashes simulation tick and ordered entity snapshot.
    public static func hash(tick: TickIndex, entities: EntitySnapshot) -> StableHash {
        var hasher = StableHasher()
        hasher.combine("Telluric.SimulationSnapshot.v1")
        hasher.combine(tick)
        hasher.combine(entities)
        return hasher.finalize()
    }

    /// Hashes an ordered replay input log.
    public static func hash(replayInputLog: ReplayInputLog) -> StableHash {
        var hasher = StableHasher()
        hasher.combine("Telluric.ReplayInputLog.v1")
        hasher.combine(replayInputLog)
        return hasher.finalize()
    }
}
