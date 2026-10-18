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

- Gem skeleton: Zeitwerk loader, version, license files and a standalone test harness.
- The 50 ported components as `Phlex::Shadcn::<Name>` with their parts nested under the root (`Phlex::Shadcn::Dialog::Content`),
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

### Changed

Relative to the in-app port (`Components::V2`):

- Stimulus identifiers use the `shadcn--` prefix (`shadcn--dialog`, `data-shadcn--dialog-part`, ...); the controllers live under
  `app/javascript/controllers/shadcn/` and are pinned `under: "controllers/shadcn"`, the shared primitives are imported as
  `shadcn/primitives/<name>`.

### Removed

Relative to the in-app port (`Components::V2`):

- The `activesupport` runtime dependency: the core needs only `phlex`, `tailwind_merge` and `zeitwerk`.

[Unreleased]: https://github.com/doncan-orozco/papyro/commits/main/gems/phlex-shadcn
