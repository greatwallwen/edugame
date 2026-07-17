# Godot Shared Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the duplicated Godot host integration in Ch11 and Ch12 with one canonical runtime that is copied into each self-contained game and verified by automated checks.

**Architecture:** Canonical GDScript lives under `packages/edugame/godot/shared/dgbook_runtime`. A Node.js tool copies that directory into each game's `addons/dgbook_runtime` and writes a deterministic lock file. Each game composes a `DGBRuntime` node and keeps all gameplay state in its existing root script.

**Tech Stack:** Godot 4.6 GDScript, Node.js 20 ESM, pnpm 9, Vitest 2, PowerShell verification commands.

## Global Constraints

- Do not create a Git commit; keep every change in the working tree.
- Every game must remain independently openable, previewable, and exportable.
- Do not use symbolic links or cross-project `res://` references.
- Keep the v1 host message names unchanged.
- Do not change gameplay balance, visuals, or scoring formulas.
- Do not split the large Ch11 or Ch12 root scripts in this change.
- Browser knowledge URLs remain fetched by React; Godot receives resolved arrays.
- Shared files under each game's `addons/dgbook_runtime` are generated and must not contain game-specific behavior.

---

### Task 1: Deterministic Runtime Synchronization

**Files:**
- Create: `packages/edugame/godot/tools/sync_runtime.mjs`
- Create: `packages/edugame/__tests__/godot-runtime-sync.test.ts`
- Modify: `package.json`

**Interfaces:**
- Produces: `syncRuntime({ sourceDir, gamesDir, mode })`, where `mode` is `"sync"` or `"check"`.
- Produces: `pnpm godot:runtime:sync` and `pnpm godot:runtime:check`.
- Produces: `<game>/dgbook-runtime.lock.json` with `version`, `sourceHash`, and sorted `files` entries.

- [ ] **Step 1: Write failing Vitest coverage**

Create temporary source and games directories. Assert that sync copies only canonical files, creates equal hashes in two games, is idempotent, and check mode rejects a modified generated file without touching game-owned `scripts/game.gd`.

- [ ] **Step 2: Verify the test fails**

Run: `pnpm -F @dgbook/game test -- godot-runtime-sync.test.ts`

Expected: FAIL because `godot/tools/sync_runtime.mjs` does not exist.

- [ ] **Step 3: Implement the synchronization module**

Export:

```js
export async function syncRuntime({ sourceDir, gamesDir, mode = 'sync' })
```

Discover direct children of `gamesDir` containing `project.godot`. Hash each canonical file using SHA-256 over its relative POSIX path, a zero byte, and file contents. In sync mode replace only `addons/dgbook_runtime`, then write a stable two-space-indented lock file. In check mode compare canonical file paths and hashes with the destination and throw an error listing every mismatch.

The CLI must resolve paths relative to the repository root and accept exactly `sync` or `check` as its first argument.

- [ ] **Step 4: Register repository commands**

Add to root `package.json`:

```json
"godot:runtime:sync": "node packages/edugame/godot/tools/sync_runtime.mjs sync",
"godot:runtime:check": "node packages/edugame/godot/tools/sync_runtime.mjs check"
```

- [ ] **Step 5: Verify synchronization tests pass**

Run: `pnpm -F @dgbook/game test -- godot-runtime-sync.test.ts`

Expected: PASS with all sync, check, idempotency, and isolation assertions successful.

### Task 2: Protocol, Knowledge, Configuration, and Reporting Primitives

**Files:**
- Create: `packages/edugame/godot/shared/dgbook_runtime/protocol.gd`
- Create: `packages/edugame/godot/shared/dgbook_runtime/knowledge_provider.gd`
- Create: `packages/edugame/godot/shared/dgbook_runtime/session_config.gd`
- Create: `packages/edugame/godot/shared/dgbook_runtime/result_reporter.gd`
- Create: `packages/edugame/godot/template/tests/test_runtime_primitives.gd`

**Interfaces:**
- Produces: `DGBProtocol.VERSION`, standard message constants, `is_supported_version(value)`.
- Produces: `DGBKnowledgeProvider.resolve(data, fallbacks, local_preview)`.
- Produces: `DGBSessionConfig.build(level, data, defaults)`.
- Produces: `DGBResultReporter.report_progress(...)`, `complete(...)`, and `reset()`.

- [ ] **Step 1: Write the failing GDScript primitive test**

Test protocol version acceptance, external knowledge priority, embedded JSON fallback, session defaults overridden by host data, progress clamping, score clamping, and completion idempotency using a fake bridge object that records payloads.

- [ ] **Step 2: Verify the primitive test cannot load the missing scripts**

Run:

```powershell
godot --headless --path packages/edugame/godot/template --script res://tests/test_runtime_primitives.gd
```

