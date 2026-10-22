---
name: ruby-gem-conventions
description: "Rules for Ruby gems that live in or are extracted from the Papyro monorepo (first: chadcn): standalone code, namespacing, public API, optional Rails integration, assets, packaging, licensing, tests and release hygiene. Use when creating or editing files under `gems/**`, a `*.gemspec`, gem Ruby/JS/CSS files, or auditing a gem."
---

# Ruby gem conventions

Applies to code under `gems/**` and to any repository whose root has a `*.gemspec`. Papyro-specific skills (controller, operation-pattern, presenter-pattern, models, pundit-auth, i18n) do NOT apply inside a gem; this skill, `naming-conventions` (generic rules only, see its library exception), `stimulus`/`radix-stimulus` for JS and `testing` (Minitest style) do. Mechanical rules are enforced by `ruby .claude/scripts/gem/gem_check.rb --gem-dir <dir>`; the code in brackets is its finding.

## Quick Rules

Cite as `ruby-gem-conventions R<n>`.

R1. **Standalone.** The gem's own test suite runs without the host app, a database or fixtures, and no gem file references a host-only constant, or a host path outside the exceptions R15 lists. `[GEM_HOST_CONSTANT, GEM_ESCAPES_ROOT]` → detail: Standalone
R2. **Core is plain Ruby/Phlex.** Rails (`Rails`, `ActionView`, `ActionController`, `ActiveRecord`) appears only in the integration files (engine, railtie, generators, rake tasks), loaded conditionally with `if defined?(Rails::Engine)`. `[GEM_RAILS_REFERENCE]` → detail: Layers
R3. **Declare what you use.** Every library namespace used in the code has its gem as a runtime dependency; ActiveSupport extensions are either avoided in core or `activesupport` is declared (or required explicitly). Runtime dependencies are minimal and have lower bounds. `[GEM_UNDECLARED_DEPENDENCY, GEM_ACTIVESUPPORT_EXT]` → detail: Dependencies
R4. **One namespace, file = constant.** `chadcn` is `Chadcn` in `lib/chadcn.rb` and `lib/chadcn/**`; loaded with `Zeitwerk::Loader.for_gem`; one constant per file. No `V2`/`Ui`/project names in the gem. No monkey patches of Ruby, Phlex or Rails classes (the recorded exceptions under Namespacing are guarded, switchable and carry a removal condition); no global mutable state (the recorded memo-cache exception under Namespacing is the only kind allowed); configuration only through one `Chadcn.configure { |config| ... }` object with defaults. → detail: Namespacing
R5. **The public API is a promise.** Public classes and methods are documented (YARD); everything else is `private` or `@api private`. The 1:1 shadcn component API (`Dialog::Content`, `as_child:`, kwargs) is the contract. A snapshot test of the public surface fails on any unreviewed change. → detail: Public API
R6. **Semver, changelog, deprecations.** `lib/chadcn/version.rb` is the single version source; `CHANGELOG.md` follows Keep a Changelog; removals are deprecated (one warning, one minor) first. → detail: Releases
R7. **Package only the gem.** Complete gemspec metadata (name, version, summary, description, authors, license, homepage, `required_ruby_version`, `source_code_uri`, `changelog_uri`, `rubygems_mfa_required`), each URI well-formed and, on GitHub, shaped `https://github.com/<owner>/<repo>/(blob|tree)/<ref>/<path>`, derived from one `repository`/`gem_path` pair at the top of the gemspec; `spec.files` lists runtime files (lib, app assets/javascript, config, vendor) plus what the README links to (top-level `docs/*.md`, `.yardopts`, LICENSE, README, CHANGELOG, notices); tests, the dev kit (oracle, parity harness, React catalog, scenarios, dummy app, `_probe_*` and `theme_panel` controllers), nested docs apps, `tmp` and `node_modules` never ship; `gem build` prints no warnings and a packaging test inspects the built gem. `[GEMSPEC_*, GEMSPEC_DEV_MATERIAL, GEMSPEC_METADATA]` → detail: Packaging
R8. **Credit what you derive from.** `LICENSE` plus `THIRD_PARTY_NOTICES.md` with the licenses of shadcn/ui (MIT), Radix (MIT) and Lucide (ISC) as soon as code derives from them. `[GEMSPEC_LICENSE, GEM_NOTICES]` → detail: Licensing
R9. **Assets belong to the gem.** JS controllers and primitives, CSS theme files and vendored libraries ship inside the gem and are wired by the engine (importmap pins, asset paths) and the install generator; nothing assumes a host path. Tailwind 4 only generates the utility classes found in the gem's Ruby files if the host CSS has an `@source` entry for the gem, so the generator writes it and a check proves it. Host-only CSS (`legacy-compat`) stays in the host. → detail: Assets
R10. **Test the promise.** Minitest, no DB. CI matrix over supported Ruby, Rails and Phlex versions; a plain-Phlex smoke test with Rails not loaded; a clean-app smoke test (`rails new`, install, render a Button and a Dialog, run one parity scenario); the port's parity gates keep running against the gem from the dev kit. `[GEM_NO_TESTS]` → detail: Testing
R11. **Gem style.** Own RuboCop config (rubocop-minitest, -performance, -rake, gemspec cops), `# frozen_string_literal: true`, keyword arguments in public APIs, no output (`puts`/`pp`) outside rake tasks and generators, never `rescue Exception`; `naming-conventions` R2, R6, R7, R11, R12 apply. → detail: Style
R12. **Supply chain.** `bundler-audit` clean, no network access at load or render time, no `eval`/`send` on caller input, MFA required for the gem owner. Publishing to RubyGems and pushing tags are human steps (`needs-human`). → detail: Security
R13. **Do not outrun the declared Ruby.** Use only language features available in `required_ruby_version`; the CI matrix proves it. → detail: Compatibility
R14. **README is the first test.** Install, Rails and non-Rails setup, Tailwind `@source`, theme file, Stimulus registration, upgrade notes. A reader can render a Button in a fresh app by following only the README (the clean-app smoke test follows the same steps). → detail: Docs
R15. **Name host paths on purpose, never around the rule.** Only code whose job is to inspect the host may name a host path (`app/assets/...`, `app/javascript/...`, `app/views/...`, `app/components/...`): the Rails integration files (engine, railtie, generators, rake tasks) freely, the doctor (`lib/chadcn/doctor/**`) with a same-line marker `# gem_check:allow GEM_ESCAPES_ROOT -- <reason without quotes>`. Core code never names one. `gem_check` lexes string literals, so `File.join("app", "assets", ...)`, `.join` chains, `Pathname("app") / "assets"`, `%w[]` lists, interpolation, `+`/`<<`/adjacent concatenation, `./app/...` and a bare `"app/assets"` are findings like a plain literal, and the marker is the only sanctioned way for the doctor to name a host path. Any spelling the script cannot see (for example a paren-less `File.join "app", "assets"`; the list of gaps is not exhaustive) is still a violation, and a heredoc body starting with a path is flagged but cannot carry a marker, so even the doctor writes it as a quoted literal: reviewers cite R15. `[GEM_ESCAPES_ROOT]` → detail: Host paths

