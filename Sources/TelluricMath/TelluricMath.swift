/// Two-dimensional signed integer coordinate.
public struct Int2: Codable, Equatable, Hashable, Sendable {
    public let x: Int64
    public let y: Int64

    public static let zero = Int2(x: 0, y: 0)

    public init(x: Int64, y: Int64) {
        self.x = x
        self.y = y
    }

    public static func + (lhs: Int2, rhs: Int2) -> Int2 {
        Int2(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    public static func - (lhs: Int2, rhs: Int2) -> Int2 {
        Int2(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
}

/// Three-dimensional signed integer coordinate.
public struct Int3: Codable, Equatable, Hashable, Sendable {
    public let x: Int64
    public let y: Int64
    public let z: Int64

    public static let zero = Int3(x: 0, y: 0, z: 0)

    public init(x: Int64, y: Int64, z: Int64) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static func + (lhs: Int3, rhs: Int3) -> Int3 {
        Int3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    public static func - (lhs: Int3, rhs: Int3) -> Int3 {
        Int3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }
}

/// Two-dimensional floating-point vector.
public struct Float2: Codable, Equatable, Hashable, Sendable {
    public let x: Float
    public let y: Float

    public static let zero = Float2(x: 0, y: 0)
    public static let one = Float2(x: 1, y: 1)

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }

    public static func + (lhs: Float2, rhs: Float2) -> Float2 {
        Float2(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    public static func - (lhs: Float2, rhs: Float2) -> Float2 {
        Float2(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    public static func * (lhs: Float2, rhs: Float) -> Float2 {
        Float2(x: lhs.x * rhs, y: lhs.y * rhs)
    }
}

/// Three-dimensional floating-point vector.
public struct Float3: Codable, Equatable, Hashable, Sendable {
    public let x: Float
    public let y: Float
    public let z: Float

    public static let zero = Float3(x: 0, y: 0, z: 0)
    public static let one = Float3(x: 1, y: 1, z: 1)

    public init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static func + (lhs: Float3, rhs: Float3) -> Float3 {
        Float3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    public static func - (lhs: Float3, rhs: Float3) -> Float3 {
        Float3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    public static func * (lhs: Float3, rhs: Float) -> Float3 {
        Float3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }
}

/// Axis-aligned bounding box in engine-space coordinates.
public struct AABB: Codable, Equatable, Hashable, Sendable {
    /// Minimum inclusive corner.
    public let min: Float3

    /// Maximum inclusive corner.
    public let max: Float3

    /// Creates a bounding box. Each minimum component must be <= its maximum.
    public init(min: Float3, max: Float3) {
        precondition(min.x <= max.x, "AABB min.x must be <= max.x")
        precondition(min.y <= max.y, "AABB min.y must be <= max.y")
        precondition(min.z <= max.z, "AABB min.z must be <= max.z")
        self.min = min
        self.max = max
    }

    /// Returns true when `point` is inside or on the box boundary.
    public func contains(_ point: Float3) -> Bool {
        point.x >= min.x && point.x <= max.x &&
            point.y >= min.y && point.y <= max.y &&
            point.z >= min.z && point.z <= max.z
    }

    /// Returns the smallest box containing this box and `other`.
    public func union(_ other: AABB) -> AABB {
        AABB(
            min: Float3(
                x: Swift.min(min.x, other.min.x),
                y: Swift.min(min.y, other.min.y),
                z: Swift.min(min.z, other.min.z)
            ),
            max: Float3(
                x: Swift.max(max.x, other.max.x),
                y: Swift.max(max.y, other.max.y),
                z: Swift.max(max.z, other.max.z)
            )
        )
    }

    /// Returns the smallest box containing this box and `point`.
    public func expanded(toInclude point: Float3) -> AABB {
        AABB(
            min: Float3(
                x: Swift.min(min.x, point.x),
                y: Swift.min(min.y, point.y),
                z: Swift.min(min.z, point.z)
            ),
            max: Float3(
                x: Swift.max(max.x, point.x),
                y: Swift.max(max.y, point.y),
                z: Swift.max(max.z, point.z)
            )
        )
    }
}

/// Angle stored in radians.
public struct Angle: Codable, Equatable, Hashable, Sendable {
    public let radians: Float

    public init(radians: Float) {
        self.radians = radians
    }

    public static func degrees(_ degrees: Float) -> Angle {
        Angle(radians: degrees * (Float.pi / 180))
    }
}

/// Translation, Euler rotation in radians, and scale.
public struct Transform: Codable, Equatable, Hashable, Sendable {
    public let translation: Float3
    public let rotationRadians: Float3
    public let scale: Float3

    public static let identity = Transform()

    public init(
        translation: Float3 = .zero,
        rotationRadians: Float3 = .zero,
        scale: Float3 = .one
    ) {
        self.translation = translation
        self.rotationRadians = rotationRadians
        self.scale = scale
    }
}

/// Clamps `value` to the closed range `lowerBound...upperBound`.
public func clamp<T: Comparable>(_ value: T, min lowerBound: T, max upperBound: T) -> T {
    precondition(lowerBound <= upperBound, "clamp lower bound must be <= upper bound")

    if value < lowerBound {
        return lowerBound
    }

    if value > upperBound {
        return upperBound
    }

    return value
}

/// Clamps a scalar to `0...1`.
public func saturate(_ value: Float) -> Float {
    clamp(value, min: 0, max: 1)
}

/// Linear interpolation between scalar endpoints.
public func lerp(_ a: Float, _ b: Float, t: Float) -> Float {
    a + (b - a) * t
}

/// Linear interpolation between two-dimensional endpoints.
public func lerp(_ a: Float2, _ b: Float2, t: Float) -> Float2 {
    a + ((b - a) * t)
}

/// Linear interpolation between three-dimensional endpoints.
public func lerp(_ a: Float3, _ b: Float3, t: Float) -> Float3 {
    a + ((b - a) * t)
}
