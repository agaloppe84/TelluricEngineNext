import Foundation
import TelluricAssets
import TelluricCore
import TelluricDeterminism
import TelluricDiagnostics

/// Parsed command-line configuration for the asset cooker.
public struct AssetCookerArguments: Equatable, Sendable {
    /// Manifest JSON path.
    public let manifestPath: String

    /// Output directory for future cooked assets.
    public let outputPath: String

    /// Optional deterministic JSON report path.
    public let reportPath: String?

    /// Treat unsupported conversions as errors.
    public let strict: Bool

    /// Prints ordered descriptor details.
    public let verbose: Bool

    /// True when help text was requested.
    public let help: Bool

    /// Creates parsed asset cooker arguments.
    public init(
        manifestPath: String,
        outputPath: String,
        reportPath: String? = nil,
        strict: Bool = false,
        verbose: Bool = false,
        help: Bool = false
    ) {
        self.manifestPath = manifestPath
        self.outputPath = outputPath
        self.reportPath = reportPath
        self.strict = strict
        self.verbose = verbose
        self.help = help
    }
}

/// User-facing CLI parsing errors.
public enum AssetCookerArgumentError: Error, Equatable, CustomStringConvertible, Sendable {
    case missingRequiredOption(String)
    case missingValue(option: String)
    case unknownOption(String)

    public var description: String {
        switch self {
        case let .missingRequiredOption(option):
            return "Missing required option \(option)."
        case let .missingValue(option):
            return "Missing value for \(option)."
        case let .unknownOption(option):
            return "Unknown option \(option)."
        }
    }
}

/// Dependency-free parser for `telluric-asset-cooker`.
public enum AssetCookerArgumentParser {
    /// Parses process arguments excluding executable name.
    public static func parse(_ arguments: [String]) throws -> AssetCookerArguments {
        var manifestPath: String?
        var outputPath: String?
        var reportPath: String?
        var strict = false
        var verbose = false
        var help = false

        var index = 0
        while index < arguments.count {
            let option = arguments[index]

            switch option {
            case "--help", "-h":
                help = true
                index += 1

            case "--strict":
                strict = true
                index += 1

            case "--verbose":
                verbose = true
                index += 1

            case "--manifest":
                manifestPath = try value(after: option, index: index, arguments: arguments)
                index += 2

            case "--output":
                outputPath = try value(after: option, index: index, arguments: arguments)
                index += 2

            case "--report":
                reportPath = try value(after: option, index: index, arguments: arguments)
                index += 2

            default:
                throw AssetCookerArgumentError.unknownOption(option)
            }
        }

        if help {
            return AssetCookerArguments(
                manifestPath: manifestPath ?? "",
                outputPath: outputPath ?? "",
                reportPath: reportPath,
                strict: strict,
                verbose: verbose,
                help: true
            )
        }

        guard let manifestPath else {
            throw AssetCookerArgumentError.missingRequiredOption("--manifest")
        }
        guard let outputPath else {
            throw AssetCookerArgumentError.missingRequiredOption("--output")
        }

        return AssetCookerArguments(
            manifestPath: manifestPath,
            outputPath: outputPath,
            reportPath: reportPath,
            strict: strict,
            verbose: verbose
        )
    }

    private static func value(after option: String, index: Int, arguments: [String]) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw AssetCookerArgumentError.missingValue(option: option)
        }

        return arguments[valueIndex]
    }
}

/// Help text for the asset cooker executable.
public enum AssetCookerHelp {
    public static let text = """
    Usage:
      swift run telluric-asset-cooker --manifest <path> --output <path> [--report <path>] [--strict] [--verbose]

    Options:
      --manifest <path>   Asset manifest JSON path.
      --output <path>     Output directory for future cooked assets.
      --report <path>     Optional deterministic JSON report path.
      --strict            Fail when actual conversion is unsupported.
      --verbose           Print ordered cooked descriptor hashes.
      --help, -h          Show this help text.
    """
}

