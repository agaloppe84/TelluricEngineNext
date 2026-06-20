import TelluricBiomes
import TelluricCore
import TelluricDeterminism
import TelluricDiagnostics
import TelluricSimulation
import TelluricStreaming
import TelluricTerrain
import TelluricWorld

/// Configuration for the synchronous engine runtime shell.
public struct RuntimeConfig: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// World generation configuration.
    public let worldConfig: WorldConfig

    /// Engine contract version for runtime snapshots and world generation context.
    public let engineVersion: EngineVersion

    /// Fixed-tick simulation configuration.
    public let simulationConfig: SimulationConfig

    /// Chunk streaming planner configuration.
    public let streamingConfig: ChunkStreamingConfig

    /// Initial neutral streaming observers.
    public let initialObservers: [StreamingObserver]

    /// Terrain generation settings owned by runtime composition.
    public let terrainSettings: TerrainGenerationSettings

    /// Biome resolving rules owned by runtime composition.
    public let biomeRules: BiomeRules

    /// Creates a runtime configuration.
    public init(
        worldConfig: WorldConfig,
        engineVersion: EngineVersion,
        simulationConfig: SimulationConfig,
        streamingConfig: ChunkStreamingConfig,
        initialObservers: [StreamingObserver],
        terrainSettings: TerrainGenerationSettings = .baseline,
        biomeRules: BiomeRules = .baseline
    ) {
        self.worldConfig = worldConfig
        self.engineVersion = engineVersion
        self.simulationConfig = simulationConfig
        self.streamingConfig = streamingConfig
        self.initialObservers = Self.sortedObservers(initialObservers)
        self.terrainSettings = terrainSettings
        self.biomeRules = biomeRules
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(worldConfig)
        hasher.combine(engineVersion)
        hasher.combine(simulationConfig)
        hasher.combine(streamingConfig)
        hasher.combine(initialObservers.count)
        for observer in initialObservers {
            hasher.combine(observer)
        }
        hasher.combine(terrainSettings)
        hasher.combine(biomeRules)
    }

    static func sortedObservers(_ observers: [StreamingObserver]) -> [StreamingObserver] {
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

/// Runtime-owned residency state for a generated chunk.
public enum RuntimeChunkResidency: String, Codable, CaseIterable, Comparable, Sendable, StableHashable {
    case resident
    case failed

    private var rank: UInt8 {
        switch self {
        case .resident:
            return 0
        case .failed:
            return 1
        }
    }

    public static func < (lhs: RuntimeChunkResidency, rhs: RuntimeChunkResidency) -> Bool {
        lhs.rank < rhs.rank
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }

    var streamingState: ChunkStreamingState {
        switch self {
        case .resident:
            return .resident
        case .failed:
            return .failed
        }
    }
}

/// Ordered runtime record for one chunk known to the runtime.
public struct RuntimeChunkRecord: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Chunk coordinate.
    public let chunkCoord: ChunkCoord

    /// Runtime residency state.
    public let residency: RuntimeChunkResidency

    /// Generated aggregate payload when generation succeeded.
    public let payload: ChunkWorldPayload?

    /// Ordered world generation report for this chunk.
    public let report: WorldGenerationReport

    /// Creates a runtime chunk record.
    public init(
        chunkCoord: ChunkCoord,
        residency: RuntimeChunkResidency,
        payload: ChunkWorldPayload?,
        report: WorldGenerationReport
    ) {
        self.chunkCoord = chunkCoord
        self.residency = residency
        self.payload = payload
        self.report = report
    }

    public static func < (lhs: RuntimeChunkRecord, rhs: RuntimeChunkRecord) -> Bool {
        if lhs.chunkCoord != rhs.chunkCoord {
            return lhs.chunkCoord < rhs.chunkCoord
        }

        return lhs.residency < rhs.residency
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(chunkCoord)
        hasher.combine(residency)
        hasher.combine(payload != nil)

        if let payload {
            hasher.combine(payload.chunkCoord)
            hasher.combine(payload.componentHashes.count)
            for componentHash in payload.componentHashes {
                hasher.combine(componentHash)
            }
            hasher.combine(payload.stableHash)
        }

        RuntimeHasher.combine(worldReport: report, into: &hasher)
    }
}

