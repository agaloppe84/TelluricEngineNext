#if canImport(Metal)
import Metal
#endif

import TelluricCore
import TelluricDiagnostics
import TelluricRender

/// Configuration for the isolated Metal render backend skeleton.
public struct MetalRenderBackendConfig: Codable, Equatable, Hashable, Sendable {
    /// Stable label used for backend-owned Metal objects.
    public let label: String

    /// True when the backend should attempt to create a command queue.
    public let createsCommandQueue: Bool

    /// Creates Metal backend configuration.
    public init(
        label: String = "telluric.render.metal",
        createsCommandQueue: Bool = true
    ) {
        precondition(!label.isEmpty, "Metal backend label must not be empty")
        self.label = label
        self.createsCommandQueue = createsCommandQueue
    }
}

/// Capability report for the current Metal backend context.
public struct MetalRenderBackendCapabilities: Codable, Equatable, Hashable, Sendable {
    /// True when the Metal framework can provide a default device.
    public let isMetalAvailable: Bool

    /// Human-readable device name when available.
    public let deviceName: String?

    /// True when a command queue was created for the backend.
    public let hasCommandQueue: Bool

    /// True when drawable presentation is implemented.
    public let supportsDrawablePresentation: Bool

    /// True when renderable instances are implemented.
    public let supportsRenderableInstances: Bool

    /// True when debug line rendering is implemented.
    public let supportsDebugLines: Bool

    /// True when debug point rendering is implemented.
    public let supportsDebugPoints: Bool

    /// True when debug label rendering is implemented.
    public let supportsDebugLabels: Bool

    /// Explanation when Metal is unavailable.
    public let unavailableReason: String?

    /// Creates an explicit capability report.
    public init(
        isMetalAvailable: Bool,
        deviceName: String?,
        hasCommandQueue: Bool,
        supportsDrawablePresentation: Bool = false,
        supportsRenderableInstances: Bool = false,
        supportsDebugLines: Bool = false,
        supportsDebugPoints: Bool = false,
        supportsDebugLabels: Bool = false,
        unavailableReason: String? = nil
    ) {
        self.isMetalAvailable = isMetalAvailable
        self.deviceName = deviceName
        self.hasCommandQueue = hasCommandQueue
        self.supportsDrawablePresentation = supportsDrawablePresentation
        self.supportsRenderableInstances = supportsRenderableInstances
        self.supportsDebugLines = supportsDebugLines
        self.supportsDebugPoints = supportsDebugPoints
        self.supportsDebugLabels = supportsDebugLabels
        self.unavailableReason = unavailableReason
    }

    /// Capability report for an unavailable Metal backend.
    public static func unavailable(reason: String) -> MetalRenderBackendCapabilities {
        MetalRenderBackendCapabilities(
            isMetalAvailable: false,
            deviceName: nil,
            hasCommandQueue: false,
            unavailableReason: reason
        )
    }
}

/// Engine-level Metal backend error.
public struct MetalRenderError: Codable, Equatable, Error, Hashable, Sendable {
    /// Stable machine-readable error code.
    public let code: NamespaceID

    /// Human-readable error message.
    public let message: String

    /// Creates a Metal backend error.
    public init(code: NamespaceID, message: String) {
        self.code = code
        self.message = message
    }

    /// Metal framework or default device is unavailable.
    public static func metalUnavailable(_ message: String) -> MetalRenderError {
        MetalRenderError(code: NamespaceID("render.metal.unavailable"), message: message)
    }

    /// Command queue creation failed.
    public static func commandQueueUnavailable(_ message: String) -> MetalRenderError {
        MetalRenderError(code: NamespaceID("render.metal.command_queue_unavailable"), message: message)
    }

    /// Diagnostic view of this error.
    public var diagnostic: DiagnosticMessage {
        DiagnosticMessage(
            severity: .error,
            code: code,
            message: message,
            source: "TelluricRenderMetal"
        )
    }
}

/// Backend-owned Metal device and command queue context.
public struct MetalDeviceContext: @unchecked Sendable {
    #if canImport(Metal)
    private let device: any MTLDevice
    private let commandQueue: (any MTLCommandQueue)?
    #endif

