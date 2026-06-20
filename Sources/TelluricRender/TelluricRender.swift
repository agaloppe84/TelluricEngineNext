import TelluricCore
import TelluricDeterminism
import TelluricMath

/// Stable backend-neutral render resource identifier.
public struct RenderResourceID: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Stable resource namespace.
    public let rawValue: NamespaceID

    /// Creates a render resource ID.
    public init(_ rawValue: NamespaceID) {
        self.rawValue = rawValue
    }

    /// Creates a render resource ID from a namespace string.
    public init(_ rawValue: String) {
        self.init(NamespaceID(rawValue))
    }

    public static func < (lhs: RenderResourceID, rhs: RenderResourceID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

/// Backend-neutral mesh resource identifier.
public struct MeshResourceID: Codable, Comparable, Hashable, Sendable, StableHashable {
    public let rawValue: RenderResourceID

    public init(_ rawValue: RenderResourceID) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.init(RenderResourceID(rawValue))
    }

    public static func < (lhs: MeshResourceID, rhs: MeshResourceID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

/// Backend-neutral material resource identifier.
public struct MaterialResourceID: Codable, Comparable, Hashable, Sendable, StableHashable {
    public let rawValue: RenderResourceID

    public init(_ rawValue: RenderResourceID) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.init(RenderResourceID(rawValue))
    }

    public static func < (lhs: MaterialResourceID, rhs: MaterialResourceID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

/// Backend-neutral texture resource identifier.
public struct TextureResourceID: Codable, Comparable, Hashable, Sendable, StableHashable {
    public let rawValue: RenderResourceID

    public init(_ rawValue: RenderResourceID) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.init(RenderResourceID(rawValue))
    }

    public static func < (lhs: TextureResourceID, rhs: TextureResourceID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

/// Stable render layer used for backend-neutral ordering and filtering.
public struct RenderLayer: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Stable layer identifier.
    public let id: NamespaceID

    /// Numeric layer order. Lower values sort first.
    public let order: Int

    /// Creates a render layer.
    public init(id: NamespaceID, order: Int) {
        self.id = id
        self.order = order
    }

    /// Default world geometry layer.
    public static let world = RenderLayer(id: NamespaceID("render.layer.world"), order: 0)

    /// Default debug visualization layer.
    public static let debug = RenderLayer(id: NamespaceID("render.layer.debug"), order: 10_000)

    public static func < (lhs: RenderLayer, rhs: RenderLayer) -> Bool {
        if lhs.order != rhs.order {
            return lhs.order < rhs.order
        }

        return lhs.id < rhs.id
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(id)
        hasher.combine(order)
    }
}

/// Backend-neutral visibility flags for a renderable instance.
public struct RenderVisibilityFlags: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// True when the instance participates in primary color rendering.
    public let isVisible: Bool

    /// True when the instance may cast shadows in a future backend.
    public let castsShadow: Bool

    /// True when the instance may receive shadows in a future backend.
    public let receivesShadow: Bool

    /// Creates visibility flags.
    public init(
        isVisible: Bool = true,
        castsShadow: Bool = true,
        receivesShadow: Bool = true
    ) {
        self.isVisible = isVisible
        self.castsShadow = castsShadow
        self.receivesShadow = receivesShadow
    }

    /// Default visible opaque-world style flags.
    public static let visible = RenderVisibilityFlags()

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(isVisible)
        hasher.combine(castsShadow)
        hasher.combine(receivesShadow)
    }
}

/// Backend-neutral camera projection.
public enum CameraProjection: Codable, Equatable, Hashable, Sendable, StableHashable {
    case perspective(verticalFieldOfViewRadians: Float, nearClip: Float, farClip: Float)
    case orthographic(height: Float, nearClip: Float, farClip: Float)

    public func stableHash(into hasher: inout StableHasher) {
        switch self {
        case let .perspective(verticalFieldOfViewRadians, nearClip, farClip):
            hasher.combine("perspective")
            hasher.combine(verticalFieldOfViewRadians)
            hasher.combine(nearClip)
            hasher.combine(farClip)

        case let .orthographic(height, nearClip, farClip):
            hasher.combine("orthographic")
            hasher.combine(height)
            hasher.combine(nearClip)
            hasher.combine(farClip)
        }
    }
}

/// Renderer-level camera state, independent of gameplay and input controls.
public struct CameraSnapshot: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Stable camera identifier.
    public let id: NamespaceID

    /// Camera transform in engine coordinates.
    public let transform: Transform

    /// Projection contract.
    public let projection: CameraProjection

    /// Viewport width divided by height.
    public let aspectRatio: Float

    /// Creates a camera snapshot.
    public init(
        id: NamespaceID,
        transform: Transform,
        projection: CameraProjection,
        aspectRatio: Float
    ) {
        precondition(aspectRatio.isFinite && aspectRatio > 0, "CameraSnapshot.aspectRatio must be finite and positive")
        self.id = id
        self.transform = transform
        self.projection = projection
        self.aspectRatio = aspectRatio
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(id)
        RenderSnapshotHasher.combine(transform: transform, into: &hasher)
        hasher.combine(projection)
        hasher.combine(aspectRatio)
    }
}

