# Codex Prompt — Phase 0 Repository Bootstrap

Use this prompt only after creating/opening the local repository.

```text
Read AGENTS.md, CODEX.md, README.md and every file under Docs/architecture.

Important context:
This is Telluric Engine Next, a clean restart of the previous Xcode-first Telluric prototype.
The old docs under Docs/legacy are design references only, not current repo structure.

Absolute constraints:
- Do not modify anything outside this repository.
- Do not run sudo.
- Do not run brew.
- Do not run gem/bundle/ruby/rails/rake.
- Do not run xcode-select.
- Do not modify shell profiles.
- Do not create an Xcode app yet.
- Do not add Metal code yet.
- Do not add gameplay yet.
- Do not add tools UI yet.
- Do not add fake implementations.
- Use only repo-local scripts for validation.

Task:
Audit the repository and prepare Phase 0 implementation.

Expected output before editing:
1. Objective.
2. Files to create/modify.
3. Proposed SwiftPM target graph.
4. Safe scripts to create/update.
5. Architecture guard rules.
6. Validation commands.
7. Risks.
8. Confirmation request before editing.

Do not edit files yet.
```
