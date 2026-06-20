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

    /// True when debug line CPU conversion and Metal buffer preparation are implemented.
    public let supportsDebugLinePreparation: Bool

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
        supportsDebugLinePreparation: Bool = false,
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
        self.supportsDebugLinePreparation = supportsDebugLinePreparation
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

/// Pixel format used by a drawable render pass.
public enum MetalDrawablePixelFormat: String, Codable, CaseIterable, Sendable {
    case bgra8Unorm

    #if canImport(Metal)
    fileprivate var metalPixelFormat: MTLPixelFormat {
        switch self {
        case .bgra8Unorm:
            return .bgra8Unorm
        }
    }
    #endif
}

/// Clear color used by the minimal drawable pass.
public struct MetalDrawableClearColor: Codable, Equatable, Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    /// Default dark clear color for debug rendering.
    public static let debugBackground = MetalDrawableClearColor(red: 0.02, green: 0.025, blue: 0.03, alpha: 1)

    /// Creates a clear color.
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        precondition(Self.isUnit(red), "red must be finite and within 0...1")
        precondition(Self.isUnit(green), "green must be finite and within 0...1")
        precondition(Self.isUnit(blue), "blue must be finite and within 0...1")
        precondition(Self.isUnit(alpha), "alpha must be finite and within 0...1")
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    #if canImport(Metal)
    fileprivate var metalClearColor: MTLClearColor {
        MTLClearColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    #endif

    private static func isUnit(_ value: Double) -> Bool {
        value.isFinite && value >= 0 && value <= 1
    }
}

/// Debug-only top-down projection for drawing world-space chunk lines.
public struct MetalDebugLineProjection: Codable, Equatable, Hashable, Sendable {
    /// World x coordinate mapped to clip-space center.
    public let centerX: Float

    /// World z coordinate mapped to clip-space center.
    public let centerZ: Float

    /// Positive world x half extent mapped to clip-space x `-1...1`.
    public let halfExtentX: Float

    /// Positive world z half extent mapped to clip-space y `-1...1`.
    public let halfExtentZ: Float

    /// Creates a debug top-down projection.
    public init(centerX: Float, centerZ: Float, halfExtentX: Float, halfExtentZ: Float) {
        precondition(centerX.isFinite, "centerX must be finite")
        precondition(centerZ.isFinite, "centerZ must be finite")
        precondition(halfExtentX.isFinite && halfExtentX > 0, "halfExtentX must be finite and positive")
        precondition(halfExtentZ.isFinite && halfExtentZ > 0, "halfExtentZ must be finite and positive")
        self.centerX = centerX
        self.centerZ = centerZ
        self.halfExtentX = halfExtentX
        self.halfExtentZ = halfExtentZ
    }
}

/// Descriptor for a drawable-backed debug line frame.
public struct MetalDrawableFrameDescriptor: Codable, Equatable, Hashable, Sendable {
    /// Frame index associated with the drawable pass.
    public let frameIndex: FrameIndex

    /// Stable frame label.
    public let label: String

    /// Drawable width in pixels.
    public let viewportWidth: Int

    /// Drawable height in pixels.
    public let viewportHeight: Int

    /// Pixel format expected by the render pipeline.
    public let pixelFormat: MetalDrawablePixelFormat

    /// Clear color applied before debug lines are drawn.
    public let clearColor: MetalDrawableClearColor

    /// Debug-only top-down projection.
    public let debugLineProjection: MetalDebugLineProjection

    /// Creates a drawable frame descriptor.
    public init(
        frameIndex: FrameIndex,
        label: String = "telluric.render.metal.drawable_frame",
        viewportWidth: Int,
        viewportHeight: Int,
        pixelFormat: MetalDrawablePixelFormat = .bgra8Unorm,
        clearColor: MetalDrawableClearColor = .debugBackground,
        debugLineProjection: MetalDebugLineProjection
    ) {
        precondition(!label.isEmpty, "Drawable frame label must not be empty")
        precondition(viewportWidth > 0, "viewportWidth must be positive")
        precondition(viewportHeight > 0, "viewportHeight must be positive")
        self.frameIndex = frameIndex
        self.label = label
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight
        self.pixelFormat = pixelFormat
        self.clearColor = clearColor
        self.debugLineProjection = debugLineProjection
    }

