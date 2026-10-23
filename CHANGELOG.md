# Changelog

All notable changes to this gem are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the gem adheres to [Semantic Versioning](https://semver.org/).

Each release records the shadcn/ui registry it tracks (`dev/decisions/shadcn-tracking.md` in the repository): the style, the `shadcn`
CLI version and the `@shadcn/react` version the oracle was extracted with, the digest of the extracted oracle (the React sources and
manifests every component is compared against), the number of oracle components, the fetch date, and the versions of Radix UI
(`radix-ui`), Lucide (`lucide-react`) and the vendored `@floating-ui/dom`.

## [Unreleased]

Tracks shadcn/ui style `new-york-v4` (shadcn CLI 4.21.4, `@shadcn/react` 0.3.1), oracle digest `7de7073d0e253001`
(61 components, fetched 2026-10-10); Radix UI through `radix-ui` 1.7.0, Lucide icons from `lucide-react` 0.577.0,
positioning with `@floating-ui/dom` 1.8.0 (vendored).

### Added

- `Chadcn::Calendar` (`Calendar::DayButton`): shadcn's react-day-picker calendar as a dependency-free port (no react-day-picker, no
  date-fns): native `Date` and `Intl` only. Single, multiple and range modes, min/max, disabled matchers, outside days, fixed weeks, week
  numbers, `label` and dropdown captions, several months, `dir: "rtl"`, month and weekday names and first day of week from `Intl` (English
  and Spanish verified), and react-day-picker's grid keyboard model (arrows, PageUp/PageDown, Shift+PageUp/PageDown, Home/End) in the
  `chadcn--calendar` controller on the new pure `date_grid` primitive. `name:` renders ISO 8601 (`YYYY-MM-DD`) hidden inputs; selection and
  month changes are the `chadcn--calendar:select` and `:month-change` events. Compared with react-day-picker 10.0.2 in 169 parity scenarios.
  shadcn's date picker is a block, not a registry component, so the date picker is a documented, tested composition (Popover, Button,
  Calendar and an external hidden ISO input; `input:`, `label:` and `close_on_select:`), not a class (see docs/form-controls.md). The
  gem now ships 54 component roots (llms drift test count 53 to 54).