Expected: non-zero exit because shared runtime scripts are absent.

- [ ] **Step 3: Implement protocol constants**

Use a `RefCounted` class with `class_name DGBProtocol`, protocol version `1`, all eight standard message constants, and integer version validation that treats a missing version as v1 for backward compatibility.

- [ ] **Step 4: Implement knowledge resolution**

Return this stable shape:

```gdscript
{
    "questions": [],
    "upgrades": [],
    "bindings": {},
    "concepts": [],
    "source": "external" # or embedded/local_preview
}
```

Only accept arrays for questions, upgrades, and concepts. Accept an array or dictionary for bindings. Load fallback JSON with `FileAccess` and return the declared empty type after logging a warning for missing or invalid files.

- [ ] **Step 5: Implement session configuration**

Merge game defaults with host `data`, preserve the full `initialState`, and normalize snake_case keys used by GDScript from camelCase host fields such as `durationSec`, `maxFaults`, `maxLeaks`, and `questionTimeSec`.

- [ ] **Step 6: Implement result reporting**

Store a bridge reference, initialized flag, and completed flag. Clamp progress and score, coerce elapsed time to a non-negative integer, reject progress before initialization, and allow only the first completion until `reset()`.

- [ ] **Step 7: Sync and run the primitive test**

Run:

```powershell
pnpm godot:runtime:sync
godot --headless --path packages/edugame/godot/template --script res://tests/test_runtime_primitives.gd
```

Expected: `runtime primitive tests passed` and exit code 0.

### Task 3: Bridge and Runtime Facade

**Files:**
- Create: `packages/edugame/godot/shared/dgbook_runtime/bridge.gd`
- Create: `packages/edugame/godot/shared/dgbook_runtime/runtime.gd`
- Create: `packages/edugame/godot/template/tests/test_runtime_contract.gd`

**Interfaces:**
- Produces: `DGBBridge` standard signals, `custom_command_received(type, payload)`, `send_payload(payload)`, and `is_web_runtime()`.
- Produces: `DGBRuntime.setup(options)`, standard lifecycle signals, `report_progress`, `complete`, and logging methods.
- Consumes: all Task 2 primitives.

- [ ] **Step 1: Write a failing facade contract test**

Instantiate `DGBRuntime`, call `setup()` before adding it to the tree, and assert that local preview emits one normalized session on a deferred frame. Assert pause, resume, reset, custom command forwarding, reporter reset, and a single completion payload through an injected fake bridge.

- [ ] **Step 2: Run the contract test and verify failure**

Run:

```powershell
godot --headless --path packages/edugame/godot/template --script res://tests/test_runtime_contract.gd
```

Expected: non-zero exit because `runtime.gd` and `bridge.gd` are absent.

- [ ] **Step 3: Implement the bridge**

Port the common behavior from the two existing bridges. Standard commands emit dedicated signals. Unknown `DGB_GODOT_*` messages emit `custom_command_received`. The bridge must use `PROCESS_MODE_ALWAYS`, send READY in Web builds, and defer an empty INIT in local preview.

- [ ] **Step 4: Implement the facade**

Require `setup(options)` before `_ready()`. Build the bridge, knowledge provider, session config, and reporter. Validate protocol version and exact `game_id`; emit `initialized(session)` only after successful validation. On reset, reset the reporter before forwarding `reset_requested`.

- [ ] **Step 5: Sync and verify the facade contract**

Run:

```powershell
pnpm godot:runtime:sync
godot --headless --path packages/edugame/godot/template --script res://tests/test_runtime_contract.gd
pnpm godot:runtime:check
```

Expected: contract tests pass and generated copies are current.

### Task 4: Migrate Ch12 Solar Survivor

**Files:**
- Modify: `packages/edugame/godot/games/ch12-solar-survivor/scripts/solar_survivor_root.gd`
- Delete: `packages/edugame/godot/games/ch12-solar-survivor/scripts/godot_bridge.gd`
- Delete: `packages/edugame/godot/games/ch12-solar-survivor/scripts/godot_bridge.gd.uid`
- Create: `packages/edugame/godot/games/ch12-solar-survivor/tests/test_runtime_integration.gd`

**Interfaces:**
- Consumes: `DGBRuntime` and normalized `session` from Task 3.
- Preserves: existing Ch12 phases, gameplay functions, scoring, statistics, and knowledge field names.

- [ ] **Step 1: Add a failing Ch12 integration test**

Load the main scene and assert its runtime is a `DGBRuntime`; initialize it with injected questions, upgrades, and bindings; verify the game uses injected arrays; then reset and verify the existing run state resets.

- [ ] **Step 2: Verify the integration test fails against the legacy bridge**

Run:

```powershell
godot --headless --path packages/edugame/godot/games/ch12-solar-survivor --script res://tests/test_runtime_integration.gd
```

