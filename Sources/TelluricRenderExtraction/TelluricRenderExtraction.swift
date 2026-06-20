import TelluricCore
import TelluricDiagnostics
import TelluricMath
import TelluricRender
import TelluricRuntime
import TelluricWorld

/// Configuration for extracting backend-neutral debug render data from runtime snapshots.
public struct RuntimeRenderExtractionConfig: Codable, Equatable, Hashable, Sendable {
    /// Camera snapshot supplied by the caller.
    public let camera: CameraSnapshot

    /// Enables flat chunk footprint lines for resident chunks.
    public let includeChunkBoundaryLines: Bool

    /// Enables coordinate labels at resident chunk centers.
    public let includeChunkLabels: Bool

    /// Enables debug points at resident chunk centers.
    public let includeChunkCenterPoints: Bool

    /// Flat world-space y value used for chunk debug primitives.
    public let flatY: Float

    /// Color for chunk boundary lines.
    public let boundaryColor: RenderColor

    /// Color for chunk coordinate labels.
    public let labelColor: RenderColor

    /// Color for optional chunk center points.
    public let centerPointColor: RenderColor

    /// Point size for optional chunk center points.
    public let centerPointSize: Float

    /// Render layer used by generated debug primitives.
    public let debugLayer: RenderLayer

    /// Creates an extraction configuration.
    public init(
        camera: CameraSnapshot,
        includeChunkBoundaryLines: Bool = true,
        includeChunkLabels: Bool = false,
        includeChunkCenterPoints: Bool = false,
        flatY: Float = 0,
        boundaryColor: RenderColor = .green,
        labelColor: RenderColor = .white,
        centerPointColor: RenderColor = .blue,
        centerPointSize: Float = 1,
        debugLayer: RenderLayer = .debug
    ) {
        self.camera = camera
        self.includeChunkBoundaryLines = includeChunkBoundaryLines
        self.includeChunkLabels = includeChunkLabels
        self.includeChunkCenterPoints = includeChunkCenterPoints
        self.flatY = flatY
        self.boundaryColor = boundaryColor
        self.labelColor = labelColor
        self.centerPointColor = centerPointColor
        self.centerPointSize = centerPointSize
        self.debugLayer = debugLayer
    }
}

/// Result of converting a runtime snapshot into a renderer-independent snapshot.
public struct RuntimeRenderExtractionResult: Codable, Equatable, Sendable {
    /// Source runtime snapshot.
    public let runtimeSnapshot: RuntimeSnapshot

    /// Backend-neutral render snapshot.
    public let renderSnapshot: RenderSnapshot

    /// Ordered extraction diagnostics.
    public let diagnostics: DiagnosticReport

    /// True when extraction produced no error diagnostics.
    public let success: Bool

    /// Creates an extraction result.
    public init(
        runtimeSnapshot: RuntimeSnapshot,
        renderSnapshot: RenderSnapshot,
        diagnostics: DiagnosticReport
    ) {
        self.runtimeSnapshot = runtimeSnapshot
        self.renderSnapshot = renderSnapshot
        self.diagnostics = diagnostics
        self.success = !diagnostics.hasErrors
    }
}

/// Synchronous extractor from runtime state to backend-neutral render contracts.
public struct RuntimeRenderExtractor: Sendable {
    /// Creates a runtime render extractor.
    public init() {}

