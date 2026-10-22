# Parity gates

A component is DONE when every gate passes. Gates are scripts; agents only fix and triage.

| Gate | What | Tool | Fails with |
|---|---|---|---|
| **G1 static** | Tailwind tokens identical, no extra tokens, `data-slot`s, parts, variant options, defaults, kwargs, no hardcoded colors | `ruby .claude/scripts/shadcn/static_gate.rb --component NAME` | `G1_*` |
| **G2 DOM + style** | For every scenario: same nodes (by `data-slot`), tag, classes, attrs (aria/data/role), id wiring, text, visibility, boxes (0.5px), 45 computed style props | `node parity_run.mjs --component NAME` | `CLASS ATTR A11Y_REL TEXT VISIBLE BOX STYLE NODE_COUNT TAG SLOT_ORDER` |
| **G2b DX helpers** | The same scenario tree rendered through the yielded-root helpers (`table.header { ... }`) instead of the explicit classes must also equal React. Run on the scenarios whose id starts with `default`, `variant-`, `example__` (cap 25) of every component that has helpers (`spec_helpers.rb --print` lists them) | `node parity_run.mjs --component NAME --dx helpers --only <ids>` | same kinds as G2 |
| **G3 behavior** | Same steps (click, hover, Tab, keys, typing) produce the same snapshot after every step: state attrs, focus target, open/close, scroll lock, roving focus, typeahead, dismissal | same run (steps in the scenario) | `FOCUS FOCUSED SCROLL_LOCK VISIBLE ATTR` at a step > 0, `PHLEX_JS_ERROR` |
| **G4 theme** | Re-run G2 on the default scenarios with each preset in `app/assets/tailwind/chadcn/presets/` (slate, stone, zinc-radius0) and `--dark` | `parity_run.mjs --theme slate [--dark]` | `STYLE` |
| **G5 house (per wave and final)** | All previously DONE components still pass G1+G2 (regression), host test suite and rubocop green, catalog complete, importmap pins resolve (`G5_IMPORTMAP`), the JS directories exist (`G5_LAYOUT_MISSING`), no unused controllers, deviations register consistent | `/shadcn-audit all --house` | `G5_*` |

## Severity

Every gate finding is MANDATORY. There is no advisory tier for G1-G4. (Advisory findings exist only for code quality items reported by the auditor on top of gates, tagged `Q_*`.)

## Triage vocabulary (for `shadcn-parity-auditor`)

For each failing diff the auditor assigns exactly one `cause` and a `fix_target`:

- `cause`: `CLASS_DRIFT` (token mismatch), `STRUCTURE` (wrong tag/nesting/missing wrapper), `ATTR_MAPPING` (aria/data not set or set on wrong element), `STATE_CLASS` (state attr present but class conditional wrong), `BEHAVIOR_MISSING` (no keyboard/dismiss/focus), `BEHAVIOR_TIMING` (race, rAF, Presence), `POSITIONING` (floating-ui options/offsets/collision), `THEME` (hardcoded value), `API` (kwarg/variant), `HARNESS` (scenario or renderer bug; not a port bug), `ORACLE_NOISE` (React-only non-determinism; add to ignore list with proof).
- `fix_target`: file + the smallest change.

`HARNESS` and `ORACLE_NOISE` verdicts require evidence (a second run on the oracle alone that is unstable, or a renderer unit failure); otherwise the port is wrong.

## Harness contract

