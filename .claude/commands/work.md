---
description: Worker loop for an epic: take the next claimable item, work it in an isolated worktree through its stages, share what you learn, release, repeat. Several sessions (yours, a colleague's) can run this on the same epic at once.
argument-hint: "--epic <slug> [--stage plan,build,...] [--max-items N] [--once]"
allowed-tools: Agent, Skill, Read, Write, Edit, Grep, Glob, TodoWrite, Bash(ruby:*), Bash(git:*), Bash(gh pr:*), Bash(bin/rails:*), Bash(bin/rubocop:*), Bash(node:*), Bash(npm:*), Bash(cd:*), Bash(ls:*), Bash(mkdir:*), Bash(grep:*)
---

# /work: take work, do it, hand it on

Arguments: $ARGUMENTS
Parse: `--epic` (required), `--stage` (limit to stages; e.g. `audit` for an optional independent second look), `--max-items N` (stop after N items; default 3), `--once` (= `--max-items 1`).
Read `.ai/skills/epic-flow/SKILL.md` and `references/stages.md` first. Every rule there (R1-R14) binds you. The board is only touched through `ruby .claude/scripts/epic/work_board.rb` (`WB` below). If the epic does not exist, stop and tell the human to run `/epic-plan`.

## Phase 0: Identify yourself
`WB session` -> `SESSION`. Run `WB reap --epic S` once (frees claims whose lease expired). `WB status --epic S` and print the counts.

## Phase 0.5: Merge sweep (at the start of Phase 0 AND at the start of every loop iteration)
Items in `review` wait for a human to merge their PR (by hand or with `/work-merge`); their dependents stay blocked until the item is `done`. Finish the merged ones yourself, first, following the Sweep and "Verifying the Gates on main" sections of `references/merge-sweep.md`:
`WB reviews --epic S` -> for each row by `verdict`:
- `merged`: `WB claim N ...`; verify the item's Gates (`gates` in the row) on `origin/main` in a detached worktree (recipe in the reference; CI jobs already green on that very `main` sha count, so does a previous sweep's log for the same sha). Green -> `shared` note if other items consume the result, then `WB advance N --epic S --session SESSION --stage done --note "merged in PR #X, gates green on main <sha>"`. Red -> `WB block N ... --reason "<gate output>"` (a merged change that breaks main is a human's problem). Out of time -> `handoff` note (what passed, sha, log paths) and `WB release N`. Remove the worktree afterwards unless a gate was red.
- `closed_unmerged`: `WB claim N ...` then `WB advance N ... --stage fix --note "PR closed without merge: <url>"` (releases it for a fix session).
- `open` or `no_pr`: leave it; you never merge (R13). Report `no_pr` rows to the human (an item in review without a PR needs one) and name `/work-merge --epic S` for the open ones.
A row held by another session (`holder` set) is theirs; skip it.

## Phase 1: Loop (until `--max-items`, no work, or a stop)
1. **Pick:** `WB next --epic S --session SESSION [--stage ...]`.
   - `item: null` with `reason` `all_done` -> print the final status and stop. `awaiting_merge` -> run the merge sweep once more (a merge may just have happened); if nothing was merged, list the awaiting PRs with their URLs and stop: the human merges them (`/work-merge --epic S`) and re-runs `/work` (or any session's next sweep picks it up). `claimed_by_others` / `waiting_on_dependencies` -> report who holds what and stop (do not poll in a loop; the human re-runs `/work` later). `needs_human` -> list the blocked items and stop. `filtered` -> report what your `--stage` excluded.
   - `next` never returns items in stage `review`; only the sweep handles them.
2. **Claim:** `WB claim N --epic S --session SESSION`. Exit 1 means someone else got it or the files overlap: go back to step 1 (at most 5 times, then stop).
3. **Read:** `WB show N --epic S` (goal, owns, gates, acceptance, notes) and `WB digest --epic S --item N --format md`. Read all of it. Create or reuse the worktree: `git fetch origin && git worktree add ../<repo>-wt/S-N -b epic/S/N-<kebab-title> origin/main` (existing branch for later stages: `git worktree add ../<repo>-wt/S-N epic/S/N-<kebab-title>`). All edits happen there, only inside the item's Owns globs (R5, R6).
4. **Work the stages** from the item's current `stage:` label with `references/stages.md` as the contract. Use the agents and skills named there (`feature-blueprint-planner` for plan, `senior-rails-dev` for test-plan/build/fix, `/audit-feature --fix` for audit (same session), specialised builders if the item's context names one). You run the Gates yourself; a green receipt from an agent is not a green gate (R9).
   - After each stage: `WB advance N --epic S --session SESSION --stage <next> --keep --note "<what changed, what to look at>"`.
   - Long stage: `WB heartbeat N --epic S --session SESSION` every ~15 min. If any board call says the item is no longer yours, STOP, do not push, go to step 1.
   - **Audit (R10), same session.** In the item worktree run `/audit-feature --fix` on the branch diff; it iterates (max 3) until every scorecard dimension is >= 8 and `VERDICT: PASS`, and writes `tmp/audit/<slug>/scorecard.json`. Re-run the Gates yourself, commit, then advance from inside the worktree: `WB advance N --epic S --session SESSION --stage review --audit-receipt tmp/audit/<slug>/scorecard.json --note "<what changed>"`. A refusal (`audit_not_passed`, with `reasons`) means: fix what it names and audit again (a stale receipt means code changed after the audit). Do not edit the receipt.
   - Only the move to `review` advances WITHOUT `--keep` (it releases the item); after `review` nobody works it until its PR is merged (the merge sweep finishes it). Your session continues with the next item.
   - Fix loop: max 3 iterations (R11), then `WB block N --epic S --session SESSION --reason "<command, output, hypothesis>"`.
5. **Share:** if you created something others will consume, `WB comment N --epic S --session SESSION --type shared --body "<path, public API, one usage example, PR>"`. A cross-cutting finding is a `lesson` note on the epic-root issue. Releasing unfinished work (budget, lease) requires a `handoff` note first.
6. **Push, never merge:** push the item branch and open or update its PR (`gh pr create` / `gh pr edit`, body links the issue number, no auto-close keyword). Merging and every other outward action stays with a human (R13). After a human merges, the merge sweep (Phase 0.5) of any `/work` run advances the item to `done` after re-running its Gates on `main` (R14).
7. Remove nothing of other sessions. Remove your own worktree only when the item is `done` or released with its branch pushed.

## Phase 2: Report
For each item: number, title, stages passed, gates run and their result, notes posted, PR link, final state. For anything stopped early: the exact reason and the next command for a human or another session.
