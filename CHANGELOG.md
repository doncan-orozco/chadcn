# Changelog

All notable changes to this gem are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the gem adheres to [Semantic Versioning](https://semver.org/).

Each release records the shadcn/ui registry it tracks: the style, the `shadcn` CLI version the oracle was extracted with, and the
digest of the extracted oracle (the React sources and manifests every component is compared against).

## [Unreleased]

Tracks shadcn/ui style `new-york-v4` (shadcn CLI 4.21.4, `@shadcn/react` 0.3.1), oracle digest `7de7073d0e253001`
(61 components, fetched 2026-10-10); Radix UI through `radix-ui` 1.7.0, Lucide icons from `lucide-react` 0.577.0,
positioning with `@floating-ui/dom` 1.8.0 (vendored).

### Added

- `Phlex::Shadcn::Toaster` (`Sonner::Toaster`) and `Sonner::Toast`: shadcn's sonner Toaster as a dependency-free port (no sonner, no
  React). A Stimulus controller (`shadcn--sonner`) on the new `toast_stack` primitive reproduces the library's stacking, auto-dismiss,
  pause on hover, swipe, hotkey (Alt+T) and `data-*` state; the stylesheet ships as `app/assets/tailwind/phlex-shadcn/sonner.css`. Toasts
  come from `window.Toaster` (sonner's `toast` API), the flash (`Toaster.new(flash:)`), a Turbo Stream that appends a `Sonner::Toast` to
  the Toaster id, or the `shadcn--sonner:show` event; dismiss, auto-close, action and cancel are events. Compared with sonner in 81
  parity scenarios; `error` toasts are also announced through an assertive live region (recorded deviation).
- Gem skeleton: Zeitwerk loader, version, license files and a standalone test harness.
- The 51 ported components as `Phlex::Shadcn::<Name>` with their parts nested under the root (`Phlex::Shadcn::Dialog::Content`),
  generated yielded-root helpers (`dialog.content { ... }`), `as_child:` with Radix Slot semantics and `**attrs` merging on every
  part; the Stimulus controllers `shadcn--<name>` and the shared primitives they build on.
- Rails engine (loaded only when `Rails::Engine` is defined): importmap pins for the Stimulus controllers, primitives and vendored
  floating-ui, asset paths, and the Tailwind entry `app/assets/tailwind/phlex-shadcn/engine.css` bundled by tailwindcss-rails.
  The engine's Tailwind inputs are excluded from Propshaft so they are never served or linked.
- `Phlex::Shadcn.configure` / `Phlex::Shadcn::Configuration#theme_dir`; Rails apps set `config.phlex_shadcn.theme_dir`
  (default `app/assets/tailwind/theme`).
- Theme tooling: `Phlex::Shadcn::Theme` and the rake tasks `phlex_shadcn:theme:list|use|import|check` (short `theme:*` aliases;
  turn them off with `config.phlex_shadcn.theme_task_aliases = false`).
- `rails g phlex:shadcn:install`: idempotent marker block in the Tailwind entry file (`@source`, engine bundle, theme import) and
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
- The `shadcn--theme` controller reads its `localStorage` key from `data-shadcn--theme-storage-key-value` (default `shadcn-theme`).
- The built gem includes `docs/*.md` and `.yardopts`; `gem_check` gained the rules `GEMSPEC_DEV_MATERIAL` and `GEMSPEC_METADATA`.
- CI: a Ruby 3.2 to 4.0 matrix against the current Phlex 2.x and the Phlex 2.3 lower bound, a plain-Phlex smoke, a clean-app
  smoke, a `js-tests` job running the Stimulus browser suite (`test/javascript`, the suite the host's `bin/rails test:javascript`
  runs) and a `docs` job that renders every Ruby example of the README and `docs/` (`bin/smoke --docs`).

### Changed

Relative to the in-app port (`Components::V2`):

- Stimulus identifiers use the `shadcn--` prefix (`shadcn--dialog`, `data-shadcn--dialog-part`, ...); the controllers live under
  `app/javascript/controllers/shadcn/` and are pinned `under: "controllers/shadcn"`, the shared primitives are imported as
  `shadcn/primitives/<name>`.

Since the first extraction of the gem:

- `Phlex::Shadcn::Theme`: the public API is the methods `use`, `import`, `check`, `presets`, `dir`, `configured?`, `theme_file`
  and `presets_dir` plus `Theme::Error`, the `COLORS_START` / `COLORS_END` markers, the `REQUIRED` / `ROOT_ONLY` variable lists and
  `MIN_CONTRAST` (a snapshot test pins the whole surface); `parse`, `validate`, `contrast`, `render_colors`, `Palette`, the
  import limits and the value filter are `@api private`. A failure to fetch, read or parse the imported source is a
  `Theme::Error` (a missing `theme.css` stays `Errno::ENOENT`); the `phlex_shadcn:theme:*` tasks print either as its message
  (for an invalid theme, the list of errors), without a backtrace, and exit non-zero.
- `Theme.import` is hardened: only `https` URLs (credentials refused), 5 s open and 10 s read timeouts, at most 3 redirects and a
  256 KiB body cap. Values containing `/* */`, `{`, `}`, `;`, a backslash or `url(` are rejected (also by `theme:check` on a
  hand-edited `theme.css`), an unbalanced `:root` or `.dark` block raises `unterminated ... block`, and the `source:` comment written
  into `theme.css` is single-line.
- The `shadcn--theme` controller's default storage key is `shadcn-theme` (it was the host-specific `papyro-theme`; pass
  `data-shadcn--theme-storage-key-value="papyro-theme"` to keep stored choices). Only `light` and `dark` are accepted from storage,
  and blocked or throwing storage degrades to the system preference. A pre-paint script must read the same key.
