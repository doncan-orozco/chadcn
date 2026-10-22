# Decision: bundler apps (jsbundling/esbuild) get the gem's JavaScript as generated, managed copies

Status: decided and implemented by item #175 (phlex-shadcn-adoption). Proof: `test/generators/install_generator_test.rb`
(esbuild tests), `test/engine/doctor_test.rb` and `bin/smoke --app --js esbuild` (a fresh Rails app, esbuild, a Dialog that opens
and closes in a browser).

## Problem

The gem ships its Stimulus controllers and primitives inside the gem (`app/javascript/controllers/shadcn/*`,
`app/javascript/shadcn/primitives/*`). importmap-rails apps get them from the engine's pins. An esbuild app resolves bare
specifiers (`shadcn/primitives/presence`, `controllers/shadcn/dialog_controller`, `@floating-ui/dom`) from `node_modules` and
relative paths only, and there is no npm package: publishing one is a human step (epic-flow R13) and is not needed.

## Options

| Option | Verdict |
|---|---|
| npm package `chadcn` | Works, but needs a maintainer to publish and then keep the gem and the npm version in lockstep. Not needed to ship, kept as a later option. |
| `NODE_PATH` or an esbuild `--alias` to the gem's `app/javascript` | The path of an installed gem is machine specific and changes with every version; it would be written into `package.json`/the shell environment of the host and break on the next `bundle update` or on another machine/CI/Docker build. Rejected. |
| `"chadcn": "file:..."` dependency in `package.json` | Same machine-specific path, plus `yarn`/`npm` copy or link semantics that differ per package manager; the install does not rerun when the gem moves. Rejected. |
| Symlink into `app/javascript` | Absolute and per machine, breaks on deploy images. Rejected. |
| **Generator copies the files into the app** | Chosen. No network, no publishing, committed with the app, esbuild resolves everything with relative paths. |

## Decision

`rails g chadcn:install` detects the pipeline (`--js auto|importmap|esbuild`, default `auto`):

- **importmap** (`config/importmap.rb`, importmap-rails): unchanged, the engine pins everything.
- **esbuild** (a `package.json` with an `esbuild` build script, or jsbundling-rails in the bundle, and no importmap): the generator
  1. copies the controllers to `app/javascript/controllers/shadcn/` and the primitives to `app/javascript/shadcn/primitives/`,
     rewriting only the two internal specifier forms (`shadcn/primitives/x`, `controllers/shadcn/x`) to relative paths, and
     prepends a `managed by` header line (edits are overwritten by the next run, like the Tailwind block);
  2. writes `app/javascript/controllers/shadcn/index.js`, which registers every controller as `shadcn--<name>` with the app's
     `application` (`./application` of stimulus-rails), and adds `import "./controllers/shadcn"` to `app/javascript/application.js`;
  3. adds `@floating-ui/dom` (the version the gem vendors) to `package.json` with the app's package manager (yarn, pnpm, bun or npm,
     chosen by the lock file), because floating-ui is a normal npm package and must not be copied.

The copies are the only state outside the gem, so they can go stale. `rails g chadcn:install` is idempotent and refreshes them
("identical" when current), and the doctor's `javascript pipeline` check compares every copy with what the generator would write and
fails with the exact command when one differs or is missing (after a `bundle update`, run the generator again).

Single source of truth: `Chadcn::JsBundle` (plain Ruby, `lib/chadcn/js_bundle.rb`, loaded by Zeitwerk)
computes the files; the generator writes them and the doctor compares against them.

## Consequences and later items

- "esbuild" means any jsbundling-rails app: the copies use relative imports, which webpack, rollup and bun resolve as well; only
  esbuild is exercised by the smoke test (in CI: job `clean-app-variants`, see dev/decisions/ci-smokes.md).
- The doctor's `stimulus controllers` check (`doctor/checks/stimulus.rb`, added to this item's scope as a deliberate, recorded deviation) accepts the managed `index.js`
  in an esbuild app: an esbuild app has no `controllers` importmap namespace, so the check would fail on a correct install.
  Recorded here and as a blocker note on #175 (epic-flow R5).
- `JsBundle` was moved (#205) to `lib/chadcn/js_bundle.rb`, where its file name and constant agree. The `app/...` layout paths
  stay in `lib/generators/chadcn/install/js_layout.rb` (`Generators::JsLayout`), because gem_check (GEM_ESCAPES_ROOT) allows
  such literals only in generator files; `JsBundle` reads them from there.

- The `shadcn--*` identifiers are the same in both pipelines, so the Phlex components and the DOM do not change.
- `stimulus:manifest:update` also registers `controllers/shadcn/*_controller.js` under the same identifiers; the double registration
  is harmless (Stimulus reloads the identifier with the same class).
- Sprockets and the eject generator (#179) can reuse `JsBundle` (eject copies a single component's controller the same way).
- If a maintainer later publishes an npm package, the generator step 1 becomes `yarn add chadcn` and `JsBundle` is retired;
  nothing in the DOM or the identifiers changes.
