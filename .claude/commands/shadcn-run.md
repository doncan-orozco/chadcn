---
description: Orchestrate the full shadcn -> Phlex port end to end: infra wave, pilot checkpoint, then fan-out waves of plan -> build -> gate -> triage -> fix, resumable. One call, no human input.
argument-hint: "[all|a,b,c|wave:N] [--resume] [--retry-blocked] [--concurrency 4] [--max-iter 3] [--pilot-only] [--no-browser]"
allowed-tools: Agent, Read, Write, Edit, Grep, Glob, TodoWrite, Bash(ruby:*), Bash(node:*), Bash(npm:*), Bash(npx:*), Bash(curl:*), Bash(cd:*), Bash(mkdir:*), Bash(bundle exec rake:*), Bash(bundle exec rubocop:*), Bash(git status:*), Bash(git diff:*), Bash(git rev-parse:*), Bash(grep:*), Bash(ls:*), Bash(lsof:*), Bash(kill:*)
---

# /shadcn-run: the orchestrator

Arguments: $ARGUMENTS
Parse: scope (`all` default | comma list | `wave:N`), `--resume` (default behavior when state exists), `--retry-blocked` (acknowledge an earlier stop: blocked components go back to pending and the dispatch counter resets), `--concurrency N` (default 4, max 6), `--max-iter N` (fix iterations per component, default 3), `--pilot-only` (stop after the pilot checkpoint), `--no-browser` (G1 only; marks components `built`, never `done`; `built` satisfies dependents and is never returned by `next` again).

You coordinate; you do NOT write app code, edit components or edit scenarios. Everything is done by `shadcn-port-planner`, `shadcn-port-builder` and `shadcn-parity-auditor` via the Agent tool, and every verdict comes from the gate scripts that YOU run yourself. Read `.ai/skills/shadcn-port/SKILL.md` and `references/parity-gates.md` first.

## Why this shape (keep in mind when deciding)
- **Per-component loop, wave-ordered.** Gates are cheap scripts, so each component is verified immediately after its build instead of at the end: failures are found while the context that caused them is fresh, and a bug in shared infra is caught by the pilot, not by 40 components.
- **Pilot checkpoint.** Infra + 6 representative components (static cva, boolean control, floating, menu, selection, modal) must be green before fan-out. If the pilot cannot go green, stop: the problem is the infra or the contract, not 50 components.
- **Ownership prevents conflicts,** so builders in a batch run in parallel on one checkout with shared dev servers (no worktrees).
- **Scripts judge, agents fix.** The auditor is called only when a gate fails twice or for the final deep review.