    /// Capability report for the context.
    public let capabilities: MetalRenderBackendCapabilities

    #if canImport(Metal)
    private init(
        device: any MTLDevice,
        commandQueue: (any MTLCommandQueue)?,
        capabilities: MetalRenderBackendCapabilities
    ) {
        self.device = device
        self.commandQueue = commandQueue
        self.capabilities = capabilities
    }
    #else
    private init(capabilities: MetalRenderBackendCapabilities) {
        self.capabilities = capabilities
    }
    #endif

    /// Attempts to create a system-default Metal context.
    public static func make(config: MetalRenderBackendConfig = MetalRenderBackendConfig()) throws -> MetalDeviceContext {
        #if canImport(Metal)
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalRenderError.metalUnavailable("MTLCreateSystemDefaultDevice() returned nil.")
        }

        let commandQueue: (any MTLCommandQueue)?
        if config.createsCommandQueue {
            guard let createdQueue = device.makeCommandQueue() else {
                throw MetalRenderError.commandQueueUnavailable("MTLDevice.makeCommandQueue() returned nil.")
            }
            createdQueue.label = "\(config.label).command_queue"
            commandQueue = createdQueue
        } else {
            commandQueue = nil
        }

        return MetalDeviceContext(
            device: device,
            commandQueue: commandQueue,
            capabilities: MetalRenderBackendCapabilities(
                isMetalAvailable: true,
                deviceName: device.name,
                hasCommandQueue: commandQueue != nil
            )
        )
        #else
        throw MetalRenderError.metalUnavailable("The Metal framework is unavailable on this platform.")
        #endif
    }

    /// Attempts to create a system-default Metal context as a result value.
    public static func makeResult(
        config: MetalRenderBackendConfig = MetalRenderBackendConfig()
    ) -> Result<MetalDeviceContext, MetalRenderError> {
        do {
            return .success(try make(config: config))
        } catch let error as MetalRenderError {
            return .failure(error)
        } catch {
            return .failure(MetalRenderError.metalUnavailable(String(describing: error)))
        }
    }
}

/// Descriptor for one backend frame submission attempt.
public struct MetalRenderFrameDescriptor: Codable, Equatable, Hashable, Sendable {
    /// Frame index associated with the render snapshot.
    public let frameIndex: FrameIndex

    /// Stable frame label.
    public let label: String

    /// True when the caller expected drawable presentation.
    public let requiresDrawable: Bool

    /// Creates a frame descriptor.
    public init(
        frameIndex: FrameIndex,
        label: String = "telluric.render.metal.frame",
        requiresDrawable: Bool = false
    ) {
        precondition(!label.isEmpty, "Metal frame label must not be empty")
        self.frameIndex = frameIndex
        self.label = label
        self.requiresDrawable = requiresDrawable
    }
}

/// Result of passing a render snapshot through the Metal backend skeleton.
public struct MetalRenderFrameResult: Codable, Equatable, Sendable {
    /// Frame descriptor consumed by the backend.
    public let descriptor: MetalRenderFrameDescriptor

    /// Stable hash of the accepted render snapshot.
    public let renderSnapshotHash: StableHash

    /// Capability report used for this frame.
    public let capabilities: MetalRenderBackendCapabilities

    /// Number of unsupported renderable instances in the snapshot.
    public let unsupportedRenderableInstanceCount: Int

    /// Number of unsupported texture references in renderable instances.
    public let unsupportedTextureReferenceCount: Int

    /// Number of unsupported debug lines.
    public let unsupportedDebugLineCount: Int

    /// Number of unsupported debug points.
    public let unsupportedDebugPointCount: Int

    /// Number of unsupported debug labels.
    public let unsupportedDebugLabelCount: Int

    /// Ordered diagnostics produced by the backend.
    public let diagnostics: DiagnosticReport

    /// True when the snapshot was accepted without unsupported content or backend errors.
    public let success: Bool

