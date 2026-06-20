import TelluricCore
import TelluricDiagnostics
import TelluricMath
import TelluricRender
import TelluricRuntime
import TelluricTerrain
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

    /// Enables debug-only wireframe lines derived from deterministic terrain heightfields.
    public let includeTerrainHeightWireframe: Bool

    /// Flat world-space y value used for chunk debug primitives.
    public let flatY: Float

    /// Sample stride used when extracting terrain height wireframe lines.
    public let terrainWireframeStride: Int

    /// Multiplicative debug-only scale applied to generated terrain heights.
    public let terrainHeightScale: Float

    /// Base y offset applied to terrain wireframe lines after height scaling.
    public let terrainDebugBaseY: Float

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

    /// Color for terrain height wireframe lines.
    public let terrainWireframeColor: RenderColor

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
        includeTerrainHeightWireframe: Bool = false,
        flatY: Float = 0,
        terrainWireframeStride: Int = 4,
        terrainHeightScale: Float = 1,
        terrainDebugBaseY: Float = 0,
        boundaryColor: RenderColor = .debugChunkBoundary,
        xAxisColor: RenderColor = .debugXAxis,
        zAxisColor: RenderColor = .debugZAxis,
        originMarkerColor: RenderColor = .debugOrigin,
        chunkCenterCrossColor: RenderColor = .debugChunkCenter,
        centralChunkHighlightColor: RenderColor = .debugCentralChunk,
        streamingRadiusBoundsColor: RenderColor = .debugStreamingRadius,
        terrainWireframeColor: RenderColor = .debugTerrainWireframe,
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
        self.includeTerrainHeightWireframe = includeTerrainHeightWireframe
        self.flatY = flatY
        self.terrainWireframeStride = terrainWireframeStride
        self.terrainHeightScale = terrainHeightScale
        self.terrainDebugBaseY = terrainDebugBaseY
        self.boundaryColor = boundaryColor
        self.xAxisColor = xAxisColor
        self.zAxisColor = zAxisColor
        self.originMarkerColor = originMarkerColor
        self.chunkCenterCrossColor = chunkCenterCrossColor
        self.centralChunkHighlightColor = centralChunkHighlightColor
        self.streamingRadiusBoundsColor = streamingRadiusBoundsColor
        self.terrainWireframeColor = terrainWireframeColor
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

        if config.includeTerrainHeightWireframe {
            if config.terrainWireframeStride <= 0 {
                collector.record(
                    severity: .error,
                    code: NamespaceID("render_extraction.config.invalid_terrain_wireframe_stride"),
                    message: "RuntimeRenderExtractionConfig.terrainWireframeStride must be positive.",
                    source: "TelluricRenderExtraction",
                    metadata: [
                        DiagnosticMetadata(key: "terrainWireframeStride", value: "\(config.terrainWireframeStride)"),
                    ]
                )
            }

            if !config.terrainHeightScale.isFinite || config.terrainHeightScale <= 0 {
                collector.record(
                    severity: .error,
                    code: NamespaceID("render_extraction.config.invalid_terrain_height_scale"),
                    message: "RuntimeRenderExtractionConfig.terrainHeightScale must be finite and positive.",
                    source: "TelluricRenderExtraction",
                    metadata: [
                        DiagnosticMetadata(key: "terrainHeightScale", value: "\(config.terrainHeightScale)"),
                    ]
                )
            }

            if !config.terrainDebugBaseY.isFinite {
                collector.record(
                    severity: .error,
                    code: NamespaceID("render_extraction.config.invalid_terrain_debug_base_y"),
                    message: "RuntimeRenderExtractionConfig.terrainDebugBaseY must be finite.",
                    source: "TelluricRenderExtraction",
                    metadata: [
                        DiagnosticMetadata(key: "terrainDebugBaseY", value: "\(config.terrainDebugBaseY)"),
                    ]
                )
            }

            if !runtimeSnapshot.config.worldConfig.verticalScale.isFinite || runtimeSnapshot.config.worldConfig.verticalScale <= 0 {
                collector.record(
                    severity: .error,
                    code: NamespaceID("render_extraction.config.invalid_world_vertical_scale"),
                    message: "Runtime world verticalScale must be finite and positive for terrain debug extraction.",
                    source: "TelluricRenderExtraction",
                    metadata: [
                        DiagnosticMetadata(key: "verticalScale", value: "\(runtimeSnapshot.config.worldConfig.verticalScale)"),
                    ]
                )
            }

            if !runtimeSnapshot.config.terrainSettings.heightScale.isFinite || runtimeSnapshot.config.terrainSettings.heightScale <= 0 {
                collector.record(
                    severity: .error,
                    code: NamespaceID("render_extraction.config.invalid_runtime_terrain_height_scale"),
                    message: "Runtime terrain settings heightScale must be finite and positive for terrain debug extraction.",
                    source: "TelluricRenderExtraction",
                    metadata: [
                        DiagnosticMetadata(key: "heightScale", value: "\(runtimeSnapshot.config.terrainSettings.heightScale)"),
                    ]
                )
            }
        }

        var debugLines: [DebugLine] = []
        var debugPoints: [DebugPoint] = []
        var debugLabels: [DebugLabel] = []
        var residentFootprints: [ChunkDebugFootprint] = []

        if !collector.report().hasErrors {
            let terrainGenerator = DeterministicTerrainGenerator()
            let terrainContext = WorldGenerationContext(
                config: runtimeSnapshot.config.worldConfig,
                engineVersion: runtimeSnapshot.config.engineVersion
            )

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

                if config.includeTerrainHeightWireframe {
                    let terrainPayload = terrainGenerator.generateTerrain(
                        context: terrainContext,
                        chunkCoord: chunkRecord.chunkCoord,
                        settings: runtimeSnapshot.config.terrainSettings
                    )
                    debugLines.append(contentsOf: Self.terrainWireframeLines(
                        payload: terrainPayload,
                        chunkSize: chunkSize,
                        sampleStride: config.terrainWireframeStride,
                        heightScale: config.terrainHeightScale,
                        baseY: config.terrainDebugBaseY,
                        color: config.terrainWireframeColor,
                        layer: config.debugLayer,
                        diagnostics: &collector
                    ))
                }

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

    private static func terrainWireframeLines(
        payload: TerrainPayload,
        chunkSize: Int,
        sampleStride: Int,
        heightScale: Float,
        baseY: Float,
        color: RenderColor,
        layer: RenderLayer,
        diagnostics collector: inout DiagnosticCollector
    ) -> [DebugLine] {
        let field = payload.heightField
        let expectedDimension = chunkSize + 1
        guard field.width == expectedDimension, field.depth == expectedDimension else {
            collector.record(
                severity: .error,
                code: NamespaceID("render_extraction.terrain.invalid_heightfield_dimensions"),
                message: "Terrain debug wireframe expects height fields with dimensions chunkSize + 1.",
                source: "TelluricRenderExtraction",
                metadata: metadata(for: payload.chunkCoord) + [
                    DiagnosticMetadata(key: "heightField.width", value: "\(field.width)"),
                    DiagnosticMetadata(key: "heightField.depth", value: "\(field.depth)"),
                    DiagnosticMetadata(key: "expectedDimension", value: "\(expectedDimension)"),
                ]
            )
            return []
        }

        guard let originX = multiply(payload.chunkCoord.x, by: Int64(chunkSize)),
              let originZ = multiply(payload.chunkCoord.z, by: Int64(chunkSize))
        else {
            collector.record(
                severity: .error,
                code: NamespaceID("render_extraction.terrain.origin_overflow"),
                message: "Terrain debug wireframe chunk origin overflowed during render extraction.",
                source: "TelluricRenderExtraction",
                metadata: metadata(for: payload.chunkCoord)
            )
            return []
        }

        let xIndices = sampleIndices(count: field.width, sampleStride: sampleStride)
        let zIndices = sampleIndices(count: field.depth, sampleStride: sampleStride)
        var lines: [DebugLine] = []
        lines.reserveCapacity(max(0, zIndices.count * max(0, xIndices.count - 1) + xIndices.count * max(0, zIndices.count - 1)))

        for z in zIndices {
            for index in 0..<max(0, xIndices.count - 1) {
                let x0 = xIndices[index]
                let x1 = xIndices[index + 1]
                guard let start = terrainPoint(
                    field: field,
                    originX: originX,
                    originZ: originZ,
                    x: x0,
                    z: z,
                    heightScale: heightScale,
                    baseY: baseY,
                    chunkCoord: payload.chunkCoord,
                    diagnostics: &collector
                ), let end = terrainPoint(
                    field: field,
                    originX: originX,
                    originZ: originZ,
                    x: x1,
                    z: z,
                    heightScale: heightScale,
                    baseY: baseY,
                    chunkCoord: payload.chunkCoord,
                    diagnostics: &collector
                ) else {
                    continue
                }

                lines.append(DebugLine(start: start, end: end, color: color, layer: layer))
            }
        }

        for x in xIndices {
            for index in 0..<max(0, zIndices.count - 1) {
                let z0 = zIndices[index]
                let z1 = zIndices[index + 1]
                guard let start = terrainPoint(
                    field: field,
                    originX: originX,
                    originZ: originZ,
                    x: x,
                    z: z0,
                    heightScale: heightScale,
                    baseY: baseY,
                    chunkCoord: payload.chunkCoord,
                    diagnostics: &collector
                ), let end = terrainPoint(
                    field: field,
                    originX: originX,
                    originZ: originZ,
                    x: x,
                    z: z1,
                    heightScale: heightScale,
                    baseY: baseY,
                    chunkCoord: payload.chunkCoord,
                    diagnostics: &collector
                ) else {
                    continue
                }

                lines.append(DebugLine(start: start, end: end, color: color, layer: layer))
            }
        }

        return lines
    }

    private static func terrainPoint(
        field: HeightField,
        originX: Int64,
        originZ: Int64,
        x: Int,
        z: Int,
        heightScale: Float,
        baseY: Float,
        chunkCoord: ChunkCoord,
        diagnostics collector: inout DiagnosticCollector
    ) -> Float3? {
        guard let sample = field.sample(x: x, z: z) else {
            collector.record(
                severity: .error,
                code: NamespaceID("render_extraction.terrain.missing_height_sample"),
                message: "Terrain debug wireframe could not read an expected height sample.",
                source: "TelluricRenderExtraction",
                metadata: metadata(for: chunkCoord) + [
                    DiagnosticMetadata(key: "sample.x", value: "\(x)"),
                    DiagnosticMetadata(key: "sample.z", value: "\(z)"),
                ]
            )
            return nil
        }

        guard let worldX = add(originX, Int64(x)),
              let worldZ = add(originZ, Int64(z))
        else {
            collector.record(
                severity: .error,
                code: NamespaceID("render_extraction.terrain.sample_coordinate_overflow"),
                message: "Terrain debug wireframe sample coordinate overflowed during render extraction.",
                source: "TelluricRenderExtraction",
                metadata: metadata(for: chunkCoord) + [
                    DiagnosticMetadata(key: "sample.x", value: "\(x)"),
                    DiagnosticMetadata(key: "sample.z", value: "\(z)"),
                ]
            )
            return nil
        }

        let y = baseY + sample.height * heightScale
        guard y.isFinite else {
            collector.record(
                severity: .error,
                code: NamespaceID("render_extraction.terrain.non_finite_projected_height"),
                message: "Terrain debug wireframe projected height must be finite.",
                source: "TelluricRenderExtraction",
                metadata: metadata(for: chunkCoord) + [
                    DiagnosticMetadata(key: "sample.x", value: "\(x)"),
                    DiagnosticMetadata(key: "sample.z", value: "\(z)"),
                    DiagnosticMetadata(key: "sample.height", value: "\(sample.height)"),
                    DiagnosticMetadata(key: "heightScale", value: "\(heightScale)"),
                    DiagnosticMetadata(key: "baseY", value: "\(baseY)"),
                ]
            )
            return nil
        }

        return Float3(x: Float(worldX), y: y, z: Float(worldZ))
    }

    private static func sampleIndices(count: Int, sampleStride: Int) -> [Int] {
        guard count > 0 else {
            return []
        }

        var indices = Array(Swift.stride(from: 0, to: count, by: sampleStride))
        let lastIndex = count - 1
        if indices.last != lastIndex {
            indices.append(lastIndex)
        }

        return indices
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
