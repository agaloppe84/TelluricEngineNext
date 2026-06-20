# Persistence

Phase 11 implements the durable persistence and snapshot serialization contract layer in `TelluricPersistence`.

This is persistence infrastructure. It is not a gameplay save system, not save slots, not cloud sync, not database storage, not asset streaming, and not platform-specific file management.

## Contracts vs Game Saves

`TelluricPersistence` defines how deterministic engine payloads are wrapped, versioned, hashed, encoded, decoded, and validated.

It does not define game concepts such as:

- player progress;
- inventory;
- quests;
- save slots;
- checkpoints;
- cloud profiles;
- platform storage paths.

Future game save systems can compose these contracts with gameplay-owned deltas, but gameplay semantics must live above the engine modules.

## Package Types

The persistence layer provides three generic package shapes:

```text
SnapshotPackage<Payload>
ReplayPackage<Payload>
ReportPackage<Payload>
```

Each package owns a `PersistenceEnvelope` containing:

- `PersistenceSchemaID`;
- `PersistenceFormatVersion`;
- `EngineVersion`;
- `PersistenceEnvelopeKind`;
- `PersistencePayloadHash`;
- ordered `PersistenceMetadataEntry` values;
- the Codable payload.

Metadata is an ordered array, not a dictionary. Package and hash output must never depend on dictionary or set iteration order.

## Dependency Direction

`TelluricPersistence` imports foundation contracts, diagnostics, and simulation replay/snapshot contracts. It does not import `TelluricRuntime`, `TelluricRender`, `TelluricRenderExtraction`, seed validator targets, or asset cooker targets.

Runtime snapshots, render snapshots, and tool reports are supported through generic packages from the calling module or test target:

```swift
let package = try SnapshotPackage(
    schemaID: PersistenceSchemaID("telluric.runtime.snapshot"),
    engineVersion: engineVersion,
    payload: runtimeSnapshot
)
```

This keeps persistence from becoming a high-level aggregation module and prevents tool report formats from polluting core engine dependencies.

## Deterministic JSON

`PersistenceJSONEncoder` configures JSON encoding with sorted object keys. Stable output still depends on payload contracts using ordered arrays for logical data. The encoder does not add timestamps or use `Date` encoding for deterministic package content.

Pretty printing is intentionally not required in this phase. Deterministic byte output is more important than formatting.

## Hash Verification

Persistence uses two stable hash domains:

```text
Telluric.PersistencePayload.v1
Telluric.PersistenceEnvelope.v1
```

`PersistencePayloadHash` is computed from deterministic JSON payload bytes. The envelope hash includes:

- schema id;
- format version;
- engine version;
- envelope kind;
- stored payload hash;
- ordered metadata entries.

Validation recomputes the payload hash from the payload and reports a mismatch if the stored hash differs. Swift's built-in `Hasher` is not used.

## Validation

`PersistenceValidation` reports:

- unsupported format versions;
- empty schema ids;
- unknown envelope kinds;
- empty metadata keys;
- payload hash mismatches;
- payload encoding failures during verification.

Validation issues are also exposed as `DiagnosticReport` data so future CLI tools can consume persistence failures without UI dependencies.

## Schema And Version Strategy

`PersistenceFormatVersion.supported` is the current envelope format version. Schema ids identify payload-specific meaning above the envelope format, for example:

```text
telluric.snapshot.package
telluric.replay.package
telluric.report.package
```

Changing the envelope shape requires a format version change. Changing payload meaning should use a new schema id or a payload-level version field.

## Not Implemented In Phase 11

Phase 11 does not implement:

- gameplay save slots;
- player progress saves;
- inventory or quest state;
- platform-specific storage;
- cloud sync;
- binary compression;
- databases;
- runtime asset streaming;
- render backend persistence;
- editor UI;
- app lifecycle integration.