    /// Returns this descriptor with updated drawable dimensions.
    public func withViewport(width: Int, height: Int) -> MetalDrawableFrameDescriptor {
        MetalDrawableFrameDescriptor(
            frameIndex: frameIndex,
            label: label,
            viewportWidth: width,
            viewportHeight: height,
            pixelFormat: pixelFormat,
            clearColor: clearColor,
            debugLineProjection: debugLineProjection
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

    /// Debug line vertex buffer creation failed.
    public static func debugLineBufferUnavailable(_ message: String) -> MetalRenderError {
        MetalRenderError(code: NamespaceID("render.metal.debug_line.buffer_unavailable"), message: message)
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
                hasCommandQueue: commandQueue != nil,
                supportsDrawablePresentation: true,
                supportsDebugLines: true,
                supportsDebugLinePreparation: true
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

    #if canImport(Metal)
    fileprivate var metalDevice: any MTLDevice {
        device
    }

    fileprivate func makeDebugLineBuffer(
        packedVertices: [PackedMetalDebugLineVertex],
        label: String
    ) throws -> any MTLBuffer {
        precondition(!packedVertices.isEmpty, "packedVertices must not be empty")

        return try packedVertices.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                throw MetalRenderError.debugLineBufferUnavailable("Debug line vertex storage had no base address.")
            }

            guard let buffer = device.makeBuffer(bytes: baseAddress, length: rawBuffer.count, options: []) else {
                throw MetalRenderError.debugLineBufferUnavailable("MTLDevice.makeBuffer(bytes:length:options:) returned nil.")
            }

            buffer.label = label
            return buffer
        }
    }

    fileprivate func makeCommandBuffer(label: String) throws -> any MTLCommandBuffer {
        guard let commandQueue else {
            throw MetalRenderError.commandQueueUnavailable("No Metal command queue is available for drawable rendering.")
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw MetalRenderError.commandQueueUnavailable("MTLCommandQueue.makeCommandBuffer() returned nil.")
        }

        commandBuffer.label = label
        return commandBuffer
    }

    fileprivate func makeDebugLineRenderPipeline(
        pixelFormat: MetalDrawablePixelFormat,
        label: String
    ) throws -> any MTLRenderPipelineState {
        let library = try device.makeLibrary(source: MetalDebugLineRenderPipeline.shaderSource, options: nil)

        guard let vertexFunction = library.makeFunction(name: "telluric_debug_line_vertex") else {
            throw MetalRenderError(
                code: NamespaceID("render.metal.debug_line.pipeline_unavailable"),
                message: "Debug line vertex function was not found."
            )
        }

        guard let fragmentFunction = library.makeFunction(name: "telluric_debug_line_fragment") else {
            throw MetalRenderError(
                code: NamespaceID("render.metal.debug_line.pipeline_unavailable"),
                message: "Debug line fragment function was not found."
            )
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = label
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = pixelFormat.metalPixelFormat

        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            throw MetalRenderError(
                code: NamespaceID("render.metal.debug_line.pipeline_unavailable"),
                message: "MTLDevice.makeRenderPipelineState failed: \(error)"
            )
        }
    }
    #endif
}

/// CPU-side Metal debug line vertex produced from backend-neutral `DebugLine` primitives.
public struct MetalDebugLineVertex: Codable, Equatable, Hashable, Sendable {
    /// X coordinate in render/world space.
    public let positionX: Float

    /// Y coordinate in render/world space.
    public let positionY: Float

    /// Z coordinate in render/world space.
    public let positionZ: Float

    /// Red color component in `0...1`.
    public let red: Float

    /// Green color component in `0...1`.
    public let green: Float

    /// Blue color component in `0...1`.
    public let blue: Float

    /// Alpha color component in `0...1`.
    public let alpha: Float

