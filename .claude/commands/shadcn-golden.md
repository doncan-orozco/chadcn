---
description: Regression test for the shadcn port tooling. Script tier (oracle extraction, static gate, scenario coverage) + agent tier (parity auditor on seeded bad components). Run after editing the scripts, agent prompts, skills or the gate rules.
argument-hint: "[case-id-prefix|all] [--scripts-only]"
allowed-tools: Agent, Read, Write, Glob, TodoWrite, Bash(ruby:*), Bash(ls:*), Bash(mkdir -p tmp/shadcn-port:*)
---

# /shadcn-golden: does the port pipeline still catch what it must?

Target: $ARGUMENTS (default `all`). `--scripts-only` skips the agent tier (free, offline, seconds).

Cases live in `dev/golden/cases/<id>/` as `files/<repo-relative path>` (seeded code, NOT part of the app) + `expected.json`. Registry fixtures for six components are checked in under `dev/golden/oracle-fixtures/registry/`, so the run is offline and reproducible. Never edit case files or source files from this command.

| Case | Kind | Seeded problem | Must detect |
|---|---|---|---|
| 01-button-drift | static | Snapshot of the first-attempt Button (2024 classes, no data-slot, missing sizes) | `G1_SLOT_MISSING G1_TOKEN_MISSING G1_TOKEN_EXTRA G1_VARIANT_MISSING G1_DATA_ATTR_MISSING` |
| 02-switch-api-gap | static | Faithful classes, `size` option and `data-size` missing | `G1_KWARG_MISSING G1_DATA_ATTR_MISSING` |
| 03-switch-behavior | agent | Markup passes G1; controller toggles classes, adds a redundant keydown handler that duplicates the native click, leaks listener + interval | `Q_STATE_VIA_CLASS Q_CLEANUP` (+ mentions keydown) |
| 28-auditor-doc-vs-source | agent | Project doc and test claim Slot class merging is conflict-resolved; the real Radix `mergeProps` (in the fixture) joins plainly; the code follows the doc | `Q_SPEC_DRIFT` MANDATORY, `DOC_CONTRADICTS_SOURCE`, mentions `className` (source over docs) |
| 29-deviations-register | deviations | `deviations_register.rb` keeps `DEVIATIONS.md` in sync with `deviations/*.json` (the G5 house check needs every deviation listed) | rows present, idempotent, human `approved-by` preserved, deleted file dropped, pipes/newlines survive |
| 04-dialog-reimplements | agent | Controller re-implements Esc/focus trap/scroll lock though primitives exist; no focus return | `Q_PRIMITIVE_REUSE Q_CLEANUP` (+ mentions focus) |
| 05-card-hardcoded-colors | static | Palette + hex colors, old shadow, root part only | `G1_HARDCODED_COLOR G1_TOKEN_EXTRA G1_TOKEN_MISSING G1_PART_MISSING G1_SLOT_MISSING` |
| 06-clean-badge | static | Control: verbatim port of badge.tsx | nothing (no G1 finding at all) |
| 07-scenario-gap | scenario | Scenario file covers half the variants/sizes | `SC_VARIANT_UNCOVERED SC_NO_DARK_TWIN` |
| 08-oracle-extract | extract | Guards the extractor (sizes, defaults, data attrs, slots, tiers, wave order) | all assertions hold |
| 09-state-waves | state | `port_state.rb` on the fixture graph: infra wave 0, pilot mini-waves (dialog after button), fan-out after pilots, resumable flow, re-init keeps progress and resets only components whose oracle source changed | all assertions and flow steps hold |
| 30-state-skip-tier | state | `port_state.rb init --skip-tier`: whole tiers leave the plan, the choice persists across a plain init, `none` clears it, unknown tiers and dependency-breaking skips are refused | present/absent per step, clear error messages |
| 31-nonrendered-slots | static | Dialog port that omits the `dialog`/`dialog-portal` slots (Radix renders no element for Root/Portal) | no `G1_SLOT_MISSING` |
| 32-cn-differential | cn | JS `twMerge` (catalog) vs Ruby `tailwind_merge` agree on pairwise merges of real shadcn class strings (catalog must run tailwind-merge 3.x) | 0 mismatches; SKIPPED without catalog node_modules |
| 33-dx-helpers | helpers | `spec_helpers.rb`: derives the helper list (strip root prefix once, snake_case), appends it before `## Dependencies`, idempotent, `--check` catches a stale section, flags element shadowing, leaves single-part components alone | rows, ordering, no-op rerun, stale detection |
| 34-dx-prototype | dx_prototype | Runs the verified reference for the DX helper generator (`const_added` + `yield self`) on the Table example | helper HTML identical to explicit classes, helpers generated, API-name collision refused |
| 35-server-ports | server_ports | `servers.rb ports` skips a port another process holds (never assumes :3000/:5173 are free) | picks a different free Rails port, distinct from Vite's |
| 10-command-lint | lint | Seeded bad command doc (missing script, flag, subcommand, rake task, reference, agent, slash command) | all 7 `LINT_*` codes |
| 11-command-lint-real | lint | The REAL shadcn commands/agents/skills must reference only things that exist | nothing (control) |
| 14-run-happy | run | Orchestrator protocol simulated against `port_state.rb` with scripted builders that all succeed | infra-internal order, pilot before fan-out, dependencies before dependents, no duplicate dispatch, run completes |
| 15-run-pilot-failure | run | A pilot component is blocked | `checkpoint` stops with `pilot_blocked` before dialog and all fan-out |
| 16-run-dependency-wait | run | A fan-out component is blocked | its dependents are never dispatched and are reported as waiting on it; independents finish; run ends |
| 17-run-ratio-stop | run | 3 of 8 in one fan-out wave blocked (> 25%) | `wave_blocked_ratio` stop; rest of the wave never dispatched |
| 18-run-ratio-tolerated | run | 2 of 8 blocked (exactly 25%) | run continues and completes |
| 19-run-resume | run | Run interrupted after 2 batches, restarted with `init` | nothing dispatched twice, run finishes |
| 20-run-dispatch-cap | run | One task consumes 500 dispatches | `dispatch_cap` stop at the next checkpoint |
| 21-run-no-browser | run | Every builder ends `built` (`--no-browser`) | `built` satisfies dependents and is never returned again (no infinite loop) |
| 22-run-contract | contract | `shadcn-run.md` text | still invokes `port_state.rb next/checkpoint/bump/set/retry-blocked`, `static_gate`, `parity_run`, `house_check`, `planner_check`, `command_lint`, and writes `run.log`, `REPORT.md`, `PILOT_FAILURE.md` |
| 23-oracle-audit-clean | oracle_audit | `oracle_audit.rb` on the extracted fixtures (incl. arrow-function `sonner`) | nothing (control) |
| 24-oracle-audit-detects | oracle_audit | Seeded extractor misses (lost parts/tokens, slot, cva table) | `AUDIT_PART_COUNT AUDIT_NO_TOKENS AUDIT_SLOT_MISMATCH AUDIT_CVA_COUNT` |
| 25-browser-selftest | browser | `parity_run.mjs` against two fixture servers, 22 scenarios of known outcome (identical passes; CLASS/ATTR/TEXT/STYLE/BOX/VISIBLE/FOCUS/A11Y_REL/NODE_COUNT/SLOT_ORDER/JS error each reported; empty render, HTTP 500 and `data-parity-error` never pass) | all 22 behave as expected; `SKIPPED` when playwright is unavailable (`PARITY_PLAYWRIGHT_DIR`, `PARITY_CHROMIUM`) |
| 12-planner-badge | planner | Real planner run (offline) on a static cva component | `planner_check` passes: >= 12 scenarios, dark twins, all variants |
| 13-planner-switch | planner | Real planner run (offline) on an interactive Radix component | `planner_check` passes: Behavior section, `press`/`click`/`tab` steps, dark twins |

