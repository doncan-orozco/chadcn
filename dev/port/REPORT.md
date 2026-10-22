# shadcn -> Phlex port: run report

Run: `/shadcn-run all` (resumed from `state.json`), 2026-10-10 to 2026-10-11. Nothing was committed; the working tree is left for review.

## Totals

- **Components: 50 of 50 done** (sidebar was blocked after the first run and closed in the second run, `/shadcn-run all --retry-blocked`, see "Resolved" below). Infra tasks (_base, _harness, _icons, _primitives, _theme): all done. 11 `third_party` components are skipped by plan (calendar, carousel, chart, combobox, command, drawer, form, input-otp, message-scroller, resizable, sonner).
- This session built or finished 23 components: slider, popover, spinner first (as requested; all three passed every gate unchanged), then wave 3 (context-menu, hover-card, menubar, native-select, navigation-menu, radio-group, scroll-area, sheet, table, tabs, toggle) and wave 4 (alert-dialog, attachment, button-group, field, input-group, item, pagination, toggle-group). Sidebar was built in the first run and finished in the second.
- Agent dispatches counted: 147 in the first run (cap 165) plus 1 in the `--retry-blocked` run (the counter resets on retry). No stop condition fired in either run.

## Resolved since the first run

### sidebar: oracle randomness, closed with option B (chosen by the user)
The only remaining gate failure was 6 BOX diffs on the random `SidebarMenuSkeleton` text width (React `Math.floor(Math.random() * 40) + 50` percent vs the port's `rand(40) + 50`), and the runner has no ignore mechanism. Both sides are now deterministic **on the parity pages only**:
- `gems/chadcn/dev/react-shadcn-catalog/src/parity/Harness.tsx` pins `Math.random = () => 0.5` (4 lines; the only `Math.random` use in the React sources is that skeleton), giving `floor(0.5 * 40) + 50 = 70` percent. The shadcn oracle files themselves are untouched.
- `Components::V2::Sidebar::MenuSkeleton` takes its width from `width_percent` (default still `rand(40) + 50`, so production is random as before); `with_pinned_width(percent)` pins it with an `ensure` restore, and `ParityScenariosController#show` pins it to 70 around the render.
- `deviations/sidebar.json` now records this (replaces the ORACLE_NOISE note); `sidebar_test.rb` covers the default range, the pinned value and the restore (also after an exception).
Verification (orchestrator-run): static gate pass, rubocop clean, sidebar tests 12 runs / 95 assertions, **3 consecutive full parity runs of 210 scenarios with 0 diffs**, slate/stone/zinc-radius0/dark and the DX-helper run at 0 diffs, a regression smoke on `default*` scenarios of button, dialog, select, tabs and field at 0 diffs; closing house checks (static house check 50 components, deviations register, rubocop 653 files, `test:with_studio` 861 runs / 0 failures). The golden suite was not re-run for this change (no scripts, agents or skills changed in the second run).

## Needs your decision

### 1. (resolved in the follow-up) JS controller tests now exist
See "Follow-up" below: `bin/rails test:javascript` (48 browser tests); the four specs now cite them.

### 2. Documented departures from strict 1:1 (please confirm)
- **toggle-group**: scenario `api__as-child-root` was **removed**. The shadcn source wraps children in `ToggleGroupContext.Provider` inside `Root`, so with `asChild` React drops every root attribute; the port merges them onto the child because the Stimulus controller lives on the root. Registered in `deviations/toggle-group.json` (fully written up in the follow-up), noted in the spec and pinned by `toggle_group_test.rb`. `approved-by` is still `pending`: it needs your approval.
- **pagination**: `deviations/pagination.json` allow-lists the words of two aria-label strings, which the static gate misreads as Tailwind classes (gate false positive, no rendered difference).

## Shared files changed during this run (all regression-checked)

| File | Change | Why |
|---|---|---|
| `app/javascript/v2/primitives/presence.js` | one guard in `onEnd` (ignore animationend/cancel of a non-current animation, like Radix `isCurrentAnimation`) | an exit starting mid-enter unmounted immediately (found by navigation-menu). All 15 presence users re-run: 0 diffs. |
| `app/javascript/controllers/v2/dropdown_menu_controller.js` | in-place subs mount before `#effects()`, `subTriggerSelector` option, idle layer for force-mounted closed levels | context-menu layer-registration order. dropdown-menu re-run: 0 diffs. |
| `gems/chadcn/dev/parity/lib/shadcn_parity/tree_renderer.rb` | an exact root name now wins over a same-named nested part of a longer root | **harness bug**: once `input_group.rb` existed, bare `Button` resolved to `InputGroup::Button` (size xs), failing alert-dialog. |
| `.claude/scripts/shadcn/static_gate.rb` | `check_kwargs` takes the prop name before `:` | renamed destructure `open: openProp` (sidebar) produced an impossible kwarg regex. Output byte-identical for other components. |

Added in the second run (sidebar option B, parity pages only): `gems/chadcn/dev/react-shadcn-catalog/src/parity/Harness.tsx` (pins `Math.random = () => 0.5`) and `ParityScenariosController` of the dummy app (pins the sidebar skeleton width to 70 around the render), with the matching overridable width source in `app/components/v2/sidebar/menu_skeleton.rb`.

Golden suite: after the static_gate change, `/shadcn-golden` was run, script tier only (`tmp/shadcn-port/golden-latest.md`): 35 of 35 executed cases PASS, 0 missed, 0 false positives. The planner (12, 13) and agent (03, 04, 28) tiers were not run because no agent prompt, skill or gate vocabulary changed. Not re-run after the second run's changes, which touched no script, agent or skill.

## Scenario fixes (ports were correct; the oracle itself was non-deterministic)

Each was diagnosed with evidence (probes on the React oracle alone) before changing scenarios; none removed coverage except the toggle-group case above.
- **scroll-area**: Chromium smooth-scrolls keyboard presses ~150ms, so mid-flight snapshots differ per run -> `snapshot:false` on presses + settle waits; hover mount race (RO + rAF + 10ms debounce) -> `snapshot:false` on the first hover.
- **navigation-menu**: clicking a trigger starts Radix 200ms hover-open timer that Escape does not clear -> open by keyboard (3 scenarios). Review also added 3 force_mount scenarios; one exposed a real port gap (forceMount Content must render in place when no viewport is mounted), fixed in the controller.
- **alert-dialog**: Outside button was aria-hidden by `hideOthers` -> `data-testid` locator; trigger hover-colour transition caught in flight -> `snapshot:false` + 600ms settle.
- **sidebar**: stationary pointer over mounting sheet content flipped `:hover` per run (on the oracle too) -> neutral pointer target + `snapshot:false`.
- **context-menu**: runner holds the root enter animation at scale 0.95 while the 100ms sub-open timer measures -> 200ms wait before the sub hover (10 of 10 clean runs; it failed 2 of 5 before).
- **button-group / field**: scenarios whose root has no `data-slot` or renders nothing gave EMPTY_RENDER on both sides -> `observe` selector / wrapper `Field`.

## Gate results

- Per-component: G1 static, G2/G3 full scenario run, G2b DX helpers, G4 (slate, stone, zinc-radius0, dark) were all re-run by the orchestrator for every component built in this session; builder reports were never accepted without it (several were wrong: field G1, scroll-area, navigation-menu, alert-dialog, context-menu).
- House phase: `house_check --static-all` clean (49 components); G4 sweep over the 49 components done at that point (sidebar got its own G4 in the second run) = 147 runs (slate, stone, dark on `default*` scenarios), 0 diffs; `bin/rubocop` clean (653 files); `bin/rails test:with_studio` 859 runs, 4269 assertions, 0 failures; deviations register consistent.

## Open items and advisories

- **Runner limits**: the parity runner has no ignore list and no wheel/touch steps (the sidebar skeleton was solved by pinning randomness on the parity pages; see "Resolved" and decision 1).
- Q review advisories worth acting on (full JSON in `tmp/shadcn-port/<name>/audit-static.json`): sidebar mobile click handler returns early on `defaultPrevented` (React has no such check); collapsible and tabs leave stale state after a Turbo cache restore; several controllers (accordion, collapsible, avatar) hand-roll template mounting instead of `template_mount`; menubar copies `MenuLevel` instead of sharing it; dialog `open-change` is cancelable although the spec says not; alert-dialog/sheet extend the dialog controller (spec says share via primitives; not recorded as a deviation); undocumented divergences that exist only as code comments (dialog focus-scope release, popover, select focus trap, collapsible force_mount); toggle-group item lookup also matches nested groups; slider hand-rolls the bubble input because `form_bubble_input` only supports checkbox/radio/select.

## Follow-up (after the second run): the four open items

1. **JS test harness.** `bin/rails test:javascript` runs `test/javascript/*.test.mjs` (Node `node:test` + the catalog's Playwright, real importmap/Stimulus, no new dependency; not in `bin/ci`). 48 tests: popover, tooltip, hover-card (touch ignored, cancelable events, `hide_when_detached`, `update_position_strategy`, `collision_boundary`, scroll-close), context-menu touch/pen long press, and popover/hover-card nested in a Dialog. Mutation-checked (breaking the touch guard and the long-press cancel turns tests red). Docs: `.ai/skills/radix-stimulus/references/js-controller-tests.md`; the four specs now cite the tests; popover caller `id:` is a Ruby test. Tooltip inside a Dialog is covered too (it passes with or without the dismissable-layer fix, so it guards behavior, not that fix).
   - **Bug found by the nesting tests and fixed:** a click (or focus) inside a popover/hover card opened from a modal Dialog closed the Dialog, because `dismissable_layer.js` counted a child layer's portaled content as "outside". It now treats the content of layers opened later as inside (Radix's React-tree check). Regression: G2/G3 0 diffs for dialog, sheet, alert-dialog, popover, hover-card, tooltip, dropdown-menu, context-menu, menubar, select, navigation-menu and the dismissable-layer probe.
2. **toggle-group deviation** written up in `deviations/toggle-group.json` (what React does, what the port does, why not "not offered" like checkbox/switch, impact, how pinned, when to revisit) and pinned by a new test. Still awaiting your approval.
3. **context-menu `typeahead__repeated-char-cycles` flake: root cause found.** Radix focuses the typeahead match in `setTimeout(0)` and reads the current item from `document.activeElement` (react-menu:233-248); the port copies this exactly, and the runner typed `ppp` with 5 ms between keys, so under load either side could lag and cycle one item differently. It is a harness race, not a port bug. The scenario now uses three `press` steps (settled between keys, and each step is compared). Evidence: 1 failure in 15 runs under CPU stress before, 0 in 30 after (a small sample; the mechanism is from the Radix source). The same race was real in `_primitives-typeahead` `repeated-letter` (`bbb`, `aa`, `aaa` typed 5 ms apart): 6 failures in 20 runs under CPU stress before, 0 in 20 after switching to `press` steps; the whole component then passed 6 of 6 stressed full runs, so its other typeahead scenarios are not race-prone.
4. **V2 catalog:** `/design-system/v2` (`Views::DesignSystem::V2Catalog`, `Components::Parity::Catalog`) renders a preview of every ported component generated from its scenario file (50), with side nav, EN/ES copy, a link from the old catalog, and tests. Previews contain fixed layers with `contain-layout`.

Golden script tier re-run after the follow-up: 35 of 35 PASS (planner and agent tiers, 5 cases, still not run: no agent prompt, skill, Quick Rule or script changed).

Closing checks: rubocop 656 files clean; `bin/rails test:with_studio` 869 runs 0 failures; `test:javascript` 48/48; context-menu full G2/G3 0 diffs; house static check clean.

## Per component

| Component | Wave | Status | Iterations | Q review (mandatory/advisory) | Deviation file |
|---|---|---|---|---|---|
| button | 1 | done | 2 | not reviewed (non-interactive) | - |
| dropdown-menu | 1 | done | 2 | 0/3 | - |
| select | 1 | done | 3 | 0/2 | yes |
| switch | 1 | done | 2 | 0/0 | yes |
| tooltip | 1 | done | 2 | 1/2 | yes |
| dialog | 2 | done | 2 | 0/4 | yes |
| accordion | 3 | done | 2 | 0/3 | yes |
| alert | 3 | done | 1 | not reviewed (non-interactive) | - |
| aspect-ratio | 3 | done | 1 | not reviewed (non-interactive) | - |
| avatar | 3 | done | 1 | 0/2 | yes |
| badge | 3 | done | 1 | not reviewed (non-interactive) | - |
| breadcrumb | 3 | done | 2 | not reviewed (non-interactive) | - |
| bubble | 3 | done | 1 | not reviewed (non-interactive) | - |
| card | 3 | done | 2 | not reviewed (non-interactive) | - |
| checkbox | 3 | done | 1 | 0/2 | yes |
| collapsible | 3 | done | 1 | 0/3 | - |
| context-menu | 3 | done | 4 | 1/3 | - |
| direction | 3 | done | 3 | not reviewed (non-interactive) | - |
| empty | 3 | done | 1 | not reviewed (non-interactive) | - |
| hover-card | 3 | done | 1 | 1/3 | yes |
| input | 3 | done | 1 | not reviewed (non-interactive) | - |
| kbd | 3 | done | 1 | not reviewed (non-interactive) | - |
| label | 3 | done | 2 | 0/1 | yes |
| marker | 3 | done | 1 | not reviewed (non-interactive) | - |
| menubar | 3 | done | 1 | 0/3 | - |
| message | 3 | done | 1 | not reviewed (non-interactive) | - |
| native-select | 3 | done | 1 | not reviewed (non-interactive) | yes |
| navigation-menu | 3 | done | 4 | 1/2 | yes |
| popover | 3 | done | 1 | 0/3 | yes |
| progress | 3 | done | 1 | not reviewed (non-interactive) | yes |
| radio-group | 3 | done | 1 | 0/0 | yes |
| scroll-area | 3 | done | 2 | 0/3 | yes |
| separator | 3 | done | 1 | not reviewed (non-interactive) | - |
| sheet | 3 | done | 1 | 0/5 | yes |
| skeleton | 3 | done | 1 | not reviewed (non-interactive) | - |
| slider | 3 | done | 1 | 0/3 | yes |
| spinner | 3 | done | 1 | not reviewed (non-interactive) | - |
| table | 3 | done | 1 | not reviewed (non-interactive) | - |
| tabs | 3 | done | 1 | 0/3 | - |
| textarea | 3 | done | 1 | not reviewed (non-interactive) | - |
| toggle | 3 | done | 1 | 0/0 | - |
| alert-dialog | 4 | done | 2 | 0/2 | yes |
| attachment | 4 | done | 1 | not reviewed (non-interactive) | - |
| button-group | 4 | done | 1 | not reviewed (non-interactive) | - |
| field | 4 | done | 2 | not reviewed (non-interactive) | - |
| input-group | 4 | done | 1 | 0/1 | - |
| item | 4 | done | 1 | not reviewed (non-interactive) | - |
| pagination | 4 | done | 1 | not reviewed (non-interactive) | yes |
| sidebar | 4 | done | 2 | 0/3 | yes |
| toggle-group | 4 | done | 2 | 0/2 | yes |

## Resume

`/shadcn-run all --resume` (nothing is pending or blocked; all 55 items are done). Logs: `tmp/shadcn-port/run.log`; per-component reports under `tmp/shadcn-port/<name>/`; G4 sweep under `tmp/shadcn-port/_house/`.
