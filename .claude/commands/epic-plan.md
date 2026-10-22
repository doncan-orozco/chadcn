---
description: Turn a goal into an epic on GitHub: decompose it into items with owns, blockers, gates and acceptance, validate the plan with scripts, then create the issues. Idempotent per slug (refuses an existing epic).
argument-hint: "<goal or ticket text> [--slug kebab-name] [--dry-run]"
allowed-tools: Agent, Read, Write, Grep, Glob, TodoWrite, Bash(ruby:*), Bash(git status:*), Bash(git log:*), Bash(ls:*), Bash(grep:*), Bash(mkdir:*)
---

# /epic-plan: decompose a goal into claimable items

Arguments: $ARGUMENTS
Read `.ai/skills/epic-flow/SKILL.md`, `references/plan-format.md` and `references/stages.md` first. You plan; you do not implement anything and you do not create issues by hand. The board is only touched through `ruby .claude/scripts/epic/work_board.rb`.

Parse: the goal (everything that is not a flag), `--slug` (default: kebab-case of the goal, max 40 chars), `--dry-run` (stop after Phase 3, create nothing).

## Phase 0: Ground the plan in the repo
1. `git status` and `git log --oneline -10` (what state is the branch in). The plan describes work from the current `main`; if the working tree has uncommitted changes that the epic depends on, say so and stop: items start from `origin/main`.
2. Read what the goal touches: `CLAUDE.md`, the relevant `.ai/skills/*/SKILL.md` (architecture, naming-conventions, testing and the domain skill), and the code or docs the human pointed at. Prefer reading to guessing; record every non-obvious fact you will rely on in the epic `body` or item `context`.
3. If the goal is ambiguous in a way that changes the item list (naming, layout, scope), ask the human ONE batch of questions and stop. Decisions the human already made in this conversation are not re-asked.

## Phase 1: Draft `tmp/epic/<slug>/plan.json`
Follow `references/plan-format.md` exactly. Decompose by these rules:
- Wave 0: decisions, scaffolding and tooling that everything else needs. Serial migrations/renames get their own wave with a single owner. Independent slices fan out in later waves.
- Every item: a one-paragraph `goal`, `owns` globs that no parallel item shares, `blocked_by` keys, `gates` as unattended shell commands that exit non-zero on failure, `acceptance` bullets. If no command can judge a requirement, add an item (or gate script) that creates the judge first.
- Include the standard stage path for each item: the worker will run plan → test-plan → build → gates → audit → fix → review (see `references/stages.md`); an item that needs a different path says so in `context`.
- Size items for one session of a few hours. Foundation items (consumed by others) block their consumers.
- Human-only steps (publish, merge, repository settings) are separate items labeled `needs-human` in their `context`, never folded into an agent item.

## Phase 2: Validate with the script, never by eye
`ruby .claude/scripts/epic/work_board.rb plan-check --file tmp/epic/<slug>/plan.json`
Exit 1 prints findings (`FIELD_MISSING`, `OWNS_OVERLAP`, `WAVE_ORDER`, `CYCLE`, ...). Fix the plan and re-run until it passes. Do not weaken a gate or drop `owns` to get a pass.

## Phase 3: Show the plan
Print a compact table: wave, key, title, blocked by, owns (first glob), first gate. State the item count, the number of items that can start right now, and the longest dependency chain. Name anything you are unsure about. With `--dry-run` stop here.

## Phase 4: Create (only after the human confirms)
Creating issues is visible to everyone with access to the repository. Ask the human for a go-ahead if they did not already give one for this plan, then:
`ruby .claude/scripts/epic/work_board.rb plan-apply --file tmp/epic/<slug>/plan.json`
Then `ruby .claude/scripts/epic/work_board.rb validate --epic <slug>` (must pass) and `ruby .claude/scripts/epic/work_board.rb status --epic <slug>`. Report the epic-root issue number, the item numbers by key, and the exact command each worker session runs: `/work --epic <slug>`.