## Procedure
1. `TodoWrite` one item per selected case.
2. **Script tier:** `ruby .claude/scripts/shadcn/golden_run.rb <target>`; parse the JSON. These results are final for `static`, `scenario` and `extract` cases; do not re-judge them. For `agent` cases the script returns `AGENT_PENDING` after confirming the G1 side (markup passes where `static_must_pass`).
3. **Planner tier** (skip with `--scripts-only`; costs two opus runs): for every `PLANNER_PENDING` case dispatch `shadcn-port-planner` (ONE message, parallel) with a self-contained prompt: `COMPONENT` from `expected.json`, `OUT_ROOT` = the case's `OUT_ROOT` note (e.g. `tmp/shadcn-port/golden/planner-out/12-planner-badge`), `OFFLINE=true`, manifest and TSX paths under `<OUT_ROOT>/dev/port/oracle/`, `TIER` from the manifest, primitives list = none, dependency components = none, and the rule that nothing may be written outside OUT_ROOT. Then validate each with `ruby .claude/scripts/shadcn/golden_run.rb planner-check <case-id>` (deterministic: spec sections, parts and slots named, scenario shape, React-named props, steps, volume, variant/state coverage, dark twins, required step kinds). The planner's own receipt is NOT evidence. Verify with `git status` that the planners wrote nothing outside `tmp/`.
4. **Agent tier** (skip with `--scripts-only`): for every `AGENT_PENDING` case dispatch `shadcn-parity-auditor` in ONE message (parallel), with a self-contained prompt:
   - `COMPONENT`: from `expected.json`, `MODE: static`, `SERVERS_UP=false`.
   - The files to review: every file under `dev/golden/cases/<id>/files/` (treat the path after `files/` as the repo-relative path; the shared primitives that exist in that case are the ones under its `app/javascript/chadcn/primitives/`).
   - Oracle: `tmp/shadcn-port/golden/oracle` (already extracted by step 2); spec/scenarios do not exist for golden cases, so ignore `Q_SCENARIO_GAP` for them.
   - Run G1 with `--files` set to the case's component `.rb` files if any and `--oracle tmp/shadcn-port/golden/oracle`.
   Validate the JSON. **Unverified claims are downgraded by you, mechanically:** any `Q_*` finding with severity MANDATORY whose `detail` contains `did not read`, `did not open`, `not opened`, `unverified` or `UNVERIFIED` (case-insensitive) is set to ADVISORY before you count it; it never blocks a PASS and never counts toward `agent_must_find` unless the case explicitly lists it. Compare `findings[].code` with `agent_must_find`; check that the `summary`/`detail` text of the findings mentions every word in `agent_must_mention` (case-insensitive); `agent_may_find` codes are BONUS. A code listed in `agent_must_be_mandatory` must also carry severity MANDATORY after the downgrade rule. A finding the auditor cannot back with a quote of the fixture code does not count.