/// Serializable deterministic representation of current runtime state.
public struct RuntimeState: Codable, Equatable, Sendable, StableHashable {
    /// Current runtime frame.
    public let frameIndex: FrameIndex

    /// Ordered resident or failed chunk records.
    public let chunkRecords: [RuntimeChunkRecord]

    /// Current ordered simulation snapshot.
    public let simulationSnapshot: SimulationSnapshot

    /// Creates a runtime state snapshot.
    public init(
        frameIndex: FrameIndex,
        chunkRecords: [RuntimeChunkRecord],
        simulationSnapshot: SimulationSnapshot
    ) {
        self.frameIndex = frameIndex
        self.chunkRecords = chunkRecords.sorted()
        self.simulationSnapshot = simulationSnapshot
    }

    /// Converts runtime chunk records into the planner residency snapshot.
    public var residencySnapshot: ChunkResidencySnapshot {
        ChunkResidencySnapshot(records: chunkRecords.map { record in
            ChunkResidencyRecord(
                chunkCoord: record.chunkCoord,
                state: record.residency.streamingState
            )
        })
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(frameIndex)
        hasher.combine(chunkRecords.count)
        for record in chunkRecords {
            hasher.combine(record)
        }
        hasher.combine(simulationSnapshot.tick)
        hasher.combine(simulationSnapshot.entities)
        hasher.combine(simulationSnapshot.stableHash)
    }
}

/// Ordered deterministic runtime snapshot.
public struct RuntimeSnapshot: Codable, Equatable, Sendable {
    /// Runtime configuration that produced this snapshot.
    public let config: RuntimeConfig

    /// Runtime state contents.
    public let state: RuntimeState

    /// Ordered runtime diagnostics.
    public let diagnostics: DiagnosticReport

    /// True when no runtime diagnostics are errors.
    public let success: Bool

    /// Stable hash over config, state, diagnostics, and success.
    public let stableHash: StableHash

    /// Creates a runtime snapshot and computes its stable hash.
    public init(config: RuntimeConfig, state: RuntimeState, diagnostics: DiagnosticReport) {
        self.config = config
        self.state = state
        self.diagnostics = diagnostics
        self.success = !diagnostics.hasErrors
        self.stableHash = RuntimeHasher.hash(
            config: config,
            state: state,
            diagnostics: diagnostics,
            success: self.success
        )
    }
}

/// Input consumed by one runtime step.
public struct RuntimeStepInput: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Simulation input frame to apply during the step.
    public let simulationInputFrame: SimulationInputFrame

    /// Optional replacement observer set. Nil preserves the runtime's current observers.
    public let observers: [StreamingObserver]?

    /// Creates runtime step input.
    public init(
        simulationInputFrame: SimulationInputFrame,
        observers: [StreamingObserver]? = nil
    ) {
        self.simulationInputFrame = simulationInputFrame
        self.observers = observers.map(RuntimeConfig.sortedObservers)
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(simulationInputFrame)
        hasher.combine(observers != nil)

        if let observers {
            hasher.combine(observers.count)
            for observer in observers {
                hasher.combine(observer)
            }
        }
    }
}

/// Result of one synchronous runtime orchestration step.
public struct RuntimeStepResult: Codable, Equatable, Sendable {
    /// Runtime frame represented by this result.
    public let frameIndex: FrameIndex

    /// Simulation step result produced or reported by the runtime.
    public let simulationStepResult: SimulationStepResult

    /// Convenience access to the simulation snapshot for this runtime result.
    public let simulationSnapshot: SimulationSnapshot

    /// Streaming plan used by this runtime step.
    public let streamingPlan: ChunkStreamingPlan

