import Foundation
import TelluricCore
import TelluricDeterminism
import TelluricDiagnostics

/// Stable identifier for an asset declared in a manifest.
public struct AssetID: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Stable textual asset identifier.
    public let rawValue: String

    /// Creates an asset identifier. Validation reports empty IDs instead of trapping.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: AssetID, rhs: AssetID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

/// Stable asset kind string used by manifests and cooker reports.
public struct AssetKind: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Raw manifest kind.
    public let rawValue: String

    /// Creates an asset kind. Validation reports unsupported kind strings.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// Mesh source or cooked asset.
    public static let mesh = AssetKind("mesh")

    /// Material source or cooked asset.
    public static let material = AssetKind("material")

    /// Texture source or cooked asset.
    public static let texture = AssetKind("texture")

    /// Audio source or cooked asset.
    public static let audio = AssetKind("audio")

    /// Motion source or cooked asset.
    public static let motion = AssetKind("motion")

    /// Biome recipe source or cooked asset.
    public static let biomeRecipe = AssetKind("biomeRecipe")

    /// Terrain recipe source or cooked asset.
    public static let terrainRecipe = AssetKind("terrainRecipe")

    /// Explicit unknown marker for unsupported assets.
    public static let unknown = AssetKind("unknown")

    /// Supported asset kinds in deterministic display order.
    public static let supported: [AssetKind] = [
        .mesh,
        .material,
        .texture,
        .audio,
        .motion,
        .biomeRecipe,
        .terrainRecipe,
    ]

    /// True when this kind is supported by the manifest contract.
    public var isSupported: Bool {
        Self.supported.contains(self)
    }

    public static func < (lhs: AssetKind, rhs: AssetKind) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

/// Version for the JSON asset manifest contract.
public struct AssetManifestVersion: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Integer manifest contract version.
    public let rawValue: Int

    /// Creates a manifest version.
    public init(_ rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(Int.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// The supported manifest version for Phase 10.
    public static let supported = AssetManifestVersion(1)

    public static func < (lhs: AssetManifestVersion, rhs: AssetManifestVersion) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

/// Repository-relative asset path stored in a manifest.
public struct AssetPath: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Raw relative path text.
    public let rawValue: String

    /// Creates an asset path. Validation reports unsafe path strings.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: AssetPath, rhs: AssetPath) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(rawValue)
    }
}

/// One source-to-cooked asset declaration in an asset manifest.
public struct AssetManifestEntry: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Stable asset ID.
    public let id: AssetID

    /// Asset kind.
    public let kind: AssetKind

    /// Source asset path under `Assets/Source`.
    public let sourcePath: AssetPath

    /// Cooked runtime path under `Assets/Cooked`.
    public let cookedPath: AssetPath

    /// Creates a manifest entry.
    public init(
        id: AssetID,
        kind: AssetKind,
        sourcePath: AssetPath,
        cookedPath: AssetPath
    ) {
        self.id = id
        self.kind = kind
        self.sourcePath = sourcePath
        self.cookedPath = cookedPath
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(id)
        hasher.combine(kind)
        hasher.combine(sourcePath)
        hasher.combine(cookedPath)
    }
}

/// Ordered JSON asset manifest.
public struct AssetManifest: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Manifest contract version.
    public let version: AssetManifestVersion

    /// Ordered manifest entries.
    public let entries: [AssetManifestEntry]

    /// Creates an asset manifest.
    public init(version: AssetManifestVersion, entries: [AssetManifestEntry]) {
        self.version = version
        self.entries = entries
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(version)
        hasher.combine(entries.count)
        for entry in entries {
            hasher.combine(entry)
        }
    }
}

/// Runtime-facing descriptor produced from a validated manifest entry.
public struct CookedAssetDescriptor: Codable, Comparable, Hashable, Sendable, StableHashable {
    /// Stable asset ID.
    public let id: AssetID

    /// Asset kind.
    public let kind: AssetKind

    /// Source path used to produce the descriptor.
    public let sourcePath: AssetPath

    /// Cooked runtime path.
    public let cookedPath: AssetPath

    /// Manifest contract version that produced this descriptor.
    public let manifestVersion: AssetManifestVersion

    /// Stable descriptor hash.
    public let stableHash: StableHash

    /// Creates a cooked asset descriptor.
    public init(
        id: AssetID,
        kind: AssetKind,
        sourcePath: AssetPath,
        cookedPath: AssetPath,
        manifestVersion: AssetManifestVersion
    ) {
        self.id = id
        self.kind = kind
        self.sourcePath = sourcePath
        self.cookedPath = cookedPath
        self.manifestVersion = manifestVersion
        self.stableHash = AssetHasher.hashDescriptorFields(
            id: id,
            kind: kind,
            sourcePath: sourcePath,
            cookedPath: cookedPath,
            manifestVersion: manifestVersion
        )
    }

