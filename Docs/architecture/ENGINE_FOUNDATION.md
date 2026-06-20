# Engine Foundation

Phase 1 implements the durable foundation layer for Telluric Engine Next:

```text
TelluricCore
TelluricMath
TelluricDeterminism
TelluricDiagnostics
```

These modules are pure engine infrastructure. They must remain independent of runtime apps, tools UI, rendering backends, audio backends, gameplay, and platform UI frameworks.

## Purity Rules

Foundation modules must not import:

```text
SwiftUI
AppKit
Metal
MetalKit
AVFoundation
CoreAudio
GameplayKit
```

They also must not depend on wall-clock time, global randomness, process-randomized hashing, or unordered collection iteration for deterministic behavior.

## TelluricCore

`TelluricCore` owns small stable value types shared across the engine:

- `EngineVersion`
- `FrameIndex`
- `TickIndex`
- `WorldSeed`
- `StableHash`
- `NamespaceID`
- `TelluricError`

These types are immutable value types and are `Codable`, `Hashable`, and `Sendable` where appropriate. They are intentionally narrow so higher layers can build durable contracts without inheriting app, renderer, or tool concerns.

## TelluricMath

`TelluricMath` owns transparent math primitives:

- `Int2`
- `Int3`
- `Float2`
- `Float3`
- `AABB`
- `Angle`
- `Transform`
- `clamp`
- `saturate`
- `lerp`

The first math layer uses simple Swift value types rather than `simd`. This keeps Codable behavior, hashing, and public storage explicit while the engine contracts are still being established. SIMD-backed implementations can be introduced later only when a measured need exists and the public deterministic contracts remain stable.

## TelluricDeterminism

`TelluricDeterminism` owns:

- `DeterministicRNG`
- `SeedDerivation`
- `StableHasher`
- `Hashing`
- `StableHashable`

This module is the only foundation module responsible for seed stream derivation and stable hashing policy. It does not use Swift's built-in `Hasher`.

## TelluricDiagnostics

`TelluricDiagnostics` owns JSON-friendly diagnostic data:

- `DiagnosticSeverity`
- `DiagnosticMetadata`
- `DiagnosticMessage`
- `DiagnosticSummary`
- `DiagnosticReport`
- `DiagnosticCollector`

Diagnostics are designed for future CLI tools such as seed validators, asset cookers, replay inspectors, and architecture checks. Reports are ordered, serializable, and UI-independent.

## Validation

Foundation changes must continue to pass:

```sh
./scripts/codex-preflight-safe.sh
./scripts/check-architecture-guards.sh
./scripts/swift-build-safe.sh
./scripts/swift-test-safe.sh
```