    /// Ordered records generated during this step.
    public let generatedChunkRecords: [RuntimeChunkRecord]

    /// Ordered chunk coordinates evicted by this step.
    public let evictedChunkCoords: [ChunkCoord]

    /// Deterministic runtime snapshot after the step when successful, or current state when failed.
    public let runtimeSnapshot: RuntimeSnapshot

    /// Ordered diagnostics from runtime validation, streaming, generation, and simulation.
    public let diagnostics: DiagnosticReport

    /// Stable runtime hash for the result snapshot.
    public let stableHash: StableHash

    /// True when runtime orchestration produced no error diagnostics.
    public let success: Bool

    /// Creates a runtime step result.
    public init(
        frameIndex: FrameIndex,
        simulationStepResult: SimulationStepResult,
        streamingPlan: ChunkStreamingPlan,
        generatedChunkRecords: [RuntimeChunkRecord],
        evictedChunkCoords: [ChunkCoord],
        runtimeSnapshot: RuntimeSnapshot,
        diagnostics: DiagnosticReport
    ) {
        self.frameIndex = frameIndex
        self.simulationStepResult = simulationStepResult
        self.simulationSnapshot = simulationStepResult.snapshot
        self.streamingPlan = streamingPlan
        self.generatedChunkRecords = generatedChunkRecords.sorted()
        self.evictedChunkCoords = evictedChunkCoords.sorted()
        self.runtimeSnapshot = runtimeSnapshot
        self.diagnostics = diagnostics
        self.stableHash = runtimeSnapshot.stableHash
        self.success = !diagnostics.hasErrors && streamingPlan.success && simulationStepResult.success && runtimeSnapshot.success
    }
}

/// Stable hashing helper for runtime snapshots.
public enum RuntimeHasher {
    /// Hashes ordered runtime snapshot contents.
    public static func hash(
        config: RuntimeConfig,
        state: RuntimeState,
        diagnostics: DiagnosticReport,
        success: Bool
    ) -> StableHash {
        var hasher = StableHasher()
        hasher.combine("Telluric.RuntimeSnapshot.v1")
        hasher.combine(config)
        hasher.combine(state)
        combine(diagnostics: diagnostics, into: &hasher)
        hasher.combine(success)
        return hasher.finalize()
    }

    static func combine(worldReport: WorldGenerationReport, into hasher: inout StableHasher) {
        hasher.combine(worldReport.issues.count)
        for issue in worldReport.issues {
            hasher.combine(issue.severity.rawValue)
            hasher.combine(issue.code)
            hasher.combine(issue.message)
            hasher.combine(issue.chunkCoord != nil)
            if let chunkCoord = issue.chunkCoord {
                hasher.combine(chunkCoord)
            }
        }
    }

