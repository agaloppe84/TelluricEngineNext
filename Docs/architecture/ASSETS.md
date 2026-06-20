# Assets

Phase 10 implements the first durable asset manifest contracts in `TelluricAssets`.

This is not a renderer, Metal backend, editor, asset streaming system, image processor, audio decoder, mesh optimizer, or gameplay content layer.

## Source vs Cooked Assets

Telluric distinguishes:

- source assets: editable source files under `Assets/Source`;
- cooked assets: future runtime-ready outputs under `Assets/Cooked`;
- manifests: versioned JSON declarations under `Assets/Manifests`;
- reports: deterministic validation/cooking reports emitted by CLI tools.

Phase 10 validates source and cooked paths and produces cooked descriptors. It does not generate cooked binary payloads.

## Asset IDs

`AssetID` is a stable string identifier. IDs are validated by manifest validation rather than trapping during JSON decode, which lets tools report bad manifests cleanly.

Asset IDs must be non-empty and unique within a manifest.

## Asset Kinds

The Phase 10 manifest contract recognizes:

```text
mesh
material
texture
audio
motion
biomeRecipe
terrainRecipe
```

Unknown or unsupported kinds decode as `AssetKind` values but fail validation. This keeps diagnostics explicit instead of making invalid JSON fail before the tool can produce a useful report.

## Manifest Contract

`AssetManifest` is JSON-friendly:

- `version`;
- ordered `entries`;
- no dictionaries for stable output.

`AssetManifestEntry` stores:

- `id`;
- `kind`;
- `sourcePath`;
- `cookedPath`.

Manifest validation checks:

- supported manifest version;
- non-empty asset IDs;
- duplicate asset IDs;
- supported asset kind;
- source paths inside `Assets/Source`;
- cooked paths inside `Assets/Cooked`;
- no absolute paths;
- no `..` traversal;
- no malformed path components.

## Cooked Descriptors and Registry

`CookedAssetDescriptor` records the validated relationship between source and future cooked runtime asset path. It includes a stable descriptor hash.

`AssetRegistry` is an ordered descriptor collection. It is a data contract, not a loader. It does not open files, allocate GPU resources, decode images, upload buffers, or stream assets.

## Asset Hashing

Asset contracts use `StableHasher`, never Swift's built-in `Hasher`.

Hash domains:

```text
Telluric.AssetManifest.v1
Telluric.CookedAssetDescriptor.v1
```

Hashes consume ordered manifest and descriptor fields only. They exclude wall-clock time, process-local values, file modification dates, platform handles, and unordered collection iteration.

## Engine vs Cooker

`TelluricAssets` is an engine contract module. It must not depend on the asset cooker executable or cooker core.

The asset cooker is a CLI client of `TelluricAssets`. It can validate manifests and produce reports/descriptors, but engine modules must not import:

```text
TelluricAssetCooker
TelluricAssetCookerCore
```

## Future Connections

Future systems can consume asset IDs and descriptors:

- `TelluricRenderMetal` can map mesh/material/texture descriptors to GPU resources;
- audio runtime can consume audio descriptors;
- motion runtime can consume motion descriptors;
- world and biome tools can reference terrain and biome recipe assets.

Those systems must remain clients of the asset contracts. They should not move renderer, audio, motion, editor, or gameplay behavior into `TelluricAssets`.

## Not Implemented In Phase 10

Phase 10 does not implement:

- GPU resource loading;
- Metal buffers or textures;
- mesh optimization;
- image processing;
- audio decoding;
- motion import/retargeting;
- runtime asset streaming;
- editor UI;
- app/window code;
- gameplay assets.