/// Deterministic JSON report emitted by `telluric-asset-cooker`.
public struct AssetCookerReport: Codable, Equatable, Sendable {
    public let toolName: String
    public let toolVersion: EngineVersion
    public let manifestPath: String
    public let outputPath: String
    public let manifestVersion: AssetManifestVersion?
    public let entriesRequested: Int
    public let descriptorsProduced: Int
    public let unsupportedConversions: Int
    public let diagnosticsSummary: DiagnosticSummary
    public let descriptors: [CookedAssetDescriptor]
    public let diagnostics: [DiagnosticMessage]
    public let rootHash: StableHash?
    public let success: Bool

    /// Creates an asset cooker report from ordered records.
    public init(
        toolName: String,
        toolVersion: EngineVersion,
        manifestPath: String,
        outputPath: String,
        manifestVersion: AssetManifestVersion?,
        entriesRequested: Int,
        descriptorsProduced: Int,
        unsupportedConversions: Int,
        diagnosticsSummary: DiagnosticSummary,
        descriptors: [CookedAssetDescriptor],
        diagnostics: [DiagnosticMessage],
        rootHash: StableHash?,
        success: Bool
    ) {
        self.toolName = toolName
        self.toolVersion = toolVersion
        self.manifestPath = manifestPath
        self.outputPath = outputPath
        self.manifestVersion = manifestVersion
        self.entriesRequested = entriesRequested
        self.descriptorsProduced = descriptorsProduced
        self.unsupportedConversions = unsupportedConversions
        self.diagnosticsSummary = diagnosticsSummary
        self.descriptors = descriptors
        self.diagnostics = diagnostics
        self.rootHash = rootHash
        self.success = success
    }
}

/// Result from an asset cooker CLI run.
public struct AssetCookerRunResult: Equatable, Sendable {
    public let report: AssetCookerReport
    public let summary: String
    public let exitCode: Int32

    /// Creates a run result.
    public init(report: AssetCookerReport, summary: String, exitCode: Int32) {
        self.report = report
        self.summary = summary
        self.exitCode = exitCode
    }
}

/// Manifest validator and descriptor-producing asset cooker foundation.
public struct AssetCooker: Sendable {
    public static let toolName = "telluric-asset-cooker"
    public static let toolVersion = EngineVersion(major: 0, minor: 10, patch: 0)

    /// Creates an asset cooker.
    public init() {}

    /// Validates and reports without writing cooked asset data.
    public func cook(
        arguments: AssetCookerArguments,
        repoRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) -> AssetCookerReport {
        let root = repoRoot.standardizedFileURL
        var diagnostics: [DiagnosticMessage] = []

        diagnostics.append(contentsOf: Self.validateToolPath(
            arguments.manifestPath,
            option: "--manifest",
            requiredRoot: nil
        ))
        diagnostics.append(contentsOf: Self.validateToolPath(
            arguments.outputPath,
            option: "--output",
            requiredRoot: ["Assets", "Cooked"]
        ))
        if let reportPath = arguments.reportPath {
            diagnostics.append(contentsOf: Self.validateToolPath(
                reportPath,
                option: "--report",
                requiredRoot: nil
            ))
        }

        guard diagnostics.isEmpty else {
            return Self.makeReport(
                arguments: arguments,
                manifestVersion: nil,
                entriesRequested: 0,
                unsupportedConversions: 0,
                descriptors: [],
                diagnostics: diagnostics
            )
        }

        let manifestURL = root.appendingPathComponent(arguments.manifestPath)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            diagnostics.append(DiagnosticMessage(
                severity: .error,
                code: NamespaceID("asset_cooker.manifest.missing"),
                message: "Asset manifest file does not exist.",
                source: "TelluricAssetCooker",
                metadata: [
                    DiagnosticMetadata(key: "manifest.path", value: arguments.manifestPath),
                ]
            ))
            return Self.makeReport(
                arguments: arguments,
                manifestVersion: nil,
                entriesRequested: 0,
                unsupportedConversions: 0,
                descriptors: [],
                diagnostics: diagnostics
            )
        }

