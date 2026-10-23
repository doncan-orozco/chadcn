---
description: Release manager for an epic, run by a human: merge the PRs of items in review that pass the merge policy, finish the merged items (Gates on main, advance to done) so their dependents become claimable, free stale claims, and report what still needs a person. The only command that merges.
argument-hint: "--epic <slug> [--dry-run] [--only N,M] [--no-sweep] [--wait-ci MIN] [--no-issues]"
allowed-tools: Read, Write, Grep, Glob, TodoWrite, Bash(ruby:*), Bash(git:*), Bash(gh pr view:*), Bash(gh pr checks:*), Bash(gh pr update-branch:*), Bash(gh pr list:*), Bash(gh run:*), Bash(gh issue list:*), Bash(gh issue create:*), Bash(bundle:*), Bash(bin/check:*), Bash(bin/test-js:*), Bash(bin/smoke:*), Bash(cd:*), Bash(ls:*), Bash(mkdir:*), Bash(cp:*), Bash(rm:*), Bash(cat:*), Bash(tail:*), Bash(grep:*), Bash(nohup:*), Bash(ps:*)
---

# /work-merge: merge what is ready, finish what is merged, say what is left

Arguments: $ARGUMENTS
Parse: `--epic` (required), `--dry-run` (judge and report, change nothing), `--only N,M` (restrict to these items), `--no-sweep` (merge only; leave the sweep to the next `/work`), `--wait-ci MIN` (how long to wait for running checks; default 15), `--no-issues` (do not file bug issues for checks failing on `main`).

You are the release manager a human would otherwise be. You act with the human's privileges because a human invoked you, so you also carry their duties: you merge nothing the script did not judge `ready`, you never loosen a gate or a check, and anything you cannot finish ends in a note on the board, not in silence. Read `.ai/skills/epic-flow/SKILL.md` (R1-R15) and `references/merge-sweep.md` first; the latter is your contract. The board is only touched through `ruby .claude/scripts/epic/work_board.rb` (`WB` below); the merge itself only through `WB merge` (there is no `gh pr merge` in your tools on purpose). If the epic does not exist, stop and say so.

## Phase 0: Identify, free, look
1. `WB session` -> `SESSION`. `WB reap --epic S`: print what it freed (a stale claim was blocking a worker; it is now claimable).
2. `WB status --epic S`: print the counts.
3. `WB mergeable --epic S` -> `J`. Print one table: `#`, title, wave, PR, verdict, failing checks, pre-existing checks, behind/overlap, audited. Then `base`: the `main` sha and the checks failing on it.
With `--dry-run` or `--only`, keep only the rows asked for, print what you would do per row (the table in `merge-sweep.md`), and stop here when `--dry-run`.

## Phase 1: Judge and prepare (every open PR, lowest wave then lowest number)
For each row by `verdict`, exactly as `merge-sweep.md` prescribes:
- `ready`: keep for Phase 2.
- `ci_pending`: `gh pr checks <pr> --watch --fail-fast` up to `--wait-ci` minutes, then `WB mergeable --epic S --item N` again and re-route.
- `ci_failed`: once, re-run the failed jobs (`gh run rerun <run-id> --failed`, the run id is in the check url) and wait as above. Still red: `WB claim N --epic S --session SESSION` then `WB advance N --epic S --session SESSION --stage fix --note "CI red on the PR, green on main: <job> <url>"`. This releases the item so `/work` fixes it.
- `behind`: `gh pr update-branch <pr>`, wait for CI, judge again. Conflicts after the update: as `conflicts`.
- `conflicts`: `WB claim N` then `WB advance N --stage fix --note "merge conflicts with main: rebase branch <branch>"`.
- `unknown_mergeability`: retry `WB mergeable --item N` up to 5 times, a few seconds apart; then treat as `ci_pending`.
- `draft`, `not_audited`, `no_pr`: do not touch; list them for the human with the reason.
- `merged`, `closed_unmerged`: Phase 3.
A row with `holder` set belongs to another session: skip it and say so.

## Phase 2: Merge
For each `ready` item in order: `WB merge N --epic S --session SESSION` (squash; the script re-judges and pins the head it judged; the remote branch is deleted, the PR keeps the history). Exit 1 means the verdict changed under you: print the reason and go back to Phase 1 for that item. After each merge, `WB mergeable --epic S` again for the remaining rows (GitHub recomputes mergeability; a row may turn `behind` or `unknown_mergeability`). Stop merging the moment a merge fails for a reason you cannot route; report it.

## Phase 3: Sweep (skip with `--no-sweep`)
`WB reviews --epic S`: every `merged` row (yours and earlier ones nobody finished) is finished here following the Sweep section of `merge-sweep.md`:
1. Claim them all (`WB claim N`), skipping rows with a `holder`.
2. Read each item's `handoff` notes (`WB show N`): a previous sweep may have left logs for the very same `main` sha that count as green (rule 4).
3. One detached worktree on the merged `main` (recipe in the reference). Collect the distinct Gate commands (`gates` in each row), run each once; gates that CI already ran on this `main` sha count by rule 2 (cite the job url from `J.base.checks`). Long gates run detached with a log; heartbeat every claimed item every 15 minutes while they run.
4. Per item: all gates green -> `shared` note if other items consume the result, then `WB advance N --epic S --session SESSION --stage done --note "PR #X merged; gates green on main <sha>: <gate list or CI job urls>"`. Any gate red -> `WB block N --epic S --session SESSION --reason "<gate>: <output excerpt, log path>"`. Out of time -> `handoff` note (gates passed so far, `main` sha, log paths) then `WB release N`.
5. `closed_unmerged` rows: `WB claim N`, `WB advance N --stage fix --note "PR closed without merge: <url>"`.
6. Remove the worktree (`git worktree remove`) when every merged item is done or blocked; keep it and name its path when something is red.

## Phase 4: Housekeeping (report, light touch)
- Checks failing on `main` itself (`J.base.failing`): unless `--no-issues`, file one issue per job with `gh issue create --title "CI: <job> fails on main" --label bug --body "<job url>, first seen sha, the failing step's last lines>"`, after `gh issue list --search "CI: <job> fails on main in:title" --state open` shows none. Print the issue urls.
- `needs-human` items: print each with its last `blocker` note (`WB show N`).
- Items in `review` with `no_pr`, `draft` or `not_audited`: print them with the reason.
- Other open PRs of the repository that are not epic branches (`gh pr list --state open`, e.g. dependabot): list number, title and check state. Do not merge them; that is outside the board.
- Gate processes of other sessions still running on this machine (`ps aux | grep -E "parity_batch|parity_run|test-js|rake test"`, older than a day): list them; killing them is the human's call.

## Phase 5: Report
Per item touched: number, title, PR, verdict at start, what you did (merged / sent to fix / finished / blocked / left), gates run on `main` and how each was judged (run here, or CI job url). Then: items that became claimable (`WB next --epic S` now returns one? say which), what still waits for a person and why, the exact next command: `/work --epic S` when something is claimable, `/work-merge --epic S` again when CI was still running, or `epic done`.
