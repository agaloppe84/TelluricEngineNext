import TelluricCore
import TelluricDeterminism
import TelluricDiagnostics
import TelluricMath
import TelluricWorld

/// Stable identifier for a streaming observer.
public struct StreamingObserverID: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Stable observer identifier.
    public let rawValue: String

    /// Creates a streaming observer identifier.
    public init(_ rawValue: String) {
        precondition(!rawValue.isEmpty, "StreamingObserverID must not be empty")
        self.rawValue = rawValue
    }

    public static func < (lhs: StreamingObserverID, rhs: StreamingObserverID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

/// Integer world-space observer used by the pure streaming planner.
public struct StreamingObserver: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Stable observer ID.
    public let id: StreamingObserverID

    /// Integer world-cell position. Runtime code should quantize any floating position before planning.
    public let worldPosition: Int3

    /// Creates a streaming observer.
    public init(id: StreamingObserverID, worldPosition: Int3) {
        self.id = id
        self.worldPosition = worldPosition
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(id)
        hasher.combine(worldPosition)
    }
}

/// Configuration for deterministic chunk streaming planning.
public struct ChunkStreamingConfig: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Positive chunk size in integer world cells.
    public let chunkSize: Int

    /// Inclusive horizontal chunk radius around each observer.
    public let radius: Int

    /// Creates streaming config from explicit values.
    public init(chunkSize: Int, radius: Int) {
        self.chunkSize = chunkSize
        self.radius = radius
    }

    /// Creates streaming config from a world config and an explicit radius.
    public init(worldConfig: WorldConfig, radius: Int) {
        self.init(chunkSize: worldConfig.chunkSize, radius: radius)
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(chunkSize)
        hasher.combine(radius)
    }
}

/// Known residency or work state for a chunk.
public enum ChunkStreamingState: String, Codable, CaseIterable, Comparable, Sendable {
    case unloaded
    case requested
    case generating
    case ready
    case resident
    case evicting
    case failed

    private var rank: UInt8 {
        switch self {
        case .unloaded:
            return 0
        case .requested:
            return 1
        case .generating:
            return 2
        case .ready:
            return 3
        case .resident:
            return 4
        case .evicting:
            return 5
        case .failed:
            return 6
        }
    }

    public static func < (lhs: ChunkStreamingState, rhs: ChunkStreamingState) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Current known residency state for one chunk.
public struct ChunkResidencyRecord: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Chunk coordinate for this record.
    public let chunkCoord: ChunkCoord

    /// Current streaming state for this chunk.
    public let state: ChunkStreamingState

    /// Creates a residency record.
    public init(chunkCoord: ChunkCoord, state: ChunkStreamingState) {
        self.chunkCoord = chunkCoord
        self.state = state
    }

    public static func < (lhs: ChunkResidencyRecord, rhs: ChunkResidencyRecord) -> Bool {
        if lhs.chunkCoord != rhs.chunkCoord {
            return lhs.chunkCoord < rhs.chunkCoord
        }

        return lhs.state < rhs.state
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(chunkCoord)
        hasher.combine(state.rawValue)
    }
}

/// Ordered snapshot of currently known chunk residency.
public struct ChunkResidencySnapshot: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Ordered residency records.
    public let records: [ChunkResidencyRecord]

    /// Empty residency snapshot.
    public static let empty = ChunkResidencySnapshot(records: [])

    /// Creates a snapshot from records, sorted by coordinate and state.
    public init(records: [ChunkResidencyRecord]) {
        self.records = records.sorted()
    }

    /// Returns the first record for `chunkCoord`, if present.
    public func record(for chunkCoord: ChunkCoord) -> ChunkResidencyRecord? {
        records.first { $0.chunkCoord == chunkCoord }
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(records.count)
        for record in records {
            hasher.combine(record)
        }
    }
}

/// Deterministic priority for one chunk request or keep decision.
public struct ChunkStreamingPriority: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Manhattan distance from the closest observer chunk.
    public let manhattanDistance: Int64

    /// Squared horizontal distance from the closest observer chunk.
    public let squaredDistance: Int64

    /// Ordinal of the closest observer after deterministic observer sorting.
    public let observerOrdinal: Int

    /// Creates a priority. Lower values sort first and represent higher priority.
    public init(manhattanDistance: Int64, squaredDistance: Int64, observerOrdinal: Int) {
        precondition(manhattanDistance >= 0, "manhattanDistance must be non-negative")
        precondition(squaredDistance >= 0, "squaredDistance must be non-negative")
        precondition(observerOrdinal >= 0, "observerOrdinal must be non-negative")
        self.manhattanDistance = manhattanDistance
        self.squaredDistance = squaredDistance
        self.observerOrdinal = observerOrdinal
    }

    public static func < (lhs: ChunkStreamingPriority, rhs: ChunkStreamingPriority) -> Bool {
        if lhs.manhattanDistance != rhs.manhattanDistance {
            return lhs.manhattanDistance < rhs.manhattanDistance
        }

        if lhs.squaredDistance != rhs.squaredDistance {
            return lhs.squaredDistance < rhs.squaredDistance
        }

        return lhs.observerOrdinal < rhs.observerOrdinal
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(manhattanDistance)
        hasher.combine(squaredDistance)
        hasher.combine(observerOrdinal)
    }
}