        let manifest: AssetManifest
        do {
            let data = try Data(contentsOf: manifestURL)
            manifest = try JSONDecoder().decode(AssetManifest.self, from: data)
        } catch {
            diagnostics.append(DiagnosticMessage(
                severity: .error,
                code: NamespaceID("asset_cooker.manifest.decode_failed"),
                message: "Asset manifest JSON could not be decoded.",
                source: "TelluricAssetCooker",
                metadata: [
                    DiagnosticMetadata(key: "manifest.path", value: arguments.manifestPath),
                    DiagnosticMetadata(key: "error", value: String(describing: error)),
                ]
            ))
            return Self.makeReport(
                arguments: arguments,
                manifestVersion: nil,
                entriesRequested: 0,
                unsupportedConversions: 0,
                descriptors: [],
                diagnostics: diagnostics
            )
        }

        let validationReport = AssetManifestValidation.validate(manifest: manifest)
        diagnostics.append(contentsOf: validationReport.diagnostics)
        diagnostics.append(contentsOf: Self.sourceExistenceDiagnostics(for: manifest, repoRoot: root))

        var descriptors: [CookedAssetDescriptor] = []
        if !DiagnosticReport(messages: diagnostics).hasErrors {
            descriptors = manifest.entries.map { entry in
                CookedAssetDescriptor(
                    id: entry.id,
                    kind: entry.kind,
                    sourcePath: entry.sourcePath,
                    cookedPath: entry.cookedPath,
                    manifestVersion: manifest.version
                )
            }.sorted()
        }

        let unsupportedConversions: Int
        if arguments.strict && !descriptors.isEmpty {
            unsupportedConversions = descriptors.count
            for descriptor in descriptors {
                diagnostics.append(DiagnosticMessage(
                    severity: .error,
                    code: NamespaceID("asset_cooker.conversion.unsupported"),
                    message: "Conversion is not implemented for asset kind \(descriptor.kind.rawValue).",
                    source: "TelluricAssetCooker",
                    metadata: [
                        DiagnosticMetadata(key: "asset.id", value: descriptor.id.rawValue),
                        DiagnosticMetadata(key: "asset.kind", value: descriptor.kind.rawValue),
                    ]
                ))
            }
        } else {
            unsupportedConversions = 0
        }

