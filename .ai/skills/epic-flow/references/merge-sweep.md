# Merge sweep

How an item in `review` becomes `done` once its PR is merged, and how the human-run `/work-merge` decides a PR may be merged. `/work` runs the sweep (Phase 0.5) at the start of every iteration; `/work-merge` runs the merge policy first and the sweep right after. Every board read or write goes through `ruby .claude/scripts/epic/work_board.rb` (`WB` below).

## Who merges

Merging to `main` is a human act (epic-flow R13). The human delegates it by running `/work-merge`, which merges only through `WB merge N` and only when `WB mergeable` says `ready` (R15). `/work` never merges; the `gh pr merge` command is not in any agent's allowed tools.

## Merge policy (`WB mergeable --epic S`)

For every item in `review` with an open PR the script answers one verdict. Facts come from GitHub; the agent does not read a checks page by eye.

| Verdict | Meaning | What the release manager does |
|---|---|---|
| `ready` | audited (the `-> review: audit ... verdict=PASS` stage-log exists), `MERGEABLE`, every check completed, no check failing that passes on `main`, and either 0 behind `main` or the PR's files are disjoint from what landed on `main` since its merge base | `WB merge N --epic S --session ID` |
| `ci_pending` | a check is still running | wait (`gh pr checks <pr> --watch`, up to `--wait-ci` minutes), judge again |
| `ci_failed` | a check fails on the PR and passes on `main` | re-run the failed jobs once (`gh run rerun <run-id> --failed`); still red: `WB claim N` then `WB advance N --stage fix --note "<job>, <log url>"` so `/work` fixes it |
| `behind` | behind `main` and touching files that changed there | `gh pr update-branch <pr>`, wait for CI, judge again; conflicts after the update: `fix` as above |
| `conflicts` | GitHub reports `CONFLICTING` | `WB claim N` then `WB advance N --stage fix --note "merge conflicts with main: rebase"` |
| `unknown_mergeability` | GitHub has not computed mergeability yet (right after another merge) | retry a few times, seconds apart |
| `draft`, `not_audited`, `no_pr` | not the worker's hand-over, or review set by hand | report to the human; touch nothing |
| `merged`, `closed_unmerged` | same as `reviews` | sweep (below) |

Checks that fail on the PR AND on `main` are pre-existing: `mergeable` lists them under `checks.preexisting` and `base.failing`; they do not block a merge (the sweep re-runs the item's own Gates on `main`), but the release manager reports them and files one `bug` issue per failing job on `main` (title `CI: <job> fails on main`, deduplicated by title).

Order: lowest wave, then lowest number. After each merge judge the rest again (GitHub recomputes mergeability).

## Sweep (`WB reviews --epic S`, after the merges)

Rows by `verdict`:

- `merged`: `WB claim N --epic S --session ID` (a row with `holder` set belongs to another session: skip it). Verify the item's Gates on `main` (next section). Green: post a `shared` note when other items consume the result, then `WB advance N --epic S --session ID --stage done --note "merged in PR #X, gates green on main <sha>"`. Red: `WB block N --epic S --session ID --reason "<gate, output excerpt>"` (a merged change that breaks `main` is a human's problem). Out of time: a `handoff` note saying which gates passed on which `main` sha and where the logs are, then `WB release N`.
- `closed_unmerged`: `WB claim N`, then `WB advance N --stage fix --note "PR closed without merge: <url>"`.
- `open`, `no_pr`: leave it; `no_pr` is reported (an item in review without a PR needs one).

## Verifying the Gates on main

Gates are the commands in the issue body (`WB show N` → `gates`). They run against `origin/main`, never against the PR branch, in a detached worktree:

```bash
git fetch origin
git worktree add --detach ../<repo>-wt/<slug>-sweep-<shortsha> origin/main
cd ../<repo>-wt/<slug>-sweep-<shortsha>
cp ../<repo>/.bundle/config .bundle/config        # BUNDLE_LOCAL__PAPYRO_STUDIO: the engine sibling
export LC_ALL=en_US.UTF-8
bin/rails db:prepare && bin/rails tailwindcss:build
```

Rules:

1. One worktree per sweep, not per item: several items merged in a row are verified together on the resulting `main`. Run each distinct gate command once; an item is green when every one of its gates is.
2. A gate that is exactly a CI job's command, already run by CI on the same `main` sha with conclusion `success`, counts as green on `main`; cite the job url from `WB mergeable` (`base.checks`). Today: `bin/rails test` ↔ job `test`, `bin/rubocop` ↔ `lint`, `bin/check` ↔ `gem_chadcn`, `bin/rails test:system` ↔ `system-test`, `bin/brakeman` ↔ `scan_ruby`. Anything else (parity batches, house checks, scripts) runs locally.
3. Long gates (the shadcn parity batch takes about an hour on an idle machine) run detached: `nohup <gate> > <scratchpad>/<slug>-<gate>.log 2>&1; echo exit=$? >> ...` and the session heartbeats every claimed item every 15 minutes (`WB heartbeat N`) while polling the log. Never run them while host test or lint runs share the machine: the harness flakes under load (lesson on #94); re-run a failing component alone before treating a diff as real.
4. A previous sweep's log counts when it names the same `main` sha and ends with `exit=0`; a `handoff` note that points to it is enough to finish without re-running.
5. Remove the worktree when every merged item is `done` or blocked; keep it, and say where it is, when a gate failed (forensics).