/// Stable renderer-facing instance identifier.
public struct RenderableInstanceID: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Stable instance namespace.
    public let rawValue: NamespaceID

    /// Creates an instance identifier.
    public init(_ rawValue: NamespaceID) {
        self.rawValue = rawValue
    }

    /// Creates an instance identifier from a namespace string.
    public init(_ rawValue: String) {
        self.init(NamespaceID(rawValue))
    }

    public static func < (lhs: RenderableInstanceID, rhs: RenderableInstanceID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

/// Backend-neutral renderable instance.
public struct RenderableInstance: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Stable instance ID.
    public let id: RenderableInstanceID

    /// Mesh resource to render.
    public let mesh: MeshResourceID

    /// Material resource to bind.
    public let material: MaterialResourceID

    /// Optional ordered texture references.
    public let textures: [TextureResourceID]

    /// Instance transform in engine coordinates.
    public let transform: Transform

    /// Render layer.
    public let layer: RenderLayer

    /// Visibility flags.
    public let visibility: RenderVisibilityFlags

    /// Creates a renderable instance.
    public init(
        id: RenderableInstanceID,
        mesh: MeshResourceID,
        material: MaterialResourceID,
        textures: [TextureResourceID] = [],
        transform: Transform,
        layer: RenderLayer = .world,
        visibility: RenderVisibilityFlags = .visible
    ) {
        self.id = id
        self.mesh = mesh
        self.material = material
        self.textures = textures.sorted()
        self.transform = transform
        self.layer = layer
        self.visibility = visibility
    }

    public static func < (lhs: RenderableInstance, rhs: RenderableInstance) -> Bool {
        if lhs.layer != rhs.layer {
            return lhs.layer < rhs.layer
        }

        if lhs.id != rhs.id {
            return lhs.id < rhs.id
        }

        if lhs.mesh != rhs.mesh {
            return lhs.mesh < rhs.mesh
        }

        return lhs.material < rhs.material
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(id)
        hasher.combine(mesh)
        hasher.combine(material)
        hasher.combine(textures.count)
        for texture in textures {
            hasher.combine(texture)
        }
        RenderSnapshotHasher.combine(transform: transform, into: &hasher)
        hasher.combine(layer)
        hasher.combine(visibility)
    }
}

/// RGBA color for backend-neutral debug primitives.
public struct RenderColor: Codable, Equatable, Hashable, Sendable, StableHashable {
    public let red: Float
    public let green: Float
    public let blue: Float
    public let alpha: Float

    /// Creates a color. Components must be finite and in `0...1`.
    public init(red: Float, green: Float, blue: Float, alpha: Float = 1) {
        precondition(Self.isUnit(red), "RenderColor.red must be finite and within 0...1")
        precondition(Self.isUnit(green), "RenderColor.green must be finite and within 0...1")
        precondition(Self.isUnit(blue), "RenderColor.blue must be finite and within 0...1")
        precondition(Self.isUnit(alpha), "RenderColor.alpha must be finite and within 0...1")
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let white = RenderColor(red: 1, green: 1, blue: 1, alpha: 1)
    public static let red = RenderColor(red: 1, green: 0, blue: 0, alpha: 1)
    public static let green = RenderColor(red: 0, green: 1, blue: 0, alpha: 1)
    public static let blue = RenderColor(red: 0, green: 0, blue: 1, alpha: 1)

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(red)
        hasher.combine(green)
        hasher.combine(blue)
        hasher.combine(alpha)
    }