## Standalone

The extraction proof is mechanical: run the gem's tests from its own directory with only its Gemfile, plus `gem_check.rb`. Anything the host provided implicitly (`Components::Base`, helpers from `Phlex::Rails::Helpers`, `Rails.root`, fixtures, Zeitwerk roots) is either moved into the gem, replaced by an explicit dependency, or deleted.

## Layers

| Layer | Allowed to know | Files |
|---|---|---|
| Core | Ruby, `phlex`, `tailwind_merge` (and `activesupport` only if declared) | `lib/chadcn/**` except below |
| Rails integration | Rails, importmap, Tailwind build | `lib/chadcn/engine.rb`, `railtie.rb`, `lib/generators/**`, `lib/tasks/**` |
| Dev kit (not packaged) | everything | `dev/**`: oracle, parity harness, specs, scenarios, React catalog, scripts |

The doctor (`lib/chadcn/doctor/**`) is Core but may name host paths under R15, with the same-line marker.

## Dependencies

`phlex ">= 2.x"` and `tailwind_merge` are the expected runtime dependencies; `lucide` icons are vendored data, not a dependency. Choose bounds from what CI proves, not from what is installed locally. Dev tooling (rubocop, minitest, bundler-audit, rake) is in the Gemfile, not the gemspec runtime list.

## Namespacing

`Chadcn::Button`, `Chadcn::Dialog::Content`. Stimulus identifiers use the `chadcn--` prefix, matching `app/javascript/controllers/chadcn/<name>_controller.js` inside the gem. A rename (for example from `Components::V2`) is a mechanical, reviewed change and is followed by the full parity gates: the DOM must not change.

Recorded exceptions to "no monkey patches" (each one guarded by a method and arity check, off through one `config.chadcn` option, logged instead of failing when the hook is gone, and named here with the condition for its removal):

- `Chadcn::Engine::TailwindStubFilter` (`lib/chadcn/engine/tailwind_stub_filter.rb`) prepends `Propshaft::LoadPath#without_dotfiles` to hide the stubs tailwindcss-rails writes into `app/assets/builds/tailwind/`. Off: `config.chadcn.hide_tailwind_stubs = false`. Remove when tailwindcss-rails stops writing stubs inside an asset root or Propshaft gains a per-file exclusion.

