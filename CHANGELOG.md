# Changelog

All notable changes to this gem are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the gem adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Gem skeleton: Zeitwerk loader, version, license files and a standalone test harness.

### Changed

- Stimulus identifiers use the `shadcn--` prefix (`shadcn--dialog`, `data-shadcn--dialog-part`, ...); the controllers live under
  `app/javascript/controllers/shadcn/` and are pinned `under: "controllers/shadcn"`, the shared primitives are imported as
  `shadcn/primitives/<name>`.

### Removed

- The `activesupport` runtime dependency: the core needs only `phlex`, `tailwind_merge` and `zeitwerk`.