    /// Creates a frame result.
    public init(
        descriptor: MetalRenderFrameDescriptor,
        renderSnapshotHash: StableHash,
        capabilities: MetalRenderBackendCapabilities,
        unsupportedRenderableInstanceCount: Int,
        unsupportedTextureReferenceCount: Int,
        unsupportedDebugLineCount: Int,
        unsupportedDebugPointCount: Int,
        unsupportedDebugLabelCount: Int,
        diagnostics: DiagnosticReport
    ) {
        precondition(unsupportedRenderableInstanceCount >= 0, "unsupportedRenderableInstanceCount must be non-negative")
        precondition(unsupportedTextureReferenceCount >= 0, "unsupportedTextureReferenceCount must be non-negative")
        precondition(unsupportedDebugLineCount >= 0, "unsupportedDebugLineCount must be non-negative")
        precondition(unsupportedDebugPointCount >= 0, "unsupportedDebugPointCount must be non-negative")
        precondition(unsupportedDebugLabelCount >= 0, "unsupportedDebugLabelCount must be non-negative")

        self.descriptor = descriptor
        self.renderSnapshotHash = renderSnapshotHash
        self.capabilities = capabilities
        self.unsupportedRenderableInstanceCount = unsupportedRenderableInstanceCount
        self.unsupportedTextureReferenceCount = unsupportedTextureReferenceCount
        self.unsupportedDebugLineCount = unsupportedDebugLineCount
        self.unsupportedDebugPointCount = unsupportedDebugPointCount
        self.unsupportedDebugLabelCount = unsupportedDebugLabelCount
        self.diagnostics = diagnostics
        self.success = !diagnostics.hasErrors
            && unsupportedRenderableInstanceCount == 0
            && unsupportedTextureReferenceCount == 0
            && unsupportedDebugLineCount == 0
            && unsupportedDebugPointCount == 0
            && unsupportedDebugLabelCount == 0
            && capabilities.isMetalAvailable
            && capabilities.hasCommandQueue
    }
}

/// Diagnostic construction helpers for the Metal backend skeleton.
public enum MetalRenderBackendDiagnostics {
    /// Creates a diagnostic for unavailable Metal.
    public static func metalUnavailable(reason: String) -> DiagnosticMessage {
        DiagnosticMessage(
            severity: .error,
            code: NamespaceID("render.metal.unavailable"),
            message: reason,
            source: "TelluricRenderMetal"
        )
    }

    /// Creates a diagnostic for unsupported renderable instances.
    public static func unsupportedRenderableInstances(count: Int) -> DiagnosticMessage {
        unsupported(
            code: "render.metal.unsupported.renderable_instances",
            message: "Metal renderable instance drawing is not implemented in this backend skeleton.",
            count: count
        )
    }

    /// Creates a diagnostic for unsupported texture references.
    public static func unsupportedTextureReferences(count: Int) -> DiagnosticMessage {
        unsupported(
            code: "render.metal.unsupported.texture_references",
            message: "Metal texture/material binding is not implemented in this backend skeleton.",
            count: count
        )
    }

    /// Creates a diagnostic for unsupported debug lines.
    public static func unsupportedDebugLines(count: Int) -> DiagnosticMessage {
        unsupported(
            code: "render.metal.unsupported.debug_lines",
            message: "Metal debug line drawing is not implemented in this backend skeleton.",
            count: count
        )
    }

    /// Creates a diagnostic for unsupported debug points.
    public static func unsupportedDebugPoints(count: Int) -> DiagnosticMessage {
        unsupported(
            code: "render.metal.unsupported.debug_points",
            message: "Metal debug point drawing is not implemented in this backend skeleton.",
            count: count
        )
    }

    /// Creates a diagnostic for unsupported debug labels.
    public static func unsupportedDebugLabels(count: Int) -> DiagnosticMessage {
        unsupported(
            code: "render.metal.unsupported.debug_labels",
            message: "Metal debug label drawing is not implemented in this backend skeleton.",
            count: count
        )
    }

    /// Creates a diagnostic for missing drawable presentation support.
    public static func drawablePresentationUnsupported() -> DiagnosticMessage {
        DiagnosticMessage(
            severity: .error,
            code: NamespaceID("render.metal.unsupported.drawable_presentation"),
            message: "Drawable presentation is not implemented in this backend skeleton.",
            source: "TelluricRenderMetal"
        )
    }