- `Direction::Provider` without `dir:` or `direction:` keeps the outer direction instead of resetting to `ltr` (a registered
  deviation from React).
- The probe controllers used by the browser tests (`shadcn--_probe-*`) and `shadcn--theme-panel` are no longer packaged, so
  consumer import maps no longer pin them; they live in `dev/dummy`.
- The class-string constants of the form and button components (`Button`, `ButtonGroup`, `Checkbox`, `Input`, `Label`,
  `NativeSelect`, `RadioGroup`, `Switch`, `Textarea`, `Toggle`, `ToggleGroup`) and `Slider::ROOT_CLASS`, `TRACK_CLASS`,
  `RANGE_CLASS` and `THUMB_CLASS` are `@api private` (`VARIANTS`, `SIZES`, `Slider::ORIENTATIONS`, `DIRECTIONS` and
  `THUMB_TRANSFORM` stay public).
- `gemspec` `homepage`, `source_code_uri` and `changelog_uri` are well-formed and derived from one block at the top of the file.

### Fixed

- `Select::Item` no longer needs Nokogiri (text is derived with a quote-aware tag strip); a plain-Phlex `Select` renders, and
  `nokogiri` is not a dependency. YARD builds without warnings.
- Dialog, AlertDialog and Sheet unmount their portaled overlay on `turbo:before-cache`: a cached page has no open modal, scroll
  lock or `aria-hidden` siblings. A dialog open on a visit that keeps the page (a `#hash` link) re-opens after the snapshot.
- `AlertDialog` open on first paint focuses its Cancel button; `HoverCard` with `data-shadcn--hover-card-open-value` follows the
  attribute when it changes.
- Accordion, collapsible, tabs, avatar and scroll-area keep closed bodies, the avatar fallback and no scrollbar in the Turbo
  snapshot and set the live page up again afterwards; `FormBubbleInput` no longer removes a server-rendered input.
- Fresh Rails apps no longer link the Tailwind engine stub (`app/assets/builds/tailwind/*.css`) with `stylesheet_link_tag :app`
  (a browser 404 that also disclosed a filesystem path): the engine hides it through Propshaft's private
  `LoadPath#without_dotfiles` (present in 1.2 and 1.3). With a Propshaft that lacks that method it logs a warning at boot; link
  `"tailwind"` explicitly there.

### Removed

Relative to the in-app port (`Components::V2`):

- The `activesupport` runtime dependency: the core needs only `phlex`, `tailwind_merge` and `zeitwerk`.

[Unreleased]: https://github.com/doncan-orozco/papyro/commits/main/gems/phlex-shadcn
