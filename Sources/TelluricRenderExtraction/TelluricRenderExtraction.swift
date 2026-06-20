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

    /// Enables red and blue world X/Z axis lines across the resident chunk footprint.
    public let includeWorldAxes: Bool

    /// Enables a small line cross at world origin.
    public let includeOriginMarker: Bool

    /// Enables optional line crosses at resident chunk centers.
    public let includeChunkCenterCrosses: Bool

    /// Enables accent boundary lines around chunk `(0, 0)`, when resident.
    public let includeCentralChunkHighlight: Bool

    /// Enables a secondary outline around the resident streaming footprint.
    public let includeStreamingRadiusBounds: Bool

    /// Flat world-space y value used for chunk debug primitives.
    public let flatY: Float

    /// Color for chunk boundary lines.
    public let boundaryColor: RenderColor

    /// Color for the world X axis.
    public let xAxisColor: RenderColor

    /// Color for the world Z axis.
    public let zAxisColor: RenderColor

    /// Color for the world origin marker.
    public let originMarkerColor: RenderColor

    /// Color for optional chunk center line crosses.
    public let chunkCenterCrossColor: RenderColor

    /// Color for the central chunk highlight.
    public let centralChunkHighlightColor: RenderColor

    /// Color for the streaming radius outline.
    public let streamingRadiusBoundsColor: RenderColor

    /// Color for chunk coordinate labels.
    public let labelColor: RenderColor

    /// Color for optional chunk center points.
    public let centerPointColor: RenderColor

    /// Point size for optional chunk center points.
    public let centerPointSize: Float

    /// Half-size of the world origin line cross in world units.
    public let originMarkerHalfSize: Float

    /// Half-size of optional chunk center line crosses in world units.
    public let chunkCenterCrossHalfSize: Float

    /// Render layer used by generated debug primitives.
    public let debugLayer: RenderLayer

    /// Creates an extraction configuration.
    public init(
        camera: CameraSnapshot,
        includeChunkBoundaryLines: Bool = true,
        includeChunkLabels: Bool = false,
        includeChunkCenterPoints: Bool = false,
        includeWorldAxes: Bool = true,
        includeOriginMarker: Bool = true,
        includeChunkCenterCrosses: Bool = false,
        includeCentralChunkHighlight: Bool = true,
        includeStreamingRadiusBounds: Bool = true,
        flatY: Float = 0,
        boundaryColor: RenderColor = .debugChunkBoundary,
        xAxisColor: RenderColor = .debugXAxis,
        zAxisColor: RenderColor = .debugZAxis,
        originMarkerColor: RenderColor = .debugOrigin,
        chunkCenterCrossColor: RenderColor = .debugChunkCenter,
        centralChunkHighlightColor: RenderColor = .debugCentralChunk,
        streamingRadiusBoundsColor: RenderColor = .debugStreamingRadius,
        labelColor: RenderColor = .white,
        centerPointColor: RenderColor = .debugChunkCenter,
        centerPointSize: Float = 1,
        originMarkerHalfSize: Float = 2,
        chunkCenterCrossHalfSize: Float = 1.5,
        debugLayer: RenderLayer = .debug
    ) {
        self.camera = camera
        self.includeChunkBoundaryLines = includeChunkBoundaryLines
        self.includeChunkLabels = includeChunkLabels
        self.includeChunkCenterPoints = includeChunkCenterPoints
        self.includeWorldAxes = includeWorldAxes
        self.includeOriginMarker = includeOriginMarker
        self.includeChunkCenterCrosses = includeChunkCenterCrosses
        self.includeCentralChunkHighlight = includeCentralChunkHighlight
        self.includeStreamingRadiusBounds = includeStreamingRadiusBounds
        self.flatY = flatY
        self.boundaryColor = boundaryColor
        self.xAxisColor = xAxisColor
        self.zAxisColor = zAxisColor
        self.originMarkerColor = originMarkerColor
        self.chunkCenterCrossColor = chunkCenterCrossColor
        self.centralChunkHighlightColor = centralChunkHighlightColor
        self.streamingRadiusBoundsColor = streamingRadiusBoundsColor
        self.labelColor = labelColor
        self.centerPointColor = centerPointColor
        self.centerPointSize = centerPointSize
        self.originMarkerHalfSize = originMarkerHalfSize
        self.chunkCenterCrossHalfSize = chunkCenterCrossHalfSize
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

        if !config.originMarkerHalfSize.isFinite || config.originMarkerHalfSize < 0 {
            collector.record(
                severity: .error,
                code: NamespaceID("render_extraction.config.invalid_origin_marker_half_size"),
                message: "RuntimeRenderExtractionConfig.originMarkerHalfSize must be finite and non-negative.",
                source: "TelluricRenderExtraction",
                metadata: [
                    DiagnosticMetadata(key: "originMarkerHalfSize", value: "\(config.originMarkerHalfSize)"),
                ]
            )
        }

        if !config.chunkCenterCrossHalfSize.isFinite || config.chunkCenterCrossHalfSize < 0 {
            collector.record(
                severity: .error,
                code: NamespaceID("render_extraction.config.invalid_chunk_center_cross_half_size"),
                message: "RuntimeRenderExtractionConfig.chunkCenterCrossHalfSize must be finite and non-negative.",
                source: "TelluricRenderExtraction",
                metadata: [
                    DiagnosticMetadata(key: "chunkCenterCrossHalfSize", value: "\(config.chunkCenterCrossHalfSize)"),
                ]
            )
        }

        var debugLines: [DebugLine] = []
        var debugPoints: [DebugPoint] = []
        var debugLabels: [DebugLabel] = []
        var residentFootprints: [ChunkDebugFootprint] = []

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

                residentFootprints.append(bounds)

                if config.includeChunkBoundaryLines {
                    debugLines.append(contentsOf: bounds.boundaryLines(
                        color: config.boundaryColor,
                        layer: config.debugLayer
                    ))
                }

                if config.includeCentralChunkHighlight && chunkRecord.chunkCoord.x == 0 && chunkRecord.chunkCoord.y == 0 && chunkRecord.chunkCoord.z == 0 {
                    debugLines.append(contentsOf: bounds.boundaryLines(
                        color: config.centralChunkHighlightColor,
                        layer: config.debugLayer
                    ))
                }

                if config.includeChunkCenterCrosses && config.chunkCenterCrossHalfSize > 0 {
                    debugLines.append(contentsOf: bounds.centerCrossLines(
                        halfSize: config.chunkCenterCrossHalfSize,
                        color: config.chunkCenterCrossColor,
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

            if let gridBounds = ChunkDebugFootprint.union(residentFootprints) {
                if config.includeWorldAxes {
                    debugLines.append(contentsOf: gridBounds.axisLines(
                        xAxisColor: config.xAxisColor,
                        zAxisColor: config.zAxisColor,
                        layer: config.debugLayer
                    ))
                }

                if config.includeOriginMarker && config.originMarkerHalfSize > 0 {
                    debugLines.append(contentsOf: ChunkDebugFootprint.originMarkerLines(
                        y: config.flatY,
                        halfSize: config.originMarkerHalfSize,
                        color: config.originMarkerColor,
                        layer: config.debugLayer
                    ))
                }

                if config.includeStreamingRadiusBounds {
                    debugLines.append(contentsOf: gridBounds.boundaryLines(
                        color: config.streamingRadiusBoundsColor,
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

    func axisLines(xAxisColor: RenderColor, zAxisColor: RenderColor, layer: RenderLayer) -> [DebugLine] {
        [
            DebugLine(
                start: Float3(x: minX, y: y, z: 0),
                end: Float3(x: maxX, y: y, z: 0),
                color: xAxisColor,
                layer: layer
            ),
            DebugLine(
                start: Float3(x: 0, y: y, z: minZ),
                end: Float3(x: 0, y: y, z: maxZ),
                color: zAxisColor,
                layer: layer
            ),
        ]
    }

    func centerCrossLines(halfSize: Float, color: RenderColor, layer: RenderLayer) -> [DebugLine] {
        let center = center
        return [
            DebugLine(
                start: Float3(x: center.x - halfSize, y: y, z: center.z),
                end: Float3(x: center.x + halfSize, y: y, z: center.z),
                color: color,
                layer: layer
            ),
            DebugLine(
                start: Float3(x: center.x, y: y, z: center.z - halfSize),
                end: Float3(x: center.x, y: y, z: center.z + halfSize),
                color: color,
                layer: layer
            ),
        ]
    }

    static func originMarkerLines(y: Float, halfSize: Float, color: RenderColor, layer: RenderLayer) -> [DebugLine] {
        [
            DebugLine(
                start: Float3(x: -halfSize, y: y, z: 0),
                end: Float3(x: halfSize, y: y, z: 0),
                color: color,
                layer: layer
            ),
            DebugLine(
                start: Float3(x: 0, y: y, z: -halfSize),
                end: Float3(x: 0, y: y, z: halfSize),
                color: color,
                layer: layer
            ),
        ]
    }

    static func union(_ footprints: [ChunkDebugFootprint]) -> ChunkDebugFootprint? {
        guard let first = footprints.first else {
            return nil
        }

        var minX = first.minX
        var maxX = first.maxX
        var minZ = first.minZ
        var maxZ = first.maxZ

        for footprint in footprints.dropFirst() {
            minX = Swift.min(minX, footprint.minX)
            maxX = Swift.max(maxX, footprint.maxX)
            minZ = Swift.min(minZ, footprint.minZ)
            maxZ = Swift.max(maxZ, footprint.maxZ)
        }

        return ChunkDebugFootprint(
            minX: minX,
            maxX: maxX,
            minZ: minZ,
            maxZ: maxZ,
            y: first.y
        )
    }
}