    private static func unsupported(
        code: String,
        message: String,
        count: Int
    ) -> DiagnosticMessage {
        DiagnosticMessage(
            severity: .error,
            code: NamespaceID(code),
            message: message,
            source: "TelluricRenderMetal",
            metadata: [
                DiagnosticMetadata(key: "count", value: "\(count)"),
            ]
        )
    }
}

/// Isolated Metal backend skeleton consuming renderer-independent render snapshots.
public struct MetalRenderBackend: Sendable {
    private let context: MetalDeviceContext?

    /// Backend configuration.
    public let config: MetalRenderBackendConfig

    /// Current backend capabilities.
    public let capabilities: MetalRenderBackendCapabilities

    /// Diagnostics produced while creating the backend.
    public let initializationDiagnostics: DiagnosticReport

    /// Creates the backend and attempts to initialize a default Metal context.
    public init(config: MetalRenderBackendConfig = MetalRenderBackendConfig()) {
        self.config = config

        switch MetalDeviceContext.makeResult(config: config) {
        case let .success(context):
            self.context = context
            self.capabilities = context.capabilities
            self.initializationDiagnostics = DiagnosticReport(messages: [])

        case let .failure(error):
            self.context = nil
            self.capabilities = .unavailable(reason: error.message)
            self.initializationDiagnostics = DiagnosticReport(messages: [error.diagnostic])
        }
    }

    /// True when a usable Metal device and command queue are available.
    public var isAvailable: Bool {
        context != nil && capabilities.isMetalAvailable && capabilities.hasCommandQueue
    }

    /// Accepts a render snapshot and reports what this backend skeleton cannot render yet.
    public func render(
        snapshot: RenderSnapshot,
        descriptor: MetalRenderFrameDescriptor? = nil
    ) -> MetalRenderFrameResult {
        let frameDescriptor = descriptor ?? MetalRenderFrameDescriptor(frameIndex: snapshot.frameIndex)
        var messages = initializationDiagnostics.messages

        if frameDescriptor.requiresDrawable {
            messages.append(MetalRenderBackendDiagnostics.drawablePresentationUnsupported())
        }

        let unsupportedInstanceCount = snapshot.instances.count
        let unsupportedTextureReferenceCount = snapshot.instances.reduce(0) { partialResult, instance in
            partialResult + instance.textures.count
        }
        let unsupportedLineCount = snapshot.debugLines.count
        let unsupportedPointCount = snapshot.debugPoints.count
        let unsupportedLabelCount = snapshot.debugLabels.count

        if unsupportedInstanceCount > 0 {
            messages.append(MetalRenderBackendDiagnostics.unsupportedRenderableInstances(count: unsupportedInstanceCount))
        }

        if unsupportedTextureReferenceCount > 0 {
            messages.append(MetalRenderBackendDiagnostics.unsupportedTextureReferences(count: unsupportedTextureReferenceCount))
        }

        if unsupportedLineCount > 0 {
            messages.append(MetalRenderBackendDiagnostics.unsupportedDebugLines(count: unsupportedLineCount))
        }

        if unsupportedPointCount > 0 {
            messages.append(MetalRenderBackendDiagnostics.unsupportedDebugPoints(count: unsupportedPointCount))
        }

        if unsupportedLabelCount > 0 {
            messages.append(MetalRenderBackendDiagnostics.unsupportedDebugLabels(count: unsupportedLabelCount))
        }

        return MetalRenderFrameResult(
            descriptor: frameDescriptor,
            renderSnapshotHash: snapshot.stableHash,
            capabilities: capabilities,
            unsupportedRenderableInstanceCount: unsupportedInstanceCount,
            unsupportedTextureReferenceCount: unsupportedTextureReferenceCount,
            unsupportedDebugLineCount: unsupportedLineCount,
            unsupportedDebugPointCount: unsupportedPointCount,
            unsupportedDebugLabelCount: unsupportedLabelCount,
            diagnostics: DiagnosticReport(messages: messages)
        )
    }
}
