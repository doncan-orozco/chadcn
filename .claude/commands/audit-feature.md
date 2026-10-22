---
description: Forensic Map-Reduce feature audit (Bricks -> Rooms -> Slices -> House) for Rails 8 + Phlex + Stimulus. Add --fix for the Actor-Critic remediation loop.
argument-hint: "[branch|range|files] [--fix] [--wide] [--no-checks] [--no-cache] [--pr-comment] [ticket text or @ticket.md]"
allowed-tools: Agent, Read, Grep, Glob, TodoWrite, Bash(git:*), Bash(bin/rubocop:*), Bash(bin/brakeman:*), Bash(bin/rails test:*), Bash(shasum:*), Bash(mkdir -p tmp/audit:*), Edit(tmp/audit/**)
---

# Map-Reduce Feature Audit: Bricks, Rooms, Slices, House (Rails + Phlex + Stimulus)

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

Stack facts every agent must assume: Ruby 4.0 / Rails 8.1 / SQLite (Solid Queue/Cache/Cable), Phlex views (`app/views`, `app/components`), Hotwire (Turbo + Stimulus via importmap), Tailwind, dry-operation/dry-monads/dry-validation in `app/concepts/**`, Pundit, Mobility + route_translator i18n (EN + ES mandatory), Minitest + Capybara/Cuprite, RuboCop omakase. **Workspace:** the product is TWO repos that often change together for one feature: the HOST (`papyro`, this repo: public site, auth, models/schema, locales, fixtures, DB) and the Studio ENGINE (`papyro_studio`, sibling repo `../papyro_studio`, a mounted Rails engine on the `studio` subdomain: authoring controllers, `Studio::` concepts/components/policies, Stimulus controllers, engine routes). Both are in scope and fully auditable; the host loads the engine through a local bundle override (`.bundle/config` → `BUNDLE_LOCAL__PAPYRO_STUDIO`). The engine has NO dummy app: its tests boot the host (`bin/rails test ../papyro_studio/test/...` run FROM the host root). The host owns schema, models, auth (`Current.user`, shared-domain session cookie), fixtures and ALL locale files; the engine consumes them. Skills live only in the host (`.ai/skills`) and apply to both repos.

## Phase 0 — Collect scope + route by track (you do this)
Auto-detect, never ask unless truly ambiguous:
- **A) Explicit files** → use directly via `Read`.
- **B) Branch or range** (`feature/x`, `origin/main...HEAD`) → resolve via git. Bare branch = that branch vs merge-base with main.
- **C) Empty / ticket text only** → ask for files, branch, or range. Do not guess.

Branch resolution (READ-ONLY git; never edit/commit/push):
1. **Discover the workspace.** `HOST` = `git rev-parse --show-toplevel`. `ENGINE` = the path in `.bundle/config` `BUNDLE_LOCAL__PAPYRO_STUDIO` if present, else `<HOST>/../papyro_studio`; it exists only if that directory is a git repo. Identify every file as `host:<path>` or `studio:<path>` and run every git command as `git -C <repo> …`. Resolve each repo independently: `git -C <repo> fetch origin --quiet; git -C <repo> branch --show-current; git -C <repo> merge-base <base> <head>; git -C <repo> diff --name-only <base>...<head>; git -C <repo> status --porcelain=v1; git -C <repo> diff --name-only; git -C <repo> diff --cached --name-only`. `<base>` defaults to `origin/main` (fallback `main`); `<head>` is the requested branch or HEAD (a bare branch name is looked up in BOTH repos; a repo where it does not exist and that has no uncommitted changes is out of scope). Include the engine only when it has changes in range or uncommitted work, or when the user passed engine paths / `--studio`. Record per repo: base SHA, head SHA, branch, committed files, PLUS uncommitted files (staged, unstaged, untracked; `.rb/.js/.erb/.yml` only) labeled UNCOMMITTED. If the repos are on different branches, say so in the report.
2. Route every changed file into exactly ONE track:
   - **Ruby track:** `app/**/*.rb`, `lib/**/*.rb` in either repo (controllers, `app/concepts/**`, models, policies, jobs, mailers, channels, helpers, Phlex views/components) → Brick (`brick-method-auditor`) + Room (`room-class-auditor`). Engine equivalents: `studio:app/controllers/papyro_studio/**` = controllers, `studio:app/concepts/studio/**` = operations/presenters, `studio:app/components/studio/**` and `studio:app/views/**` = Phlex, `studio:app/policies/studio/**` = Pundit.
   - **Stimulus track:** `app/javascript/**/*.js` in either repo (engine: `studio:app/javascript/controllers/studio/**`; except `importmap`/vendor) → ONE `stimulus-controller-auditor` call per file (it covers brick + room; controllers are small).
   - **Gem track:** files under `gems/**` (or, in a standalone gem repo, anything below a directory with a `*.gemspec`): Ruby (`lib/**`, `app/**`) -> Brick + Room with skills `ruby-gem-conventions` + `naming-conventions` (generic rules; its library exception applies) INSTEAD of the Papyro layer skills (controller, operation-pattern, presenter-pattern, models, pundit-auth, i18n do not apply); JS -> `stimulus-controller-auditor` with `radix-stimulus` (skip the Papyro wiring check; identifiers are `chadcn--*`); `*.gemspec`, `Gemfile`, `CHANGELOG.md`, `LICENSE`, `THIRD_PARTY_NOTICES*`, `lib/**/{engine,railtie}.rb`, `lib/generators/**`, `lib/tasks/**` -> House-only; `gems/**/test/**` -> Room only (skill `testing`). The dev kit (`gems/**/dev/**`) is audited by `/shadcn-audit`, not here.
   - **Slice (derived):** group changed Phlex views/components, their presenter, the Stimulus controllers they reference (`data-controller`), Turbo Frame ids and i18n keys into one slice per page/feature folder → `view-slice-auditor` (Phase 2.5).
   - **House-only:** `config/routes.rb` (both repos), `studio:config/importmap.rb`, `studio:*.gemspec`, `studio:lib/**` (engine.rb autoload/importmap initializers), `config/locales/**/*.yml`, `db/migrate/**`, `db/schema.rb`, `app/assets/**` (CSS/Tailwind), `Gemfile*`, `config/importmap.rb`, `.github/**`, `Dockerfile`, `.kamal/**`, and everything else → NO Brick/Room; excerpt straight to House (secrets, config, migrations safety, cross-boundary).
   - **Tests:** `test/**/*.rb` in either repo → Room only (no Bricks), skill `testing`. Engine tests: `studio:test/{controllers,policies,concepts}/studio/**`; engine system tests (if any) `studio:test/system`; host system tests for Studio flows `host:test/system/studio/**`.
3. Empty list → stop: "No auditable changes in <base>...<head>".
4. If >15 Brick/Room files → audit the 15 largest by `git diff --stat`, list the rest as skipped, ask whether to run a second pass. House-only files never count toward the cap.
5. Build `RAW_CODE` yourself, per repo: `git -C <repo> diff <base>...<head> -- <selected + House-only files>` plus `git -C <repo> diff` / `--cached` for uncommitted files, truncated per file to 400 lines (House-only: 100), labeled UNCOMMITTED when applicable.
6. Compute these mechanical checks yourself with `Grep`/`Glob` (cheap, deterministic) and keep them for House:
   - `GEM_GATE` (only when the Gem track has files): run `ruby .claude/scripts/gem/gem_check.rb --gem-dir <gem dir> --host-dir .` per touched gem and keep its JSON verbatim for House; every finding is MANDATORY and cites `ruby-gem-conventions R<n>` (the skill maps each finding code to its rule in square brackets). For gem Ruby files, `TEST_COVERAGE_MAP` mirrors `lib/x.rb` to `test/x_test.rb` inside the gem, and `I18N_PARITY` / `STIMULUS_WIRING` against the host are skipped.
   - `TEST_COVERAGE_MAP`: for each changed `app/**/*.rb` file, does a matching test exist and is it in the diff? Host: mirror path under `host:test/`. Engine: `app/controllers/papyro_studio/foo_controller.rb` ↔ `studio:test/controllers/studio/foo_controller_test.rb`; `app/policies/studio/x.rb` ↔ `test/policies/studio/x_test.rb`; `app/concepts/studio/**` ↔ `test/concepts/studio/**`. Mark `MISSING` otherwise (`testing` skill requires concept coverage).
   - `I18N_PARITY`: every `t("…")` key added in the diff exists in BOTH `host:config/locales/en*` and `es*` (keys used by ENGINE code are translated in the HOST); list gaps. Also `\bt\(["']\.` relative keys and hardcoded user-facing strings in views/components/controllers/operations.
   - `STIMULUS_WIRING`: every `data-controller="x"` / `data: { controller: … }` in changed views has a matching `*_controller.js` in `host:app/javascript/controllers/` or `studio:app/javascript/controllers/studio/` (engine identifiers are namespaced, e.g. `studio--articles--autosave`; verify the pin in `studio:config/importmap.rb` and host registration), and vice versa for changed controllers.
7. **Workspace warnings** (cheap, report them even when everything else passes; they are facts, not findings): (a) both repos in scope on DIFFERENT branches; (b) engine commits not on its remote (`git -C <ENGINE> log --oneline origin/<branch>..HEAD`), or uncommitted engine changes, while the host `Gemfile.lock` records a different `papyro_studio` revision (compare `grep -A4 papyro_studio Gemfile.lock` with `git -C <ENGINE> rev-parse HEAD`): the local bundle override hides this, but CI and other machines will build the OLD engine until the engine is pushed and `bundle update papyro_studio` is run; (c) host changes that call engine code (or the reverse) while only one repo has a branch/diff. Record them as `WORKSPACE_WARNINGS`.
8. Create a `TodoWrite` list (items prefixed `host:` / `studio:`): one item for mechanical checks, one per Ruby file (Brick+Room), per Stimulus file, per slice, one for House-only, one for House. Put each repo's `base...head` SHAs in the title.

## Phase 0.5 — Skill Matrix Router (you do this, once per file)
Skills are plain Markdown under `S = <HOST>/.ai/skills` and apply to BOTH repos (also exposed natively through the host `.claude/skills` symlink, but leaf agents load them by ABSOLUTE PATH with `Read`, never through the Skill tool). Resolve by path AND content (`Glob`/`Grep`; do not read bodies) and pass absolute paths in a `<SKILL_FILES>` block. Bricks inherit their file's Room skills.

Matrix (`Read` only on match):
- `naming-conventions`: ALL `*.rb`, `*.js` (both repos) — always.
- `controller`: `app/controllers/**` (host and `studio:app/controllers/papyro_studio/**`); for engine controllers or any file crossing the mount/session boundary also load `architecture/references/host-coupled-engine-pattern.md`.
- `pundit-auth`: `app/policies/**`; or controllers/operations containing `authorize|policy_scope|Pundit|policy_class`.
- `operation-pattern`: `app/concepts/*/operation/**`, `app/concepts/*/contract/**` (both repos).
- `jobs-and-mailers`: `app/jobs/**`, `app/mailers/**`, mailer views, and `app/services/**` (external clients such as `GeminiClient`) in either repo.
- `query-object-pattern`: `app/concepts/*/query/**`; or controllers/presenters whose body matches `/Query|\.call\(.*filters/`.
- `presenter-pattern`: `app/concepts/*/presenter/**`; and for any view/component whose body references a `Presenter`.
- `models`: `app/models/**`, `app/validators/**`, `app/concepts/*/validator/**`; add `i18n` when the model has `translates`/Mobility.
- `ruby-gem-conventions`: every file of the Gem track (Ruby, JS, gemspec, CSS in the gem), plus `gems/**` House-only files.
- `phlex-view-pattern`: `app/views/**`, `app/components/**` (except `components/ui/**`; the shadcn port lives in the Gem track), `app/assets/stylesheets/**` in either repo. Add `accessibility` for views/components.
- `stimulus`: `app/javascript/**` in either repo (+ `accessibility`).
- `design-system`: `app/components/ui/**` (legacy) and the shadcn port in `**` (with `shadcn-port` + `radix-stimulus`; the gem track also loads `ruby-gem-conventions`; for component parity prefer `/shadcn-audit`, which is gate-based).
- `i18n`: any Ruby file matching `/\bt\(|I18n|Mobility|translates/`, all views/components, `config/locales/**`.
- `seo`: `app/helpers/seo_helper.rb`, `config/sitemap.rb`, or content `/hreflang|canonical|og:|sitemap|friendly_id/`.
- `sqlite`: `db/migrate/**`, `db/*schema*` (House-only; never Bricks).
- `testing`: `test/**`.
- `realtime`: `app/channels/**`.
- House macro skills (pasted bodies, once): `architecture` (always), `controller` (if controllers/routes touched), `pundit-auth` (if auth touched), `i18n` (if locales/user text touched), `sqlite` (if migrations touched), `testing` (if tests or coverage gaps) — each trimmed to 120 lines. House never receives micro skills (no double jeopardy with Rooms).

Prompt block:
```
<SKILL_FILES>
<REPO>/.ai/skills/naming-conventions/SKILL.md
<REPO>/.ai/skills/operation-pattern/SKILL.md
</SKILL_FILES>
(Read every listed file first; enforce all of them as law; cite `<skill> R<n>` (the numbered Quick Rules at the top of each skill) for every smell; report skills_loaded / skills_failed.)
```
Caps: Bricks max 3 skills (naming-conventions first, then layer skills by specificity; Bricks read only the first 150 lines of each skill — the leading rules); Rooms/Slices/Stimulus max 5, full files. Budget guard: keep `naming-conventions` + the most specific layer skills and name dropped ones in the prompt footer. `Glob` each path before dispatch; missing ⇒ drop and add `SKILL_MISSING: <name>`. If a leaf reports `skills_failed`, re-dispatch that call once, then surface it in the report.

## Phase 0.7 — Scope Map (you do this; skipped only with `--wide`)
Ship safe, reviewable code: the ticket changed one part, so audit and fix stay on that part; legacy around it is reported as debt, never rewritten.
1. For each in-scope file get status and changed lines in WORKING-TREE coordinates, using the file's own repo: `git -C <repo> diff -U0 <base>...<head> -- <file>` plus `git -C <repo> diff -U0 -- <file>` and `git -C <repo> diff -U0 --cached -- <file>` (the `+c,d` side). Status `A`/untracked ⇒ `NEW_FILE` (whole file in scope).
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
2. **Slices only when UI changed:** run `view-slice-auditor` for a slice only if it contains at least one changed view, component, presenter or Stimulus file. Backend-only changes skip Phase 2.5 and say so.
3. **Brick size cap:** a method longer than 120 lines is sent as its signature + the touched range ±15 lines, marked `TRUNCATED: true`; the Room sees the full file.
4. **Result cache** (skip entirely with `--no-cache`): for each Brick/Room/Stimulus/Slice call compute `KEY = shasum(<agent name> + <file or method source> + <git hash-object of every SKILL_FILES entry>)` with `Bash(shasum)`. If `tmp/audit/cache/<KEY>.json` exists, reuse that JSON verbatim and count a cache hit; otherwise run the agent and `Write` its JSON there (`mkdir -p tmp/audit/cache` first). A changed method, file or skill automatically changes the key, so stale reuse is impossible; the `--fix` re-audits therefore only pay for files the Builder changed. Never cache House, Builder or mechanical results.
5. Record `COST_SUMMARY`: files audited / skipped (trivial, cap, backend-only), agent calls made, cache hits.

## Phase 0.9 — Mechanical checks (you do this; skipped only with `--no-checks`)
Run the deterministic tools BEFORE any agent fan-out: their results are facts, they cost almost nothing, and they let agents skip what a tool already proves. This phase never edits source files (the test run only touches the test database). Run each command in the FOREGROUND with the Bash tool's `timeout` parameter (up to 600000 ms), from the HOST root, on the selected files only:
1. **Style:** `bin/rubocop <selected .rb files, host and engine, absolute paths>`. RuboCop picks each file's nearest config, so engine files use the engine's `.rubocop.yml`. Report offenses per file:line. NEVER pass `-a`/`-A`.
2. **Security:** `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` when any controller, view, route, param handling or raw output changed. Brakeman scans the host app only; engine controllers are covered by the House security review, say so in the report.
3. **Tests:** `bin/rails test <changed test files + the tests found by TEST_COVERAGE_MAP, host paths and ../papyro_studio/test/... paths>` (system tests are NOT run here). Report failures with test name, file:line and message, and say plainly if nothing could be mapped.
4. **Locales/wiring:** already computed in Phase 0 step 6 (`I18N_PARITY`, `STIMULUS_WIRING`, `TEST_COVERAGE_MAP`); merge them here.
Output a `MECHANICAL_CHECKS` block: per tool `PASS|FAIL|SKIPPED(reason)` plus the offenses/failures, truncated to 60 lines each. Rules:
- A failing tool NEVER stops the pipeline (the agents still run and the report stays complete), but every failure becomes a ledger finding with `source: mechanical`, `rule: <tool>` (e.g. `rubocop Style/GuardClause`, `brakeman SQL Injection`, `minitest <test name>`), severity `High` for test/security failures and `Medium` for style, and is MANDATORY when it lies in IN_SCOPE code (new files, touched methods, changed lines; classify by file:line against Phase 0.7). Offenses in untouched code are `PRE_EXISTING_DEBT`.
- Pass `MECHANICAL_CHECKS` to House, and to every Brick/Room prompt for the files it mentions as `<MECHANICAL for FILE>` with the offenses for that file, with the instruction: "Do not re-report these; spend effort on what tools cannot see."
- A red test suite caps the verdict: House may not issue `PASS` while an IN_SCOPE test failure is open.

## Phase 1 — Bricks (Map, parallel per method)
1. Ruby: extract each `def … end` (`Read` + `Grep`) — only TOUCHED_METHODS of MODIFIED files plus all methods of NEW files (`--wide`: all). For Phlex classes this includes `view_template` and its helper methods.
2. ONE `Agent` call PER METHOD, all in the SAME parallel block, prompt = `<SKILL_FILES>` + `<SCOPE>`/touched line + `FILE: <path>\nMETHOD:\n<source>\nReturn JSON only.` → `brick-method-auditor`. Expect `method_name, health_score, time_complexity, space_complexity, smells, refactored_code` (+ `skills_loaded, skills_failed, pre_existing_debt`).
3. Unparseable output: retry once with "JSON only, no fences"; still bad ⇒ record `health_score: 0, smells: ["Brick agent returned unparseable output"]` and continue.

## Phase 2 — Rooms and Stimulus controllers (per file, parallel)
All files in ONE block, each prompt with its `<SKILL_FILES>` + `<SCOPE>`:
- Ruby (and `test/**` files with `BRICK_AGENT_REPORTS: []`): `<SKILL_FILES>\nRAW_CLASS_CODE:\n<full source>\nBRICK_AGENT_REPORTS:\n<JSON array>\nReturn JSON only.` → `room-class-auditor`. Expect `class_name, structural_health_score, primary_responsibility, srp_violations, encapsulation_smells, brick_synthesis, refactoring_strategy, refactored_class_skeleton` (+ `caller_changes, skills_loaded, skills_failed, pre_existing_debt`).
- Stimulus: `<SKILL_FILES>\nRAW_FILE_CODE:\n<full source>\nWIRING:\n<STIMULUS_WIRING excerpt + the views that reference it>\nReturn JSON only.` → `stimulus-controller-auditor`. Expect `controller_name, health_score, lifecycle_smells, wiring_smells, a11y_smells, refactoring_strategy, refactored_controller` (+ `skills_loaded, skills_failed, pre_existing_debt`).
Mark todos complete as each returns.

## Phase 2.5 — Slices (per page/feature folder, needs Rooms)
1. Slice = changed Phlex view/components of one folder (e.g. `app/views/studio/articles/index*`) + the presenter it receives + referenced Stimulus controllers + Turbo Frame ids + i18n keys. Single-file slices still run (missing parts = `MISSING`).
2. ONE `view-slice-auditor` call per slice, parallel, prompt = `<SKILL_FILES>(union, max 5)\nSLICE_FILES:\n<paths>\nVIEW_ROOMS:\n<room JSONs or MISSING>\nPRESENTER_ROOM:\n<JSON or MISSING>\nSTIMULUS_REPORTS:\n<JSONs or MISSING>\nFRAME_IDS:\n<frame ids + the controller actions that render them>\nI18N_EXCERPT:\n<I18N_PARITY lines for this slice>\nReturn JSON only.` Expect `slice_name, slice_health_score, contract_shape, contract_violations, wiring_smells, room_synthesis, refactoring_strategy, refactored_contract_skeleton`.
3. Fail the slice on: logic/queries/CSS-decision/branching on model state inside a view, view reaching around the presenter, `data-controller` with no matching file or declared targets/values missing from markup, Turbo Frame id not matched by a dedicated action response, missing EN/ES key, or controller building HTML.

## Phase 3 — House (Reduce, once)
0. Collect INTEGRATION_ANCHORS yourself with `Read`/`Grep` (even for files not in the diff): (in BOTH repos) `host:config/routes.rb` lines for every touched endpoint (subdomain constraint, `localized` block, the `PapyroStudio::Engine` mount) and `studio:config/routes.rb`; for engine features, the host models, fixtures, `Current`/session handling and locale files they depend on; for host features, any engine route or helper they link to; touching controllers' `authorize`, operation call, render/redirect + status; the operation/contract/query a controller calls; the view/presenter it renders; Turbo Frame/Stream targets; locale files. Missing anchor ⇒ write `MISSING: <path> (assumed <X>)`.
1. Call `principal-architect` ONCE with `<HOUSE_SKILLS>` (macro skill bodies, trimmed to 120 lines, "enforce as architecture law; never re-litigate micro skills") plus:
   - `FEATURE_TICKET`, `RUBY_ROOM_REPORTS`, `RUBY_BRICK_REPORTS` (trim long `refactored_code`), `STIMULUS_REPORTS`, `SLICE_REPORTS`
   - `HOUSE_ONLY_DIFF` (routes, locales, migrations, CSS, config; secrets/safety), `INTEGRATION_ANCHORS`, `RAW_CODE`
   - `MECHANICAL_CHECKS` (Phase 0.9 tool results), `TEST_COVERAGE_MAP`, `I18N_PARITY`, `STIMULUS_WIRING`
   - `SCOPE_MAP` (or `wide`) and `PRE_EXISTING_DEBT` — House scores and issues the VERDICT on IN_SCOPE findings only; debt is listed separately and never lowers the Scorecard. House also flags SCOPE CREEP (any proposed fix larger than the ticket requires).
   - Instruction: "You are House final (full-stack Rails + Phlex + Stimulus). Synthesize ALL tracks. Verify route → controller → authorize → operation → presenter → view → Stimulus/Turbo per endpoint, including the host↔engine seam (mount/subdomain constraint, shared session cookie, engine touching host models/schema only through their public API, no engine migrations, host-owned locale keys present in EN+ES). Output Executive Summary, Scorecard, Forensic Audit (incl. Integration Verdict), Enterprise Fix, VERDICT."
2. Do not re-score the House output; it is published verbatim inside the Phase 5 report.
   Per-repo verdicts: ask House to emit `VERDICT_HOST: PASS|NEEDS-REWORK|FAIL` and `VERDICT_STUDIO: …` (only for repos in scope) immediately before the final `VERDICT:` line, each judged on that repo's IN_SCOPE findings.
3. If `$ARGUMENTS` has `--fix` AND (`VERDICT: FAIL`, `NEEDS-REWORK`, or `PASS` with OPEN mandatory ledger items) ⇒ Phase 4. Otherwise go straight to Phase 5. Never edit code in audit-only mode. In every mode the ONLY files you write are under `tmp/audit/`.

## Findings Ledger & Conformance Gate (maintain from Phase 1 on)
"Works", "low risk" and "keeps the PR small" never excuse a skill violation in code that belongs to the feature. Scope-limiting protects UNTOUCHED code only.
1. **Ledger.** Every finding gets an id (`F-001…`): `source` (brick|room|stimulus|slice|house|mechanical), `file#method`, `rule` (skill + rule, e.g. `controller R2`), `scope` (IN_SCOPE|PRE_EXISTING), `severity`, `status` (OPEN|FIXED|DEFERRED(code)|ADVISORY). A finding with NO cited rule is `ADVISORY`.
2. **Feature code** = NEW files + touched methods + changed class-level lines + whatever the fix creates or moves. A finding there that cites a skill rule is **MANDATORY** at any severity. Callers inside the same branch are feature code too.
3. **Allowed deferral codes** (each needs a one-line justification you verify with `Read`/`Grep`): `PRE_EXISTING`, `PRODUCT_DECISION`, `UPSTREAM_TICKET:<id>`, `NEEDS_OUT_OF_SCOPE_EDIT` (list exact files; ends in `HUMAN_REQUIRED`), `RULE_DISPUTED` (quote evidence). NOT valid: "preference", "style", "low risk", "works", "keeps the PR small", "would require a refactor", "callers/specs here rely on it", "scope creep" (for in-scope code), "extra files" (extractions create new files), "the auditor's suggestion".
4. **Reject invalid deferrals** (from House, the Builder or yourself): they return to OPEN and go to the Builder as mandatory.
5. **Conformance gate.** PASS = `VERDICT: PASS` AND every MANDATORY item FIXED or allowed-deferred AND no IN_SCOPE `mechanical` failure open (rubocop, brakeman, tests). With `--fix`, OPEN mandatory items force another iteration (N < 3); out of iterations ⇒ `HUMAN_REQUIRED`, never PASS. Audit-only reports `CONFORMANCE: FAIL (n mandatory open)`.
6. **Final report:** see Phase 5 (ledger table, `PRE_EXISTING_DEBT`, TL;DR, persisted files).

## Phase 4 — Remediation Loop / Actor-Critic (ONLY with `--fix`)
Max 3 iterations (initial audit = 0). Pass bar: min Scorecard >= 8 AND `VERDICT: PASS`. Stay in one session.
0. **Scope guard.** Before the first Builder call: `git -C <repo> stash create` → `SNAP_host` / `SNAP_studio` (read-only snapshot SHAs, one per repo with changes); record the SCOPE_MAP as the EDIT_MANIFEST. The Builder may edit ONLY: NEW files, TOUCHED_METHODS bodies, CLASS_LEVEL_CHANGED_LINES, files it CREATES to receive extracted in-scope code (operation, query, presenter, validator, policy, Stimulus controller, locale keys EN+ES, tests), additive edits that append a method/constant, moving a feature file to its right layer, and minimal call-site/test edits a contract change forces (listed in `caller_changes`). PRE_EXISTING code is off limits: no renames, reordering, "while I'm here" cleanups, whole-file rewrites, or formatter runs.
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
RULES: implement §1 exactly; apply §2+§3 unless they conflict with §1; update every §4 caller in the same change; minimal diff; update/add Minitest tests and EN+ES locale keys (locales always live in the HOST); edit across repos only as findings require; run the validation loop (engine tests run from the host root: `bin/rails test ../papyro_studio/test/<path>`); return git diff stat + diff per repo + `EDITED:` list prefixed `host:`/`studio:`.
```
1b. **Verify scope.** `git -C <repo> diff -U0 SNAP_<repo> -- <files>`: every hunk's old range must lie inside a TOUCHED method, changed class-level line, NEW file, or approved `caller_changes`. Otherwise send the Builder ONE correction ("revert these hunks: <file:range>; re-apply inside scope or report DEFERRED_SCOPE"); a second violation ends with `HUMAN_REQUIRED`. Reject a diff disproportionate to the findings.
2. Re-run Phase 0.9 yourself on the files the Builder touched (never trust the Builder's own green run), then re-run the FULL Critic pipeline on every file the Builder modified or created: Bricks → Rooms/Stimulus → Slices → House. A "condensed" House-only re-audit is FORBIDDEN. Before publishing, self-check that every file in `git -C <repo> diff --name-only` (each repo) since the last audit has a fresh Brick+Room JSON; record `reaudit_coverage: <re-audited>/<modified>` (must be 100%).
3. **Mandatory sweep.** If House says PASS but OPEN mandatory items remain and N < 3, consume the next iteration on ALL of them (data-integrity/security first). `PRE_EXISTING_DEBT` never triggers an iteration.
4. Gate met ⇒ go to Phase 5 (final House review + ledger), close todos, state `iterations_used: N` and every `DEFERRED(code)`. N = 3 with mandatory items open ⇒ `HUMAN_REQUIRED`.
5. Still FAIL after 3 fixes ⇒ stop; Phase 5 publishes the last House review + `HUMAN_REQUIRED: <top 3 blocking findings + files>`; ask for direction. Never commit or push in either repo and never force-merge — output the diffs only.

## Phase 5 — Report and persistence (you do this, always, after Phase 3 or Phase 4)
1. **TL;DR block FIRST** (max 10 lines): combined `VERDICT` and, per repo in scope, `VERDICT_HOST` / `VERDICT_STUDIO`; `CONFORMANCE: PASS|FAIL (n mandatory open)`; mechanical status (rubocop / brakeman / tests); the single highest-risk finding (id, file:line, one sentence); `WORKSPACE_WARNINGS`; `COST_SUMMARY` (audited / skipped / calls / cache hits); iterations used when `--fix` ran.
2. **Findings grouped by file, in FIX ORDER.** Order the work the developer should do: (1) security, data integrity, failing tests; (2) cross-layer contracts (route ↔ controller ↔ operation ↔ view ↔ Stimulus/Turbo, host ↔ engine seam, locale parity); (3) layer placement and structure (SRP, extractions); (4) naming, style, advisory items. Under each file list its OPEN mandatory items (`F-id | rule | line | one-line fix`), then DEFERRED items with their code.
3. Then the full House review verbatim, the ledger table (id | rule | where | status) and `PRE_EXISTING_DEBT`.
4. **Persist** (`mkdir -p tmp/audit/<slug>`; `slug` = sanitized `<host-branch>` plus `+<studio-branch>` when the engine is in scope plus the short head SHAs; `tmp/` is git-ignored): `Write` `report.md` (steps 1-3) and `ledger.json` (every finding: id, source, file, method, rule, scope, severity, status, deferral code). Then write the machine-readable receipt with the FINAL House scorecard (the five /10 numbers of the last audit, not an earlier iteration): `ruby .claude/scripts/audit_receipt.rb write --scores architecture=<n>,clean_code=<n>,scalability=<n>,security=<n>,testability=<n> --verdict <PASS|NEEDS-REWORK|FAIL> --mandatory-open <open MANDATORY ledger items> --iterations <used> --out tmp/audit/<slug>/scorecard.json`. It fingerprints the code as it is now (including uncommitted edits the Builder made), so run it after the last fix and before any further edit. Callers such as `/work` pass this file to `work_board.rb advance --audit-receipt`; with both repos in scope write it for the repo whose directory you run in. If a previous `ledger.json` exists for the same slug, read it first and add a **Since last run** section: findings now FIXED, NEW, and STILL OPEN (matched by file + rule).
5. **Rule statistics:** append ONE JSON line to `tmp/audit/rule-stats.jsonl` — `{"at":"<ISO date>","scope":"<slug>","skills_loaded":[…union of skills_loaded…],"rules_cited":["controller R2",…,every distinct cited rule…]}` (use `Write` of the whole file after reading the existing one; keep prior lines). `ruby .claude/scripts/audit_rule_coverage.rb` reports rules never cited and skills never loaded, to tune vague rules and the router.
6. **`--pr-comment`:** also `Write` `tmp/audit/<slug>/pr-comment.md`: verdict line, then the OPEN mandatory items grouped by file with `file:line` and the fix, then deferrals and debt in a collapsed `<details>` block. Never post it anywhere; tell the user the path.

## Rules
- Parallelism = multiple `Agent` calls in ONE block. Never run methods sequentially.
- Context: Brick/Room/Slice JSONs are the compressed matrix; never paste thousands of lines into House. Reuse prior JSONs across iterations; re-audit only changed code.
- Cost: Bricks `haiku`, Rooms/Stimulus/Slices `sonnet`, House `opus`, Builder `sonnet`. Leaf agents are read-only (Read/Grep/Glob).
- Triage and cache (Phase 0.8) decide what agents see; reuse cached JSON only when the key matches.
- Mechanical tools run first (Phase 0.9) and their output is fact: agents never re-litigate it.
- Diff-scoped by default; audit-only by default; `--fix` edits code max 3 iterations then human fallback. You never edit code yourself.