- `Chadcn::Toaster` (`Sonner::Toaster`) and `Sonner::Toast`: shadcn's sonner Toaster as a dependency-free port (no sonner, no
  React). A Stimulus controller (`chadcn--sonner`) on the new `toast_stack` primitive reproduces the library's stacking, auto-dismiss,
  pause on hover, swipe, hotkey (Alt+T) and `data-*` state; the stylesheet ships as `app/assets/tailwind/chadcn/sonner.css`. Toasts
  come from `window.Toaster` (sonner's `toast` API), the flash (`Toaster.new(flash:)`), a Turbo Stream that appends a `Sonner::Toast` to
  the Toaster id, or the `chadcn--sonner:show` event; dismiss, auto-close, action and cancel are events. Compared with sonner in 81
  parity scenarios; `error` toasts are also announced through an assertive live region (recorded deviation).
- `Chadcn::Command` (with `Command::Dialog`, `Input`, `List`, `Empty`, `Group`, `Item`, `Shortcut`, `Separator`): shadcn's
  cmdk palette without cmdk. A Stimulus controller (`chadcn--command`) reproduces cmdk's DOM (`cmdk-*` attributes, `aria-activedescendant`),
  keyboard model (arrows, Home/End, Ctrl+N/P/J/K, Enter) and group hiding, and ranks items with the new built-in `scorer` primitive
  (subsequence match with prefix and word-boundary bonuses and diacritic folding); the dialog variant renders `Chadcn::Dialog`.
  Compared with cmdk in 128 parity scenarios; selection and search changes are events (`chadcn--command:select`, `:search-change`,
  `:value-change`).
- `Chadcn::Combobox` (`Input`, `Trigger`, `Clear`, `Value`, `Content`, `List`, `Item`, `Group`, `Label`, `Collection`, `Empty`,
  `Separator`, `Chips`, `Chip`, `ChipsInput`): shadcn's Base UI combobox with single and multiple (chips) selection, grouped items,
  clear button, `filter: "fuzzy"` (default, the scorer) or `"contains"` (Base UI's matching), and native form submission through hidden
  inputs (`name:`), restored from a Turbo snapshot. Positioned by the new `anchor_positioner` primitive (Base UI's anchor positioning,
  next to the Radix `positioner`). Compared with Base UI in 151 parity scenarios; no new JavaScript dependency (no cmdk, fuse.js or
  Base UI).
- Primitives `scorer` (fuzzy match and ranking, with its own unit tests) and `anchor_positioner`.
- `bin/rails chadcn:doctor` diagnoses a host app's chadcn setup with one PASS/WARN/FAIL line per check and a one-line fix under each warning or failure
  (asset pipeline, ejected components, engine bundle, JavaScript pipeline, Phlex versions, Propshaft stub filter, source block,
  Stimulus controllers, Tailwind, theme files and theme import). `chadcn:doctor[json]` or `JSON=1` prints JSON for CI and
  agents, `CSS=path` points it at another Tailwind entry file, and it exits 1 when any check fails (warnings do not fail it).
- `rails g chadcn:install --js auto|importmap|esbuild`: the generator detects the JavaScript pipeline (`auto`, the default: a
  `config/importmap.rb` means importmap, `package.json` with jsbundling-rails or an esbuild build script means esbuild; with neither it
  writes no JavaScript). For
  jsbundling-rails/esbuild apps, which have no importmap, it copies the gem's controllers and primitives into `app/javascript` (managed
  copies with relative imports), writes `controllers/chadcn/index.js`, adds the import to `application.js` and adds `@floating-ui/dom`
  with yarn, pnpm, bun or npm; the doctor fails when a copy is stale (`dev/decisions/js-bundlers.md`).
- Sprockets 4 support: with Sprockets the engine declares the gem's JavaScript in `config.assets.precompile`, and the doctor's
  `asset pipeline` check names the pipeline and checks that `manifest.js` links the Tailwind build. The supported matrix (Propshaft with
  importmap or esbuild, Sprockets 4 with importmap; Sprockets with esbuild not covered; Sprockets below 4 unsupported) is in
  `docs/compatibility.md` and `dev/decisions/sprockets.md`.
- `rails g chadcn:eject NAME...` copies a component (a compound one with all its parts; `dialog/content` ejects one part) into
  `app/components/chadcn`, where it replaces the gem's file. Options `--list`, `--diff`, `--force`, `--skip`, `--pretend` and
  `--dir`; the copy's header records the gem version and a digest, and the doctor's `ejected components` check warns on a stale copy.
  New public configuration: `Chadcn::Configuration#override_dir` and `#override_dir=` (Rails: `config.chadcn.override_dir`
  in `config/application.rb` or `config/environments/*.rb`; plain Phlex: the environment variable `CHADCN_OVERRIDE_DIR`), and
  `Chadcn::Configuration::LateSettingError`, raised when the directory is set after the components loaded. Editing an ejected
  file reloads; adding or removing one needs a restart (`dev/decisions/eject-override.md`).
- `llms.txt`, `llms-full.txt` and `skills/chadcn/SKILL.md` ship with the gem, generated from the YARD docs and the Stimulus
  controllers (`rake llms:generate`); `rake llms:check` and `rake test` fail when they drift.
- `bin/demo` serves the component catalog of `dev/dummy` on a free port, and `bin/bench` prints allocations and time per render of
  representative components (`--check` compares allocations with `dev/bench/baseline.json`). Both belong to the dev kit and are not
  packaged.
- `docs/compatibility.md`: the supported Ruby, Phlex, Rails, Tailwind and Stimulus versions, the asset pipelines, what CI proves and the
  Phlex 3 policy; the policy for tracking shadcn/ui releases is `dev/decisions/shadcn-tracking.md` (repository only).
- Gem skeleton: Zeitwerk loader, version, license files and a standalone test harness.
- The 54 ported components (the four above included) as `Chadcn::<Name>` with their parts nested under the root (`Chadcn::Dialog::Content`),
  generated yielded-root helpers (`dialog.content { ... }`), `as_child:` with Radix Slot semantics and `**attrs` merging on every
  part; the Stimulus controllers `chadcn--<name>` and the shared primitives they build on.
- Rails engine (loaded only when `Rails::Engine` is defined): importmap pins for the Stimulus controllers, primitives and vendored
  floating-ui, asset paths, and the Tailwind entry `app/assets/tailwind/chadcn/engine.css` bundled by tailwindcss-rails.
  The engine's Tailwind inputs are excluded from Propshaft so they are never served or linked.
- `Chadcn.configure` / `Chadcn::Configuration#theme_dir`; Rails apps set `config.chadcn.theme_dir`
  (default `app/assets/tailwind/theme`).
- Theme tooling: `Chadcn::Theme` and the rake tasks `chadcn:theme:list|use|import|check` (short `theme:*` aliases;
  turn them off with `config.chadcn.theme_task_aliases = false`).
- `rails g chadcn:install`: idempotent marker block in the Tailwind entry file (engine bundle and theme imports; the engine's
  `engine.css` carries the `@source` for the gem's Ruby files) and
  the default theme files; exits non-zero on malformed input.
- YARD documentation of the public API of every component family (display, form controls, disclosure and navigation, overlays,
  menus and select), with an example per root and the generated helpers listed on their owner class; implementation details are
  `@api private`.
- README covering install, Rails and non-Rails setup, Tailwind `@source`, the theme file and presets, Stimulus registration,
  `as_child` and the generated helpers, and upgrade notes; `.yardopts` publishing only the documented promise (`--hide-api private`,
  `--no-private`); one guide per family under `docs/` plus `docs/api-conventions.md`.
- Localizable default strings, as keyword arguments whose defaults are the exact React strings (the DOM does not change):
  `Pagination::Previous` (`label:`, `aria_label:`), `Pagination::Next` (`label:`, `aria_label:`), `Pagination::Ellipsis` (`label:`),
  `Breadcrumb::Ellipsis` (`label:`), `Dialog::Content`, `Dialog::Footer` and `Sheet::Content` (`close_label:`), `Sidebar::Trigger`
  (`label:`), `Sidebar` (`mobile_title:`, `mobile_description:`) and `Slider` (`min_label:`, `max_label:`, `value_label:`, a
  `Kernel.format` template with `%<index>d` and `%<count>d` for three or more thumbs).
- The `chadcn--theme` controller reads its `localStorage` key from `data-chadcn--theme-storage-key-value` (default `shadcn-theme`).
- The built gem includes `docs/*.md` and `.yardopts`; `gem_check` gained the rules `GEMSPEC_DEV_MATERIAL` and `GEMSPEC_METADATA`.
- CI: a Ruby 3.3 to 4.0 matrix against the current Phlex 2.x and the Phlex 2.3 lower bound, a plain-Phlex smoke, a clean-app
  smoke, a `js-tests` job running the Stimulus browser suite (`test/javascript`, the suite the host's `bin/rails test:javascript`
  runs) and a `docs` job that renders every Ruby example of the README and `docs/` (`bin/smoke --docs`).
- CI: the esbuild and Sprockets clean-app smokes (`bin/smoke --app --js esbuild` and `--assets sprockets`) run on every gem change
  (job `clean-app-variants`, `dev/decisions/ci-smokes.md`).
- `bin/bench --check --expect-improvement SCENARIO=PERCENT[,...]` exits 1 unless each named scenario allocates at least that percent
  less than a baseline: `dev/bench/baseline.json`, or another one given with `--against FILE_OR_GIT_REV` (a baseline file or a git
  revision), so a performance change can prove its gain. It compares allocations only and, unlike plain `--check`, never skips when the
  baseline was recorded on another Ruby or Phlex version: it exits 1 and asks for a baseline recorded there.
- `gem_check` accepts a same-line `# gem_check:allow GEM_ESCAPES_ROOT -- reason` marker for an intentional host path, honoured only in
  the doctor (`lib/chadcn/doctor/`); `dev/decisions/gem-check-host-paths.md`.

### Changed

- `rails g chadcn:install` no longer writes an `@source` line into the managed block: the block is now the same on every machine
  (the engine bundle import and the theme import), because the engine's `engine.css` carries a self-relative `@source` for the gem's
  Ruby files and the Tailwind output is byte-identical without the generator's line. Re-run the generator after updating: it rewrites
  the block, and until then `chadcn:doctor`'s `source block` check warns about the leftover `@source` line (it now checks that the block
  imports the engine bundle). The clean-app smoke installs the gem from a `git:` source (a `file://` URL to the checkout) instead of
  `path:`, as a `github:` install lands: outside the app, with no machine-specific path in `application.css`.
- Ruby 3.3 is the minimum (`required_ruby_version >= 3.3`): Ruby 3.2 reached upstream end of life on 2026-03-31, so the
  first release does not claim it (`docs/compatibility.md`).
- Renamed from phlex-shadcn (Phlex::Shadcn) to chadcn (Chadcn). The gem is unreleased, so there is no compatibility alias. Every
  renamed spelling:
  - renamed the gem `phlex-shadcn` to `chadcn` (`gem "chadcn"`, `chadcn.gemspec`, `require "chadcn"`);
  - renamed the module `Phlex::Shadcn` to the top-level `Chadcn` (`Phlex::Shadcn::Dialog::Content` is `Chadcn::Dialog::Content`);
  - renamed the source paths `lib/phlex/shadcn.rb` and `lib/phlex/shadcn/` to `lib/chadcn.rb` and `lib/chadcn/`;
  - renamed the Zeitwerk loader `Loader.for_gem_extension(Phlex)` to `Loader.for_gem` (chadcn is a top-level gem);
  - renamed the generators `phlex:shadcn:install` and `phlex:shadcn:eject` to `chadcn:install` and `chadcn:eject`;
  - renamed the rake tasks `phlex_shadcn:*` to `chadcn:*` (`chadcn:doctor`, `chadcn:theme:*`; the `theme:*` aliases are unchanged);
  - renamed the Rails setting `config.phlex_shadcn` to `config.chadcn`;
  - renamed the environment variables `PHLEX_SHADCN_*` to `CHADCN_*` (for example `CHADCN_OVERRIDE_DIR`);
  - renamed the default override directory `app/components/phlex_shadcn` to `app/components/chadcn` (`config.chadcn.override_dir`,
    `rails g chadcn:eject`): move ejected files there, or set `config.chadcn.override_dir` to the old directory;
  - renamed the managed CSS markers `phlex-shadcn:start` / `phlex-shadcn:end` to `chadcn:start` / `chadcn:end` (re-run
    `rails g chadcn:install`);
  - renamed the theme directory `app/assets/tailwind/phlex-shadcn/` to `app/assets/tailwind/chadcn/`;
  - renamed the engine and its bundle `builds/tailwind/phlex-shadcn` to `builds/tailwind/chadcn`;
  - renamed the agent skill `skills/phlex-shadcn/` to `skills/chadcn/`;
  - renamed the Stimulus prefix `shadcn--` to `chadcn--` (identifiers such as `chadcn--dialog`, their actions, targets, values,
    outlets and events such as `chadcn--sonner:show`);
  - renamed the Phlex data keys `shadcn__` to `chadcn__` (`data: { chadcn__dialog_target: ... }`);
  - renamed the JavaScript paths `app/javascript/controllers/shadcn/` and `app/javascript/shadcn/` to `controllers/chadcn/` and
    `app/javascript/chadcn/` (importmap `under: "chadcn"`, imports `chadcn/primitives/...`).
- The README opens with the chadcn wordmark and tagline and ends with the not-affiliated-with-shadcn notice that keeps the
  shadcn/ui MIT credit; the gemspec summary is "shadcn/ui for Phlex. chadcn go brrrrrr." and its description carries the short
  form of that notice. The brand assets live in `dev/brand/` of the repository (not packaged; the README links them by URL).
- A caller's `data-controller` no longer replaces a component's own: `merge_attrs` (and `as_child`) appends the caller's controller
  names after the component's and de-duplicates them, so `Calendar.new(data: { controller: "x" })` renders
  `data-controller="chadcn--calendar x"` instead of an inert calendar. The component's controller cannot be removed through `data:`
  (not even with `controller: nil`); `data-action` still concatenates and every other `data:` key still lets the caller win
  (`dev/decisions/data-controller-merge.md`). Behavior change for callers who relied on replacing the controller.
- `Chadcn::Overrides` and `Chadcn::JsBundle` (the install generator's JavaScript helper, formerly
  `Generators::JsBundle`) now live under `lib/chadcn/` (`@api private`).
- The signatures printed in `llms-full.txt` and the public-surface snapshot are rendered identically on Ruby 3.3 to 4.0; negative
  keyword defaults no longer print a doubled comma (`align_offset: -4,,`). A default that spans several lines is joined onto one
  line, except line breaks inside a string literal, which are kept; a default that cannot be rendered raises an error naming the method
  and the parameter.
- Behavior change in `chadcn:doctor`: the `tailwind` check now FAILS for tailwindcss-rails older than 4.3.0 (the first release
  that bundles an engine's CSS, `tailwindcss:engines`); hosts on 4.0 to 4.2.x passed before and now exit 1 until they run
  `bundle update tailwindcss-rails`. An unknown format argument (`chadcn:doctor[jsn]`) is rejected with a usage message on
  stderr and exit 1, instead of printing text.
- `bin/check` also runs the `bin/bench` tests (`dev/bench/runner_test.rb`).
- The gem's Zeitwerk loader is set up by an engine initializer that runs before Rails sets its autoload paths, instead of at require
  time, so the override directory of ejected components is known first. `Loader.setup` therefore no longer runs when the gem is
  required in a Rails app; a component referenced before the app initializes (in `config/application.rb`, say) sets the loader up on
  first lookup. Without Rails the loader is still set up at require time.
- `Base#cn` memoizes merged class strings (bounded cache, internal; no public API change), which cut allocations per render:
  `bin/bench` button 57 to 41, card 197 to 119, select 882 to 597, dialog 540 to 378, table 7115 to 4339 (Ruby 4.0.0, Phlex 2.4.1).
- `gem_check` (repo tooling) strips comments with Ruby's lexer (Ripper), so commented-out code no longer triggers or hides a
  finding, and `GEM_ESCAPES_ROOT` now sees a host path written as `%w[app/assets/x]`, `File.join("app", "assets", ...)`, an
  interpolated or concatenated string (`+`, `<<`, adjacent literals, `.join` chains, backslash continuations), `Pathname("app") /
  "assets"` or `./app/...`, not only a quote directly before `app/`. The `# gem_check:allow GEM_ESCAPES_ROOT -- reason` marker keeps
  its meaning but must now be a real comment. Not detected: a paren-less `File.join "app", "assets"`; a heredoc body that starts with
  a host path is flagged and cannot carry a marker (write it as a quoted literal).

Relative to the in-app port (`Components::V2`):

- Stimulus identifiers use the `chadcn--` prefix (`chadcn--dialog`, `data-chadcn--dialog-part`, ...); the controllers live under
  `app/javascript/controllers/chadcn/` and are pinned `under: "controllers/chadcn"`, the shared primitives are imported as
  `chadcn/primitives/<name>`.

Since the first extraction of the gem:

- `Chadcn::Theme`: the public API is the methods `use`, `import`, `check`, `presets`, `dir`, `configured?`, `theme_file`
  and `presets_dir` plus `Theme::Error`, the `COLORS_START` / `COLORS_END` markers, the `REQUIRED` / `ROOT_ONLY` variable lists and
  `MIN_CONTRAST` (a snapshot test pins the whole surface); `parse`, `validate`, `contrast`, `render_colors`, `Palette`, the
  import limits and the value filter are `@api private`. A failure to fetch, read or parse the imported source is a
  `Theme::Error` (a missing `theme.css` stays `Errno::ENOENT`); the `chadcn:theme:*` tasks print either as its message
  (for an invalid theme, the list of errors), without a backtrace, and exit non-zero.
- `Theme.import` is hardened: only `https` URLs (credentials refused), 5 s open and 10 s read timeouts, at most 3 redirects and a
  256 KiB body cap. Values containing `/* */`, `{`, `}`, `;`, a backslash or `url(` are rejected (also by `theme:check` on a
  hand-edited `theme.css`), an unbalanced `:root` or `.dark` block raises `unterminated ... block`, and the `source:` comment written
  into `theme.css` is single-line.
- The `chadcn--theme` controller's default storage key is `shadcn-theme` (it was the host-specific `papyro-theme`; pass
  `data-chadcn--theme-storage-key-value="papyro-theme"` to keep stored choices). Only `light` and `dark` are accepted from storage,
  and blocked or throwing storage degrades to the system preference. A pre-paint script must read the same key.
- `Direction::Provider` without `dir:` or `direction:` keeps the outer direction instead of resetting to `ltr` (a registered
  deviation from React).
- The probe controllers used by the browser tests (`chadcn--_probe-*`) and `chadcn--theme-panel` are no longer packaged, so
  consumer import maps no longer pin them; they live in `dev/dummy`.
- The class-string constants of the form and button components (`Button`, `ButtonGroup`, `Checkbox`, `Input`, `Label`,
  `NativeSelect`, `RadioGroup`, `Switch`, `Textarea`, `Toggle`, `ToggleGroup`) and `Slider::ROOT_CLASS`, `TRACK_CLASS`,
  `RANGE_CLASS` and `THUMB_CLASS` are `@api private` (`VARIANTS`, `SIZES`, `Slider::ORIENTATIONS`, `DIRECTIONS` and
  `THUMB_TRANSFORM` stay public).
- `gemspec` `homepage`, `source_code_uri` and `changelog_uri` are well-formed and derived from one block at the top of the file.

### Fixed

- The engine no longer raises `NoMethodError` at boot in apps without Propshaft (`config.assets.excluded_paths`).
- `Select::Item` no longer needs Nokogiri (text is derived with a quote-aware tag strip); a plain-Phlex `Select` renders, and
  `nokogiri` is not a dependency. YARD builds without warnings.
- Dialog, AlertDialog and Sheet unmount their portaled overlay on `turbo:before-cache`: a cached page has no open modal, scroll
  lock or `aria-hidden` siblings. A dialog open on a visit that keeps the page (a `#hash` link) re-opens after the snapshot.
- `AlertDialog` open on first paint focuses its Cancel button; `HoverCard` with `data-chadcn--hover-card-open-value` follows the
  attribute when it changes.
- Accordion, collapsible, tabs, avatar and scroll-area keep closed bodies, the avatar fallback and no scrollbar in the Turbo
  snapshot and set the live page up again afterwards; `FormBubbleInput` no longer removes a server-rendered input.
- Fresh Rails apps no longer link the Tailwind engine stub (`app/assets/builds/tailwind/*.css`) with `stylesheet_link_tag :app`
  (a browser 404 that also disclosed a filesystem path): the engine hides it through Propshaft's private
  `LoadPath#without_dotfiles` (present in 1.2 and 1.3). With a Propshaft that lacks that method it logs a warning at boot; link
  `"tailwind"` explicitly there.
- A caller's `data-controller` is normalized the same way on every path: strings, symbols, arrays and sets are flattened, split on
  whitespace and de-duplicated, and nil, `false` and blank entries are dropped (an empty result removes the attribute). This now also
  holds for components that have no controller of their own and for `as_child` onto a bare tag.
- `bin/bench` rejects a repeated `--against` (exit 2) and merges a repeated `--expect-improvement` instead of keeping only the last
  one (a scenario named twice exits 2). The default `dev/bench/baseline.json` is validated like an `--against` file: an unreadable or
  malformed one exits 1 with a message (for plain runs, `--json` and `--check` alike; `--record` warns and rewrites it instead), and
  the baseline is validated before anything is measured.
- `chadcn--theme` instances with the same storage key stay in sync: each follows `chadcn--theme:changed` from the others (the event
  detail now also carries `storageKey`) and the `storage` event from other tabs, re-applying without dispatching again, so a stale
  instance no longer re-applies `system` over the stored choice when the OS scheme changes, and one choice is exactly one `changed`
  event.

### Removed

Relative to the in-app port (`Components::V2`):

- The `activesupport` runtime dependency: the core needs only `phlex`, `tailwind_merge` and `zeitwerk`.

[Unreleased]: https://github.com/doncan-orozco/chadcn/commits/main