5. Verdict per case: `FOUND` = every must item present; `MISSED` = absent; `FALSE POSITIVE` = a `must_not_detect` code present (for `"*"`: any G1/SC finding); `BONUS` = may-find present. PASS only if nothing missed and no false positive.
6. Output one table: `case | kind | must found/total | missed | bonus | false positives | verdict`. Finish with `GOLDEN: PASS` or `GOLDEN: FAIL (<n> cases)` and, per failure, the likely cause:
   - script case failed -> regex/heuristic bug in the named script (`oracle_extract.rb`, `static_gate.rb`, `scenario_coverage.rb`) or a changed fixture;
   - lint case failed -> the commands/agents/skills reference something that does not exist (fix the doc, never the lint) or the lint regex lost a case;
   - state case failed -> `port_state.rb` wave/pilot/idempotency regression;
   - planner case failed -> planner prompt or `state-matrix.md` too vague, or `planner_check.rb` too strict (read the finding before deciding);
   - agent case missed -> auditor prompt or the `radix-stimulus`/`shadcn-port` Quick Rule is too vague, or the agent did not read the skill;
   - clean case false positive -> a gate is too strict; fix the gate, never the fixture.
7. Persist the table to `tmp/shadcn-port/golden-latest.md` with `Write`.

## When to run
After changing: any script in `.claude/scripts/shadcn/`, the three `shadcn-*` agents, `shadcn-port` / `radix-stimulus` Quick Rules, or the gate vocabulary. Not on every component run.

## Not covered here (and why)
The LLM-driven parts of `/shadcn-run` (how well a builder ports a component, how the orchestrator phrases agent prompts) are only exercised by a real run. What IS tested is every decision the orchestrator makes: the protocol simulation (cases 14-21) drives `port_state.rb`, which now owns wave order, dependency waiting, pilot/ratio/cap stops and resume.

The runner's own logic is covered by case 25. The REAL React and Phlex pages need both live catalogs, so they are proven by the `_harness` self-test (`infra-tasks.md`: identical probe must pass, mutated probe must fail).