    /// Extracts a deterministic render snapshot without mutating runtime state.
    public func extract(
        from runtimeSnapshot: RuntimeSnapshot,
        config: RuntimeRenderExtractionConfig
    ) -> RuntimeRenderExtractionResult {
        var collector = DiagnosticCollector()
        let chunkSize = runtimeSnapshot.config.worldConfig.chunkSize

        if chunkSize <= 0 {
            collector.record(
                severity: .error,
                code: NamespaceID("render_extraction.config.invalid_chunk_size"),
                message: "Runtime world chunk size must be positive for render extraction.",
                source: "TelluricRenderExtraction",
                metadata: [
                    DiagnosticMetadata(key: "chunkSize", value: "\(chunkSize)"),
                ]
            )
        }

        if !config.flatY.isFinite {
            collector.record(
                severity: .error,
                code: NamespaceID("render_extraction.config.invalid_flat_y"),
                message: "RuntimeRenderExtractionConfig.flatY must be finite.",
                source: "TelluricRenderExtraction",
                metadata: [
                    DiagnosticMetadata(key: "flatY", value: "\(config.flatY)"),
                ]
            )
        }

        if !config.centerPointSize.isFinite || config.centerPointSize < 0 {
            collector.record(
                severity: .error,
                code: NamespaceID("render_extraction.config.invalid_center_point_size"),
                message: "RuntimeRenderExtractionConfig.centerPointSize must be finite and non-negative.",
                source: "TelluricRenderExtraction",
                metadata: [
                    DiagnosticMetadata(key: "centerPointSize", value: "\(config.centerPointSize)"),
                ]
            )
        }

        var debugLines: [DebugLine] = []
        var debugPoints: [DebugPoint] = []
        var debugLabels: [DebugLabel] = []

        if !collector.report().hasErrors {
            for chunkRecord in runtimeSnapshot.state.chunkRecords.sorted() where chunkRecord.residency == .resident {
                guard let bounds = Self.chunkFootprint(
                    chunkCoord: chunkRecord.chunkCoord,
                    chunkSize: chunkSize,
                    flatY: config.flatY,
                    diagnostics: &collector
                ) else {
                    continue
                }

                if config.includeChunkBoundaryLines {
                    debugLines.append(contentsOf: bounds.boundaryLines(
                        color: config.boundaryColor,
                        layer: config.debugLayer
                    ))
                }

                if config.includeChunkLabels {
                    debugLabels.append(Self.chunkLabel(
                        chunkCoord: chunkRecord.chunkCoord,
                        position: bounds.center,
                        color: config.labelColor,
                        layer: config.debugLayer
                    ))
                }

                if config.includeChunkCenterPoints {
                    debugPoints.append(DebugPoint(
                        position: bounds.center,
                        size: config.centerPointSize,
                        color: config.centerPointColor,
                        layer: config.debugLayer
                    ))
                }
            }
        }

        let renderSnapshot = RenderSnapshot(
            engineVersion: runtimeSnapshot.config.engineVersion,
            frameIndex: runtimeSnapshot.state.frameIndex,
            camera: config.camera,
            instances: [],
            debugLines: debugLines,
            debugPoints: debugPoints,
            debugLabels: debugLabels
        )

        return RuntimeRenderExtractionResult(
            runtimeSnapshot: runtimeSnapshot,
            renderSnapshot: renderSnapshot,
            diagnostics: collector.report()
        )
    }

    private static func chunkFootprint(
        chunkCoord: ChunkCoord,
        chunkSize: Int,
        flatY: Float,
        diagnostics collector: inout DiagnosticCollector
    ) -> ChunkDebugFootprint? {
        let size = Int64(chunkSize)

        guard let minX = multiply(chunkCoord.x, by: size),
              let minZ = multiply(chunkCoord.z, by: size),
              let maxX = add(minX, size),
              let maxZ = add(minZ, size)
        else {
            collector.record(
                severity: .error,
                code: NamespaceID("render_extraction.chunk_bounds.overflow"),
                message: "Chunk footprint coordinates overflowed during render extraction.",
                source: "TelluricRenderExtraction",
                metadata: metadata(for: chunkCoord)
            )
            return nil
        }

        return ChunkDebugFootprint(
            minX: Float(minX),
            maxX: Float(maxX),
            minZ: Float(minZ),
            maxZ: Float(maxZ),
            y: flatY
        )
    }

    private static func multiply(_ value: Int64, by multiplier: Int64) -> Int64? {
        let result = value.multipliedReportingOverflow(by: multiplier)
        return result.overflow ? nil : result.partialValue
    }

    private static func add(_ value: Int64, _ amount: Int64) -> Int64? {
        let result = value.addingReportingOverflow(amount)
        return result.overflow ? nil : result.partialValue
    }

    private static func chunkLabel(
        chunkCoord: ChunkCoord,
        position: Float3,
        color: RenderColor,
        layer: RenderLayer
    ) -> DebugLabel {
        DebugLabel(
            id: NamespaceID("render.debug.chunk_label.\(chunkCoord.x).\(chunkCoord.y).\(chunkCoord.z)"),
            text: "chunk(\(chunkCoord.x),\(chunkCoord.y),\(chunkCoord.z))",
            position: position,
            color: color,
            layer: layer
        )
    }

    private static func metadata(for chunkCoord: ChunkCoord) -> [DiagnosticMetadata] {
        [
            DiagnosticMetadata(key: "chunk.x", value: "\(chunkCoord.x)"),
            DiagnosticMetadata(key: "chunk.y", value: "\(chunkCoord.y)"),
            DiagnosticMetadata(key: "chunk.z", value: "\(chunkCoord.z)"),
        ]
    }
}

private struct ChunkDebugFootprint {
    let minX: Float
    let maxX: Float
    let minZ: Float
    let maxZ: Float
    let y: Float

    var center: Float3 {
        Float3(
            x: (minX + maxX) * 0.5,
            y: y,
            z: (minZ + maxZ) * 0.5
        )
    }

    func boundaryLines(color: RenderColor, layer: RenderLayer) -> [DebugLine] {
        let a = Float3(x: minX, y: y, z: minZ)
        let b = Float3(x: maxX, y: y, z: minZ)
        let c = Float3(x: maxX, y: y, z: maxZ)
        let d = Float3(x: minX, y: y, z: maxZ)

        return [
            DebugLine(start: a, end: b, color: color, layer: layer),
            DebugLine(start: b, end: c, color: color, layer: layer),
            DebugLine(start: c, end: d, color: color, layer: layer),
            DebugLine(start: d, end: a, color: color, layer: layer),
        ]
    }
}
