# Codex Prompt — Phase 1 Engine Foundation

Use this after Phase 0 has been reviewed.

```text
Read AGENTS.md, CODEX.md and Docs/architecture.

Task:
Implement the first real engine foundation slice for Telluric Engine Next:
- TelluricCore
- TelluricMath
- TelluricDeterminism
- TelluricDiagnostics

Constraints:
- No Xcode app.
- No Metal implementation.
- No gameplay.
- No tools UI.
- No fake implementation.
- Respect the Phase 0 SwiftPM target graph.
- Respect MODULE_GRAPH.md.
- Keep all build artifacts local to the repo.
- Do not run forbidden commands.

Create:
- real deterministic foundation contracts and implementations only;
- focused tests for deterministic behavior, stable hashing, math invariants and diagnostics contracts;
- documentation updates for any public contracts introduced.

Validation:
- ./scripts/codex-preflight-safe.sh
- ./scripts/swift-build-safe.sh
- ./scripts/swift-test-safe.sh
- ./scripts/check-architecture-guards.sh

Do not commit unless the user explicitly asks.
```
