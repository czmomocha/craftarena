# Bugbot

This file is what GitHub PR Bugbot would load. It is **not** a merge gate: findings default to `neutral`.

GitHub PR-side Bugbot is **deferred** (Cursor SCM installation does not match this repository). Merge relies on CI plus a human approval. Local `/review-bugbot` remains optional.

Local `/review-bugbot` already injects root [`AGENTS.md`](../AGENTS.md). Follow the linked sources instead of copying numbers out of them.

## Sources (do not restate parameters)

- Constitution: [CD-00](../Confirmed-docs/00-constitution/CONSTITUTION.md)
- Agent rules: [AGENTS.md](../AGENTS.md)
- Open decisions: [CD-63](../Confirmed-docs/60-plan/63-open-decisions.md) — if a value is listed there, it has no default; flag invented constants.

## Mechanical red lines (ADR-0004 §4.2 gate 2)

CI already runs `tools/redline-scanner/`. Still flag a diff that introduces any of the following.

1. **Article 5 — simulation vs presentation.** `game/src/simulation/` must not gain `Node`, `get_tree`, `SceneTree`, or `_process`. `_physics_process` is not `_process`.
2. **Article 5 — fixed point.** `game/src/simulation/` must not gain `float` literals or `float` type declarations unless that line has an explicit `# redline-allow: float` exemption.
3. **Article 7 — no GDExtension in shared core.** `game/src/shared/`, `game/src/simulation/`, `game/src/ugc/`, and `game/src/server/` must not add `.gdextension`.
4. **Article 7 — no C# in the Godot project.** `game/` must not add `.cs`, `.csproj`, or `.sln`.
5. **Article 11 — no Godot 3 APIs.** `game/src` must not reintroduce high-signal Godot 3 identifiers. The scanner list is a subset of the official 3→4 rename table, not exhaustive; if a rename-table symbol appears in the diff, flag it.
6. **Article 23** is already covered by ADR-0001 (warnings as errors). Do not ask for a new scanner rule for it here.

When the diff touches commands, simulation, or UGC, also apply CD-00 articles 2–5 (server authority, UGC untrusted, UGC is data not code, sim vs presentation) via the CD-00 link above.