    public static func < (lhs: CookedAssetDescriptor, rhs: CookedAssetDescriptor) -> Bool {
        if lhs.id != rhs.id {
            return lhs.id < rhs.id
        }

        if lhs.kind != rhs.kind {
            return lhs.kind < rhs.kind
        }

        return lhs.cookedPath < rhs.cookedPath
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(id)
        hasher.combine(kind)
        hasher.combine(sourcePath)
        hasher.combine(cookedPath)
        hasher.combine(manifestVersion)
    }
}

/// Ordered cooked asset registry.
public struct AssetRegistry: Codable, Equatable, Hashable, Sendable, StableHashable {
    /// Ordered cooked descriptors.
    public let descriptors: [CookedAssetDescriptor]

    /// Creates an asset registry sorted by descriptor identity.
    public init(descriptors: [CookedAssetDescriptor]) {
        self.descriptors = descriptors.sorted()
    }

    /// Finds a descriptor by asset ID.
    public func descriptor(for id: AssetID) -> CookedAssetDescriptor? {
        descriptors.first { $0.id == id }
    }

    public func stableHash(into hasher: inout StableHasher) {
        hasher.combine(descriptors.count)
        for descriptor in descriptors {
            hasher.combine(descriptor)
        }
    }
}

/// One asset validation issue.
public struct AssetValidationIssue: Codable, Equatable, Hashable, Sendable {
    /// Issue severity.
    public let severity: DiagnosticSeverity

    /// Stable machine-readable code.
    public let code: NamespaceID

    /// Human-readable validation message.
    public let message: String

    /// Optional manifest entry index.
    public let entryIndex: Int?

    /// Optional related asset ID.
    public let assetID: AssetID?

    /// Optional related path.
    public let path: AssetPath?

    /// Creates an asset validation issue.
    public init(
        severity: DiagnosticSeverity,
        code: NamespaceID,
        message: String,
        entryIndex: Int? = nil,
        assetID: AssetID? = nil,
        path: AssetPath? = nil
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.entryIndex = entryIndex
        self.assetID = assetID
        self.path = path
    }

    /// Converts the issue into a generic diagnostic message.
    public var diagnostic: DiagnosticMessage {
        var metadata: [DiagnosticMetadata] = []

        if let entryIndex {
            metadata.append(DiagnosticMetadata(key: "entry.index", value: "\(entryIndex)"))
        }
        if let assetID {
            metadata.append(DiagnosticMetadata(key: "asset.id", value: assetID.rawValue))
        }
        if let path {
            metadata.append(DiagnosticMetadata(key: "asset.path", value: path.rawValue))
        }

        return DiagnosticMessage(
            severity: severity,
            code: code,
            message: message,
            source: "TelluricAssets",
            metadata: metadata
        )
    }
}

/// Ordered asset validation report.
public struct AssetValidationReport: Codable, Equatable, Hashable, Sendable {
    /// Ordered validation issues.
    public let issues: [AssetValidationIssue]

    /// Creates an asset validation report.
    public init(issues: [AssetValidationIssue]) {
        self.issues = issues
    }

    /// Ordered diagnostics derived from validation issues.
    public var diagnostics: [DiagnosticMessage] {
        issues.map(\.diagnostic)
    }

    /// Severity summary for diagnostics.
    public var summary: DiagnosticSummary {
        DiagnosticReport(messages: diagnostics).summary
    }

    /// True when any issue has error severity.
    public var hasErrors: Bool {
        issues.contains { $0.severity == .error }
    }

    /// True when validation produced no error issues.
    public var isSuccess: Bool {
        !hasErrors
    }
}

/// Asset manifest validation.
public enum AssetManifestValidation {
    /// Validates the manifest contract and path policy.
    public static func validate(manifest: AssetManifest) -> AssetValidationReport {
        var issues: [AssetValidationIssue] = []

        if manifest.version != .supported {
            issues.append(AssetValidationIssue(
                severity: .error,
                code: NamespaceID("assets.manifest.unsupported_version"),
                message: "Asset manifest version is not supported."
            ))
        }

        for index in manifest.entries.indices {
            let entry = manifest.entries[index]

            if entry.id.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(AssetValidationIssue(
                    severity: .error,
                    code: NamespaceID("assets.entry.empty_id"),
                    message: "Asset manifest entry ID must not be empty.",
                    entryIndex: index,
                    assetID: entry.id
                ))
            }

            if !entry.kind.isSupported {
                issues.append(AssetValidationIssue(
                    severity: .error,
                    code: NamespaceID("assets.entry.unsupported_kind"),
                    message: "Asset kind is not supported by the manifest contract.",
                    entryIndex: index,
                    assetID: entry.id
                ))
            }

            issues.append(contentsOf: validate(
                path: entry.sourcePath,
                expectedRoot: ["Assets", "Source"],
                codePrefix: "source",
                entryIndex: index,
                assetID: entry.id
            ))
            issues.append(contentsOf: validate(
                path: entry.cookedPath,
                expectedRoot: ["Assets", "Cooked"],
                codePrefix: "cooked",
                entryIndex: index,
                assetID: entry.id
            ))
        }