Expected: FAIL because the root still creates the legacy bridge.

- [ ] **Step 3: Replace Ch12 bridge setup with the runtime facade**

Configure game ID, embedded questions and upgrades, and defaults for 180 seconds, five faults, and 15-second questions. Change `_on_init_received` to `_on_session_initialized(session)` and read `session.config` plus `session.knowledge`. Replace direct bridge reporting with runtime methods.

- [ ] **Step 4: Remove the legacy Ch12 bridge files**

Delete only the two local bridge files after every reference points at `addons/dgbook_runtime`.

- [ ] **Step 5: Run Ch12 regression checks**

Run:

```powershell
godot --headless --path packages/edugame/godot/games/ch12-solar-survivor --script res://tests/test_runtime_integration.gd
godot --headless --path packages/edugame/godot/games/ch12-solar-survivor --script res://tests/test_watch_debug_ui.gd
godot --headless --path packages/edugame/godot/games/ch12-solar-survivor --scene res://scenes/main.tscn --quit-after 20
```

Expected: both tests pass and the smoke run has no script or runtime error.

### Task 5: Migrate Ch11 Band Defense

**Files:**
- Modify: `packages/edugame/godot/games/ch11-band-defense/scripts/band_defense_root.gd`
- Delete: `packages/edugame/godot/games/ch11-band-defense/scripts/godot_bridge.gd`
- Delete: `packages/edugame/godot/games/ch11-band-defense/scripts/godot_bridge.gd.uid`
- Create: `packages/edugame/godot/games/ch11-band-defense/tests/test_runtime_integration.gd`

**Interfaces:**
- Consumes: `DGBRuntime`, normalized session, and custom command signal.
- Preserves: all Ch11 menus, three levels, nine waves, diagnosis, quiz, unlock, recording demo, scoring, and statistics.

- [ ] **Step 1: Add a failing Ch11 integration test**

Load the main scene, assert runtime type and fallback data counts, inject a replacement questions array, verify it is used, deliver `DGB_GODOT_RECORDING_DEMO` through the custom command path, and verify reset returns to `main_menu`.

- [ ] **Step 2: Verify the test fails against the legacy bridge**

Run:

```powershell
godot --headless --path packages/edugame/godot/games/ch11-band-defense --script res://tests/test_runtime_integration.gd
```

Expected: FAIL because the root still creates the legacy bridge.

- [ ] **Step 3: Replace Ch11 bridge setup with the runtime facade**

Configure the game ID and embedded question fallbacks. Preserve the three wave fallback files in game code, while allowing an injected `waves` array from session data. Connect the recording demo command in `_on_custom_command(type, payload)`. Replace direct bridge reporting with runtime methods.

- [ ] **Step 4: Remove the legacy Ch11 bridge files**

Delete only the two local bridge files after all references use the generated runtime.

- [ ] **Step 5: Run focused Ch11 regression checks**

Run the runtime integration test plus existing wave director, balance, layout, diagnostic, tower identity, menu, and hit feedback tests. Then run the main scene headlessly for 20 seconds.

Expected: all selected tests pass and the smoke run has no script or runtime error.

### Task 6: Template, Documentation, and Full Verification

**Files:**
- Modify: `packages/edugame/godot/template/scripts/game_root.gd`
- Modify: `packages/edugame/godot/template/README.md`
- Modify: `packages/edugame/godot/README.md`
- Modify: `GODOT_GAME_HANDOFF.md`

**Interfaces:**
- Consumes: the final `DGBRuntime` public API.
- Produces: a copyable, self-contained template and documented sync workflow.

- [ ] **Step 1: Update the template root**

Configure `DGBRuntime` before adding it to the scene tree, connect initialization and control signals, and demonstrate progress and completion through the facade without game-specific protocol calls.

- [ ] **Step 2: Document ownership and commands**

State that `shared/dgbook_runtime` is canonical, generated addon copies must not be edited, and every runtime change requires sync plus check. Document external-first and embedded-fallback knowledge behavior.

- [ ] **Step 3: Run full static verification**

Run:

```powershell
pnpm godot:runtime:sync
pnpm godot:runtime:check
pnpm -F @dgbook/game test
pnpm -F @dgbook/game typecheck
```

Expected: all commands exit 0.

- [ ] **Step 4: Run all runtime and game smoke checks**

Run template runtime tests, both game integration tests, existing focused regressions, and both main scenes. Verify there are no parser errors, runtime errors, or duplicate COMPLETE messages.

- [ ] **Step 5: Inspect the working tree without committing**

Run:

```powershell
git status --short
git diff --check
```

Expected: only intended runtime, game integration, template, test, documentation, generated addon, lock, and plan/spec files are changed; no whitespace errors are reported.
