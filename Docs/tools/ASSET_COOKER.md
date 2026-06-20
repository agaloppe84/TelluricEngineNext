# Asset Cooker CLI

`telluric-asset-cooker` validates asset manifests and emits deterministic JSON reports.

It is a command-line client of engine asset contracts. It is not a renderer, Metal backend, editor UI, asset streaming runtime, mesh optimizer, image processor, audio decoder, or gameplay pipeline.

## Usage

Run through SwiftPM:

```sh
swift run telluric-asset-cooker --manifest Assets/Manifests/assets.json --output Assets/Cooked --report Tools/benchmarks/asset_cook_report.json
```

Strict mode requires actual conversion support:

```sh
swift run telluric-asset-cooker --manifest Assets/Manifests/assets.json --output Assets/Cooked --strict
```

Phase 10 has no real mesh/material/texture/audio/motion conversion yet, so strict mode reports unsupported conversion diagnostics and exits non-zero.

## Arguments

- `--manifest <path>`: manifest JSON path.
- `--output <path>`: output directory for future cooked assets.
- `--report <path>`: optional deterministic JSON report output path.
- `--strict`: fail when actual conversion is unsupported.
- `--verbose`: print ordered descriptor hashes.
- `--help`: print usage.

Paths must be repository-relative and must not contain absolute prefixes or `..` traversal. The output path must be inside `Assets/Cooked`.

## Validation vs Conversion

Phase 10 performs:

- manifest JSON decoding;
- manifest contract validation;
- source path safety checks;
- source file existence checks;
- cooked path safety checks;
- descriptor production;
- deterministic report writing.

Phase 10 does not perform actual conversion. It does not write cooked mesh, material, texture, audio, motion, terrain recipe, or biome recipe payloads.

Non-strict mode succeeds when validation succeeds and descriptors can be produced. Strict mode treats unsupported conversion as an explicit error.

## Report Contract

`AssetCookerReport` uses ordered arrays, not dictionaries.

It includes:

- tool name and version;
- manifest path;
- output path;
- manifest version;
- entry and descriptor counts;
- unsupported conversion count;
- ordered cooked descriptors;
- ordered diagnostics;
- deterministic root hash;
- success boolean.

Reports intentionally omit timestamps, file modification times, performance timing, process IDs, and platform handles.

The report hash domain is:

```text
Telluric.AssetCookReport.v1
```

## Example Manifest

The repository includes:

```text
Assets/Manifests/assets.json
Assets/Source/debug/debug_mesh.mesh.json
Assets/Source/debug/debug_material.material.json
```

These are small text fixtures for validation and tests. They are not cooked runtime assets.

## Exit Codes

- `0`: parsing succeeded, validation succeeded, and no required conversion failed.
- `1`: parsing succeeded but validation/report writing/conversion requirements failed.
- `2`: command-line parsing failed.

## Current Limits

The asset cooker currently validates and reports. It does not:

- generate cooked files;
- optimize meshes;
- decode or transcode images;
- decode audio;
- import motion data;
- load GPU resources;
- integrate with runtime streaming;
- provide editor UI.