    private static func isUnit(_ value: Float) -> Bool {
        value.isFinite && value >= 0 && value <= 1
    }
}

/// Backend-neutral debug line.
public struct DebugLine: Codable, Comparable, Hashable, Sendable, StableHashable {
    public let start: Float3
    public let end: Float3
    public let color: RenderColor
    public let layer: RenderLayer

    /// Creates a debug line.
    public init(start: Float3, end: Float3, color: RenderColor = .white, layer: RenderLayer = .debug) {
        self.start = start
        self.end = end
        self.color = color
        self.layer = layer
    }

    public static func < (lhs: DebugLine, rhs: DebugLine) -> Bool {
        if lhs.layer != rhs.layer {
            return lhs.layer < rhs.layer
        }

        if lhs.start != rhs.start {
            return RenderSnapshotHasher.isLess(lhs.start, rhs.start)
        }

        if lhs.end != rhs.end {
            return RenderSnapshotHasher.isLess(lhs.end, rhs.end)
        }

        return RenderSnapshotHasher.isLess(lhs.color, rhs.color)
    }

    public func stableHash(into hasher: inout StableHasher) {
        RenderSnapshotHasher.combine(float3: start, into: &hasher)
        RenderSnapshotHasher.combine(float3: end, into: &hasher)
        hasher.combine(color)
        hasher.combine(layer)
    }
}

/// Backend-neutral debug point.
public struct DebugPoint: Codable, Comparable, Hashable, Sendable, StableHashable {
    public let position: Float3
    public let size: Float
    public let color: RenderColor
    public let layer: RenderLayer

    /// Creates a debug point.
    public init(position: Float3, size: Float = 1, color: RenderColor = .white, layer: RenderLayer = .debug) {
        precondition(size.isFinite && size >= 0, "DebugPoint.size must be finite and non-negative")
        self.position = position
        self.size = size
        self.color = color
        self.layer = layer
    }

    public static func < (lhs: DebugPoint, rhs: DebugPoint) -> Bool {
        if lhs.layer != rhs.layer {
            return lhs.layer < rhs.layer
        }

        if lhs.position != rhs.position {
            return RenderSnapshotHasher.isLess(lhs.position, rhs.position)
        }

        if lhs.size != rhs.size {
            return lhs.size < rhs.size
        }

        return RenderSnapshotHasher.isLess(lhs.color, rhs.color)
    }

    public func stableHash(into hasher: inout StableHasher) {
        RenderSnapshotHasher.combine(float3: position, into: &hasher)
        hasher.combine(size)
        hasher.combine(color)
        hasher.combine(layer)
    }
}

/// Backend-neutral debug label.
public struct DebugLabel: Codable, Comparable, Hashable, Sendable, StableHashable {
    public let id: NamespaceID
    public let text: String
    public let position: Float3
    public let color: RenderColor
    public let layer: RenderLayer

    /// Creates a debug label.
    public init(
        id: NamespaceID,
        text: String,
        position: Float3,
        color: RenderColor = .white,
        layer: RenderLayer = .debug
    ) {
        self.id = id
        self.text = text
        self.position = position
        self.color = color
        self.layer = layer
    }

    public static func < (lhs: DebugLabel, rhs: DebugLabel) -> Bool {
        if lhs.layer != rhs.layer {
            return lhs.layer < rhs.layer
        }

        if lhs.id != rhs.id {
            return lhs.id < rhs.id
        }

        if lhs.position != rhs.position {
            return RenderSnapshotHasher.isLess(lhs.position, rhs.position)
        }

        return lhs.text < rhs.text
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(id)
        hasher.combine(text)
        RenderSnapshotHasher.combine(float3: position, into: &hasher)
        hasher.combine(color)
        hasher.combine(layer)
    }
}

/// Ordered renderer-independent snapshot consumed by future render backends and tools.
public struct RenderSnapshot: Codable, Equatable, Sendable {
    /// Engine version for the snapshot contract.
    public let engineVersion: EngineVersion

    /// Frame represented by this render snapshot.
    public let frameIndex: FrameIndex

    /// Camera used to render the snapshot.
    public let camera: CameraSnapshot

