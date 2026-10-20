# Decision: tracking upstream shadcn/ui

Status: accepted. Applies to every release of the gem.

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
