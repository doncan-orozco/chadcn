# Decision: Sprockets apps are supported through a precompile declaration, a boot fix and a doctor check

Status: decided and implemented by item #177 (phlex-shadcn-adoption). Proof: `test/engine/sprockets_test.rb` (the declaration, the
boot guard, the doctor check) and `bin/smoke --app --assets sprockets` (a fresh Rails 8.1 app on sprockets-rails + importmap +
tailwindcss-rails renders a styled Button and a Dialog that opens and closes in a browser).

## Is Sprockets support realistic on Rails 8?

Yes, with a small amount of code, and the shrink to "documentation + doctor check" was not needed. Propshaft is the Rails 8 default,
but Sprockets is not gone: sprockets-rails 3.5 supports Rails 8.1, and importmap-rails and tailwindcss-rails both support it. Apps
that upgraded from Rails 7 keep Sprockets, and these are the apps this item serves. (Rails 8.1's `rails new` no longer offers
`--asset-pipeline sprockets`; the smoke builds such an app with `--skip-asset-pipeline` plus the gems' own installers.)

Trying a real app found two problems, nothing more:

1. **The engine crashed at boot.** `phlex_shadcn.exclude_tailwind_inputs` read `config.assets.excluded_paths`, a Propshaft option. Under
   Sprockets the options object answers `nil` for it and the initializer raised `NoMethodError` (every `rails` command failed).
   Fixed by running the exclusion only when the option exists.
2. **Pinned files were refused.** sprockets-rails raises `AssetNotPrecompiledError` for any asset not declared precompiled, and the app's
   `app/assets/config/manifest.js` cannot link files inside an installed gem. The importmap pins of the gem (`controllers/shadcn/*`,
   `shadcn/primitives/*`, the vendored `@floating-ui--*`) are therefore declared by the engine in `config.assets.precompile`
   (`Engine::SprocketsAssets`, only when `Sprockets::Railtie` is loaded; Propshaft ignores that list).

What needed nothing: the asset paths (the engine adds `app/javascript` and `vendor/javascript`, which Sprockets uses as is), the
Tailwind build (tailwindcss-rails writes `app/assets/builds/tailwind.css`, the app links it with `stylesheet_link_tag "tailwind"` and
`//= link_tree ../builds`, which its installers write), the generator (it edits the Tailwind entry file only) and the theme tooling.

## Supported pipeline matrix

| Rails | Assets | JavaScript | CSS | Status |
|---|---|---|---|---|
| 8.1 | Propshaft | importmap | tailwindcss-rails | supported, smoke in CI (`bin/smoke --app`) |
| 8.1 | Propshaft | esbuild (jsbundling) | tailwindcss-rails | supported, CI smoke (`--js esbuild`, job `clean-app-variants`), see js-bundlers.md |
| 8.1 | Sprockets 4 (sprockets-rails 3.5) | importmap | tailwindcss-rails | supported; `bin/smoke --app --assets sprockets` (development server, doctor, `assets:precompile` in production mode, browser dialog) first checked manually at #177, now a CI smoke (job `clean-app-variants`) |
| 8.1 | Sprockets | esbuild | tailwindcss-rails | not covered: the copied JavaScript is bundled by esbuild and linked as `application.js`, which does not touch the asset pipeline, but no smoke proves it |
| any | sprockets < 4 (any sprockets-rails), or Sass/SCSS instead of the Tailwind CLI | any | any | not supported (manifest.js is a Sprockets 4 concept; the doctor says so; the gem's CSS is bundled by the Tailwind CLI, never by Sprockets) |

## What stays Propshaft-only

`Engine::TailwindStubFilter` (the recorded R4 exception) hides the engine stubs that tailwindcss-rails writes to
`app/assets/builds/tailwind/` from Propshaft. It is installed only when `Propshaft::LoadPath` exists, so Sprockets apps neither get
the hook nor a warning, and `config.phlex_shadcn.hide_tailwind_stubs` does nothing for them. A Sprockets app never links the stubs:
it names `tailwind` explicitly. Known limit: `//= link_tree ../builds` (what tailwindcss-rails' installer writes) also declares the
stubs precompiled, so `assets:precompile` copies them to `public/assets`. They are inert, but they name the gem's path on the build
machine; an app that cares links `//= link tailwind.css` instead of the whole directory (the doctor accepts both).

## Doctor

`asset_pipeline` names the detected pipeline: Propshaft, Sprockets (sprockets and sprockets-rails versions; below 4 is a warning), both (warning), or none
(warning). For Sprockets it also checks that `app/assets/config/manifest.js` exists and links the builds directory or
`tailwind.css`, because Sprockets refuses `stylesheet_link_tag "tailwind"` otherwise. The existing `propshaft stub filter` check
already says "not applicable" without Propshaft, so the hook warning appears only where Propshaft is in use.

## Follow-ups (not done here, by Owns)

- CI: done by #204, see dev/decisions/ci-smokes.md.
- CHANGELOG and README belong to docs-sync #181; the user-facing text is posted as a `shared` note on #177. The Sprockets user must have
  `//= link_tree ../builds` (or `//= link tailwind.css`) in `app/assets/config/manifest.js`.
- Sprockets also puts the gem's `app/assets/tailwind` folder on its load path (harmless: it is served only if linked).

## Edits outside this item's Owns

`lib/phlex/shadcn/engine.rb` (the boot guard, the `require_relative` and a `phlex_shadcn.sprockets` initializer),
`test/smoke/clean_app.rb` and `test/smoke/runner.rb` (`--assets sprockets`, and a check that every linked `/assets` file answers 200
in all smokes). They belong to js-bundlers (#175, merged); recorded as a blocker note on #177 and in the PR.

The manifest path lives in `lib/generators/phlex/shadcn/install/sprockets_manifest.rb` (new, outside Owns) only because gem_check forbids
`app/...` literals outside the generators; the audit suggested inlining it, which would turn that gate red.
