# Decision: the esbuild and Sprockets clean-app smokes run in CI as a matrix of a sibling job

Status: decided and implemented by item #204 (phlex-shadcn-adoption-followups). Proof: the `clean-app-variants` job of
`.github/workflows/chadcn.yml`, one run per matrix row, on every pull request, and on push to `main`, that touches the gem or the workflow.

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
