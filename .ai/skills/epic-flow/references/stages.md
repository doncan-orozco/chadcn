# Stages

One issue goes through these stages. The label `stage:<name>` is the column. A worker advances only when the exit criteria are met by commands it ran itself (epic-flow R9).

| Stage | Who | Does | Leaves behind | Exit (gate) | Next |
|---|---|---|---|---|---|
| `plan` | any | Reads item + `digest`; writes a short implementation plan as a `handoff` note: files, approach, risks, how the Gates will be satisfied. | plan note | plan names every file inside Owns and every Gate | `test-plan` |
| `test-plan` | any (same session may continue) | Writes the failing tests / characterization tests / before-screenshots first, per the `testing` skill. | tests committed on the branch | new tests exist and fail (or, for characterization, pass on the old code) | `build` |
| `build` | any | Implements with the relevant skills loaded (`senior-rails-dev` for gem Ruby, Phlex and Stimulus work; `shadcn-port-builder` when the item is a component port; the item says if another specialised builder applies). Commits in small steps. | code on the branch | Gates green locally | `gates` |
| `gates` | same session | Runs every Gate command from the issue exactly as written, plus `bundle exec rubocop` on touched Ruby. Pastes the summary into the advance note. | gate output summary | all green | `audit` (keep) |
| `audit` | **same session** (R10) | Runs `/audit-feature --fix` on the branch diff inside the item worktree (every file is on the Gem track). Fresh brick, room and house agents judge; the fix loop (max 3 iterations, R11) runs inside the command. Re-runs the Gates itself afterwards and commits. The command leaves `tmp/audit/<slug>/scorecard.json`. | commits, report, `scorecard.json`, one `handoff` note with MANDATORY vs ADVISORY and what was deferred | EVERY scorecard dimension >= 8, `VERDICT: PASS`, 0 mandatory open, receipt written for the committed code | `review` (release, with `--audit-receipt`) |
| `fix` | any | Used when the PR was closed unmerged or a human-requested independent audit (`/work --stage audit`) found MANDATORY issues: fix, re-run Gates, then audit again. Not a normal step of the happy path. | commits | Gates green and findings resolved | `audit` (keep) |
| `review` | the worker opens the PR; a human merges (by hand or with `/work-merge`, which merges only what `mergeable` judges `ready`, R15) | Opens/updates the PR from branch `epic/<slug>/<N>-<title>` (the branch name is how `reviews` finds it; `Closes #N` is NOT used), requests review, releases the item. Nobody works an item in `review`. A PR that fails the merge policy (CI red only on the PR, conflicts) is sent back to `fix` by `/work-merge`. | PR | merged to `main` | `done` (via the merge sweep) |
| `done` | the merge sweep, run first by every `/work` iteration and right after `/work-merge` merges | `reviews` reports `merged`; the sweeper claims the item, re-runs the Gates on `origin/main` in a detached worktree (one worktree for all items merged in a row; CI jobs already green on that very sha count), posts a `shared` note if others consume the result, advances to `done` (closes the issue, unblocking dependents). Red on main -> `block`. PR `closed_unmerged` -> `fix`. Procedure: `merge-sweep.md`. | `shared` note | Gates green on `main` (R14) | |

## Rules of thumb

- Pull the lowest `wave` first; `next` already does.
- Between `build` and `gates`, `heartbeat`. A stage longer than 15 minutes without a heartbeat risks takeover.
- A gate that cannot run for environmental reasons (no browser, no network) is a `blocker`, not a skip.
- The receipt is checked by `advance --stage review --audit-receipt <file>` in the item worktree: five scores >= 8, verdict PASS, no mandatory finding open, and the receipt's tree equals the code there. Edit code after the audit and the receipt is stale: audit again. The numbers come from House's scorecard; the script proves they pass and belong to this code, not that they were copied honestly, which is why the report stays on disk next to the receipt.
- `advance --note` is read by the next worker: say what changed and what to look at.
