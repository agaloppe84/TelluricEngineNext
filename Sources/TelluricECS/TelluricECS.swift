import TelluricCore
import TelluricDeterminism
import TelluricMath

/// Lifecycle generation for an entity identifier.
public struct EntityGeneration: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Raw generation value.
    public let rawValue: UInt32

    /// The first entity generation.
    public static let zero = EntityGeneration(rawValue: 0)

    /// Creates an entity generation.
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static func < (lhs: EntityGeneration, rhs: EntityGeneration) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(UInt64(rawValue))
    }
}

/// Stable engine-level entity identifier.
public struct EntityID: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Stable entity index.
    public let index: UInt64

    /// Lifecycle generation for this index.
    public let generation: EntityGeneration

    /// Creates an entity identifier.
    public init(index: UInt64, generation: EntityGeneration = .zero) {
        self.index = index
        self.generation = generation
    }

    public static func < (lhs: EntityID, rhs: EntityID) -> Bool {
        if lhs.index != rhs.index {
            return lhs.index < rhs.index
        }

        return lhs.generation < rhs.generation
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(index)
        hasher.combine(generation)
    }
}

/// Stable component type identifier.
public struct ComponentTypeID: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Stable component namespace.
    public let rawValue: NamespaceID

    /// Built-in neutral position component type.
    public static let position = ComponentTypeID("ecs.component.position")

    /// Built-in neutral velocity component type.
    public static let velocity = ComponentTypeID("ecs.component.velocity")

    /// Creates a component type identifier.
    public init(_ rawValue: NamespaceID) {
        self.rawValue = rawValue
    }

    /// Creates a component type identifier from a namespace string.
    public init(_ rawValue: String) {
        self.init(NamespaceID(rawValue))
    }

    public static func < (lhs: ComponentTypeID, rhs: ComponentTypeID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

/// Stable key for one entity component slot.
public struct ComponentKey: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Entity that owns the component.
    public let entityID: EntityID

    /// Component type stored for the entity.
    public let componentTypeID: ComponentTypeID

    /// Creates a component key.
    public init(entityID: EntityID, componentTypeID: ComponentTypeID) {
        self.entityID = entityID
        self.componentTypeID = componentTypeID
    }

    public static func < (lhs: ComponentKey, rhs: ComponentKey) -> Bool {
        if lhs.entityID != rhs.entityID {
            return lhs.entityID < rhs.entityID
        }

        return lhs.componentTypeID < rhs.componentTypeID
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(entityID)
        hasher.combine(componentTypeID)
    }
}

/// Neutral position component stored in world-space engine coordinates.
public struct PositionComponent: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Component value.
    public let value: Float3

    /// Creates a position component.
    public init(_ value: Float3) {
        self.value = value
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(value.x)
        hasher.combine(value.y)
        hasher.combine(value.z)
    }
}

/// Neutral velocity component in world units per second.
public struct VelocityComponent: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Component value.
    public let value: Float3

    /// Creates a velocity component.
    public init(_ value: Float3) {
        self.value = value
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(value.x)
        hasher.combine(value.y)
        hasher.combine(value.z)
    }
}

/// Engine-neutral component payloads currently understood by the foundation ECS.
public enum ComponentValue: Codable, Equatable, Hashable, Sendable, StableHashable {
    case position(PositionComponent)
    case velocity(VelocityComponent)

    /// Stable component type ID for this value.
    public var componentTypeID: ComponentTypeID {
        switch self {
        case .position:
            return .position
        case .velocity:
            return .velocity
        }
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(componentTypeID)

        switch self {
        case let .position(component):
            hasher.combine(component)
        case let .velocity(component):
            hasher.combine(component)
        }
    }
}