## Phase 0: State and servers
1. If `dev/port/state.json` or the oracle is missing: run the `/shadcn-plan --lazy` procedure first (Phases 0-3), then continue. Always run `ruby .claude/scripts/shadcn/command_lint.rb` first; on findings STOP (the docs name something that does not exist).
2. `ruby .claude/scripts/shadcn/port_state.rb init` (reuses the plan's `--skip-tier` stored in `state.json`; idempotent: keeps progress, resets only components whose oracle `source_sha` changed and says which), then with `--retry-blocked` `ruby .claude/scripts/shadcn/port_state.rb retry-blocked`, then `port_state.rb summary`. Print it.
3. Unless `--no-browser`: (a) `ruby .claude/scripts/shadcn/playwright_ensure.rb` (installs a Playwright into the catalog that can launch a browser already on this machine, then smoke-tests a real launch; exit 1 => STOP and report, browser gates cannot run); (b) `ruby .claude/scripts/shadcn/servers.rb start` (the dummy app + the Vite catalog on FREE ports, default 3055/5177, recorded in `dev/tmp/shadcn-port/servers.json`; it only ever reuses servers it started and never touches another project's server on :3000 or :5173; the parity route is on the public host `localhost:PORT`). `parity_run.mjs` reads the recorded URLs by itself, so never pass fixed ports to it. Exit 1 from `start` => read `tmp/shadcn-port/{rails,vite}.log`, STOP and report. Set `SERVERS_UP=true`. At the very end (Phase 3, also after any stop condition) run `ruby .claude/scripts/shadcn/servers.rb stop`. Wave 0 is allowed to start before `_harness` exists; set `SERVERS_UP=false` for wave 0 builders except `_harness` self-test.
4. `mkdir -p tmp/shadcn-port`; append every step to `tmp/shadcn-port/run.log` (one line: time, wave, component, event). TodoWrite one item per wave.

## Phase 1: Main loop
Repeat until `port_state.rb next` returns `done: true`, or a stop condition fires:

1. `port_state.rb next --concurrency N` -> `{ wave, kind, batch[], waiting{}, done }`. `next` is the ONLY source of what to run: it already enforces wave order, infra-internal dependencies (`_harness` after `_theme`/`_base`/`_icons`, `_primitives` after `_harness`) and dependency order, and it never returns components that depend on a blocked one (they appear in `waiting` with the root blocker and are reported at the end). With `--pilot-only`, stop as soon as `kind` is `fanout`.
2. **Plan just-in-time** (components still `pending`): dispatch `shadcn-port-planner` for the batch AND, in the same message, for the pending components of the next wave (`summary --json`; pipelining, so planning is ahead of building). **Never trust the receipt:** run `ruby .claude/scripts/shadcn/planner_check.rb --component X`; findings go back to the planner once, still failing -> `port_state.rb set X blocked --note "planner_check: <codes>"`. Passing -> `port_state.rb set X planned`, then `ruby .claude/scripts/shadcn/spec_helpers.rb --component X` (derived DX helpers section) and `ruby .claude/scripts/shadcn/deviations_register.rb` (G5 fails an unregistered deviation).
3. **Build:** dispatch one `shadcn-port-builder` per batch item, all in ONE message (parallel). Count every planner, builder and auditor dispatch with `port_state.rb bump <n>` (the global cap is enforced by `checkpoint`). Prompt (self-contained): `COMPONENT`, `SERVERS_UP`, `OWNS` (infra only), paths of spec/scenarios/oracle, `MAX_RUNS=4`, list of DONE dependencies (their Phlex class names). `_primitives` is one task executed by four parallel family builders (overlay, floating, selection, forms); mark it `done` only after its acceptance checks pass.
4. **Verify yourself (never trust the receipt):** for each returned component run, in this order, and stop at the first red:
   - `ruby .claude/scripts/shadcn/static_gate.rb --component X` (G1)
   - `bundle exec rubocop lib/chadcn/<x>.rb` (RuboCop covers the Ruby files only; the JS is judged by the gates).
   - if browser: `cd dev/react-shadcn-catalog && node ../../.claude/scripts/shadcn/parity_run.mjs --component X > ../../tmp/shadcn-port/X/g2.json` (G2+G3), then G2b for components with helpers (`--dx helpers --only <ids starting default, variant- or example__, cap 25>`), then G4: for each `--theme slate|stone|zinc-radius0` with `--only` = the scenarios whose id starts with `variant-` or equals `default*` (cap 12), and once with `--dark`.
   - infra items: the acceptance checks in `references/infra-tasks.md`.
   Green -> `port_state.rb set X done --sha $(git rev-parse --short HEAD) --iteration n`. No browser -> `built`.
5. **Fix loop (Actor-Critic), per red component, max `--max-iter`:**
   - iteration 1: send the gate diffs back to the SAME builder via `SendMessage` if still available, else a new `shadcn-port-builder` with the diffs (capped to 40 entries, grouped by `kind`).
   - iteration 2+: dispatch `shadcn-parity-auditor` (`MODE: triage`, with the gate JSONs) and pass its `causes[].fix_target` to the builder.
   - after each fix re-run step 4. Stop early when the diff count did not drop for two consecutive iterations.
   - Exhausted -> `port_state.rb set X blocked --note "<top cause, scenario ids>"`; write `tmp/shadcn-port/X/BLOCKED.md` with the last triage. `next` stops returning its dependents by itself; do not mark them.
6. **After every batch:** `ruby .claude/scripts/shadcn/port_state.rb checkpoint`. If `stop` is true, follow "Stop conditions" below; never continue past it.
7. **When `next` moves to a new wave:**
   - regression: `ruby .claude/scripts/shadcn/house_check.rb --static-all`; if any file under `app/javascript/chadcn/`, `app/assets/tailwind/chadcn/` or `lib/chadcn/base.rb` changed this wave (`git diff --name-only` against the wave start sha you recorded) re-run G2 default scenarios (`--only` ids starting `default`) for all `done` components, and treat red ones as new work for the fix loop.
   - `bundle exec rake test` (the gem suite) must stay green.
   - print `port_state.rb summary` (compact).

## Stop conditions
The rules live in `port_state.rb checkpoint` (tested by the golden suite); you only act on its answer. Reasons:
- `infra_blocked`: an infra task is blocked, nothing can work. Write `tmp/shadcn-port/<task>/BLOCKED.md`, stop.
- `dispatch_cap`: more than 3 x components dispatches were counted (runaway fix loops). Stop and report.
- `pilot_blocked`: STOP before any further pilot mini-wave or fan-out. Write `dev/port/PILOT_FAILURE.md` with the causes grouped by shared layer (primitive, harness, theme, contract) and the proposed fix to infra/contract. Do not fan out.
- `wave_blocked_ratio`: more than 25% of a fan-out wave (of at least 4) is blocked. Stop that wave's remainder, report the common causes.
- Servers die twice: stop with the log.
After any stop, finish with Phase 3 (report) so nothing is lost. The user fixes the cause and re-runs with `--retry-blocked`.

## Phase 2: House (final)
1. `ruby .claude/scripts/shadcn/house_check.rb --static-all` (must be clean).
2. Full G4: for every `done` component run G2 with `--theme slate` and `--theme stone` over its `default*` scenarios, and `--dark`.
3. `bundle exec rubocop`, `bundle exec rake test test:engine` and the dummy app's Minitest suite (`bin/check` runs all of them). Every previously `done` component must be unaffected: any new failure is a regression from shared files (`app/assets/tailwind/chadcn/*.css`, `config/importmap.rb`, `lib/chadcn/base.rb`, the primitives) and goes back through the fix loop (`_theme`, `_base` or `_harness` owner).
4. Dispatch ONE `shadcn-parity-auditor` per `done` interactive component in `MODE: static` only for the `Q_*` review (parallel, 6 at a time) and attach advisories to the report; MANDATORY `Q_*` findings re-open the component through the fix loop once.
5. Catalog: confirm the dummy app's catalog (`dev/dummy/app/components/catalog`, served by `bin/demo`) lists every `done` component (it is generated from the scenario files; a missing component is a gap to report, never a hand edit).

## Phase 3: Report
Write `dev/port/REPORT.md`: totals by status; per component: status, iterations, scenarios, deviations; blocked list with the top cause and the exact file to look at; `waiting` components and the blocker each waits on; visual-regression notes from `_theme` (see theme-contract.md, "Coexistence"); theme gate result per theme; advisories; time and dispatch counts; the command to resume (`/shadcn-run all --resume`). Final chat message: 10 lines max: counts, blocked components, where the report is.

## Rules
- You never edit app/component/scenario/oracle files. Only `dev/port/{state.json,REPORT.md,PILOT_FAILURE.md}` (state only through `port_state.rb`) and `tmp/shadcn-port/**`.
- Every agent prompt is self-contained: paths, component, constraints, expected JSON. Agents do not see this conversation.
- Parallel means ONE message with several Agent calls. Never more than `--concurrency` builders at once.
- A gate result you ran yourself overrides any agent claim. If a script crashes (not a diff), that is `HARNESS_ERROR`: re-run once, then stop the wave and report; do not mark components done or blocked on harness crashes.
- Do not commit or push. Leave the working tree for the user's review.
