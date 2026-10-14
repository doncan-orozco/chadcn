# Changelog

All notable changes to this gem are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the gem adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Gem skeleton: Zeitwerk loader, version, license files and a standalone test harness.
- Rails engine (loaded only when `Rails::Engine` is defined): importmap pins for the Stimulus controllers, primitives and vendored
  floating-ui, asset paths, and the Tailwind entry `app/assets/tailwind/phlex-shadcn/engine.css` bundled by tailwindcss-rails.
  The engine's Tailwind inputs are excluded from Propshaft so they are never served or linked.
- `Phlex::Shadcn.configure` / `Phlex::Shadcn::Configuration#theme_dir`; Rails apps set `config.phlex_shadcn.theme_dir`
  (default `app/assets/tailwind/theme`).
- Theme tooling: `Phlex::Shadcn::Theme` and the rake tasks `phlex_shadcn:theme:list|use|import|check` (short `theme:*` aliases;
  turn them off with `config.phlex_shadcn.theme_task_aliases = false`).
- `rails g phlex:shadcn:install`: idempotent marker block in the Tailwind entry file (`@source`, engine bundle, theme import) and
  the default theme files; exits non-zero on malformed input.

### Changed

- Stimulus identifiers use the `shadcn--` prefix (`shadcn--dialog`, `data-shadcn--dialog-part`, ...); the controllers live under
  `app/javascript/controllers/shadcn/` and are pinned `under: "controllers/shadcn"`, the shared primitives are imported as
  `shadcn/primitives/<name>`.

### Removed

- The `activesupport` runtime dependency: the core needs only `phlex`, `tailwind_merge` and `zeitwerk`.
