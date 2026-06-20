import TelluricCore

/// Severity level for engine diagnostics.
public enum DiagnosticSeverity: String, Codable, CaseIterable, Comparable, Sendable {
    case info
    case warning
    case error

    private var rank: UInt8 {
        switch self {
        case .info:
            return 0
        case .warning:
            return 1
        case .error:
            return 2
        }
    }

    public static func < (lhs: DiagnosticSeverity, rhs: DiagnosticSeverity) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Ordered key-value metadata attached to a diagnostic message.
public struct DiagnosticMetadata: Codable, Equatable, Hashable, Sendable {
    /// Stable metadata key.
    public let key: String

    /// String-encoded metadata value.
    public let value: String

    /// Creates a metadata entry.
    public init(key: String, value: String) {
        precondition(!key.isEmpty, "Diagnostic metadata key must not be empty")
        self.key = key
        self.value = value
    }
}

/// Serializable diagnostic entry for CLI and report consumers.
public struct DiagnosticMessage: Codable, Equatable, Hashable, Sendable {
    /// Severity for this diagnostic.
    public let severity: DiagnosticSeverity

    /// Stable machine-readable diagnostic code.
    public let code: NamespaceID

    /// Human-readable diagnostic message.
    public let message: String

    /// Optional source path, module, or subsystem identifier.
    public let source: String?

    /// Ordered metadata entries.
    public let metadata: [DiagnosticMetadata]

    /// Creates a diagnostic message.
    public init(
        severity: DiagnosticSeverity,
        code: NamespaceID,
        message: String,
        source: String? = nil,
        metadata: [DiagnosticMetadata] = []
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.source = source
        self.metadata = metadata
    }
}

/// Serializable summary of diagnostic severity counts.
public struct DiagnosticSummary: Codable, Equatable, Hashable, Sendable {
    /// Number of info messages.
    public let infos: Int

    /// Number of warning messages.
    public let warnings: Int

    /// Number of error messages.
    public let errors: Int

    /// Creates a diagnostic summary.
    public init(infos: Int, warnings: Int, errors: Int) {
        precondition(infos >= 0, "infos must be non-negative")
        precondition(warnings >= 0, "warnings must be non-negative")
        precondition(errors >= 0, "errors must be non-negative")
        self.infos = infos
        self.warnings = warnings
        self.errors = errors
    }
}

/// JSON-friendly diagnostic report.
public struct DiagnosticReport: Codable, Equatable, Hashable, Sendable {
    /// Ordered diagnostic messages.
    public let messages: [DiagnosticMessage]

    /// Creates a report from ordered diagnostic messages.
    public init(messages: [DiagnosticMessage]) {
        self.messages = messages
    }

    /// Deterministic severity summary derived from `messages`.
    public var summary: DiagnosticSummary {
        DiagnosticSummary(
            infos: count(.info),
            warnings: count(.warning),
            errors: count(.error)
        )
    }

    /// True when the report contains at least one error.
    public var hasErrors: Bool {
        count(.error) > 0
    }

    /// Counts messages matching `severity`.
    public func count(_ severity: DiagnosticSeverity) -> Int {
        messages.reduce(0) { partialResult, message in
            partialResult + (message.severity == severity ? 1 : 0)
        }
    }
}

/// Mutable deterministic collector for future CLI diagnostics.
public struct DiagnosticCollector: Sendable {
    /// Ordered collected diagnostic messages.
    public private(set) var messages: [DiagnosticMessage]

    /// Creates an empty collector.
    public init() {
        self.messages = []
    }

    /// Records a prebuilt diagnostic message.
    public mutating func record(_ message: DiagnosticMessage) {
        messages.append(message)
    }

    /// Records a diagnostic message from parts.
    public mutating func record(
        severity: DiagnosticSeverity,
        code: NamespaceID,
        message: String,
        source: String? = nil,
        metadata: [DiagnosticMetadata] = []
    ) {
        record(
            DiagnosticMessage(
                severity: severity,
                code: code,
                message: message,
                source: source,
                metadata: metadata
            )
        )
    }

    /// Builds a serializable report from collected messages.
    public func report() -> DiagnosticReport {
        DiagnosticReport(messages: messages)
    }
}
