# Compatibility

What [chadcn](../README.md) supports today, what CI proves, and what happens when Phlex 3 ships.

## Supported versions

| Dependency | Supported | Where it is declared |
|---|---|---|
| Ruby | 3.3, 3.4 and 4.0 (`>= 3.3`) | `required_ruby_version` in the gemspec; the CI matrix |
| Phlex | `phlex ~> 2.3` (2.3 up to, not including, 3.0) | `add_dependency "phlex", "~> 2.3"` |
| tailwind_merge | `~> 1.4` | gemspec |
| zeitwerk | `~> 2.7` | gemspec |
| Rails (optional) | `~> 8.1` | the engine loads only when `Rails::Engine` is defined; CI runs the engine tests on the locked Rails 8.1 and, on the freshly resolved runs (the Phlex 2.3 floor) and the clean `rails new` app, on the newest Rails 8.x allowed by `~> 8.1` |
| Tailwind CSS | 4 (with Rails, `tailwindcss-rails` 4.3.0 or newer) | the components use Tailwind 4 syntax and theme variables; 4.3.0 is the first `tailwindcss-rails` that bundles an engine's CSS (`tailwindcss:engines`), and `chadcn:doctor` fails with `tailwindcss-rails X found, it cannot bundle an engine's CSS before 4.3.0` below it |
| Stimulus | 3 (`@hotwired/stimulus`) | needed only by the interactive components |

The gem itself depends only on `phlex`, `tailwind_merge` and `zeitwerk`. Rails, `phlex-rails`, `importmap-rails` and `tailwindcss-rails` are the host app's choice, not dependencies.

## Asset and JavaScript pipelines

| Rails | Assets | JavaScript | Status |
|---|---|---|---|
| 8.1 | Propshaft | importmap | supported; the clean-app smoke runs it in CI |
| 8.1 | Propshaft | esbuild (jsbundling-rails) | supported; covered by a CI smoke (`bin/smoke --app --js esbuild`, job `clean-app-variants`) |
| 8.1 | Sprockets 4 (sprockets-rails 3.5) | importmap | supported; covered by a CI smoke (`bin/smoke --app --assets sprockets`, job `clean-app-variants`) |
| 8.1 | Sprockets | esbuild | not covered: no smoke proves it |
| any | Sprockets below 4, or Sass/SCSS instead of the Tailwind CLI | any | not supported |

The install generator chooses the JavaScript pipeline with `--js auto|importmap|esbuild`, and `bin/rails chadcn:doctor` names the
asset pipeline and checks the setup; both are described in the README.

## What CI proves

The gem workflow runs the plain-Phlex suite, the Rails engine and generator suite, RuboCop, the dependency audit, the YARD coverage check and the packaging check on every Ruby in the table, each against two Phlex versions:

- the current Phlex 2.x (the committed `Gemfile`);
- Phlex 2.3, the floor of the constraint (`test/smoke/gemfiles/phlex_2.3.gemfile` in the repository).

A plain-Phlex smoke renders the components with Rails not loaded, and clean-app jobs follow the README in a new Rails app and drive a browser scenario (importmap, plus esbuild and Sprockets in `clean-app-variants`). A version outside this matrix may work, but nothing tests it and bugs reported against it are triaged after those inside it.

## Phlex 3

Phlex 3 is not supported today. The gemspec constraint `~> 2.3` makes Bundler refuse it, on purpose: a new major can change the rendering API the components are written against, and we do not promise behavior we have not run.

The plan when Phlex 3 is released:

1. Run the gem suite and the oracle comparison against the first Phlex 3 release candidate in a branch, without changing the published constraint.
2. If the components work unchanged, widen the constraint (`">= 2.3", "< 4"`) and add Phlex 3 to the CI matrix next to 2.3 and the current 2.x. This is a minor release.
3. If they need changes, support both majors for as long as the changes can be written for both. Where one codebase cannot serve both, the release that drops Phlex 2 is a breaking release of this gem (a major once the gem is 1.0; before that, a minor release with a "Changed (breaking)" entry, as in the shadcn tracking policy), announced in the CHANGELOG at least one minor release ahead (the deprecation window), and the previous release line keeps receiving fixes for security and rendering bugs for six months.

Until step 2 ships, the answer to "does it work with Phlex 3?" is no.

## Ruby, Rails and Tailwind

- A Ruby version is dropped only in a minor release at the earliest after upstream end of life, and the CHANGELOG announces it one release ahead. Ruby 3.3 is the floor today: Ruby 3.2 (upstream end of life 2026-03-31) is not supported from the first release, so no release ever claimed it.
- A new Rails or Ruby release is added to the CI matrix when it is available on CI; support is claimed from the first green run.
- The Tailwind classes are copied verbatim from shadcn/ui, which targets Tailwind 4. A Tailwind major is handled like a Phlex major: evaluated first, claimed only after CI covers it. How upstream changes reach the gem is described in the shadcn tracking policy (`dev/decisions/shadcn-tracking.md` in the repository).
