# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

chadcn is a 1:1 port of shadcn/ui to Phlex views with Stimulus behavior (Ruby >= 3.3, phlex ~> 2.3). The core is plain Phlex; a
Rails engine (`lib/chadcn/engine.rb`) loads only when Rails is present and adds importmap pins, the Tailwind entry point, the theme
tasks and the `chadcn:install` / `chadcn:eject` generators. The README is the user guide; `docs/` holds the longer guides.

It was extracted from the Papyro monorepo (`doncan-orozco/papyro`, formerly `gems/chadcn`), which still consumes it as a git gem
with a local bundle override (`BUNDLE_LOCAL__CHADCN` pointing at this checkout).

## Commands

```bash
bin/check                       # rake test, rake test:engine, dev bench + dummy parity tests, rubocop, bundler-audit, gem_check
bundle exec rake test           # plain suite (never loads Rails)
bundle exec rake test:engine    # engine and install generator (boots a minimal Rails app in-process)
bundle exec rake test:tooling   # tests of the repository tooling in .claude/scripts (not the gem)
bin/test-js                     # browser tests of the Stimulus controllers and primitives (Playwright; starts the dev servers)
bin/smoke --docs | --plain | --app   # README/docs examples, plain-Phlex smoke, clean Rails app from the README
bin/demo                        # the component catalog of dev/dummy on a free local port
bundle exec rake llms:generate  # llms.txt, llms-full.txt, skills/chadcn/SKILL.md (rake llms:check fails on drift)
bundle exec rake public_api:update   # test/fixtures/public_api.txt after a public API change (add a CHANGELOG entry)
ruby .claude/scripts/gem/gem_check.rb --gem-dir .   # packaging and standalone gate
```

Run them with `env -u BUNDLE_GEMFILE` and a UTF-8 locale (`LANG=en_US.UTF-8`) if your shell exports something else: a foreign
`BUNDLE_GEMFILE` fakes red gates and a US-ASCII locale fails tests with "invalid byte sequence".

## Layout

- `lib/chadcn/*`: components (`Chadcn::Dialog`, `Chadcn::Dialog::Trigger`, ...), 1:1 with the React API; nested classes are the
  canonical API, generated yielded-root helpers (`table.header { ... }`) are offered too.
- `app/javascript/controllers/chadcn/*` (Stimulus `chadcn--*`) and `app/javascript/chadcn/primitives/*` (shared behavior).
- `app/assets/tailwind/chadcn/*`: engine CSS, tokens and the default theme (shadcn format).
- `dev/` (not packaged): the port's dev kit. `dev/port` (oracle, specs, scenarios, deviations, state), `dev/react-shadcn-catalog`
  (the React oracle renderer), `dev/dummy` (the Phlex side of the parity harness), `dev/golden`, `dev/decisions` (design records).
- `.claude/scripts/shadcn/layout.rb` is the one place that says where these live; scripts read it instead of hard-coding paths.

## Conventions live in `.ai/skills/` (exposed through the `.claude/skills` symlink)

Read the relevant SKILL.md before working in an area; every skill starts with numbered Quick Rules that audits cite as `<skill> R<n>`
(a rule marked `(dropped: ...)` is a tombstone that keeps the numbering stable and is never cited). The ten skills:
`ruby-gem-conventions` (standalone code, public API, packaging, release), `shadcn-port` (the 1:1 contract and parity gates),
`radix-stimulus` (behavior primitives), `design-system` (writing and using the components), `stimulus` (controller lifecycle and
wiring), `accessibility`, `testing` (the suites and what each covers), `naming-conventions` (with the library exception for the
shadcn vocabulary), `linting`, `epic-flow` (the issue board). Every one of them describes this repository alone.

## Commands and agents (`.claude/`)

- shadcn port (oracle-driven, script-judged): `/shadcn-plan`, `/shadcn-run`, `/shadcn-audit [scope] [--fix]` (G1 static, G2 DOM/style,
  G3 behavior, G4 theme, G5 house), `/shadcn-golden`. Scripts in `.claude/scripts/shadcn/`; agents `shadcn-port-planner`,
  `shadcn-port-builder`, `shadcn-parity-auditor`.
- Epic flow (GitHub issues of this repository as the board, `.claude/scripts/epic/work_board.rb`): `/epic-plan`, `/work --epic <slug>`
  (never merges), `/work-merge --epic <slug>` (human-run, the only command that merges), `/work-status`, `/work-release`.
- `/audit-feature [range] [--fix]`: Map-Reduce audit of one repository; every file is on the Gem track (`ruby-gem-conventions` +
  `naming-conventions`, plus `design-system`/`shadcn-port` for components, `stimulus`/`radix-stimulus` for JavaScript, `testing` for
  tests). `--fix` runs the Actor-Critic loop (max 3 iterations). Agents: `brick-method-auditor`, `room-class-auditor`,
  `stimulus-controller-auditor`, `view-slice-auditor`, `principal-architect`, `senior-rails-dev` (the builder).
- Merging to `main`, tagging and `gem push` (with MFA) are human steps.
