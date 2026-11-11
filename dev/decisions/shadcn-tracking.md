# Decision: tracking upstream shadcn/ui

Status: accepted; the window (six months), the deprecation notice (one release ahead), the re-sync cadence (quarterly and before each minor or major), the Ruby rule (dropped only after upstream end of life) and pre-1.0 breaking changes as minor releases were confirmed by the maintainer on 2026-10-22 (#226). Applies to every release of the gem.

## What is tracked

The gem is a port, so the shadcn/ui registry is the reference, not a dependency. Each port is compared against an **oracle**: the React sources and component manifests extracted with the `shadcn` CLI for one style (`new-york-v4` today), rendered in a browser next to the Phlex version.

Every release records, in the CHANGELOG header of its section ("Tracks shadcn/ui style ..."):

- the style;
- the `shadcn` CLI version and the `@shadcn/react` version the oracle was extracted with;
- the oracle digest (the 16-character digest the oracle extraction writes to `dev/port/oracle/VERSION.json`, also in `dev/port/PORT_PLAN.md`) and the number of components;
- the fetch date;
- the Radix UI (`radix-ui`), Lucide (`lucide-react`) and vendored `@floating-ui/dom` versions.

A release without that line is not publishable.

## Re-sync cadence

- The oracle is re-synced (`/shadcn-plan`, which upgrades the React catalog and re-extracts the oracle) before every minor or major release of the gem, and at least once per quarter even when no release is planned.
- A re-sync is a pull request of its own: new digest, the list of components whose oracle changed, and the parity gates re-run for those components. Components whose oracle did not change are not touched.
- Upstream's own changes are never applied in the middle of an unrelated change. Drift found outside a re-sync is filed as an issue and waits for the next one.

## Mapping upstream changes to semver

The gem's version follows the effect on a user of the gem, not the size of the upstream change.

| Upstream change | Gem release |
|---|---|
| Class string, markup or style tweak with the same API | patch (visible in the CHANGELOG, since users may have snapshots) |
| New component, new variant, new prop, new Stimulus behavior | minor |
| Bug fix in an existing behavior | patch |
| Renamed or removed prop, part, variant or `data-slot`; changed default; changed Stimulus controller or event name | major once the gem is 1.0; before that, a minor release with a "Changed (breaking)" entry |
| A new upstream component we do not port yet | none until ported; it stays in the oracle and in the skipped list of the port plan |
| A deliberate departure from upstream | recorded in `dev/port/DEVIATIONS.md` with the reason and a condition to revisit; never silent |

Where upstream breaks something and the gem keeps the old behavior for a while, the old behavior is kept behind a clearly named option for one minor release and removed in the next, announced in the CHANGELOG.

## How the CHANGELOG records it

The `[Unreleased]` section always carries the registry line of the oracle the code was last checked against. A re-sync pull request updates that line and adds one entry per changed component under Added, Changed or Fixed. Releasing copies the line into the dated section and does not edit it afterwards.

## Styles and Base UI

Decided 2026-11-10 by the maintainer (#101), after checking the live registry the same day.

**Styles: one at a time, never a choice.** The gem tracks exactly one registry style per release (`new-york-v4` today). Upstream now
serves `{base}-{style}` ids (Vega, Nova, Maia, Lyra, Mira, Luma, Rhea, Sera on Radix, Base UI and React Aria). Between two styles on
the same base only class strings differ (radius, ring, spacing, sizes), so a style is a restyle of the gem, not a feature. Offering
several would put a class table per style in every component and multiply every scenario, parity run, re-sync and the CSS output.
A style is not something the theme file can carry (style items have no CSS variables; the theme only sets colors and `--radius`);
a user who wants another style's shape overrides classes with `class:` or ejects the component. Out of scope.

**Switching the tracked style: deferred.** `new-york-v4` is still served and unchanged, but it no longer receives new components
(`code-block`, `questionnaire` and `trace` exist only in the new styles, so they are not in the oracle and not tracked; upstream
presents Vega as New York's successor). Moving to `radix-vega` changes about 40% of the class tokens in nearly every component,
7 `data-slot` sets and 3 exports, and drops Form upstream; behavior stays Radix. The oracle extraction already accepts `--style`,
but its manifest writes `new-york-v4` as a literal (`.claude/scripts/shadcn/oracle_extract.rb`); the switch makes the manifest follow
the option and maps upstream's icon placeholder back to lucide. It is done as one re-sync epic, released per the semver table above
(a minor with a "Changed (breaking)" entry before 1.0, a major after), when the first of these happens: upstream deprecates or stops
serving `new-york-v4`; an issue asks for a component that exists only in the new styles; or a re-sync finds a fix in `radix-vega`
that `new-york-v4` did not get. Every re-sync checks the three: it records whether `new-york-v4` is still served, lists the registry
components missing from `new-york-v4`, and diffs the tracked components against `radix-vega` for behavior or markup fixes (class-only
differences do not count).

**Base UI (and React Aria): out of scope as a variant.** Radix stays the behavior reference even though Base UI is upstream's default
since July 2026; upstream states Radix is not deprecated and ships new components for both libraries, except Base-UI-only ones. A
Base UI variant is a second behavior port (different parts, `render` instead of `asChild`, `data-open` instead of `data-state`, Base
UI's drawer instead of vaul) of about 40 stateful components and a fork of the Ruby API, with no gain a user rendering Phlex and
Stimulus can see. A component of the tracked style whose upstream source is built on Base UI is ported from that source as a single
component, as Combobox is, and its spec says so; a Base-UI-only component outside the tracked style (`toast` today) is not tracked.
Revisit if upstream deprecates Radix or stops shipping fixes or components for its Radix styles.

The README states this in one sentence; follow-up #111 adds it.