    /// Creates a scalar Metal debug line vertex.
    public init(
        positionX: Float,
        positionY: Float,
        positionZ: Float,
        red: Float,
        green: Float,
        blue: Float,
        alpha: Float
    ) {
        self.positionX = positionX
        self.positionY = positionY
        self.positionZ = positionZ
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

/// Ordered CPU conversion output for debug line primitives.
public struct MetalDebugLineBatch: Codable, Equatable, Sendable {
    /// Ordered vertices. Each valid debug line contributes exactly two vertices.
    public let vertices: [MetalDebugLineVertex]

    /// Number of source debug lines consumed by the conversion pass.
    public let sourceLineCount: Int

    /// Diagnostics emitted while converting source debug lines.
    public let diagnostics: DiagnosticReport

    /// Creates a debug line batch.
    public init(
        vertices: [MetalDebugLineVertex],
        sourceLineCount: Int,
        diagnostics: DiagnosticReport = DiagnosticReport(messages: [])
    ) {
        precondition(sourceLineCount >= 0, "sourceLineCount must be non-negative")
        precondition(vertices.count % 2 == 0, "Debug line vertices must be stored in start/end pairs")
        self.vertices = vertices
        self.sourceLineCount = sourceLineCount
        self.diagnostics = diagnostics
    }

    /// Number of valid debug lines represented by `vertices`.
    public var validLineCount: Int {
        vertices.count / 2
    }

    /// Number of vertices represented by this batch.
    public var vertexCount: Int {
        vertices.count
    }

    /// Byte length required by the internal packed Metal vertex representation.
    public var packedByteLength: Int {
        vertices.count * MemoryLayout<PackedMetalDebugLineVertex>.stride
    }

    /// True when conversion completed without errors.
    public var success: Bool {
        !diagnostics.hasErrors
    }
}

/// Result of preparing debug line vertices for a Metal buffer.
public struct MetalDebugLineBuffer: @unchecked Sendable {
    #if canImport(Metal)
    private let buffer: (any MTLBuffer)?

    fileprivate var metalBuffer: (any MTLBuffer)? {
        buffer
    }
    #endif

    /// Number of source debug lines consumed by the conversion pass.
    public let sourceLineCount: Int

    /// Number of valid debug lines represented by this buffer result.
    public let validLineCount: Int

    /// Number of vertices represented by this buffer result.
    public let vertexCount: Int

    /// Byte length of the packed vertex data.
    public let byteLength: Int

    /// True when a Metal buffer exists for non-empty vertex data.
    public let hasMetalBuffer: Bool

    /// Diagnostics emitted while preparing the buffer.
    public let diagnostics: DiagnosticReport

    /// True when buffer preparation completed without errors.
    public let success: Bool

    #if canImport(Metal)
    fileprivate init(
        batch: MetalDebugLineBatch,
        buffer: (any MTLBuffer)?,
        diagnostics: DiagnosticReport
    ) {
        self.buffer = buffer
        self.sourceLineCount = batch.sourceLineCount
        self.validLineCount = batch.validLineCount
        self.vertexCount = batch.vertexCount
        self.byteLength = batch.packedByteLength
        self.hasMetalBuffer = buffer != nil
        self.diagnostics = diagnostics
        self.success = !diagnostics.hasErrors && (batch.vertexCount == 0 || buffer != nil)
    }
    #else
    fileprivate init(batch: MetalDebugLineBatch, diagnostics: DiagnosticReport) {
        self.sourceLineCount = batch.sourceLineCount
        self.validLineCount = batch.validLineCount
        self.vertexCount = batch.vertexCount
        self.byteLength = batch.packedByteLength
        self.hasMetalBuffer = false
        self.diagnostics = diagnostics
        self.success = !diagnostics.hasErrors && batch.vertexCount == 0
    }
    #endif
}

/// Debug line preparation pipeline for the isolated Metal backend.
public enum MetalDebugLinePipeline {
    /// Converts ordered debug line primitives into ordered Metal debug line vertices.
    public static func makeBatch(lines: [DebugLine]) -> MetalDebugLineBatch {
        var vertices: [MetalDebugLineVertex] = []
        vertices.reserveCapacity(lines.count * 2)
        var diagnostics: [DiagnosticMessage] = []

        for (index, line) in lines.enumerated() {
            guard hasFiniteEndpoints(line) else {
                diagnostics.append(
                    MetalRenderBackendDiagnostics.invalidDebugLine(
                        index: index,
                        reason: "Debug line endpoints must contain only finite coordinates."
                    )
                )
                continue
            }

            vertices.append(vertex(fromStartOf: line))
            vertices.append(vertex(fromEndOf: line))
        }

        return MetalDebugLineBatch(
            vertices: vertices,
            sourceLineCount: lines.count,
            diagnostics: DiagnosticReport(messages: diagnostics)
        )
    }

    /// Creates a Metal vertex buffer for a converted debug line batch when a context is available.
    public static func makeBuffer(
        batch: MetalDebugLineBatch,
        context: MetalDeviceContext?,
        label: String = "telluric.render.metal.debug_lines"
    ) -> MetalDebugLineBuffer {
        var diagnostics = batch.diagnostics.messages

        guard !batch.diagnostics.hasErrors else {
            return bufferResultWithoutMetalBuffer(batch: batch, diagnostics: DiagnosticReport(messages: diagnostics))
        }

        guard batch.vertexCount > 0 else {
            return bufferResultWithoutMetalBuffer(batch: batch, diagnostics: DiagnosticReport(messages: diagnostics))
        }

        guard let context else {
            diagnostics.append(
                MetalRenderBackendDiagnostics.debugLineBufferUnavailable(
                    reason: "No Metal device context is available for debug line buffer creation.",
                    vertexCount: batch.vertexCount
                )
            )
            return bufferResultWithoutMetalBuffer(batch: batch, diagnostics: DiagnosticReport(messages: diagnostics))
        }

        #if canImport(Metal)
        do {
            let packedVertices = batch.vertices.map(PackedMetalDebugLineVertex.init(vertex:))
            let buffer = try context.makeDebugLineBuffer(packedVertices: packedVertices, label: label)
            return bufferResult(batch: batch, buffer: buffer, diagnostics: DiagnosticReport(messages: diagnostics))
        } catch let error as MetalRenderError {
            diagnostics.append(
                MetalRenderBackendDiagnostics.debugLineBufferUnavailable(
                    reason: error.message,
                    vertexCount: batch.vertexCount
                )
            )
            return bufferResultWithoutMetalBuffer(batch: batch, diagnostics: DiagnosticReport(messages: diagnostics))
        } catch {
            diagnostics.append(
                MetalRenderBackendDiagnostics.debugLineBufferUnavailable(
                    reason: String(describing: error),
                    vertexCount: batch.vertexCount
                )
            )
            return bufferResultWithoutMetalBuffer(batch: batch, diagnostics: DiagnosticReport(messages: diagnostics))
        }
        #else
        diagnostics.append(
            MetalRenderBackendDiagnostics.debugLineBufferUnavailable(
                reason: "The Metal framework is unavailable on this platform.",
                vertexCount: batch.vertexCount
            )
        )
        return bufferResult(batch: batch, diagnostics: DiagnosticReport(messages: diagnostics))
        #endif
    }

    private static func vertex(fromStartOf line: DebugLine) -> MetalDebugLineVertex {
        MetalDebugLineVertex(
            positionX: line.start.x,
            positionY: line.start.y,
            positionZ: line.start.z,
            red: line.color.red,
            green: line.color.green,
            blue: line.color.blue,
            alpha: line.color.alpha
        )
    }

    private static func vertex(fromEndOf line: DebugLine) -> MetalDebugLineVertex {
        MetalDebugLineVertex(
            positionX: line.end.x,
            positionY: line.end.y,
            positionZ: line.end.z,
            red: line.color.red,
            green: line.color.green,
            blue: line.color.blue,
            alpha: line.color.alpha
        )
    }

    private static func hasFiniteEndpoints(_ line: DebugLine) -> Bool {
        line.start.x.isFinite
            && line.start.y.isFinite
            && line.start.z.isFinite
            && line.end.x.isFinite
            && line.end.y.isFinite
            && line.end.z.isFinite
    }

    private static func bufferResultWithoutMetalBuffer(
        batch: MetalDebugLineBatch,
        diagnostics: DiagnosticReport
    ) -> MetalDebugLineBuffer {
        #if canImport(Metal)
        MetalDebugLineBuffer(batch: batch, buffer: nil, diagnostics: diagnostics)
        #else
        MetalDebugLineBuffer(batch: batch, diagnostics: diagnostics)
        #endif
    }

    #if canImport(Metal)
    private static func bufferResult(
        batch: MetalDebugLineBatch,
        buffer: (any MTLBuffer)?,
        diagnostics: DiagnosticReport
    ) -> MetalDebugLineBuffer {
        MetalDebugLineBuffer(batch: batch, buffer: buffer, diagnostics: diagnostics)
    }
    #else
    private static func bufferResult(
        batch: MetalDebugLineBatch,
        diagnostics: DiagnosticReport
    ) -> MetalDebugLineBuffer {
        MetalDebugLineBuffer(batch: batch, diagnostics: diagnostics)
    }
    #endif
}

/// Result of creating the minimal Metal pipeline state for debug line drawing.
public struct MetalDebugLineRenderPipeline: @unchecked Sendable {
    #if canImport(Metal)
    fileprivate let pipelineState: (any MTLRenderPipelineState)?
    #endif

    /// Pixel format used to create the pipeline.
    public let pixelFormat: MetalDrawablePixelFormat

    /// Ordered diagnostics emitted while creating the pipeline.
    public let diagnostics: DiagnosticReport

    /// True when a Metal render pipeline state exists.
    public let success: Bool

    #if canImport(Metal)
    private init(
        pixelFormat: MetalDrawablePixelFormat,
        pipelineState: (any MTLRenderPipelineState)?,
        diagnostics: DiagnosticReport
    ) {
        self.pixelFormat = pixelFormat
        self.pipelineState = pipelineState
        self.diagnostics = diagnostics
        self.success = pipelineState != nil && !diagnostics.hasErrors
    }
    #else
    private init(pixelFormat: MetalDrawablePixelFormat, diagnostics: DiagnosticReport) {
        self.pixelFormat = pixelFormat
        self.diagnostics = diagnostics
        self.success = false
    }
    #endif

    /// Builds the debug line render pipeline or reports why it cannot be built.
    public static func make(
        context: MetalDeviceContext?,
        pixelFormat: MetalDrawablePixelFormat,
        label: String = "telluric.render.metal.debug_line_pipeline"
    ) -> MetalDebugLineRenderPipeline {
        guard let context else {
            let diagnostics = DiagnosticReport(messages: [
                MetalRenderBackendDiagnostics.debugLinePipelineUnavailable(
                    reason: "No Metal device context is available for debug line pipeline creation."
                ),
            ])
            return resultWithoutPipeline(pixelFormat: pixelFormat, diagnostics: diagnostics)
        }

        #if canImport(Metal)
        do {
            let pipelineState = try context.makeDebugLineRenderPipeline(pixelFormat: pixelFormat, label: label)
            return MetalDebugLineRenderPipeline(
                pixelFormat: pixelFormat,
                pipelineState: pipelineState,
                diagnostics: DiagnosticReport(messages: [])
            )
        } catch let error as MetalRenderError {
            let diagnostics = DiagnosticReport(messages: [
                MetalRenderBackendDiagnostics.debugLinePipelineUnavailable(reason: error.message),
            ])
            return MetalDebugLineRenderPipeline(pixelFormat: pixelFormat, pipelineState: nil, diagnostics: diagnostics)
        } catch {
            let diagnostics = DiagnosticReport(messages: [
                MetalRenderBackendDiagnostics.debugLinePipelineUnavailable(reason: String(describing: error)),
            ])
            return MetalDebugLineRenderPipeline(pixelFormat: pixelFormat, pipelineState: nil, diagnostics: diagnostics)
        }
        #else
        let diagnostics = DiagnosticReport(messages: [
            MetalRenderBackendDiagnostics.debugLinePipelineUnavailable(
                reason: "The Metal framework is unavailable on this platform."
            ),
        ])
        return resultWithoutPipeline(pixelFormat: pixelFormat, diagnostics: diagnostics)
        #endif
    }

    fileprivate static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct TelluricDebugLineVertex {
        float positionX;
        float positionY;
        float positionZ;
        float red;
        float green;
        float blue;
        float alpha;
    };

    struct TelluricDebugLineUniforms {
        float centerX;
        float centerZ;
        float halfExtentX;
        float halfExtentZ;
    };

    struct TelluricDebugLineOutput {
        float4 position [[position]];
        float4 color;
    };

    vertex TelluricDebugLineOutput telluric_debug_line_vertex(
        const device TelluricDebugLineVertex *vertices [[buffer(0)]],
        constant TelluricDebugLineUniforms& uniforms [[buffer(1)]],
        uint vertexID [[vertex_id]]
    ) {
        TelluricDebugLineVertex vertex = vertices[vertexID];
        float clipX = (vertex.positionX - uniforms.centerX) / uniforms.halfExtentX;
        float clipY = (vertex.positionZ - uniforms.centerZ) / uniforms.halfExtentZ;

        TelluricDebugLineOutput output;
        output.position = float4(clipX, clipY, 0.0, 1.0);
        output.color = float4(vertex.red, vertex.green, vertex.blue, vertex.alpha);
        return output;
    }

    fragment float4 telluric_debug_line_fragment(TelluricDebugLineOutput input [[stage_in]]) {
        return input.color;
    }
    """

    private static func resultWithoutPipeline(
        pixelFormat: MetalDrawablePixelFormat,
        diagnostics: DiagnosticReport
    ) -> MetalDebugLineRenderPipeline {
        #if canImport(Metal)
        MetalDebugLineRenderPipeline(pixelFormat: pixelFormat, pipelineState: nil, diagnostics: diagnostics)
        #else
        MetalDebugLineRenderPipeline(pixelFormat: pixelFormat, diagnostics: diagnostics)
        #endif
    }
}

fileprivate struct PackedMetalDebugLineUniforms {
    let centerX: Float
    let centerZ: Float
    let halfExtentX: Float
    let halfExtentZ: Float

    init(projection: MetalDebugLineProjection) {
        self.centerX = projection.centerX
        self.centerZ = projection.centerZ
        self.halfExtentX = projection.halfExtentX
        self.halfExtentZ = projection.halfExtentZ
    }
}

fileprivate struct PackedMetalDebugLineVertex {
    let positionX: Float
    let positionY: Float
    let positionZ: Float
    let red: Float
    let green: Float
    let blue: Float
    let alpha: Float

    init(vertex: MetalDebugLineVertex) {
        self.positionX = vertex.positionX
        self.positionY = vertex.positionY
        self.positionZ = vertex.positionZ
        self.red = vertex.red
        self.green = vertex.green
        self.blue = vertex.blue
        self.alpha = vertex.alpha
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

    /// Number of debug lines converted into Metal-side vertex data.
    public let preparedDebugLineCount: Int

    /// Number of debug line vertices prepared for Metal-side consumption.
    public let preparedDebugLineVertexCount: Int

    /// Byte length of prepared debug line vertex data.
    public let preparedDebugLineBufferByteLength: Int

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
        preparedDebugLineCount: Int = 0,
        preparedDebugLineVertexCount: Int = 0,
        preparedDebugLineBufferByteLength: Int = 0,
        unsupportedDebugPointCount: Int,
        unsupportedDebugLabelCount: Int,
        diagnostics: DiagnosticReport
    ) {
        precondition(unsupportedRenderableInstanceCount >= 0, "unsupportedRenderableInstanceCount must be non-negative")
        precondition(unsupportedTextureReferenceCount >= 0, "unsupportedTextureReferenceCount must be non-negative")
        precondition(unsupportedDebugLineCount >= 0, "unsupportedDebugLineCount must be non-negative")
        precondition(preparedDebugLineCount >= 0, "preparedDebugLineCount must be non-negative")
        precondition(preparedDebugLineVertexCount >= 0, "preparedDebugLineVertexCount must be non-negative")
        precondition(preparedDebugLineBufferByteLength >= 0, "preparedDebugLineBufferByteLength must be non-negative")
        precondition(unsupportedDebugPointCount >= 0, "unsupportedDebugPointCount must be non-negative")
        precondition(unsupportedDebugLabelCount >= 0, "unsupportedDebugLabelCount must be non-negative")

        self.descriptor = descriptor
        self.renderSnapshotHash = renderSnapshotHash
        self.capabilities = capabilities
        self.unsupportedRenderableInstanceCount = unsupportedRenderableInstanceCount
        self.unsupportedTextureReferenceCount = unsupportedTextureReferenceCount
        self.unsupportedDebugLineCount = unsupportedDebugLineCount
        self.preparedDebugLineCount = preparedDebugLineCount
        self.preparedDebugLineVertexCount = preparedDebugLineVertexCount
        self.preparedDebugLineBufferByteLength = preparedDebugLineBufferByteLength
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

/// Result of rendering debug lines into a drawable-backed Metal frame.
public struct MetalDrawableRenderResult: Codable, Equatable, Sendable {
    /// Descriptor consumed by the drawable pass.
    public let descriptor: MetalDrawableFrameDescriptor

    /// Stable hash of the accepted render snapshot.
    public let renderSnapshotHash: StableHash

    /// Capability report used for this frame.
    public let capabilities: MetalRenderBackendCapabilities

    /// Number of unsupported renderable instances in the snapshot.
    public let unsupportedRenderableInstanceCount: Int

    /// Number of unsupported texture references in renderable instances.
    public let unsupportedTextureReferenceCount: Int

    /// Number of debug lines converted into Metal-side vertex data.
    public let preparedDebugLineCount: Int

    /// Number of debug line vertices prepared for Metal-side consumption.
    public let preparedDebugLineVertexCount: Int

    /// Byte length of prepared debug line vertex data.
    public let preparedDebugLineBufferByteLength: Int

    /// Number of debug lines submitted to the drawable render pass.
    public let drawnDebugLineCount: Int

    /// Number of debug line vertices submitted to the drawable render pass.
    public let drawnDebugLineVertexCount: Int

    /// Number of unsupported debug points.
    public let unsupportedDebugPointCount: Int

    /// Number of unsupported debug labels.
    public let unsupportedDebugLabelCount: Int

    /// True when a drawable was presented by this pass.
    public let presentedDrawable: Bool

    /// Ordered diagnostics produced by the drawable pass.
    public let diagnostics: DiagnosticReport

    /// True when drawable rendering completed without unsupported content or backend errors.
    public let success: Bool

    /// Creates a drawable render result.
    public init(
        descriptor: MetalDrawableFrameDescriptor,
        renderSnapshotHash: StableHash,
        capabilities: MetalRenderBackendCapabilities,
        unsupportedRenderableInstanceCount: Int,
        unsupportedTextureReferenceCount: Int,
        preparedDebugLineCount: Int,
        preparedDebugLineVertexCount: Int,
        preparedDebugLineBufferByteLength: Int,
        drawnDebugLineCount: Int,
        drawnDebugLineVertexCount: Int,
        unsupportedDebugPointCount: Int,
        unsupportedDebugLabelCount: Int,
        presentedDrawable: Bool,
        diagnostics: DiagnosticReport
    ) {
        precondition(unsupportedRenderableInstanceCount >= 0, "unsupportedRenderableInstanceCount must be non-negative")
        precondition(unsupportedTextureReferenceCount >= 0, "unsupportedTextureReferenceCount must be non-negative")
        precondition(preparedDebugLineCount >= 0, "preparedDebugLineCount must be non-negative")
        precondition(preparedDebugLineVertexCount >= 0, "preparedDebugLineVertexCount must be non-negative")
        precondition(preparedDebugLineBufferByteLength >= 0, "preparedDebugLineBufferByteLength must be non-negative")
        precondition(drawnDebugLineCount >= 0, "drawnDebugLineCount must be non-negative")
        precondition(drawnDebugLineVertexCount >= 0, "drawnDebugLineVertexCount must be non-negative")
        precondition(unsupportedDebugPointCount >= 0, "unsupportedDebugPointCount must be non-negative")
        precondition(unsupportedDebugLabelCount >= 0, "unsupportedDebugLabelCount must be non-negative")

        self.descriptor = descriptor
        self.renderSnapshotHash = renderSnapshotHash
        self.capabilities = capabilities
        self.unsupportedRenderableInstanceCount = unsupportedRenderableInstanceCount
        self.unsupportedTextureReferenceCount = unsupportedTextureReferenceCount
        self.preparedDebugLineCount = preparedDebugLineCount
        self.preparedDebugLineVertexCount = preparedDebugLineVertexCount
        self.preparedDebugLineBufferByteLength = preparedDebugLineBufferByteLength
        self.drawnDebugLineCount = drawnDebugLineCount
        self.drawnDebugLineVertexCount = drawnDebugLineVertexCount
        self.unsupportedDebugPointCount = unsupportedDebugPointCount
        self.unsupportedDebugLabelCount = unsupportedDebugLabelCount
        self.presentedDrawable = presentedDrawable
        self.diagnostics = diagnostics
        self.success = !diagnostics.hasErrors
            && unsupportedRenderableInstanceCount == 0
            && unsupportedTextureReferenceCount == 0
            && unsupportedDebugPointCount == 0
            && unsupportedDebugLabelCount == 0
            && capabilities.isMetalAvailable
            && capabilities.hasCommandQueue
            && presentedDrawable
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

    /// Creates a diagnostic for a missing drawable.
    public static func missingDrawable() -> DiagnosticMessage {
        DiagnosticMessage(
            severity: .error,
            code: NamespaceID("render.metal.drawable.missing"),
            message: "Drawable rendering was requested but no Metal drawable was provided.",
            source: "TelluricRenderMetal"
        )
    }

    /// Creates a diagnostic for a missing render pass descriptor.
    public static func missingRenderPassDescriptor() -> DiagnosticMessage {
        DiagnosticMessage(
            severity: .error,
            code: NamespaceID("render.metal.render_pass_descriptor.missing"),
            message: "Drawable rendering was requested but no render pass descriptor was provided.",
            source: "TelluricRenderMetal"
        )
    }

    /// Creates a diagnostic for debug line pipeline creation failure.
    public static func debugLinePipelineUnavailable(reason: String) -> DiagnosticMessage {
        DiagnosticMessage(
            severity: .error,
            code: NamespaceID("render.metal.debug_line.pipeline_unavailable"),
            message: reason,
            source: "TelluricRenderMetal"
        )
    }

    /// Creates a diagnostic for command buffer creation failure.
    public static func commandBufferUnavailable(reason: String) -> DiagnosticMessage {
        DiagnosticMessage(
            severity: .error,
            code: NamespaceID("render.metal.command_buffer_unavailable"),
            message: reason,
            source: "TelluricRenderMetal"
        )
    }

    /// Creates a diagnostic for command encoder creation failure.
    public static func commandEncoderUnavailable(reason: String) -> DiagnosticMessage {
        DiagnosticMessage(
            severity: .error,
            code: NamespaceID("render.metal.command_encoder_unavailable"),
            message: reason,
            source: "TelluricRenderMetal"
        )
    }

    /// Creates a diagnostic for invalid debug line source data.
    public static func invalidDebugLine(index: Int, reason: String) -> DiagnosticMessage {
        DiagnosticMessage(
            severity: .error,
            code: NamespaceID("render.metal.debug_line.invalid"),
            message: reason,
            source: "TelluricRenderMetal",
            metadata: [
                DiagnosticMetadata(key: "index", value: "\(index)"),
            ]
        )
    }

    /// Creates a diagnostic for debug line buffer creation that cannot proceed.
    public static func debugLineBufferUnavailable(reason: String, vertexCount: Int) -> DiagnosticMessage {
        DiagnosticMessage(
            severity: .error,
            code: NamespaceID("render.metal.debug_line.buffer_unavailable"),
            message: reason,
            source: "TelluricRenderMetal",
            metadata: [
                DiagnosticMetadata(key: "vertexCount", value: "\(vertexCount)"),
            ]
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

    #if canImport(Metal)
    /// Metal device owned by this backend context, if available.
    public var metalDevice: (any MTLDevice)? {
        context?.metalDevice
    }
    #endif

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
        let debugLineBatch = MetalDebugLinePipeline.makeBatch(lines: snapshot.debugLines)
        let debugLineBuffer = MetalDebugLinePipeline.makeBuffer(
            batch: debugLineBatch,
            context: context,
            label: "\(config.label).debug_lines"
        )
        messages.append(contentsOf: debugLineBuffer.diagnostics.messages)

        let unsupportedLineCount = 0
        let unsupportedPointCount = snapshot.debugPoints.count
        let unsupportedLabelCount = snapshot.debugLabels.count

        if unsupportedInstanceCount > 0 {
            messages.append(MetalRenderBackendDiagnostics.unsupportedRenderableInstances(count: unsupportedInstanceCount))
        }

        if unsupportedTextureReferenceCount > 0 {
            messages.append(MetalRenderBackendDiagnostics.unsupportedTextureReferences(count: unsupportedTextureReferenceCount))
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
            preparedDebugLineCount: debugLineBuffer.validLineCount,
            preparedDebugLineVertexCount: debugLineBuffer.vertexCount,
            preparedDebugLineBufferByteLength: debugLineBuffer.byteLength,
            unsupportedDebugPointCount: unsupportedPointCount,
            unsupportedDebugLabelCount: unsupportedLabelCount,
            diagnostics: DiagnosticReport(messages: messages)
        )
    }

    /// Attempts drawable-backed debug line rendering without requiring app frameworks.
    public func renderDrawable(
        snapshot: RenderSnapshot,
        descriptor: MetalDrawableFrameDescriptor
    ) -> MetalDrawableRenderResult {
        #if canImport(Metal)
        renderDrawable(
            snapshot: snapshot,
            descriptor: descriptor,
            drawable: nil,
            renderPassDescriptor: nil
        )
        #else
        var messages = initializationDiagnostics.messages
        messages.append(MetalRenderBackendDiagnostics.missingDrawable())
        messages.append(MetalRenderBackendDiagnostics.missingRenderPassDescriptor())

        return drawableResult(
            snapshot: snapshot,
            descriptor: descriptor,
            debugLineBuffer: MetalDebugLinePipeline.makeBuffer(
                batch: MetalDebugLinePipeline.makeBatch(lines: snapshot.debugLines),
                context: nil
            ),
            drawnDebugLineCount: 0,
            drawnDebugLineVertexCount: 0,
            presentedDrawable: false,
            diagnostics: DiagnosticReport(messages: messages + unsupportedDiagnostics(for: snapshot))
        )
        #endif
    }

    #if canImport(Metal)
    /// Attempts drawable-backed debug line rendering using caller-owned drawable lifecycle.
    public func renderDrawable(
        snapshot: RenderSnapshot,
        descriptor: MetalDrawableFrameDescriptor,
        drawable: (any MTLDrawable)?,
        renderPassDescriptor: MTLRenderPassDescriptor?
    ) -> MetalDrawableRenderResult {
        var messages = initializationDiagnostics.messages
        messages.append(contentsOf: unsupportedDiagnostics(for: snapshot))

        let debugLineBatch = MetalDebugLinePipeline.makeBatch(lines: snapshot.debugLines)
        let debugLineBuffer = MetalDebugLinePipeline.makeBuffer(
            batch: debugLineBatch,
            context: context,
            label: "\(config.label).drawable_debug_lines"
        )
        messages.append(contentsOf: debugLineBuffer.diagnostics.messages)

        if drawable == nil {
            messages.append(MetalRenderBackendDiagnostics.missingDrawable())
        }

        if renderPassDescriptor == nil {
            messages.append(MetalRenderBackendDiagnostics.missingRenderPassDescriptor())
        }

        guard let context else {
            return drawableResult(
                snapshot: snapshot,
                descriptor: descriptor,
                debugLineBuffer: debugLineBuffer,
                drawnDebugLineCount: 0,
                drawnDebugLineVertexCount: 0,
                presentedDrawable: false,
                diagnostics: DiagnosticReport(messages: messages)
            )
        }

        guard let drawable else {
            return drawableResult(
                snapshot: snapshot,
                descriptor: descriptor,
                debugLineBuffer: debugLineBuffer,
                drawnDebugLineCount: 0,
                drawnDebugLineVertexCount: 0,
                presentedDrawable: false,
                diagnostics: DiagnosticReport(messages: messages)
            )
        }

        guard let renderPassDescriptor else {
            return drawableResult(
                snapshot: snapshot,
                descriptor: descriptor,
                debugLineBuffer: debugLineBuffer,
                drawnDebugLineCount: 0,
                drawnDebugLineVertexCount: 0,
                presentedDrawable: false,
                diagnostics: DiagnosticReport(messages: messages)
            )
        }

        var drawnDebugLineCount = 0
        var drawnDebugLineVertexCount = 0
        var presentedDrawable = false

        do {
            let commandBuffer = try context.makeCommandBuffer(label: "\(descriptor.label).command_buffer")

            if let colorAttachment = renderPassDescriptor.colorAttachments[0] {
                colorAttachment.loadAction = .clear
                colorAttachment.clearColor = descriptor.clearColor.metalClearColor
                colorAttachment.storeAction = .store
            }

            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                messages.append(
                    MetalRenderBackendDiagnostics.commandEncoderUnavailable(
                        reason: "MTLCommandBuffer.makeRenderCommandEncoder(descriptor:) returned nil."
                    )
                )
                return drawableResult(
                    snapshot: snapshot,
                    descriptor: descriptor,
                    debugLineBuffer: debugLineBuffer,
                    drawnDebugLineCount: 0,
                    drawnDebugLineVertexCount: 0,
                    presentedDrawable: false,
                    diagnostics: DiagnosticReport(messages: messages)
                )
            }

            encoder.label = "\(descriptor.label).encoder"

            if debugLineBuffer.vertexCount > 0, let vertexBuffer = debugLineBuffer.metalBuffer {
                let pipeline = MetalDebugLineRenderPipeline.make(
                    context: context,
                    pixelFormat: descriptor.pixelFormat,
                    label: "\(config.label).debug_line_pipeline"
                )
                messages.append(contentsOf: pipeline.diagnostics.messages)

                if pipeline.success, let pipelineState = pipeline.pipelineState {
                    var uniforms = PackedMetalDebugLineUniforms(projection: descriptor.debugLineProjection)
                    encoder.setRenderPipelineState(pipelineState)
                    encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                    encoder.setVertexBytes(
                        &uniforms,
                        length: MemoryLayout<PackedMetalDebugLineUniforms>.stride,
                        index: 1
                    )
                    encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: debugLineBuffer.vertexCount)
                    drawnDebugLineCount = debugLineBuffer.validLineCount
                    drawnDebugLineVertexCount = debugLineBuffer.vertexCount
                }
            }

            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
            presentedDrawable = true
        } catch let error as MetalRenderError {
            messages.append(MetalRenderBackendDiagnostics.commandBufferUnavailable(reason: error.message))
        } catch {
            messages.append(MetalRenderBackendDiagnostics.commandBufferUnavailable(reason: String(describing: error)))
        }

        return drawableResult(
            snapshot: snapshot,
            descriptor: descriptor,
            debugLineBuffer: debugLineBuffer,
            drawnDebugLineCount: drawnDebugLineCount,
            drawnDebugLineVertexCount: drawnDebugLineVertexCount,
            presentedDrawable: presentedDrawable,
            diagnostics: DiagnosticReport(messages: messages)
        )
    }
    #endif

    private func drawableResult(
        snapshot: RenderSnapshot,
        descriptor: MetalDrawableFrameDescriptor,
        debugLineBuffer: MetalDebugLineBuffer,
        drawnDebugLineCount: Int,
        drawnDebugLineVertexCount: Int,
        presentedDrawable: Bool,
        diagnostics: DiagnosticReport
    ) -> MetalDrawableRenderResult {
        MetalDrawableRenderResult(
            descriptor: descriptor,
            renderSnapshotHash: snapshot.stableHash,
            capabilities: capabilities,
            unsupportedRenderableInstanceCount: snapshot.instances.count,
            unsupportedTextureReferenceCount: snapshot.instances.reduce(0) { partialResult, instance in
                partialResult + instance.textures.count
            },
            preparedDebugLineCount: debugLineBuffer.validLineCount,
            preparedDebugLineVertexCount: debugLineBuffer.vertexCount,
            preparedDebugLineBufferByteLength: debugLineBuffer.byteLength,
            drawnDebugLineCount: drawnDebugLineCount,
            drawnDebugLineVertexCount: drawnDebugLineVertexCount,
            unsupportedDebugPointCount: snapshot.debugPoints.count,
            unsupportedDebugLabelCount: snapshot.debugLabels.count,
            presentedDrawable: presentedDrawable,
            diagnostics: diagnostics
        )
    }

    private func unsupportedDiagnostics(for snapshot: RenderSnapshot) -> [DiagnosticMessage] {
        var messages: [DiagnosticMessage] = []
        let unsupportedInstanceCount = snapshot.instances.count
        let unsupportedTextureReferenceCount = snapshot.instances.reduce(0) { partialResult, instance in
            partialResult + instance.textures.count
        }
        let unsupportedPointCount = snapshot.debugPoints.count
        let unsupportedLabelCount = snapshot.debugLabels.count

        if unsupportedInstanceCount > 0 {
            messages.append(MetalRenderBackendDiagnostics.unsupportedRenderableInstances(count: unsupportedInstanceCount))
        }

        if unsupportedTextureReferenceCount > 0 {
            messages.append(MetalRenderBackendDiagnostics.unsupportedTextureReferences(count: unsupportedTextureReferenceCount))
        }

        if unsupportedPointCount > 0 {
            messages.append(MetalRenderBackendDiagnostics.unsupportedDebugPoints(count: unsupportedPointCount))
        }

        if unsupportedLabelCount > 0 {
            messages.append(MetalRenderBackendDiagnostics.unsupportedDebugLabels(count: unsupportedLabelCount))
        }

        return messages
    }
}
