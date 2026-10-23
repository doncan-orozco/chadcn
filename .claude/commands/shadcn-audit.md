---
description: Strict parity audit of ported shadcn components (G1 static, G2 DOM/style, G3 behavior, G4 theme, G5 house). Script-judged, agent-triaged. Add --fix for the Actor-Critic loop.
argument-hint: "[all|a,b,c|wave:N|changed] [--fix] [--themes] [--house] [--deep] [--no-browser] [--max-iter 3]"
allowed-tools: Agent, Read, Write, Grep, Glob, TodoWrite, Bash(ruby:*), Bash(node:*), Bash(curl:*), Bash(cd:*), Bash(mkdir:*), Bash(bundle exec rubocop:*), Bash(bundle exec rake:*), Bash(git diff:*), Bash(git status:*), Bash(ls:*), Bash(grep:*)
---

# /shadcn-audit: parity audit

Arguments: $ARGUMENTS
Scope: `all` | comma list | `wave:N` (from state.json) | `changed` (components whose files differ from HEAD: `git diff --name-only` mapped `lib/chadcn/<x>.rb`, `app/javascript/controllers/chadcn/<x>_controller.js`). Default `changed`.
Flags: `--fix` (remediation loop), `--themes` (G4 on all four themes), `--house` (G5 only/also), `--deep` (always run the auditor agent, not only on failures), `--no-browser` (G1 only).

Read `.ai/skills/shadcn-port/SKILL.md` + `references/parity-gates.md`. You orchestrate and report; you do not audit by reading code yourself.

## Why not bricks / rooms / house
The old audit judged code quality bottom-up. Here the oracle exists, so truth is a **diff against it**, not an opinion about the code. The map step is therefore one deterministic gate run per component (cheap, parallelizable, identical every time); the only LLM step is triage and the few things a diff cannot see. The "house" step stays, as a library-wide regression + consistency check.

## Phase 0: Prepare
1. Resolve scope; `ruby .claude/scripts/shadcn/port_state.rb summary --json` to map names, ignore `_infra` unless named.
2. Browser gates need the dev servers: `ruby .claude/scripts/shadcn/servers.rb status` must exit 0 (they are started by `servers.rb start`, on free ports recorded in `dev/tmp/shadcn-port/servers.json`, which the runner reads by itself). If it does not and you are not `--no-browser`, run `playwright_ensure.rb` then `servers.rb start`, and stop it again when the audit ends if YOU started it.
3. `mkdir -p tmp/shadcn-port/<c>` per component. TodoWrite one item per component.

## Phase 1: Map (scripts, no agents)
For each component, in parallel Bash calls (up to 6 at a time), write outputs under `tmp/shadcn-port/<c>/`:
1. G1: `ruby .claude/scripts/shadcn/static_gate.rb --component <c> > g1.json`
2. Scenario coverage: `ruby .claude/scripts/shadcn/scenario_coverage.rb --component <c> > coverage.json` (a gap is a `Q_SCENARIO_GAP`, MANDATORY)
3. G2+G3 (browser): `cd dev/react-shadcn-catalog && node ../../.claude/scripts/shadcn/parity_run.mjs --component <c> > ../../tmp/shadcn-port/<c>/g2.json`; then G2b for components with DX helpers: the same with `--dx helpers --only <ids starting default, variant- or example__, cap 25>` > `g2b.json`
4. G4 (browser, `--themes` or always for `--house`): `--theme slate|stone|zinc-radius0` with `--only` = scenario ids starting `default` or `variant-` (cap 12), plus `--dark`.
Collect `{ component, g1, coverage, g2, g4 }` pass/fail and diff counts. A script crash is `HARNESS_ERROR`: re-run once, report it separately, never count it as a component failure.

## Phase 2: Triage (agents, only where needed)
Dispatch `shadcn-parity-auditor` in ONE message, parallel, for each component that failed any gate, plus all components when `--deep`. Prompt: `COMPONENT`, `MODE: triage` (or `full` for `--deep`), `GATE_REPORTS` paths, `SERVERS_UP`. Validate every returned JSON (`verdict`, `causes[].fix_target`, rule citations); re-ask once if malformed. Drop any finding that does not quote code or a diff entry. **Unverified claims are downgraded by you, mechanically:** any `Q_*` finding with severity MANDATORY whose `detail` contains `did not read`, `did not open`, `not opened`, `unverified` or `UNVERIFIED` (case-insensitive) is set to ADVISORY before you count it; it never blocks a PASS and never counts toward `agent_must_find` unless the case explicitly lists it.

## Phase 3: House (G5)
Always with `--house` or `all`: `ruby .claude/scripts/shadcn/house_check.rb --static-all`; `bundle exec rubocop lib/chadcn`; `bundle exec rake test`. Merge into the report.

## Phase 4: Report (`tmp/shadcn-port/audit-<timestamp>.md`)
One table: `component | G1 | G2 | G3 | G4 | scenarios | top cause | verdict`. Below it, per failing component the grouped causes with `fix_target`. House findings last. Verdict per component is PASS only when every gate that ran is green and no MANDATORY `Q_*` exists. End with `AUDIT: PASS` or `AUDIT: FAIL (<n> components)` and, for failures, the single command to fix them (`/shadcn-audit <list> --fix`).

## Phase 5: `--fix` (Actor-Critic, max `--max-iter`, default 3)
For each failing component: dispatch `shadcn-port-builder` with the auditor's `causes[]` (ordered, with `fix_target`) as its only instructions; then re-run Phase 1 for that component yourself; if still red run the auditor again with the new reports. Stop early when the diff count does not drop for two iterations; mark the component `blocked` via `port_state.rb set` with the top cause. Never loosen a gate, edit scenarios, the oracle, the runner or the ignore list to turn a component green.

## Rules
- Gates are facts. An agent may explain a diff, never dismiss it. `HARNESS`/`ORACLE_NOISE` verdicts need the evidence described in `parity-gates.md`.
- No writes outside `tmp/shadcn-port/**` unless `--fix` (then only through the builder).
- Do not update `state.json` to `done` here except when `--fix` ends fully green (then `port_state.rb set <c> done`).