/// Planned request or keep entry for a desired chunk.
public struct ChunkStreamingRequest: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Desired chunk coordinate.
    public let chunkCoord: ChunkCoord

    /// Deterministic nearest-first priority.
    public let priority: ChunkStreamingPriority

    /// Ordered observers that want this chunk.
    public let observerIDs: [StreamingObserverID]

    /// Creates a request or keep entry.
    public init(
        chunkCoord: ChunkCoord,
        priority: ChunkStreamingPriority,
        observerIDs: [StreamingObserverID]
    ) {
        self.chunkCoord = chunkCoord
        self.priority = priority
        self.observerIDs = observerIDs.sorted()
    }

    public static func < (lhs: ChunkStreamingRequest, rhs: ChunkStreamingRequest) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority < rhs.priority
        }

        if lhs.chunkCoord != rhs.chunkCoord {
            return lhs.chunkCoord < rhs.chunkCoord
        }

        return lhs.observerIDs.lexicographicallyPrecedes(rhs.observerIDs)
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(chunkCoord)
        hasher.combine(priority)
        hasher.combine(observerIDs.count)
        for observerID in observerIDs {
            hasher.combine(observerID)
        }
    }
}

/// Deterministic chunk streaming plan.
public struct ChunkStreamingPlan: Codable, Equatable, Sendable {
    /// Config used to produce this plan.
    public let config: ChunkStreamingConfig

    /// Ordered observers used to produce this plan.
    public let observers: [StreamingObserver]

    /// Desired chunks that are not already usable or in progress.
    public let chunksToRequest: [ChunkStreamingRequest]

    /// Desired chunks already resident, ready, requested, or generating.
    public let chunksToKeep: [ChunkStreamingRequest]

    /// Existing chunks that are outside the desired set.
    public let chunksToEvict: [ChunkResidencyRecord]

    /// Ordered planner diagnostics.
    public let diagnostics: DiagnosticReport

    /// Stable hash over ordered plan contents.
    public let stableHash: StableHash

    /// True when validation produced no errors.
    public let success: Bool

