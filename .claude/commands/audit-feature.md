---
description: Forensic Map-Reduce audit (Bricks -> Rooms -> Slices -> House) of a change to the chadcn gem (Phlex components, Stimulus controllers and primitives, Rails integration, tests, tooling). Every file is on the Gem track. Add --fix for the Actor-Critic remediation loop.
argument-hint: "[branch|range|files] [--fix] [--wide] [--no-checks] [--no-cache] [--pr-comment] [ticket text or @ticket.md]"
allowed-tools: Agent, Read, Grep, Glob, TodoWrite, Bash(git:*), Bash(bundle exec rubocop:*), Bash(bundle exec rake:*), Bash(bundle exec ruby:*), Bash(ruby:*), Bash(shasum:*), Bash(mkdir -p tmp/audit:*), Edit(tmp/audit/**), Bash(bin/smoke:*), Bash(env -u BUNDLE_GEMFILE:*)
---

# Map-Reduce Audit: Bricks, Rooms, Slices, House (the chadcn gem)

Target: $ARGUMENTS
If $ARGUMENTS is empty, ask user for files, git diff range, or feature ticket.

Input convention — parse $ARGUMENTS as: `[scope] [--fix] [--wide] [--no-checks] [--no-cache] [--pr-comment] [ticket...]`
- `scope` (first token(s) before flags): branch, range (`origin/main...HEAD`), or explicit file paths. Defaults to HEAD diff if omitted.
- `--fix`: enables Phase 4 Actor-Critic remediation (max 3 iterations). Without it, audit-only.
- `--wide`: lifts diff-scoping (Phase 0.7). DEFAULT is **diff-scoped**: the audit judges, and `--fix` edits, only what the change touched. `--wide` audits and may refactor whole touched files.
- `--no-checks`: skips Phase 0.9 (mechanical checks). Default is to run them.
- `--no-cache`: ignores and does not write the Brick/Room result cache (Phase 0.8).
- `--pr-comment`: additionally writes a ready-to-paste review comment file (Phase 5). Never posts anything.
- `ticket...` (everything else: PR description, AC, pasted text, or `@path/to/ticket.md`): pass VERBATIM as `FEATURE_TICKET` to House and as intent context to the Builder. `Read` any `@file` first. Never truncate intent; trim code instead.

You are the orchestrator, running in the main session. You DO NOT audit code yourself. You fan out to sub-agents with the `Agent` tool (`subagent_type` = agent name) and reduce their JSON into a final House audit. Sub-agents cannot spawn sub-agents or talk to each other — you are the only pipeline.

Stack facts every agent must assume: ONE repository, ONE gem (`chadcn`, Ruby >= 3.3, `phlex ~> 2.3`, `tailwind_merge`, Zeitwerk). Core is plain Phlex in `lib/chadcn/**` (`Chadcn::Base`, one class per React export, parts nested under the root); the Rails integration (`lib/chadcn/engine*.rb`, `lib/generators/chadcn/**`, `lib/tasks/*.rake`) loads only when Rails is present; Stimulus controllers in `app/javascript/controllers/chadcn/**` (`chadcn--*`) compose the primitives in `app/javascript/chadcn/primitives/**`, pinned by `config/importmap.rb` (esbuild hosts get managed copies from the install generator); CSS theme, tokens, presets and vendored CSS in `app/assets/tailwind/chadcn/**`; Minitest with no database and no network (`bundle exec rake test` never loads Rails, `rake test:engine` boots one minimal app in-process, `rake test:tooling` tests `.claude/scripts`); browser tests in `test/javascript` (`bin/test-js`, needs a browser and the dev servers); RuboCop (minitest, performance, rake); `gem_check.rb` is the gem gate; a public API snapshot (`test/fixtures/public_api.txt`); YARD at 100%; generated llms files. The dev kit under `dev/` (oracle, specs, scenarios, dummy app, React catalog) is not packaged and is judged by `/shadcn-audit`, not here. Conventions are the skills under `.ai/skills` (`ruby-gem-conventions`, `design-system`, `shadcn-port`, `radix-stimulus`, `stimulus`, `accessibility`, `testing`, `naming-conventions`, `linting`, `epic-flow`); there is no other layer.

## Phase 0 — Collect scope + route by track (you do this)
Auto-detect, never ask unless truly ambiguous:
- **A) Explicit files** → use directly via `Read`.
- **B) Branch or range** (`feature/x`, `origin/main...HEAD`) → resolve via git. Bare branch = that branch vs merge-base with main.
- **C) Empty / ticket text only** → ask for files, branch, or range. Do not guess.

Branch resolution (READ-ONLY git; never edit/commit/push):
1. `ROOT` = `git rev-parse --show-toplevel`. `git fetch origin --quiet; git branch --show-current; git merge-base <base> <head>; git diff --name-only <base>...<head>; git status --porcelain=v1; git diff --name-only; git diff --cached --name-only`. `<base>` defaults to `origin/main` (fallback `main`); `<head>` is the requested branch or HEAD. Record: base SHA, head SHA, branch, committed files, PLUS uncommitted files (staged, unstaged, untracked; `.rb/.js/.mjs/.rake/.gemspec/.css/.md/.yml` only) labeled UNCOMMITTED.
2. Route every changed file into exactly ONE track:
   - **Ruby track:** `lib/chadcn.rb`, `lib/chadcn/**/*.rb` except the integration files → Brick (`brick-method-auditor`) + Room (`room-class-auditor`). Skills: `ruby-gem-conventions` + `naming-conventions` always; component files (`lib/chadcn/<name>.rb`, `lib/chadcn/<name>/**`, `base.rb`, `icon.rb`) add `design-system` + `shadcn-port` (and `accessibility` when the part renders interactive markup); `theme.rb`, `configuration.rb`, `js_bundle.rb`, `overrides.rb`, `doctor.rb`, `doctor/**` stay on the gem skills.
   - **Integration track:** `lib/chadcn/engine.rb`, `lib/chadcn/engine/**`, `lib/generators/**`, `lib/tasks/**` → Room only (`ruby-gem-conventions`, `naming-conventions`; R2, R9, R15 are the law here) and House.
   - **Stimulus track:** `app/javascript/controllers/chadcn/**/*.js`, `app/javascript/chadcn/primitives/**/*.js` → ONE `stimulus-controller-auditor` call per file (it covers brick + room) with `stimulus` + `radix-stimulus` (+ `accessibility`, `naming-conventions`).
   - **Tooling track:** `.claude/scripts/**/*.rb` (not the tests) → Room only with `naming-conventions` + `linting`; `dev/llms/**` and `bin/*` Ruby → the same.
   - **Tests:** `test/**/*.rb`, `test/javascript/*.mjs`, `.claude/scripts/test/**`, `dev/dummy/test/**` → Room only (no Bricks), skill `testing` (+ `naming-conventions`).
   - **Slice (derived):** group each changed component's Ruby files, its controller `app/javascript/controllers/chadcn/<name>_controller.js`, the primitives it imports, `dev/port/specs/<name>.md`, `dev/port/scenarios/<name>.json`, `test/chadcn/<name>_test.rb` and `test/javascript/<name>.test.mjs` into one slice per component → `view-slice-auditor` (Phase 2.5). Spec, scenario and test files that are untouched are still passed as context.
   - **House-only:** `chadcn.gemspec`, `Gemfile*`, `Rakefile`, `.rubocop.yml`, `.yardopts`, `CHANGELOG.md`, `LICENSE`, `THIRD_PARTY_NOTICES*`, `README.md`, `docs/**`, `config/importmap.rb`, `app/assets/**`, `vendor/**`, `lib/generators/**/templates/**`, `.github/**`, `bin/*` (shell), `llms*.txt`, `skills/chadcn/SKILL.md`, `test/fixtures/**`, `.ai/skills/**`, `.claude/{agents,commands}/**`, `CLAUDE.md`, `dev/**` (except its Ruby tests above) and everything else → NO Brick/Room; excerpt straight to House (packaging, pins, asset wiring, docs, secrets, public API promise).
3. Empty list → stop: "No auditable changes in <base>...<head>".
4. If >15 Brick/Room files → audit the 15 largest by `git diff --stat`, list the rest as skipped, ask whether to run a second pass. House-only files never count toward the cap.
5. Build `RAW_CODE` yourself: `git diff <base>...<head> -- <selected + House-only files>` plus `git diff` / `--cached` for uncommitted files, truncated per file to 400 lines (House-only: 100), labeled UNCOMMITTED when applicable.
6. Compute these mechanical checks yourself with `Grep`/`Glob` (cheap, deterministic) and keep them for House:
   - `GEM_GATE` (when anything under `lib/`, `app/`, `config/`, `vendor/`, the gemspec or the Gemfile changed): run `ruby .claude/scripts/gem/gem_check.rb --gem-dir .` and keep its JSON verbatim for House; every finding is MANDATORY and cites `ruby-gem-conventions R<n>` (the skill maps each finding code to its rule in square brackets).
   - `TEST_COVERAGE_MAP`: for each changed Ruby or JS file, does its test exist and is it in the diff? `lib/chadcn/<name>.rb` (and `lib/chadcn/<name>/**`) ↔ `test/chadcn/<name>_test.rb`; `lib/chadcn/doctor/**` ↔ `test/doctor/**`; `lib/generators/**` ↔ `test/generators/**`; `lib/chadcn/engine*` ↔ `test/engine/**`; `lib/chadcn/theme.rb` ↔ `test/chadcn/theme*_test.rb`; `app/javascript/controllers/chadcn/<name>_controller.js` ↔ `dev/port/scenarios/<name>.json` (behavior scenarios) and, when the spec lists runner-inexpressible behavior, `test/javascript/<name>.test.mjs`; `app/javascript/chadcn/primitives/<name>.js` ↔ `test/javascript/primitive_<name>.test.mjs`; `.claude/scripts/**/<x>.rb` ↔ `.claude/scripts/test/<x>_test.rb`. Mark `MISSING` otherwise (`testing` R1).
   - `STIMULUS_WIRING`: every `data-controller="chadcn--<x>"` (or `controller: "chadcn--<x>"` in a `data:` hash) a changed part renders has `app/javascript/controllers/chadcn/<x>_controller.js`; every `data-chadcn--<x>-target="<t>"` and `data-chadcn--<x>-<v>-value` the parts render is declared in that controller's `static targets/values`, and vice versa for changed controllers (every declared target/value appears in a part). Pins: `config/importmap.rb` covers the directory (`pin_all_from`); a new primitive needs no pin change, a new vendored library does.
   - `API_SURFACE`: when `lib/**` changed, run `bundle exec ruby -Itest -Ilib test/public_api_test.rb` (Phase 0.9 reports it); a changed `test/fixtures/public_api.txt` without a `CHANGELOG.md` hunk in the same diff is a House finding (`ruby-gem-conventions` R5, R6); a changed component signature or controller `static values` without a regenerated `llms-full.txt`/`skills/chadcn/SKILL.md` is reported through `bundle exec rake llms:check` in Phase 0.9.
   - `DOCS_PARITY`: a new public kwarg, part or component that appears in no README or `docs/*.md` fence is a House advisory; a changed fence is checked by `bin/smoke --docs` only when the orchestrator may run it (it is offline and fast: run it in Phase 0.9 when README or docs changed).
7. **Workspace warnings** (facts, not findings): (a) uncommitted changes mixed into the range; (b) `Gemfile.lock` changed without a gemspec or Gemfile change; (c) generated files edited by hand (`lib/chadcn/icons/catalog.rb`, `llms*.txt`, `skills/chadcn/SKILL.md`, `app/assets/tailwind/chadcn/presets/*`, `tokens.css`) when the generator was not run. Record them as `WORKSPACE_WARNINGS`.
8. Create a `TodoWrite` list: one item for mechanical checks, one per Ruby file (Brick+Room), per Stimulus file, per slice, one for House-only, one for House. Put `base...head` SHAs in the title.

## Phase 0.5 — Skill Router (you do this, once per file)
Skills are plain Markdown under `S = <ROOT>/.ai/skills` (also exposed through the `.claude/skills` symlink, but leaf agents load them by ABSOLUTE PATH with `Read`, never through the Skill tool). Resolve by path AND content (`Glob`/`Grep`; do not read bodies) and pass absolute paths in a `<SKILL_FILES>` block. Bricks inherit their file's Room skills.

Matrix (`Read` only on match):
- `naming-conventions`: ALL `*.rb`, `*.js`, `*.mjs` — always.
- `ruby-gem-conventions`: every gem Ruby, JS, CSS, gemspec and Gemfile file (everything outside `dev/`, `test/` and `.claude/`), plus House-only gem files.
- `design-system` + `shadcn-port`: component files under `lib/chadcn/` (`<name>.rb`, `<name>/**`, `base.rb`, `icon.rb`, `icons/**`), `app/assets/tailwind/chadcn/**`; add `accessibility` for parts that render interactive markup (buttons, triggers, inputs, items, menus, dialogs).
- `stimulus` + `radix-stimulus`: `app/javascript/**` (+ `accessibility`).
- `testing`: `test/**`, `.claude/scripts/test/**`, `dev/dummy/test/**`.
- `linting`: `.claude/scripts/**/*.rb` (tooling), `dev/llms/**`.
- `epic-flow`: `.claude/scripts/epic/**`, `.claude/commands/work*.md`, `epic-plan.md`.
- House macro skills (pasted bodies, once): `ruby-gem-conventions` (always), `shadcn-port` (if components, assets or the importmap were touched), `testing` (if tests or coverage gaps), `stimulus` (if controllers or primitives were touched) — each trimmed to 120 lines. House never receives micro skills (no double jeopardy with Rooms).

Prompt block:
```
<SKILL_FILES>
<ROOT>/.ai/skills/naming-conventions/SKILL.md
<ROOT>/.ai/skills/ruby-gem-conventions/SKILL.md
</SKILL_FILES>
(Read every listed file first; enforce all of them as law; cite `<skill> R<n>` (the numbered Quick Rules at the top of each skill) for every smell; a rule marked `(dropped: ...)` is a tombstone and is never cited; report skills_loaded / skills_failed.)
```
Caps: Bricks max 3 skills (naming-conventions first, then the most specific ones; Bricks read only the first 150 lines of each skill — the leading rules); Rooms/Slices/Stimulus max 5, full files. Budget guard: keep `naming-conventions` + `ruby-gem-conventions` + the most specific skill and name dropped ones in the prompt footer. `Glob` each path before dispatch; missing ⇒ drop and add `SKILL_MISSING: <name>`. If a leaf reports `skills_failed`, re-dispatch that call once, then surface it in the report.

## Phase 0.7 — Scope Map (you do this; skipped only with `--wide`)
Ship safe, reviewable code: the ticket changed one part, so audit and fix stay on that part; surrounding code is reported as debt, never rewritten.
1. For each in-scope file get status and changed lines in WORKING-TREE coordinates: `git diff -U0 <base>...<head> -- <file>` plus `git diff -U0 -- <file>` and `git diff -U0 --cached -- <file>` (the `+c,d` side). Status `A`/untracked ⇒ `NEW_FILE` (whole file in scope).
2. For modified files `Read` the working tree and map each changed line to its enclosing method/handler. `SCOPE[file] = { status, touched_methods: [{name,start,end}], class_level_lines: [...], changed_ranges }`. Untouched methods are OUT_OF_SCOPE even in a touched file.
3. Classification: `IN_SCOPE` = NEW file, touched method, changed class-level line, or a defect the change introduced/exposed. `PRE_EXISTING` = same defect in untouched code: never a blocker, never fixed, never consumes a `--fix` iteration; listed once as `PRE_EXISTING_DEBT`.
4. Bricks run ONLY on touched methods of MODIFIED files and every method of NEW files. Rooms/Slices/Stimulus receive the full file for context plus the SCOPE block.
5. Pass to every Room/Slice/Stimulus/House/Builder prompt (and a `touched_methods` line to each Brick):
```
<SCOPE mode="diff">
FILE: <path>   STATUS: NEW|MODIFIED
TOUCHED_METHODS: <name start-end>, ...    (NEW file: ALL)
CLASS_LEVEL_CHANGED_LINES: <lines or none>
RULE: report out-of-scope problems ONLY under `pre_existing_debt`; `refactored_*` output and every patch must stay inside TOUCHED_METHODS/changed lines/NEW files.
</SCOPE>
```
With `--wide` omit this phase; everything in touched files is IN_SCOPE.

## Phase 0.8 — Triage and cache (you do this)
Spend agent effort where it pays. Decisions are made per file from the Phase 0.7 SCOPE data:
1. **Trivial edits skip Bricks:** a MODIFIED file with <= 10 changed lines and <= 1 touched method goes to its Room only (the Room gets the method source in `RAW_CLASS_CODE` and `BRICK_AGENT_REPORTS: []`). NEW files, larger edits and `--wide` always run the full Brick + Room path.
2. **Slices only when a component changed:** run `view-slice-auditor` for a slice only if it contains at least one changed part, controller, primitive, spec or scenario. Integration-only, tooling-only or docs-only changes skip Phase 2.5 and say so.
3. **Brick size cap:** a method longer than 120 lines is sent as its signature + the touched range ±15 lines, marked `TRUNCATED: true`; the Room sees the full file.
4. **Result cache** (skip entirely with `--no-cache`): for each Brick/Room/Stimulus/Slice call compute `KEY = shasum(<agent name> + <file or method source> + <git hash-object of every SKILL_FILES entry>)` with `Bash(shasum)`. If `tmp/audit/cache/<KEY>.json` exists, reuse that JSON verbatim and count a cache hit; otherwise run the agent and `Write` its JSON there (`mkdir -p tmp/audit/cache` first). A changed method, file or skill automatically changes the key, so stale reuse is impossible; the `--fix` re-audits therefore only pay for files the Builder changed. Never cache House, Builder or mechanical results.
5. Record `COST_SUMMARY`: files audited / skipped (trivial, cap, no component), agent calls made, cache hits.

## Phase 0.9 — Mechanical checks (you do this; skipped only with `--no-checks`)
Run the deterministic tools BEFORE any agent fan-out: their results are facts, they cost almost nothing, and they let agents skip what a tool already proves. This phase never edits source files. Run each command in the FOREGROUND with the Bash tool's `timeout` parameter (up to 600000 ms), from `ROOT`, with `env -u BUNDLE_GEMFILE LANG=en_US.UTF-8` when the shell exports something else, on the selected files only:
1. **Style:** `bundle exec rubocop <selected .rb files>`. Report offenses per file:line. NEVER pass `-a`/`-A`.
2. **Gem gate:** `ruby .claude/scripts/gem/gem_check.rb --gem-dir .` (the `GEM_GATE` of Phase 0; run once).
3. **Tests:** plain suite files mapped by `TEST_COVERAGE_MAP` plus the changed test files: one `bundle exec rake test TEST=<comma-separated files>` (never several files after `ruby -Itest -Ilib`: only the first would run); `bundle exec rake test:engine` when an engine, generator or rake file changed; `bundle exec rake test:tooling` when `.claude/scripts/**` changed; `bundle exec ruby -Itest -Ilib test/public_api_test.rb` when `lib/**` changed; `bundle exec rake llms:check` when a component signature, YARD doc or controller `static values` changed. Browser tests (`bin/test-js`) and the parity gates are NOT run here: report them `SKIPPED(browser)` and name the tests/scenarios the change needs, so `/work` runs them as the item's gates. Report failures with test name, file:line and message, and say plainly if nothing could be mapped.
4. **Docs and tooling docs:** `bin/smoke --docs` when README or `docs/**` changed (offline); `ruby .claude/scripts/shadcn/command_lint.rb` when `.claude/commands/**`, `.claude/agents/**` or `.ai/skills/**` changed.
5. **Wiring and coverage:** already computed in Phase 0 step 6 (`STIMULUS_WIRING`, `TEST_COVERAGE_MAP`, `API_SURFACE`, `DOCS_PARITY`); merge them here.
Output a `MECHANICAL_CHECKS` block: per tool `PASS|FAIL|SKIPPED(reason)` plus the offenses/failures, truncated to 60 lines each. Rules:
- A failing tool NEVER stops the pipeline (the agents still run and the report stays complete), but every failure becomes a ledger finding with `source: mechanical`, `rule: <tool>` (e.g. `rubocop Style/GuardClause`, `gem_check GEM_RAILS_REFERENCE`, `minitest <test name>`, `llms:check drift`), severity `High` for test/gem-gate failures and `Medium` for style, and is MANDATORY when it lies in IN_SCOPE code (new files, touched methods, changed lines; classify by file:line against Phase 0.7). Offenses in untouched code are `PRE_EXISTING_DEBT`.
- Pass `MECHANICAL_CHECKS` to House, and to every Brick/Room prompt for the files it mentions as `<MECHANICAL for FILE>` with the offenses for that file, with the instruction: "Do not re-report these; spend effort on what tools cannot see."
- A red test suite or gem gate caps the verdict: House may not issue `PASS` while an IN_SCOPE test or gem-gate failure is open.

## Phase 1 — Bricks (Map, parallel per method)
1. Ruby: extract each `def … end` (`Read` + `Grep`) — only TOUCHED_METHODS of MODIFIED files plus all methods of NEW files (`--wide`: all). For Phlex classes this includes `view_template` and its helper methods; for `Base` the merge helpers and the generator hook.
2. ONE `Agent` call PER METHOD, all in the SAME parallel block, prompt = `<SKILL_FILES>` + `<SCOPE>`/touched line + `FILE: <path>\nMETHOD:\n<source>\nReturn JSON only.` → `brick-method-auditor`. Expect `method_name, health_score, time_complexity, space_complexity, smells, refactored_code` (+ `skills_loaded, skills_failed, pre_existing_debt`).
3. Unparseable output: retry once with "JSON only, no fences"; still bad ⇒ record `health_score: 0, smells: ["Brick agent returned unparseable output"]` and continue.

## Phase 2 — Rooms and Stimulus files (per file, parallel)
All files in ONE block, each prompt with its `<SKILL_FILES>` + `<SCOPE>`:
- Ruby (and `test/**` / tooling files with `BRICK_AGENT_REPORTS: []`): `<SKILL_FILES>\nRAW_CLASS_CODE:\n<full source>\nBRICK_AGENT_REPORTS:\n<JSON array>\nReturn JSON only.` → `room-class-auditor`. Expect `class_name, structural_health_score, primary_responsibility, srp_violations, encapsulation_smells, brick_synthesis, refactoring_strategy, refactored_class_skeleton` (+ `caller_changes, skills_loaded, skills_failed, pre_existing_debt`).
- Stimulus: `<SKILL_FILES>\nRAW_FILE_CODE:\n<full source>\nWIRING:\n<STIMULUS_WIRING excerpt + the part that renders it (data attributes it emits) + the spec's Behavior section>\nReturn JSON only.` → `stimulus-controller-auditor`. Expect `controller_name, health_score, lifecycle_smells, wiring_smells, a11y_smells, refactoring_strategy, refactored_controller` (+ `skills_loaded, skills_failed, pre_existing_debt`).
Mark todos complete as each returns.

## Phase 2.5 — Slices (per component, needs Rooms)
1. Slice = one component: its root and parts + the controller + the primitives it imports + `dev/port/specs/<name>.md` + `dev/port/scenarios/<name>.json` + `test/chadcn/<name>_test.rb` + `test/javascript/<name>.test.mjs`. Single-file slices still run (missing parts = `MISSING`).
2. ONE `view-slice-auditor` call per slice, parallel, prompt = `<SKILL_FILES>(union, max 5)\nSLICE_FILES:\n<paths>\nPART_ROOMS:\n<room JSONs or MISSING>\nSTIMULUS_REPORTS:\n<JSONs or MISSING>\nSPEC_EXCERPT:\n<API + Structure + Behavior sections, or MISSING>\nSCENARIO_IDS:\n<ids or MISSING>\nTEST_FILES:\n<paths or MISSING>\nWIRING:\n<STIMULUS_WIRING lines for this component>\nReturn JSON only.` Expect `slice_name, slice_health_score, contract_shape, contract_violations, wiring_smells, room_synthesis, refactoring_strategy, refactored_contract_skeleton`.
3. Fail the slice on: a target/value/action rendered but undeclared or declared but never rendered, a kwarg without its value (or the reverse), a spec section the code contradicts, a new variant/state without a scenario, a primitive re-implemented in the controller, a hand-written DX helper, an `aria-*` id that resolves to nothing before JS.

## Phase 3 — House (Reduce, once)
0. Collect INTEGRATION_ANCHORS yourself with `Read`/`Grep` (even for files not in the diff): `config/importmap.rb` pins; `lib/chadcn/engine.rb` initializers (loader setup, importmap, assets, tasks); the generator templates and the doctor checks that mirror a changed asset or pin; `app/assets/tailwind/chadcn/engine.css` `@source` and imports; `dev/port/specs/<name>.md` and `scenarios/<name>.json` for every touched component; the README/docs sections that document a touched kwarg or part; `test/fixtures/public_api.txt` and the `CHANGELOG.md` `Unreleased` section; `llms-full.txt` for a touched signature. Missing anchor ⇒ write `MISSING: <path> (assumed <X>)`.
1. Call `principal-architect` ONCE with `<HOUSE_SKILLS>` (macro skill bodies, trimmed to 120 lines, "enforce as architecture law; never re-litigate micro skills") plus:
   - `FEATURE_TICKET`, `RUBY_ROOM_REPORTS`, `RUBY_BRICK_REPORTS` (trim long `refactored_code`), `STIMULUS_REPORTS`, `SLICE_REPORTS`
   - `HOUSE_ONLY_DIFF` (gemspec, Gemfile, importmap, assets, templates, docs, CHANGELOG, workflows; packaging and secrets), `INTEGRATION_ANCHORS`, `RAW_CODE`
   - `MECHANICAL_CHECKS` (Phase 0.9 tool results), `TEST_COVERAGE_MAP`, `STIMULUS_WIRING`, `API_SURFACE`, `DOCS_PARITY`, `GEM_GATE`
   - `SCOPE_MAP` (or `wide`) and `PRE_EXISTING_DEBT` — House scores and issues the VERDICT on IN_SCOPE findings only; debt is listed separately and never lowers the Scorecard. House also flags SCOPE CREEP (any proposed fix larger than the ticket requires).
   - Instruction: "You are House final (the chadcn gem: Phlex + Stimulus + optional Rails integration). Synthesize ALL tracks. Verify part → data attributes → controller → primitives → pin/copy, spec → code → scenario → test, and the public API promise (snapshot, CHANGELOG, docs, llms) per touched component or integration seam. Output Executive Summary, Scorecard, Forensic Audit (incl. Integration Verdict), Enterprise Fix, VERDICT."
2. Do not re-score the House output; it is published verbatim inside the Phase 5 report.
3. If `$ARGUMENTS` has `--fix` AND (`VERDICT: FAIL`, `NEEDS-REWORK`, or `PASS` with OPEN mandatory ledger items) ⇒ Phase 4. Otherwise go straight to Phase 5. Never edit code in audit-only mode. In every mode the ONLY files you write are under `tmp/audit/`.

## Findings Ledger & Conformance Gate (maintain from Phase 1 on)
"Works", "low risk" and "keeps the PR small" never excuse a skill violation in code that belongs to the change. Scope-limiting protects UNTOUCHED code only.
1. **Ledger.** Every finding gets an id (`F-001…`): `source` (brick|room|stimulus|slice|house|mechanical), `file#method`, `rule` (skill + rule, e.g. `ruby-gem-conventions R2`), `scope` (IN_SCOPE|PRE_EXISTING), `severity`, `status` (OPEN|FIXED|DEFERRED(code)|ADVISORY). A finding with NO cited rule, or one citing a tombstoned rule, is `ADVISORY`.
2. **Feature code** = NEW files + touched methods + changed class-level lines + whatever the fix creates or moves. A finding there that cites a skill rule is **MANDATORY** at any severity. Callers inside the same branch are feature code too.
3. **Allowed deferral codes** (each needs a one-line justification you verify with `Read`/`Grep`): `PRE_EXISTING`, `PRODUCT_DECISION`, `UPSTREAM_TICKET:<id>`, `NEEDS_OUT_OF_SCOPE_EDIT` (list exact files; ends in `HUMAN_REQUIRED`), `RULE_DISPUTED` (quote evidence). NOT valid: "preference", "style", "low risk", "works", "keeps the PR small", "would require a refactor", "callers/specs here rely on it", "scope creep" (for in-scope code), "extra files" (extractions create new files), "the auditor's suggestion".
4. **Reject invalid deferrals** (from House, the Builder or yourself): they return to OPEN and go to the Builder as mandatory.
5. **Conformance gate.** PASS = `VERDICT: PASS` AND every MANDATORY item FIXED or allowed-deferred AND no IN_SCOPE `mechanical` failure open (rubocop, gem gate, tests, llms drift). With `--fix`, OPEN mandatory items force another iteration (N < 3); out of iterations ⇒ `HUMAN_REQUIRED`, never PASS. Audit-only reports `CONFORMANCE: FAIL (n mandatory open)`.
6. **Final report:** see Phase 5 (ledger table, `PRE_EXISTING_DEBT`, TL;DR, persisted files).

## Phase 4 — Remediation Loop / Actor-Critic (ONLY with `--fix`)
Max 3 iterations (initial audit = 0). Pass bar: min Scorecard >= 8 AND `VERDICT: PASS`. Stay in one session.
0. **Scope guard.** Before the first Builder call: `git stash create` → `SNAP` (a read-only snapshot SHA); record the SCOPE_MAP as the EDIT_MANIFEST. The Builder may edit ONLY: NEW files, TOUCHED_METHODS bodies, CLASS_LEVEL_CHANGED_LINES, files it CREATES to receive extracted in-scope code (a part class, a `Base` helper, a primitive, a doctor check, a generator step, a test, a scenario, a CHANGELOG line, a docs fence), additive edits that append a method/constant, and minimal call-site/test edits a contract change forces (listed in `caller_changes`). PRE_EXISTING code is off limits: no renames, reordering, "while I'm here" cleanups, whole-file rewrites, or formatter runs.
1. Iteration N/3: send ONE `senior-rails-dev` call with the full payload:
```
ITERATION: N/3
FILES IN SCOPE: <scope>
1. MACRO DIRECTIVE (always wins conflicts):
ARCHITECT_FEEDBACK: <House Danger + Integration Verdict + Slice contract violations>
ENTERPRISE_FIX: <House Enterprise Fix verbatim>
2. FILE-LEVEL PATCHES: <Room/Stimulus/Slice JSONs with score < 10: refactoring_strategy + skeleton>
3. METHOD-LEVEL PATCHES: <Brick JSONs with score < 10: smells + refactored_code verbatim>
SKILL_FILES: <union of the paths used in Phases 1-2.5>
4. CALLER CHANGES (mandatory): <all `caller_changes` entries>
RULES: implement §1 exactly; apply §2+§3 unless they conflict with §1; update every §4 caller in the same change; minimal diff; update/add Minitest tests, scenarios, the public API snapshot and the CHANGELOG entry as the contract-change discipline requires; run the validation loop (plain suite files, `rake test:engine` when integration files changed, rubocop on touched files, the gem gate); return git diff stat + diff + `EDITED:` list.
```
1b. **Verify scope.** `git diff -U0 SNAP -- <files>`: every hunk's old range must lie inside a TOUCHED method, changed class-level line, NEW file, or approved `caller_changes`. Otherwise send the Builder ONE correction ("revert these hunks: <file:range>; re-apply inside scope or report DEFERRED_SCOPE"); a second violation ends with `HUMAN_REQUIRED`. Reject a diff disproportionate to the findings.
2. Re-run Phase 0.9 yourself on the files the Builder touched (never trust the Builder's own green run), then re-run the FULL Critic pipeline on every file the Builder modified or created: Bricks → Rooms/Stimulus → Slices → House. A "condensed" House-only re-audit is FORBIDDEN. Before publishing, self-check that every file in `git diff --name-only` since the last audit has a fresh Brick+Room JSON; record `reaudit_coverage: <re-audited>/<modified>` (must be 100%).
3. **Mandatory sweep.** If House says PASS but OPEN mandatory items remain and N < 3, consume the next iteration on ALL of them (security and public API promise first). `PRE_EXISTING_DEBT` never triggers an iteration.
4. Gate met ⇒ go to Phase 5 (final House review + ledger), close todos, state `iterations_used: N` and every `DEFERRED(code)`. N = 3 with mandatory items open ⇒ `HUMAN_REQUIRED`.
5. Still FAIL after 3 fixes ⇒ stop; Phase 5 publishes the last House review + `HUMAN_REQUIRED: <top 3 blocking findings + files>`; ask for direction. Never commit or push and never force anything — output the diffs only.

## Phase 5 — Report and persistence (you do this, always, after Phase 3 or Phase 4)
1. **TL;DR block FIRST** (max 10 lines): `VERDICT`; `CONFORMANCE: PASS|FAIL (n mandatory open)`; mechanical status (rubocop / gem gate / tests / llms / docs; browser gates `SKIPPED(browser)` with the tests named); the single highest-risk finding (id, file:line, one sentence); `WORKSPACE_WARNINGS`; `COST_SUMMARY` (audited / skipped / calls / cache hits); iterations used when `--fix` ran.
2. **Findings grouped by file, in FIX ORDER.** Order the work the developer should do: (1) security, the gem gate, failing tests; (2) cross-file contracts (part ↔ controller ↔ primitives ↔ pins, spec ↔ scenario ↔ test, public API snapshot ↔ CHANGELOG ↔ docs ↔ llms); (3) layer placement and structure (Rails in core, behavior in Ruby, extractions into `Base` or a primitive); (4) naming, style, advisory items. Under each file list its OPEN mandatory items (`F-id | rule | line | one-line fix`), then DEFERRED items with their code.
3. Then the full House review verbatim, the ledger table (id | rule | where | status) and `PRE_EXISTING_DEBT`.
4. **Persist** (`mkdir -p tmp/audit/<slug>`; `slug` = sanitized branch name plus the short head SHA; `tmp/` is git-ignored): `Write` `report.md` (steps 1-3) and `ledger.json` (every finding: id, source, file, method, rule, scope, severity, status, deferral code). Then write the machine-readable receipt with the FINAL House scorecard (the five /10 numbers of the last audit, not an earlier iteration): `ruby .claude/scripts/audit_receipt.rb write --scores architecture=<n>,clean_code=<n>,scalability=<n>,security=<n>,testability=<n> --verdict <PASS|NEEDS-REWORK|FAIL> --mandatory-open <open MANDATORY ledger items> --iterations <used> --out tmp/audit/<slug>/scorecard.json`. It fingerprints the code as it is now (including uncommitted edits the Builder made), so run it after the last fix and before any further edit. Callers such as `/work` pass this file to `work_board.rb advance --audit-receipt`. If a previous `ledger.json` exists for the same slug, read it first and add a **Since last run** section: findings now FIXED, NEW, and STILL OPEN (matched by file + rule).
5. **Rule statistics:** append ONE JSON line to `tmp/audit/rule-stats.jsonl` — `{"at":"<ISO date>","scope":"<slug>","skills_loaded":[…union of skills_loaded…],"rules_cited":["ruby-gem-conventions R2",…,every distinct cited rule…]}` (use `Write` of the whole file after reading the existing one; keep prior lines). `ruby .claude/scripts/audit_rule_coverage.rb` reports rules never cited and skills never loaded, to tune vague rules and the router.
6. **`--pr-comment`:** also `Write` `tmp/audit/<slug>/pr-comment.md`: verdict line, then the OPEN mandatory items grouped by file with `file:line` and the fix, then deferrals and debt in a collapsed `<details>` block. Never post it anywhere; tell the user the path.

## Rules
- Parallelism = multiple `Agent` calls in ONE block. Never run methods sequentially.
- Context: Brick/Room/Slice JSONs are the compressed matrix; never paste thousands of lines into House. Reuse prior JSONs across iterations; re-audit only changed code.
- Cost: Bricks `haiku`, Rooms/Stimulus/Slices `sonnet`, House `opus`, Builder `sonnet`. Leaf agents are read-only (Read/Grep/Glob).
- Triage and cache (Phase 0.8) decide what agents see; reuse cached JSON only when the key matches.
- Mechanical tools run first (Phase 0.9) and their output is fact: agents never re-litigate it.
- One repository, one track: every file is gem code or its tests, tooling or docs; there is no host application, no engine of another product and no second checkout to discover. Component parity (classes, DOM, behavior, theme) is `/shadcn-audit`'s job: this audit judges code quality, contracts and the gem's promises.
- Diff-scoped by default; audit-only by default; `--fix` edits code max 3 iterations then human fallback. You never edit code yourself.
