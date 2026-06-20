// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TelluricEngineNext",
    products: [
        .library(name: "TelluricCore", targets: ["TelluricCore"]),
        .library(name: "TelluricMath", targets: ["TelluricMath"]),
        .library(name: "TelluricDeterminism", targets: ["TelluricDeterminism"]),
        .library(name: "TelluricDiagnostics", targets: ["TelluricDiagnostics"]),
        .library(name: "TelluricECS", targets: ["TelluricECS"]),
        .library(name: "TelluricSimulation", targets: ["TelluricSimulation"]),
        .library(name: "TelluricWorld", targets: ["TelluricWorld"]),
        .library(name: "TelluricTerrain", targets: ["TelluricTerrain"]),
        .library(name: "TelluricBiomes", targets: ["TelluricBiomes"]),
        .library(name: "TelluricStreaming", targets: ["TelluricStreaming"]),
        .library(name: "TelluricAssets", targets: ["TelluricAssets"]),
        .library(name: "TelluricPersistence", targets: ["TelluricPersistence"]),
        .library(name: "TelluricRuntime", targets: ["TelluricRuntime"]),
        .library(name: "TelluricRender", targets: ["TelluricRender"]),
        .library(name: "TelluricRenderExtraction", targets: ["TelluricRenderExtraction"]),
        .executable(name: "telluric-seed-validator", targets: ["TelluricSeedValidator"]),
        .executable(name: "telluric-asset-cooker", targets: ["TelluricAssetCooker"]),
        .executable(name: "TelluricReplayInspector", targets: ["TelluricReplayInspector"]),
    ],
    targets: [
        .target(name: "TelluricCore"),
        .target(name: "TelluricMath", dependencies: ["TelluricCore"]),
        .target(name: "TelluricDeterminism", dependencies: ["TelluricCore", "TelluricMath"]),
        .target(name: "TelluricDiagnostics", dependencies: ["TelluricCore"]),

        .target(name: "TelluricECS", dependencies: ["TelluricCore", "TelluricMath", "TelluricDeterminism"]),
        .target(name: "TelluricSimulation", dependencies: ["TelluricCore", "TelluricMath", "TelluricDeterminism", "TelluricDiagnostics", "TelluricECS"]),

        .target(name: "TelluricWorld", dependencies: ["TelluricCore", "TelluricMath", "TelluricDeterminism"]),
        .target(name: "TelluricTerrain", dependencies: ["TelluricCore", "TelluricMath", "TelluricDeterminism", "TelluricWorld"]),
        .target(name: "TelluricBiomes", dependencies: ["TelluricCore", "TelluricMath", "TelluricDeterminism", "TelluricWorld", "TelluricTerrain"]),
        .target(name: "TelluricStreaming", dependencies: ["TelluricCore", "TelluricMath", "TelluricDeterminism", "TelluricDiagnostics", "TelluricWorld"]),

        .target(name: "TelluricAssets", dependencies: ["TelluricCore", "TelluricDeterminism", "TelluricDiagnostics"]),
        .target(name: "TelluricPersistence", dependencies: ["TelluricCore", "TelluricDeterminism", "TelluricSimulation", "TelluricWorld", "TelluricDiagnostics"]),
        .target(name: "TelluricRuntime", dependencies: ["TelluricCore", "TelluricDeterminism", "TelluricDiagnostics", "TelluricAssets", "TelluricSimulation", "TelluricWorld", "TelluricTerrain", "TelluricBiomes", "TelluricStreaming", "TelluricPersistence"]),
        .target(name: "TelluricRender", dependencies: ["TelluricCore", "TelluricMath", "TelluricDeterminism", "TelluricAssets"]),
        .target(name: "TelluricRenderExtraction", dependencies: ["TelluricCore", "TelluricDiagnostics", "TelluricMath", "TelluricRender", "TelluricRuntime", "TelluricWorld"]),

        .target(name: "TelluricSeedValidatorCore", dependencies: ["TelluricCore", "TelluricDeterminism", "TelluricWorld", "TelluricTerrain", "TelluricBiomes", "TelluricDiagnostics"]),
        .executableTarget(name: "TelluricSeedValidator", dependencies: ["TelluricSeedValidatorCore"]),
        .target(name: "TelluricAssetCookerCore", dependencies: ["TelluricAssets", "TelluricCore", "TelluricDeterminism", "TelluricDiagnostics"]),
        .executableTarget(name: "TelluricAssetCooker", dependencies: ["TelluricAssetCookerCore"]),
        .executableTarget(name: "TelluricReplayInspector", dependencies: ["TelluricRuntime", "TelluricSimulation", "TelluricDiagnostics"]),

        .testTarget(
            name: "TelluricArchitectureTests",
            dependencies: [
                "TelluricCore",
                "TelluricMath",
                "TelluricDeterminism",
                "TelluricDiagnostics",
                "TelluricECS",
                "TelluricSimulation",
                "TelluricWorld",
                "TelluricTerrain",
                "TelluricBiomes",
                "TelluricStreaming",
                "TelluricAssets",
                "TelluricPersistence",
                "TelluricRuntime",
                "TelluricRender",
                "TelluricRenderExtraction",
                "TelluricAssetCookerCore",
                "TelluricSeedValidatorCore",
            ]
        ),
    ]
)