- React: `dev/react-shadcn-catalog` serves `/#/parity/<component>/<scenarioId>` which renders `tree` through `import.meta.glob("/src/components/ui/*.tsx")`; no chrome except the tree. Body has `class="bg-background text-foreground"`.
- Phlex: route of the dummy app (`dev/dummy`) `GET /design-system/parity/:component/:scenario` -> `ParityScenariosController` -> `ShadcnParity::Page` -> `ShadcnParity::TreeRenderer` reading the same JSON and applying `api-mapping.md`. Same body classes, same fonts, same CSS variables source (generated from one file; see theme-contract.md).
- The Phlex page sets `data-turbo="false"` on `<body>` (React has no Turbo; a `#hash` link click must not cause a Turbo visit that re-renders the body and loses open layers/focus).
- Both pages load the same font files and set `html { font-size: 16px }`.
- Runner ignores: `id`, `for`, Stimulus/Turbo/React attributes (regex in `parity_run.mjs`); ids are compared structurally through `A11Y_REL`.
- Settle: after every step (also `snapshot:false` ones and before the initial snapshot) the runner awaits two macrotask turns, 2 rAF and two more turns on both sides (before the animation clock seeks), so `setTimeout(0)` hops and mount effects have run; `press`/`tab` of a single key hold the key down for two macrotask turns before keyup (like a real press), and mousedown/mouseup/click/hover use `force: true`.
- Animation determinism (`animations: true` scenarios only; others get the no-motion style installed via `addInitScript` before any page script runs, and reduced motion is never emulated so host-only `prefers-reduced-motion` rules cannot make the pages differ): the runner never samples in-flight CSS animations/transitions at wall-clock time. At every snapshot, each running CSSAnimation/CSSTransition is paused and seeked to a logical offset (sum of the scenario's `wait` step `ms` since the first snapshot that saw that animation; animations whose offset reaches their end are finished), the snapshot is taken, then the paused ones resume so JS that waits for `animationend` (Radix Presence) still proceeds. Both sides use the same function, so mid-flight values (opacity, transform, colors) are compared at the same animation time and settled states are compared after a long enough `wait`. A scenario that wants to assert a mid-flight value must put a `wait` of that many ms before the snapshot; real timers (hover delays) still run in real time. `--phlex-scenario <id>` renders another scenario on the Phlex side (used by the harness self-test to prove a duration mismatch still fails). A step with `"snapshot": false` runs on both sides but is not compared (for steps whose immediate state is timing-dependent, e.g. a hover starting an autoscroll interval; never the last step, see state-matrix.md). A scenario `observe: [selectors]` adds slot-less oracle elements (an svg icon) to the compared nodes as `observe:<selector>[i]`, so components without any `data-slot` are still compared (see state-matrix.md).
- Not compared: scrollbar rendering, subpixel text anti-aliasing (boxes rounded to 0.5px), `data-radix-*` internals.

## Reports

`tmp/shadcn-port/<component>/{g1.json,g2.json,g4-<theme>.json,triage.json}` and `shots/` (optional PNG pairs). `dev/port/state.json` stores per component: `status` (`pending|planned|built|fixing|done|blocked`), `iteration`, `last_green_sha`, `oracle_sha`, `blocked_reason`.

The runner applies `--dark` and the theme CSS (as an adopted stylesheet) in an init script before any page script, so no colour transition starts after load.

## Running the browser gates for many components: `parity_batch.rb`

`ruby .claude/scripts/shadcn/parity_batch.rb --components button,card` ensures a Playwright that can launch (`playwright_ensure.rb`), starts the dev servers on free ports (`servers.rb start`), runs G2/G3 per component, and stops only the servers it started. Flags:

- `--components a,b|all`: a comma list, or every scenario file whose name does not start with `_`.
- `--dx`: also G2b, only for components that have yielded-root helpers (`spec_helpers.rb --print`), on scenarios starting `default`, `variant-` or `example__` (cap 25).
- `--themes [slate,stone,zinc-radius0]`: also G4 on scenarios starting `variant-` or `default` (cap 12), plus one `--dark` run; without a list the three presets above are used.
- `--no-servers`: skip Playwright and server handling (they must already be running: the recorded ones, or `PARITY_REACT_URL` and `PARITY_PHLEX_URL`).
- `--out DIR`: report directory (default `tmp/shadcn-port`).

Reports land in `tmp/shadcn-port/<component>/{g2,g2b,g4-<theme>,g4-dark}.json`; stdout is `{ pass, servers_started, components }`. Exit 0 all green, 1 a gate found diffs, 2 bad arguments or an environment that cannot run the gates (no browser, servers down, a gate crashed without a report). Gates that cannot apply (`--dx` on a component without helpers) appear as `skipped` with a reason.

## Where the files are (`layout.rb`)

Scripts never hard-code component paths: `.claude/scripts/shadcn/layout.rb` is the single configuration point (Ruby dir, namespace, controller dir, primitives dir, test dirs, Stimulus identifier prefix) with `SHADCN_*` env overrides.