    static func combine(diagnostics: DiagnosticReport, into hasher: inout StableHasher) {
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

/// Synchronous runtime shell that coordinates engine systems without app, gameplay, or rendering concerns.
public struct TelluricRuntime: Sendable {
    /// Runtime configuration.
    public let config: RuntimeConfig

    /// Current runtime frame.
    public private(set) var frameIndex: FrameIndex

    /// Current neutral streaming observers.
    public private(set) var observers: [StreamingObserver]

    private var chunkRecords: [RuntimeChunkRecord]
    private var simulationWorld: SimulationWorld
    private let streamingPlanner: ChunkStreamingPlanner
    private let worldGenerator: DeterministicWorldGenerator

    /// Creates a runtime with empty residency and simulation state.
    public init(config: RuntimeConfig) {
        self.config = config
        self.frameIndex = .zero
        self.observers = config.initialObservers
        self.chunkRecords = []
        self.simulationWorld = SimulationWorld(config: config.simulationConfig)
        self.streamingPlanner = ChunkStreamingPlanner()
        self.worldGenerator = DeterministicWorldGenerator(
            componentGenerator: DeterministicTerrainBiomeChunkGenerator(
                terrainSettings: config.terrainSettings,
                biomeRules: config.biomeRules
            )
        )
    }

    /// Current deterministic runtime state.
    public func state() -> RuntimeState {
        RuntimeState(
            frameIndex: frameIndex,
            chunkRecords: chunkRecords,
            simulationSnapshot: simulationWorld.snapshot()
        )
    }

    /// Current deterministic runtime snapshot with optional diagnostics.
    public func snapshot(diagnostics: DiagnosticReport = DiagnosticReport(messages: [])) -> RuntimeSnapshot {
        RuntimeSnapshot(config: config, state: state(), diagnostics: diagnostics)
    }

    /// Performs one synchronous runtime orchestration step.
    @discardableResult
    public mutating func step(_ input: RuntimeStepInput) -> RuntimeStepResult {
        let nextObservers = input.observers ?? observers
        let startingState = state()
        let streamingPlan = streamingPlanner.plan(
            config: config.streamingConfig,
            observers: nextObservers,
            residency: startingState.residencySnapshot
        )

        var collector = DiagnosticCollector()
        appendRuntimeConfigDiagnostics(observers: nextObservers, to: &collector)
        append(diagnostics: streamingPlan.diagnostics, to: &collector)

        var nextChunkRecords = chunkRecords
        var nextSimulationWorld = simulationWorld
        var generatedChunkRecords: [RuntimeChunkRecord] = []
        let evictedChunkCoords = streamingPlan.chunksToEvict.map(\.chunkCoord).sorted()

        if !collector.report().hasErrors && streamingPlan.success {
            nextChunkRecords = nextChunkRecords.filter { record in
                !evictedChunkCoords.contains(record.chunkCoord)
            }

            for request in streamingPlan.chunksToRequest {
                let generatedRecord = generateChunkRecord(
                    chunkCoord: request.chunkCoord,
                    diagnostics: &collector
                )
                generatedChunkRecords.append(generatedRecord)
                nextChunkRecords = Self.replacing(generatedRecord, in: nextChunkRecords)
            }
        }

        let simulationStepResult: SimulationStepResult
        if !collector.report().hasErrors && streamingPlan.success {
            simulationStepResult = nextSimulationWorld.step(inputFrame: input.simulationInputFrame)
            append(diagnostics: simulationStepResult.diagnostics, to: &collector)
        } else {
            simulationStepResult = SimulationStepResult(
                inputFrame: input.simulationInputFrame,
                snapshot: simulationWorld.snapshot(),
                diagnostics: DiagnosticReport(messages: [])
            )
        }

        let diagnostics = collector.report()
        let shouldCommit = !diagnostics.hasErrors && streamingPlan.success && simulationStepResult.success
        let resultFrameIndex = shouldCommit ? frameIndex.advanced(by: 1) : frameIndex
        let resultState: RuntimeState

        if shouldCommit {
            frameIndex = resultFrameIndex
            observers = nextObservers
            chunkRecords = nextChunkRecords.sorted()
            simulationWorld = nextSimulationWorld
            resultState = state()
        } else {
            resultState = startingState
        }

        let runtimeSnapshot = RuntimeSnapshot(
            config: config,
            state: resultState,
            diagnostics: diagnostics
        )

        return RuntimeStepResult(
            frameIndex: resultFrameIndex,
            simulationStepResult: simulationStepResult,
            streamingPlan: streamingPlan,
            generatedChunkRecords: generatedChunkRecords,
            evictedChunkCoords: evictedChunkCoords,
            runtimeSnapshot: runtimeSnapshot,
            diagnostics: diagnostics
        )
    }

    private func generateChunkRecord(
        chunkCoord: ChunkCoord,
        diagnostics collector: inout DiagnosticCollector
    ) -> RuntimeChunkRecord {
        do {
            let result = try worldGenerator.generateChunk(
                at: chunkCoord,
                context: WorldGenerationContext(
                    config: config.worldConfig,
                    engineVersion: config.engineVersion
                )
            )
            append(worldReport: result.report, to: &collector)
            return RuntimeChunkRecord(
                chunkCoord: chunkCoord,
                residency: .resident,
                payload: result.payload,
                report: result.report
            )
        } catch let error as WorldGenerationError {
            append(worldReport: error.report, to: &collector)
            return RuntimeChunkRecord(
                chunkCoord: chunkCoord,
                residency: .failed,
                payload: nil,
                report: error.report
            )
        } catch {
            let report = WorldGenerationReport(issues: [
                WorldGenerationIssue(
                    severity: .error,
                    code: NamespaceID("runtime.generation.unhandled_error"),
                    message: "Chunk generation failed with an unhandled error.",
                    chunkCoord: chunkCoord
                ),
            ])
            append(worldReport: report, to: &collector)
            return RuntimeChunkRecord(
                chunkCoord: chunkCoord,
                residency: .failed,
                payload: nil,
                report: report
            )
        }
    }

    private func appendRuntimeConfigDiagnostics(
        observers: [StreamingObserver],
        to collector: inout DiagnosticCollector
    ) {
        append(worldReport: WorldGenerationValidation.validate(config: config.worldConfig), to: &collector)

        if config.streamingConfig.chunkSize != config.worldConfig.chunkSize {
            collector.record(
                severity: .error,
                code: NamespaceID("runtime.config.chunk_size_mismatch"),
                message: "RuntimeConfig streaming chunk size must match WorldConfig.chunkSize.",
                source: "TelluricRuntime",
                metadata: [
                    DiagnosticMetadata(key: "world.chunkSize", value: "\(config.worldConfig.chunkSize)"),
                    DiagnosticMetadata(key: "streaming.chunkSize", value: "\(config.streamingConfig.chunkSize)"),
                ]
            )
        }

        if config.simulationConfig.engineVersion != config.engineVersion {
            collector.record(
                severity: .error,
                code: NamespaceID("runtime.config.engine_version_mismatch"),
                message: "RuntimeConfig engineVersion must match SimulationConfig.engineVersion.",
                source: "TelluricRuntime",
                metadata: [
                    DiagnosticMetadata(key: "runtime.engineVersion", value: config.engineVersion.description),
                    DiagnosticMetadata(key: "simulation.engineVersion", value: config.simulationConfig.engineVersion.description),
                ]
            )
        }

        if observers.isEmpty {
            collector.record(
                severity: .error,
                code: NamespaceID("runtime.config.missing_observer"),
                message: "Runtime requires at least one streaming observer.",
                source: "TelluricRuntime"
            )
        }
    }

    private func append(worldReport: WorldGenerationReport, to collector: inout DiagnosticCollector) {
        for issue in worldReport.issues {
            collector.record(
                severity: Self.diagnosticSeverity(for: issue.severity),
                code: issue.code,
                message: issue.message,
                source: "TelluricRuntime.WorldGeneration",
                metadata: issue.chunkCoord.map(Self.metadata(for:)) ?? []
            )
        }
    }

    private func append(diagnostics: DiagnosticReport, to collector: inout DiagnosticCollector) {
        for message in diagnostics.messages {
            collector.record(message)
        }
    }

    private static func replacing(
        _ record: RuntimeChunkRecord,
        in records: [RuntimeChunkRecord]
    ) -> [RuntimeChunkRecord] {
        (records.filter { $0.chunkCoord != record.chunkCoord } + [record]).sorted()
    }

    private static func diagnosticSeverity(for severity: WorldGenerationIssueSeverity) -> DiagnosticSeverity {
        switch severity {
        case .info:
            return .info
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }

    private static func metadata(for chunkCoord: ChunkCoord) -> [DiagnosticMetadata] {
        [
            DiagnosticMetadata(key: "chunk.x", value: "\(chunkCoord.x)"),
            DiagnosticMetadata(key: "chunk.y", value: "\(chunkCoord.y)"),
            DiagnosticMetadata(key: "chunk.z", value: "\(chunkCoord.z)"),
        ]
    }
}