    /// Ordered renderable instances.
    public let instances: [RenderableInstance]

    /// Ordered debug lines.
    public let debugLines: [DebugLine]

    /// Ordered debug points.
    public let debugPoints: [DebugPoint]

    /// Ordered debug labels.
    public let debugLabels: [DebugLabel]

    /// Stable hash over ordered snapshot contents.
    public let stableHash: StableHash

    /// Creates a render snapshot and canonicalizes ordered arrays.
    public init(
        engineVersion: EngineVersion,
        frameIndex: FrameIndex,
        camera: CameraSnapshot,
        instances: [RenderableInstance] = [],
        debugLines: [DebugLine] = [],
        debugPoints: [DebugPoint] = [],
        debugLabels: [DebugLabel] = []
    ) {
        self.engineVersion = engineVersion
        self.frameIndex = frameIndex
        self.camera = camera
        self.instances = instances.sorted()
        self.debugLines = debugLines.sorted()
        self.debugPoints = debugPoints.sorted()
        self.debugLabels = debugLabels.sorted()
        self.stableHash = RenderSnapshotHasher.hash(
            engineVersion: engineVersion,
            frameIndex: frameIndex,
            camera: camera,
            instances: self.instances,
            debugLines: self.debugLines,
            debugPoints: self.debugPoints,
            debugLabels: self.debugLabels
        )
    }
}

/// Stable hashing helper for renderer-independent snapshots.
public enum RenderSnapshotHasher {
    /// Hashes ordered render snapshot contents.
    public static func hash(snapshot: RenderSnapshot) -> StableHash {
        hash(
            engineVersion: snapshot.engineVersion,
            frameIndex: snapshot.frameIndex,
            camera: snapshot.camera,
            instances: snapshot.instances,
            debugLines: snapshot.debugLines,
            debugPoints: snapshot.debugPoints,
            debugLabels: snapshot.debugLabels
        )
    }

    /// Hashes render snapshot fields from ordered contents.
    public static func hash(
        engineVersion: EngineVersion,
        frameIndex: FrameIndex,
        camera: CameraSnapshot,
        instances: [RenderableInstance],
        debugLines: [DebugLine],
        debugPoints: [DebugPoint],
        debugLabels: [DebugLabel]
    ) -> StableHash {
        var hasher = StableHasher()
        hasher.combine("Telluric.RenderSnapshot.v1")
        hasher.combine(engineVersion)
        hasher.combine(frameIndex)
        hasher.combine(camera)

        let orderedInstances = instances.sorted()
        hasher.combine(orderedInstances.count)
        for instance in orderedInstances {
            hasher.combine(instance)
        }

        let orderedLines = debugLines.sorted()
        hasher.combine(orderedLines.count)
        for line in orderedLines {
            hasher.combine(line)
        }

        let orderedPoints = debugPoints.sorted()
        hasher.combine(orderedPoints.count)
        for point in orderedPoints {
            hasher.combine(point)
        }

        let orderedLabels = debugLabels.sorted()
        hasher.combine(orderedLabels.count)
        for label in orderedLabels {
            hasher.combine(label)
        }

        return hasher.finalize()
    }

    static func combine(transform: Transform, into hasher: inout StableHasher) {
        combine(float3: transform.translation, into: &hasher)
        combine(float3: transform.rotationRadians, into: &hasher)
        combine(float3: transform.scale, into: &hasher)
    }

    static func combine(float3: Float3, into hasher: inout StableHasher) {
        hasher.combine(float3.x)
        hasher.combine(float3.y)
        hasher.combine(float3.z)
    }

    static func isLess(_ lhs: Float3, _ rhs: Float3) -> Bool {
        if lhs.x != rhs.x {
            return lhs.x < rhs.x
        }

        if lhs.y != rhs.y {
            return lhs.y < rhs.y
        }

        return lhs.z < rhs.z
    }

    static func isLess(_ lhs: RenderColor, _ rhs: RenderColor) -> Bool {
        if lhs.red != rhs.red {
            return lhs.red < rhs.red
        }

        if lhs.green != rhs.green {
            return lhs.green < rhs.green
        }

        if lhs.blue != rhs.blue {
            return lhs.blue < rhs.blue
        }

        return lhs.alpha < rhs.alpha
    }
}