/// Ordered component record for one entity.
public struct EntityRecord: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Entity identifier.
    public let id: EntityID

    /// Ordered component values. At most one component exists per component type.
    public let components: [ComponentValue]

    /// Creates an entity record, applying last-write-wins for duplicate component types.
    public init(id: EntityID, components: [ComponentValue] = []) {
        self.id = id
        self.components = Self.orderedUniqueComponents(components)
    }

    /// Returns a component value by type.
    public func componentValue(_ componentTypeID: ComponentTypeID) -> ComponentValue? {
        components.first { $0.componentTypeID == componentTypeID }
    }

    /// Returns the position component if present.
    public var position: PositionComponent? {
        guard case let .position(component)? = componentValue(.position) else {
            return nil
        }

        return component
    }

    /// Returns the velocity component if present.
    public var velocity: VelocityComponent? {
        guard case let .velocity(component)? = componentValue(.velocity) else {
            return nil
        }

        return component
    }

    /// Returns a new record with `component` set.
    public func setting(_ component: ComponentValue) -> EntityRecord {
        EntityRecord(id: id, components: components + [component])
    }

    /// Returns a new record without `componentTypeID`.
    public func removing(_ componentTypeID: ComponentTypeID) -> EntityRecord {
        EntityRecord(id: id, components: components.filter { $0.componentTypeID != componentTypeID })
    }

    public static func < (lhs: EntityRecord, rhs: EntityRecord) -> Bool {
        lhs.id < rhs.id
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(id)
        hasher.combine(components.count)
        for component in components {
            hasher.combine(component)
        }
    }

    private static func orderedUniqueComponents(_ components: [ComponentValue]) -> [ComponentValue] {
        var unique: [ComponentValue] = []

        for component in components {
            unique.removeAll { $0.componentTypeID == component.componentTypeID }
            unique.append(component)
        }

        return unique.sorted { lhs, rhs in
            lhs.componentTypeID < rhs.componentTypeID
        }
    }
}

/// Ordered snapshot of entity records.
public struct EntitySnapshot: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Ordered entities.
    public let entities: [EntityRecord]

    /// Creates a snapshot, applying last-write-wins for duplicate entity IDs.
    public init(entities: [EntityRecord]) {
        self.entities = Self.orderedUniqueEntities(entities)
    }

    /// Returns an entity record by ID.
    public func record(for entityID: EntityID) -> EntityRecord? {
        entities.first { $0.id == entityID }
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(entities.count)
        for entity in entities {
            hasher.combine(entity)
        }
    }

    private static func orderedUniqueEntities(_ entities: [EntityRecord]) -> [EntityRecord] {
        var unique: [EntityRecord] = []

        for entity in entities {
            unique.removeAll { $0.id == entity.id }
            unique.append(entity)
        }

        return unique.sorted()
    }
}

/// Minimal ordered component storage used by simulation contracts.
public struct ComponentStorage: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Ordered entity records.
    public let records: [EntityRecord]

    /// Empty component storage.
    public static let empty = ComponentStorage(records: [])

    /// Creates storage from records, applying deterministic ordering.
    public init(records: [EntityRecord]) {
        self.records = EntitySnapshot(entities: records).entities
    }

    /// Returns the entity record for `entityID`.
    public func record(for entityID: EntityID) -> EntityRecord? {
        records.first { $0.id == entityID }
    }

    /// Returns the component for `componentTypeID` on `entityID`.
    public func componentValue(_ componentTypeID: ComponentTypeID, for entityID: EntityID) -> ComponentValue? {
        record(for: entityID)?.componentValue(componentTypeID)
    }

    /// Returns storage with `record` set.
    public func setting(_ record: EntityRecord) -> ComponentStorage {
        ComponentStorage(records: records.filter { $0.id != record.id } + [record])
    }

    /// Returns storage with `entityID` removed.
    public func removing(entityID: EntityID) -> ComponentStorage {
        ComponentStorage(records: records.filter { $0.id != entityID })
    }

    /// Returns storage with `component` set on `entityID`.
    public func setting(_ component: ComponentValue, for entityID: EntityID) -> ComponentStorage {
        let record = self.record(for: entityID) ?? EntityRecord(id: entityID)
        return setting(record.setting(component))
    }

    /// Returns storage with `componentTypeID` removed from `entityID`.
    public func removing(_ componentTypeID: ComponentTypeID, for entityID: EntityID) -> ComponentStorage {
        guard let record = record(for: entityID) else {
            return self
        }

        return setting(record.removing(componentTypeID))
    }

    /// Builds an ordered snapshot from current storage.
    public var snapshot: EntitySnapshot {
        EntitySnapshot(entities: records)
    }

    public func stableHash(into hasher: inout StableHasher) {
        snapshot.stableHash(into: &hasher)
    }
}

/// Stable hashing helper for ECS snapshots.
public enum ECSHasher {
    /// Hashes an ordered entity snapshot.
    public static func hash(snapshot: EntitySnapshot) -> StableHash {
        var hasher = StableHasher()
        hasher.combine("Telluric.EntitySnapshot.v1")
        hasher.combine(snapshot)
        return hasher.finalize()
    }
}