        return Self.makeReport(
            arguments: arguments,
            manifestVersion: manifest.version,
            entriesRequested: manifest.entries.count,
            unsupportedConversions: unsupportedConversions,
            descriptors: descriptors,
            diagnostics: diagnostics
        )
    }

    /// Runs the cooker, creates the safe output directory when successful, and writes an optional report.
    public func run(
        arguments: AssetCookerArguments,
        repoRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) throws -> AssetCookerRunResult {
        let report = cook(arguments: arguments, repoRoot: repoRoot)

        if report.success {
            let outputURL = try Self.safeURL(for: arguments.outputPath, repoRoot: repoRoot)
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        }

        if let reportPath = arguments.reportPath {
            try Self.write(report: report, to: reportPath, repoRoot: repoRoot)
        }

        return AssetCookerRunResult(
            report: report,
            summary: Self.summary(for: report, verbose: arguments.verbose),
            exitCode: report.success ? 0 : 1
        )
    }

    /// Writes a deterministic JSON report to a safe repo-local path.
    public static func write(report: AssetCookerReport, to path: String, repoRoot: URL) throws {
        let url = try safeURL(for: path, repoRoot: repoRoot)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try jsonEncoder().encode(report)
        try data.write(to: url, options: [.atomic])
    }

    /// Creates the stable JSON encoder used for asset cooker reports.
    public static func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    /// Creates a human-readable asset cooker summary.
    public static func summary(for report: AssetCookerReport, verbose: Bool = false) -> String {
        var lines = [
            "\(report.toolName) \(report.toolVersion)",
            "manifest: \(report.manifestPath)",
            "output: \(report.outputPath)",
            "entries: requested \(report.entriesRequested), descriptors \(report.descriptorsProduced)",
            "unsupported conversions: \(report.unsupportedConversions)",
            "diagnostics: info \(report.diagnosticsSummary.infos), warning \(report.diagnosticsSummary.warnings), error \(report.diagnosticsSummary.errors)",
            "root hash: \(report.rootHash?.description ?? "unavailable")",
            "success: \(report.success)",
        ]

        if verbose {
            for descriptor in report.descriptors {
                lines.append(
                    "asset \(descriptor.id.rawValue): \(descriptor.kind.rawValue) \(descriptor.stableHash)"
                )
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func makeReport(
        arguments: AssetCookerArguments,
        manifestVersion: AssetManifestVersion?,
        entriesRequested: Int,
        unsupportedConversions: Int,
        descriptors: [CookedAssetDescriptor],
        diagnostics: [DiagnosticMessage]
    ) -> AssetCookerReport {
        let diagnosticReport = DiagnosticReport(messages: diagnostics)
        let success = !diagnosticReport.hasErrors
        let reportWithoutHash = AssetCookerReport(
            toolName: toolName,
            toolVersion: toolVersion,
            manifestPath: arguments.manifestPath,
            outputPath: arguments.outputPath,
            manifestVersion: manifestVersion,
            entriesRequested: entriesRequested,
            descriptorsProduced: descriptors.count,
            unsupportedConversions: unsupportedConversions,
            diagnosticsSummary: diagnosticReport.summary,
            descriptors: descriptors,
            diagnostics: diagnostics,
            rootHash: nil,
            success: success
        )

        return AssetCookerReport(
            toolName: reportWithoutHash.toolName,
            toolVersion: reportWithoutHash.toolVersion,
            manifestPath: reportWithoutHash.manifestPath,
            outputPath: reportWithoutHash.outputPath,
            manifestVersion: reportWithoutHash.manifestVersion,
            entriesRequested: reportWithoutHash.entriesRequested,
            descriptorsProduced: reportWithoutHash.descriptorsProduced,
            unsupportedConversions: reportWithoutHash.unsupportedConversions,
            diagnosticsSummary: reportWithoutHash.diagnosticsSummary,
            descriptors: reportWithoutHash.descriptors,
            diagnostics: reportWithoutHash.diagnostics,
            rootHash: rootHash(for: reportWithoutHash),
            success: reportWithoutHash.success
        )
    }

    private static func sourceExistenceDiagnostics(
        for manifest: AssetManifest,
        repoRoot: URL
    ) -> [DiagnosticMessage] {
        var diagnostics: [DiagnosticMessage] = []

        for index in manifest.entries.indices {
            let entry = manifest.entries[index]
            guard AssetManifestValidation.validate(manifest: AssetManifest(version: manifest.version, entries: [entry])).isSuccess else {
                continue
            }

            let sourceURL = repoRoot.appendingPathComponent(entry.sourcePath.rawValue)
            if !FileManager.default.fileExists(atPath: sourceURL.path) {
                diagnostics.append(DiagnosticMessage(
                    severity: .error,
                    code: NamespaceID("asset_cooker.source.missing"),
                    message: "Source asset file does not exist.",
                    source: "TelluricAssetCooker",
                    metadata: [
                        DiagnosticMetadata(key: "entry.index", value: "\(index)"),
                        DiagnosticMetadata(key: "asset.id", value: entry.id.rawValue),
                        DiagnosticMetadata(key: "source.path", value: entry.sourcePath.rawValue),
                    ]
                ))
            }
        }

        return diagnostics
    }

    private static func validateToolPath(
        _ path: String,
        option: String,
        requiredRoot: [String]?
    ) -> [DiagnosticMessage] {
        var diagnostics: [DiagnosticMessage] = []

        if path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            diagnostics.append(pathDiagnostic(
                option: option,
                code: "asset_cooker.path.empty",
                message: "Path option must not be empty.",
                path: path
            ))
            return diagnostics
        }

        if path.hasPrefix("/") || path.hasPrefix("~") {
            diagnostics.append(pathDiagnostic(
                option: option,
                code: "asset_cooker.path.absolute",
                message: "Path option must be repository-relative, not absolute.",
                path: path
            ))
        }

        let components = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        if components.contains("..") {
            diagnostics.append(pathDiagnostic(
                option: option,
                code: "asset_cooker.path.traversal",
                message: "Path option must not contain '..' traversal components.",
                path: path
            ))
        }

        if components.contains("") || components.contains(".") {
            diagnostics.append(pathDiagnostic(
                option: option,
                code: "asset_cooker.path.malformed",
                message: "Path option must not contain empty or current-directory components.",
                path: path
            ))
        }

        if let requiredRoot, (!hasPrefix(components, requiredRoot) || components.count < requiredRoot.count) {
            diagnostics.append(pathDiagnostic(
                option: option,
                code: "asset_cooker.path.outside_required_root",
                message: "Path option must be inside \(requiredRoot.joined(separator: "/")).",
                path: path
            ))
        }

        return diagnostics
    }

    private static func safeURL(for path: String, repoRoot: URL) throws -> URL {
        let diagnostics = validateToolPath(path, option: "path", requiredRoot: nil)
        guard diagnostics.isEmpty else {
            throw TelluricError(
                code: NamespaceID("asset_cooker.path.unsafe"),
                message: "Unsafe repo-local path: \(path)"
            )
        }

        let root = repoRoot.standardizedFileURL
        let resolved = root.appendingPathComponent(path).standardizedFileURL
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"

        guard resolved.path == root.path || resolved.path.hasPrefix(rootPath) else {
            throw TelluricError(
                code: NamespaceID("asset_cooker.path.outside_repo"),
                message: "Path resolves outside the repository: \(path)"
            )
        }

        return resolved
    }

    private static func pathDiagnostic(option: String, code: String, message: String, path: String) -> DiagnosticMessage {
        DiagnosticMessage(
            severity: .error,
            code: NamespaceID(code),
            message: message,
            source: "TelluricAssetCooker",
            metadata: [
                DiagnosticMetadata(key: "option", value: option),
                DiagnosticMetadata(key: "path", value: path),
            ]
        )
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

    private static func rootHash(for report: AssetCookerReport) -> StableHash {
        var hasher = StableHasher()
        hasher.combine("Telluric.AssetCookReport.v1")
        hasher.combine(report.toolName)
        hasher.combine(report.toolVersion)
        hasher.combine(report.manifestPath)
        hasher.combine(report.outputPath)
        hasher.combine(report.manifestVersion != nil)
        if let manifestVersion = report.manifestVersion {
            hasher.combine(manifestVersion)
        }
        hasher.combine(report.entriesRequested)
        hasher.combine(report.descriptorsProduced)
        hasher.combine(report.unsupportedConversions)
        hasher.combine(report.success)
        hasher.combine(report.descriptors.count)
        for descriptor in report.descriptors {
            hasher.combine(descriptor)
            hasher.combine(descriptor.stableHash)
        }
        combineDiagnostics(report.diagnostics, into: &hasher)
        return hasher.finalize()
    }

    private static func combineDiagnostics(_ diagnostics: [DiagnosticMessage], into hasher: inout StableHasher) {
        hasher.combine(diagnostics.count)
        for diagnostic in diagnostics {
            hasher.combine(diagnostic.severity.rawValue)
            hasher.combine(diagnostic.code)
            hasher.combine(diagnostic.message)
            hasher.combine(diagnostic.source ?? "")
            hasher.combine(diagnostic.metadata.count)
            for metadata in diagnostic.metadata {
                hasher.combine(metadata.key)
                hasher.combine(metadata.value)
            }
        }
    }
}