Recorded exception to "no global mutable state" (R4): a process-wide memo is allowed only when ALL hold: it is a pure function of its arguments (same input, same output, so a hit is indistinguishable from a miss); it is bounded (a hard size limit, cleared or evicted when full, because callers can pass arbitrary strings); every read and write in gem code goes through one `Mutex` created at load time (not lazily with `||=`); it is `@api private` and no caller code reads, mutates or resets it (an `@api private` reader used only by the gem's own cache test is tolerated); and it holds no configuration, request or host state. The instance is the `Base#cn` result cache (`CN_CACHE_LIMIT`, PR #189). `Chadcn::Base.tw_merger` is the second instance: one `TailwindMerge::Merger` with default configuration, assigned when `base.rb` loads (Zeitwerk autoload, serialized by Ruby, so threads racing on first use cannot build several; a lazy `||=` could), bounded and thread-safe through the merger's own internal LRU (`LruRedux::ThreadSafeCache`) rather than through `CN_CACHE_LOCK`. Process-wide state lives in private constants of `Base` (`TW_MERGER`, `CN_CACHE`, `CN_CACHE_LOCK`), never in class-level instance variables, so every subclass shares the one instance by design. The `@api private` test hooks are `cn_cache` (a frozen snapshot taken under the lock, never the live hash) and `clear_cn_cache` (under the lock); `test/chadcn/base_cache_test.rb` proves first-use thread safety in a fresh process. A new memo outside these conditions violates R4 and needs its own entry here with a removal or revisit condition.

## Host paths

`gem_check` (`GEM_ESCAPES_ROOT`) rejects a hard-coded host path literal in any scanned gem Ruby file (`lib/**/*.rb`, `app/**/*.rb`) that is not Rails integration (R1, R9). Some code inspects the host on purpose: the generators (already exempt) and the doctor, which reads `app/assets/tailwind/application.css` and the host bundle files. For the doctor the explicit form is a marker on the same line as the literal:

```ruby
DEFAULT_CSS = "app/assets/tailwind/application.css" # gem_check:allow GEM_ESCAPES_ROOT -- the doctor reads the host stylesheet
```

The allowlist is narrow and tested both ways: exact rule id, a required reason after `--`, only files matching `HOST_PATH_ALLOW_GLOBS` (`lib/chadcn/doctor/**/*.rb`), same line only, as the line's trailing comment with a quote-free reason (marker text inside a string never counts); the same literal anywhere else still fails, and a marker never allows a `require_relative` that leaves the gem. The marker must be a real comment (Ripper), not a `#` inside a `%w[]` list or heredoc, and the check runs on lexed literals, so building the path with `File.join`, `%w[]`, interpolation or concatenation is no longer a way around it: it is a finding, and the marker is the only sanctioned form. Known gaps (not exhaustive): a paren-less `File.join "app", "assets"` is not seen, a heredoc body starting with a path is flagged and cannot carry a marker, and a syntax error gets no finding of its own; a gap is still a violation of R15. The maintainer kept the allowlist (#223). Why: `dev/decisions/gem-check-host-paths.md`.

## Public API

Anything a README example, a spec or a consumer's view calls is public. Keep the set small and listed. The snapshot test dumps public constants and public instance/class methods to a reviewed file; a diff in a PR means a deliberate API decision.

## Releases

Pre-1.0 versions still follow semver for the documented API. Record the shadcn registry version the port tracks in the changelog entry of each release. A release is: version bump PR, changelog, tagged commit, `gem build`, `gem push` by a maintainer with MFA. Agents prepare everything up to the build and stop.

## Packaging

`gem build *.gemspec` must succeed without warnings and `gem_check.rb` must pass. Check the file list with `gem spec <built.gem> files`. Keep binary or generated artifacts out unless they are the product. `test/packaging/packaging_test.rb` builds the gem and asserts on `Gem::Package#spec.files`: every `docs/` link of README/CHANGELOG and `.yardopts` is in, no dev controller is.

## Licensing

Copy the license text of each upstream project into `THIRD_PARTY_NOTICES.md` with its copyright holder and what in the gem derives from it. The class strings copied verbatim from shadcn/ui are derived code.

## Assets

JS: ES modules under the gem's `app/javascript/chadcn/`, pinned by the engine's `config/importmap.rb` (and published as an npm package later if bundler-based hosts need it). CSS: the theme file, token mapping, presets and vendored animation CSS ship in the gem; the install generator imports them and adds the Tailwind `@source` line. Host customisation goes through the theme file and CSS variables, never through patching gem files.

## Testing

The unit tests render components to HTML strings and assert structure; the parity gates (oracle compare in a real browser) prove styles and behavior. Both run in CI; only the unit tests need no browser.

## Style

Follow the patterns already in the codebase; run the gem's RuboCop. Generated helper methods (`Base.const_added`) are documented in the README and covered by a unit test per component family.

## Security

No secrets in the repository or gem. Treat every rendered attribute as untrusted: attributes are escaped by Phlex; the `as_child` merge never evaluates strings.

## Compatibility

The matrix lives in CI config. When a dependency range is widened, add it to the matrix in the same PR.

## Docs

README plus generated per-component pages (from specs) can come later; the README and CHANGELOG are required for the first release.