    /// Creates a plan and computes its stable hash.
    public init(
        config: ChunkStreamingConfig,
        observers: [StreamingObserver],
        chunksToRequest: [ChunkStreamingRequest],
        chunksToKeep: [ChunkStreamingRequest],
        chunksToEvict: [ChunkResidencyRecord],
        diagnostics: DiagnosticReport
    ) {
        self.config = config
        self.observers = Self.sortedObservers(observers)
        self.chunksToRequest = chunksToRequest.sorted()
        self.chunksToKeep = chunksToKeep.sorted()
        self.chunksToEvict = chunksToEvict.sorted()
        self.diagnostics = diagnostics
        self.success = !diagnostics.hasErrors
        self.stableHash = ChunkStreamingHasher.hash(
            config: self.config,
            observers: self.observers,
            chunksToRequest: self.chunksToRequest,
            chunksToKeep: self.chunksToKeep,
            chunksToEvict: self.chunksToEvict,
            diagnostics: self.diagnostics,
            success: self.success
        )
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

/// Stable hashing helper for streaming plans.
public enum ChunkStreamingHasher {
    /// Hashes ordered streaming plan contents.
    public static func hash(
        config: ChunkStreamingConfig,
        observers: [StreamingObserver],
        chunksToRequest: [ChunkStreamingRequest],
        chunksToKeep: [ChunkStreamingRequest],
        chunksToEvict: [ChunkResidencyRecord],
        diagnostics: DiagnosticReport,
        success: Bool
    ) -> StableHash {
        var hasher = StableHasher()
        hasher.combine("Telluric.ChunkStreamingPlan.v1")
        hasher.combine(config)
        hasher.combine(observers.count)
        for observer in observers {
            hasher.combine(observer)
        }
        hasher.combine(chunksToRequest.count)
        for request in chunksToRequest {
            hasher.combine(request)
        }
        hasher.combine(chunksToKeep.count)
        for keep in chunksToKeep {
            hasher.combine(keep)
        }
        hasher.combine(chunksToEvict.count)
        for evict in chunksToEvict {
            hasher.combine(evict)
        }
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

/// Pure deterministic chunk streaming planner.
public struct ChunkStreamingPlanner: Sendable {
    /// Creates a streaming planner.
    public init() {}

    /// Builds a deterministic streaming plan for ordered observers and current residency.
    public func plan(
        config: ChunkStreamingConfig,
        observers: [StreamingObserver],
        residency: ChunkResidencySnapshot
    ) -> ChunkStreamingPlan {
        let sortedObservers = sortedObservers(observers)
        let validationDiagnostics = validate(
            config: config,
            observers: sortedObservers,
            residency: residency
        )

        if validationDiagnostics.hasErrors {
            return ChunkStreamingPlan(
                config: config,
                observers: sortedObservers,
                chunksToRequest: [],
                chunksToKeep: [],
                chunksToEvict: [],
                diagnostics: validationDiagnostics
            )
        }

        let desired = desiredRequests(config: config, observers: sortedObservers)
        var chunksToRequest: [ChunkStreamingRequest] = []
        var chunksToKeep: [ChunkStreamingRequest] = []

        for request in desired {
            if let record = residency.record(for: request.chunkCoord), Self.isKeepState(record.state) {
                chunksToKeep.append(request)
            } else {
                chunksToRequest.append(request)
            }
        }

        let chunksToEvict = residency.records.filter { record in
            !desired.contains { $0.chunkCoord == record.chunkCoord }
        }

        return ChunkStreamingPlan(
            config: config,
            observers: sortedObservers,
            chunksToRequest: chunksToRequest,
            chunksToKeep: chunksToKeep,
            chunksToEvict: chunksToEvict,
            diagnostics: validationDiagnostics
        )
    }

    /// Converts an integer world position to a chunk coordinate using floor division.
    public static func chunkCoord(forWorldPosition worldPosition: Int3, chunkSize: Int) -> ChunkCoord {
        precondition(chunkSize > 0, "chunkSize must be positive")
        let divisor = Int64(chunkSize)
        return ChunkCoord(
            x: floorDiv(worldPosition.x, by: divisor),
            y: floorDiv(worldPosition.y, by: divisor),
            z: floorDiv(worldPosition.z, by: divisor)
        )
    }

    private func validate(
        config: ChunkStreamingConfig,
        observers: [StreamingObserver],
        residency: ChunkResidencySnapshot
    ) -> DiagnosticReport {
        var collector = DiagnosticCollector()

        if config.chunkSize <= 0 {
            collector.record(
                severity: .error,
                code: NamespaceID("streaming.config.invalid_chunk_size"),
                message: "ChunkStreamingConfig.chunkSize must be positive.",
                source: "TelluricStreaming"
            )
        }

        if config.radius < 0 {
            collector.record(
                severity: .error,
                code: NamespaceID("streaming.config.invalid_radius"),
                message: "ChunkStreamingConfig.radius must be non-negative.",
                source: "TelluricStreaming"
            )
        }

        if gridWouldOverflow(radius: config.radius) {
            collector.record(
                severity: .error,
                code: NamespaceID("streaming.config.grid_too_large"),
                message: "ChunkStreamingConfig.radius produces a grid that is too large.",
                source: "TelluricStreaming"
            )
        }

        appendDuplicateObserverDiagnostics(observers, to: &collector)
        appendResidencyDiagnostics(residency, to: &collector)
        return collector.report()
    }

    private func desiredRequests(
        config: ChunkStreamingConfig,
        observers: [StreamingObserver]
    ) -> [ChunkStreamingRequest] {
        var candidates: [ChunkStreamingRequest] = []
        let radius = Int64(config.radius)

        for (observerOrdinal, observer) in observers.enumerated() {
            let center = Self.chunkCoord(forWorldPosition: observer.worldPosition, chunkSize: config.chunkSize)

            for zOffset in (-radius)...radius {
                for xOffset in (-radius)...radius {
                    let chunkCoord = ChunkCoord(
                        x: center.x + xOffset,
                        y: center.y,
                        z: center.z + zOffset
                    )
                    let priority = Self.priority(
                        chunkCoord: chunkCoord,
                        center: center,
                        observerOrdinal: observerOrdinal
                    )
                    candidates.append(ChunkStreamingRequest(
                        chunkCoord: chunkCoord,
                        priority: priority,
                        observerIDs: [observer.id]
                    ))
                }
            }
        }

        return mergeCandidates(candidates)
    }

    private func mergeCandidates(_ candidates: [ChunkStreamingRequest]) -> [ChunkStreamingRequest] {
        let sortedCandidates = candidates.sorted { lhs, rhs in
            if lhs.chunkCoord != rhs.chunkCoord {
                return lhs.chunkCoord < rhs.chunkCoord
            }

            return lhs < rhs
        }
        var merged: [ChunkStreamingRequest] = []
        var index = 0

        while index < sortedCandidates.count {
            let chunkCoord = sortedCandidates[index].chunkCoord
            var bestPriority = sortedCandidates[index].priority
            var observerIDs: [StreamingObserverID] = []

            while index < sortedCandidates.count && sortedCandidates[index].chunkCoord == chunkCoord {
                let candidate = sortedCandidates[index]
                if candidate.priority < bestPriority {
                    bestPriority = candidate.priority
                }

                for observerID in candidate.observerIDs where !observerIDs.contains(observerID) {
                    observerIDs.append(observerID)
                }

                index += 1
            }

            merged.append(ChunkStreamingRequest(
                chunkCoord: chunkCoord,
                priority: bestPriority,
                observerIDs: observerIDs.sorted()
            ))
        }

        return merged.sorted()
    }

    private static func priority(
        chunkCoord: ChunkCoord,
        center: ChunkCoord,
        observerOrdinal: Int
    ) -> ChunkStreamingPriority {
        let dx = chunkCoord.x - center.x
        let dz = chunkCoord.z - center.z
        let absX = magnitude(dx)
        let absZ = magnitude(dz)
        return ChunkStreamingPriority(
            manhattanDistance: clampedAdd(absX, absZ),
            squaredDistance: clampedAdd(clampedMultiply(absX, absX), clampedMultiply(absZ, absZ)),
            observerOrdinal: observerOrdinal
        )
    }

    private func sortedObservers(_ observers: [StreamingObserver]) -> [StreamingObserver] {
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

    private static func isKeepState(_ state: ChunkStreamingState) -> Bool {
        switch state {
        case .requested, .generating, .ready, .resident:
            return true
        case .unloaded, .evicting, .failed:
            return false
        }
    }

    private func appendDuplicateObserverDiagnostics(
        _ observers: [StreamingObserver],
        to collector: inout DiagnosticCollector
    ) {
        for index in observers.indices.dropFirst() where observers[index].id == observers[index - 1].id {
            collector.record(
                severity: .error,
                code: NamespaceID("streaming.observer.duplicate_id"),
                message: "Streaming observers must have unique IDs.",
                source: "TelluricStreaming",
                metadata: [
                    DiagnosticMetadata(key: "observer.id", value: observers[index].id.rawValue),
                ]
            )
        }
    }

    private func appendResidencyDiagnostics(
        _ residency: ChunkResidencySnapshot,
        to collector: inout DiagnosticCollector
    ) {
        let records = residency.records

        for record in records where record.state == .unloaded {
            collector.record(
                severity: .error,
                code: NamespaceID("streaming.residency.unloaded_record"),
                message: "Unloaded chunks must be omitted from ChunkResidencySnapshot.",
                source: "TelluricStreaming",
                metadata: Self.metadata(for: record.chunkCoord)
            )
        }

        for index in records.indices.dropFirst() where records[index].chunkCoord == records[index - 1].chunkCoord {
            collector.record(
                severity: .error,
                code: NamespaceID("streaming.residency.duplicate_chunk"),
                message: "ChunkResidencySnapshot contains duplicate chunk records.",
                source: "TelluricStreaming",
                metadata: Self.metadata(for: records[index].chunkCoord)
            )
        }
    }

    private func gridWouldOverflow(radius: Int) -> Bool {
        guard radius >= 0 else {
            return false
        }

        let (doubled, doubledOverflow) = radius.multipliedReportingOverflow(by: 2)
        let (span, spanOverflow) = doubled.addingReportingOverflow(1)
        let (_, countOverflow) = span.multipliedReportingOverflow(by: span)
        return doubledOverflow || spanOverflow || countOverflow
    }

    private static func floorDiv(_ value: Int64, by divisor: Int64) -> Int64 {
        let quotient = value / divisor
        let remainder = value % divisor
        return remainder < 0 ? quotient - 1 : quotient
    }

    private static func magnitude(_ value: Int64) -> Int64 {
        if value == Int64.min {
            return Int64.max
        }

        return value < 0 ? -value : value
    }

    private static func clampedAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int64.max : value
    }

    private static func clampedMultiply(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (value, overflow) = lhs.multipliedReportingOverflow(by: rhs)
        return overflow ? Int64.max : value
    }

    private static func metadata(for chunkCoord: ChunkCoord) -> [DiagnosticMetadata] {
        [
            DiagnosticMetadata(key: "chunk.x", value: "\(chunkCoord.x)"),
            DiagnosticMetadata(key: "chunk.y", value: "\(chunkCoord.y)"),
            DiagnosticMetadata(key: "chunk.z", value: "\(chunkCoord.z)"),
        ]
    }
}
