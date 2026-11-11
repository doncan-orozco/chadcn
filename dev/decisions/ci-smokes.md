# Decision: the esbuild and Sprockets clean-app smokes run in CI as a matrix of a sibling job

Status: decided and implemented by item #204 (phlex-shadcn-adoption-followups). Proof: the `clean-app-variants` job of
`.github/workflows/chadcn.yml`, one run per matrix row, on every pull request, and on push to `main`.

## What runs

`bin/smoke --app` (importmap + Propshaft) keeps its own job, `clean-app`, untouched. The two other supported pipelines are rows of a
new job, `clean-app-variants`:

| Row | Command | What it proves |
|---|---|---|
| esbuild | `bin/smoke --app --js esbuild` | `rails new --javascript esbuild` (jsbundling-rails) plus the README's bundler path: the gem's controllers are copied and bundled, the Dialog opens and closes in a browser |
| sprockets | `bin/smoke --app --assets sprockets` | a Rails 8.1 app on sprockets-rails + importmap + tailwindcss-rails: the engine's precompile declaration, the doctor's asset-pipeline check, `assets:precompile`, a Dialog in a browser |

Why a sibling job and not extra rows of `clean-app`: a matrix renames the job's checks (`clean Rails app from the README (x)`), which
would silently orphan any branch-protection rule that requires the current name. The sibling leaves that check as it was. The setup steps
(Ruby 4.0, Node 22, Rails ~> 8.1, Playwright 1.61.0 with chromium) are copied from `clean-app`; they are short and a composite action
would be one more moving part for three steps. The rows run in parallel, `fail-fast: false`, so one red row does not hide the other.

## Runtime added

Two more `ubuntu-latest` runners per run, in parallel with the existing jobs, so wall-clock time does not grow while runners are available (the
longest job of the run, not these rows, set the 2m29s total: the gem matrix, js-tests and docs run alongside). Measured on the PR run (cold caches): importmap smoke 1m32s, esbuild 1m45s, sprockets 1m53s; the whole workflow
finished in 2m29s. Runner minutes grow by about two importmap smokes (~4 minutes). Timeout is 30 minutes per row, like `clean-app`.

## Caching

- Playwright's chromium (`~/.cache/ms-playwright`) is cached with `actions/cache`, keyed by the pinned Playwright version; the
  `playwright install --with-deps` step still runs (it installs the apt libraries and is a no-op for a cached browser download).
- Node: the esbuild row's `yarn`/`npm install` happens inside the generated app, which has no committed lockfile to key a cache on, so
  the packages are fetched fresh each run. The same holds for the generated app's bundle (`bundle install` resolves a new app each time).
  Caching either would key on something that changes by design; it is intentionally not done.

## Intentionally not covered

- Other jsbundling bundlers (rollup, webpack, bun): the README documents esbuild as the bundler path and `dev/decisions/js-bundlers.md`
  explains why one bundler is the proof; the copied-controllers mechanism is the same for the others.
- Sprockets with a JavaScript bundler: the Sprockets smoke supports importmap only.
- Ruby versions other than 4.0 for the app smokes: the gem job already runs the gem on 3.3 to 4.0; the app smokes need a current Rails 8.1.
- Making the new job a required status check is a repository setting (a human step).

# Decision: CI runs a React-versus-Phlex parity smoke on every push

Status: decided and implemented by item #95 (review-gaps). Proof: the `parity` job of `.github/workflows/chadcn.yml`, on every pull
request and on push to `main`. Before it, the parity gate (the README's "checked against the React original in a browser") ran only
locally through `/shadcn-audit`.

## What runs

`bin/parity-smoke` (`.claude/scripts/shadcn/parity_smoke.rb`) starts the dev servers once (the dummy app and the React catalog, like
`bin/test-js`), then calls `parity_batch.rb --components <name> --only <ids> --no-servers` once per component and stops the servers.
Each call is G2 (DOM, classes, computed style) on every step of the selected scenarios, so the scenarios that click, hover or type are
also G3 behavior. Any diff exits 1 and names the component; the reports land in `tmp/shadcn-port/<component>/g2.json`, which the job
uploads (with `parity-smoke.json` and the server logs) when it fails.

## The subset

Per component scenario file (`dev/port/scenarios/<name>.json`; the `_primitives-*` files are left out):

- the scenario ids starting with `default` (`default`, `defaults`, `default__dark`, `default-open__click`, ...): 48 components;
- a component without one contributes its first scenario and the ids that extend it, i.e. the closed or resting state the file opens with
  and its `__dark` twin: accordion, alert-dialog, chart, context-menu, dialog, drawer, dropdown-menu, field, menubar, navigation-menu,
  select, sheet.

That is 60 components and 179 of about 5,500 scenarios today (`bin/parity-smoke --list` prints the current subset). The rule picks
itself up for a new component: a new scenario file joins the subset without editing the smoke. `parity_smoke_test.rb` (rake
test:tooling) pins the rule and that every component scenario file has a non-empty subset.

Known non-deterministic scenarios: the ones `dev/port/REPORT.md` lists under "Scenario fixes" were fixed at the scenario (settled steps,
neutral pointer targets, pinned randomness), so none is excluded. A scenario that turns flaky in CI is fixed in its scenario file, not
dropped from the smoke.

## Time budget

`--budget 900` seconds by default, measured from the first gate (server start excluded). Running out is exit 2 and lists the components
not run: a budget overrun is a failure, never a silent skip, so a subset that grows past it is noticed. Measured locally on a loaded
laptop (other browser suites running): 540 to 576 s for the 60 components, 2.5 s (select) to 33 s (chart) each, one Playwright browser per call. The job's
`timeout-minutes: 30` covers the install steps and the budget.

## The full gate

The smoke is a tripwire, not the parity gate. The full gate is `/shadcn-audit` (G1 static, G2 DOM/style, G3 behavior, G4 theme, G5
house), or, for the browser gates alone:

    ruby .claude/scripts/shadcn/parity_batch.rb --components all                # G2 + G3, every scenario
    ruby .claude/scripts/shadcn/parity_batch.rb --components all --dx --themes  # plus G2b DX helpers and G4 themes

Run it before a release and after any change to a component, controller, primitive or theme.

## Intentionally not covered

- G2b (yielded-root helpers) and G4 (theme presets, dark): they multiply the runs and are covered by the full gate.
- Making `parity` a required status check is a repository setting (a human step, issue #3).