        for index in manifest.entries.indices {
            let entry = manifest.entries[index]
            guard !entry.id.rawValue.isEmpty else {
                continue
            }

            for previousIndex in manifest.entries.indices where previousIndex < index {
                let previous = manifest.entries[previousIndex]
                if previous.id == entry.id {
                    issues.append(AssetValidationIssue(
                        severity: .error,
                        code: NamespaceID("assets.entry.duplicate_id"),
                        message: "Asset manifest contains a duplicate asset ID.",
                        entryIndex: index,
                        assetID: entry.id
                    ))
                    break
                }
            }
        }

        return AssetValidationReport(issues: issues)
    }

    private static func validate(
        path: AssetPath,
        expectedRoot: [String],
        codePrefix: String,
        entryIndex: Int,
        assetID: AssetID
    ) -> [AssetValidationIssue] {
        var issues: [AssetValidationIssue] = []
        let rawPath = path.rawValue

        if rawPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(pathIssue(
                code: "assets.path.\(codePrefix).empty",
                message: "Asset path must not be empty.",
                entryIndex: entryIndex,
                assetID: assetID,
                path: path
            ))
            return issues
        }

        if rawPath.hasPrefix("/") || rawPath.hasPrefix("~") {
            issues.append(pathIssue(
                code: "assets.path.\(codePrefix).absolute",
                message: "Asset path must be repository-relative, not absolute.",
                entryIndex: entryIndex,
                assetID: assetID,
                path: path
            ))
        }

        let components = rawPath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)

        if components.contains("..") {
            issues.append(pathIssue(
                code: "assets.path.\(codePrefix).traversal",
                message: "Asset path must not contain '..' traversal components.",
                entryIndex: entryIndex,
                assetID: assetID,
                path: path
            ))
        }

        if components.contains("") || components.contains(".") {
            issues.append(pathIssue(
                code: "assets.path.\(codePrefix).malformed",
                message: "Asset path must not contain empty or current-directory components.",
                entryIndex: entryIndex,
                assetID: assetID,
                path: path
            ))
        }

        if !hasPrefix(components, expectedRoot) || components.count <= expectedRoot.count {
            issues.append(pathIssue(
                code: "assets.path.\(codePrefix).outside_root",
                message: "Asset path must be inside \(expectedRoot.joined(separator: "/")).",
                entryIndex: entryIndex,
                assetID: assetID,
                path: path
            ))
        }

        return issues
    }

    private static func hasPrefix(_ components: [String], _ prefix: [String]) -> Bool {
        guard components.count >= prefix.count else {
            return false
        }

        for index in prefix.indices where components[index] != prefix[index] {
            return false
        }

        return true
    }

    private static func pathIssue(
        code: String,
        message: String,
        entryIndex: Int,
        assetID: AssetID,
        path: AssetPath
    ) -> AssetValidationIssue {
        AssetValidationIssue(
            severity: .error,
            code: NamespaceID(code),
            message: message,
            entryIndex: entryIndex,
            assetID: assetID,
            path: path
        )
    }
}

/// Stable hashing helpers for asset contracts.
public enum AssetHasher {
    /// Hashes an ordered asset manifest.
    public static func hash(manifest: AssetManifest) -> StableHash {
        var hasher = StableHasher()
        hasher.combine("Telluric.AssetManifest.v1")
        hasher.combine(manifest)
        return hasher.finalize()
    }

    /// Hashes a cooked asset descriptor.
    public static func hash(descriptor: CookedAssetDescriptor) -> StableHash {
        hashDescriptorFields(
            id: descriptor.id,
            kind: descriptor.kind,
            sourcePath: descriptor.sourcePath,
            cookedPath: descriptor.cookedPath,
            manifestVersion: descriptor.manifestVersion
        )
    }

    /// Hashes descriptor fields before the descriptor stores its stable hash.
    public static func hashDescriptorFields(
        id: AssetID,
        kind: AssetKind,
        sourcePath: AssetPath,
        cookedPath: AssetPath,
        manifestVersion: AssetManifestVersion
    ) -> StableHash {
        var hasher = StableHasher()
        hasher.combine("Telluric.CookedAssetDescriptor.v1")
        hasher.combine(id)
        hasher.combine(kind)
        hasher.combine(sourcePath)
        hasher.combine(cookedPath)
        hasher.combine(manifestVersion)
        return hasher.finalize()
    }
}
