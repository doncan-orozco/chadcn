# Shadcn port plan

- Oracle: style `new-york-v4`, 61 components, digest `7de7073d0e253001`, fetched 2026-10-10T04:52:14Z
- React catalog upgraded to the registry stack (React 19, Tailwind 4, `radix-ui`); `--verify-catalog`, `--check-tokens`, `npm run build` and dev `GET /` all pass.
- Skipped (by name, listed in `skipped` in `state.json` with `skip_reasons`): chart (recharts; product decision to defer, see `skip_reasons`) and form (react-hook-form and zod, no Phlex counterpart; Rails form builders cover it). The oracle still covers them; no spec or scenarios exist for them. calendar, combobox, command and sonner are ported or planned, not skipped; carousel, drawer, input-otp, message-scroller and resizable are planned again (pending). Caution: `port_state.rb init` (and so `/shadcn-run`) derives `skipped` from `skip_tiers` only and does not keep `skip_reasons`, so a re-init puts chart and form back as pending until a follow-up teaches it per-name skips; until then, re-apply the skip after any `init`.
- Planned: 59 components (52 done, 7 pending incl. sonner and calendar; chart and form skipped), plus the 5 wave-0 infra items, all done. Tier tally at the original plan: radix_stateful=16, overlay=11, static=22, client=1.
- Wave 0 infra (done): `_theme`, `_base`, `_icons`, `_harness`, `_primitives`.

## Waves

Waves follow `wave` in `state.json`; chart and form are skipped and have no wave.

| Wave | Components |
|---|---|
| 0 | _base, _harness, _icons, _primitives, _theme |
| 1 | button, dropdown-menu, select, switch, tooltip |
| 2 | dialog |
| 3 | accordion, alert, aspect-ratio, avatar, badge, breadcrumb, bubble, card, checkbox, collapsible, context-menu, direction, drawer, empty, hover-card, input, input-otp, kbd, label, marker, menubar, message, native-select, navigation-menu, popover, progress, radio-group, resizable, scroll-area, separator, sheet, skeleton, slider, sonner, spinner, table, tabs, textarea, toggle |
| 4 | alert-dialog, attachment, button-group, calendar, carousel, field, input-group, item, message-scroller, pagination, sidebar, toggle-group |
| 5 | combobox, command |

## Components

Status and counts here are plan-time (rows added in #27 use the counts at #27); the live status is `ruby .claude/scripts/shadcn/port_state.rb summary`.

| Component | Tier | Scenarios | Deviations | Status |
|---|---|---|---|---|
| accordion | radix_stateful | 61 | yes (see deviations/) | planned |
| alert | static | 39 | - | planned |
| alert-dialog | overlay | 124 | yes (see deviations/) | planned |
| aspect-ratio | radix_stateful | 30 | - | planned |
| attachment | static | 131 | - | planned |
| avatar | radix_stateful | 57 | yes (see deviations/) | planned |
| badge | static | 87 | - | planned |
| breadcrumb | static | 58 | - | planned |
| bubble | static | 109 | - | planned |
| button | static | 148 | - | planned |
| button-group | static | 92 | - | planned |
| calendar | third_party | 174 | yes (see deviations/) | planned |
| card | static | 48 | - | planned |
| carousel | third_party | - | - | planned |
| checkbox | radix_stateful | 73 | yes (see deviations/) | planned |
| collapsible | radix_stateful | 50 | - | planned |
| combobox | third_party | 158 | yes (see deviations/) | done |
| command | third_party | 130 | yes (see deviations/) | done |
| context-menu | overlay | 181 | - | planned |
| dialog | overlay | 78 | yes (see deviations/) | planned |
| direction | radix_stateful | 27 | - | planned |
| drawer | third_party | - | - | planned |
| dropdown-menu | overlay | 177 | - | planned |
| empty | static | 60 | - | planned |
| field | static | 110 | - | planned |
| hover-card | overlay | 67 | yes (see deviations/) | planned |
| input | static | 55 | - | planned |
| input-group | static | 144 | - | planned |
| input-otp | third_party | - | - | planned |
| item | static | 96 | - | planned |
| kbd | static | 45 | - | planned |
| label | radix_stateful | 41 | yes (see deviations/) | planned |
| marker | static | 91 | - | planned |
| menubar | overlay | 236 | - | planned |
| message | static | 64 | - | planned |
| message-scroller | third_party | - | - | planned |
| native-select | static | 67 | yes (see deviations/) | planned |
| navigation-menu | overlay | 109 | yes (see deviations/) | planned |
| pagination | static | 97 | - | planned |
| popover | overlay | 91 | yes (see deviations/) | planned |
| progress | radix_stateful | 31 | yes (see deviations/) | planned |
| radio-group | radix_stateful | 70 | yes (see deviations/) | planned |
| resizable | third_party | - | - | planned |
| scroll-area | radix_stateful | 66 | yes (see deviations/) | planned |
| select | overlay | 152 | yes (see deviations/) | planned |
| separator | radix_stateful | 29 | - | planned |
| sheet | overlay | 101 | yes (see deviations/) | planned |
| sidebar | client | 210 | yes (see deviations/) | planned |
| skeleton | static | 20 | - | planned |
| slider | radix_stateful | 104 | yes (see deviations/) | planned |
| sonner | third_party | 80 | yes (see deviations/) | planned |
| spinner | static | 25 | - | planned |
| switch | radix_stateful | 52 | yes (see deviations/) | planned |
| table | static | 41 | - | planned |
| tabs | radix_stateful | 117 | - | planned |
| textarea | static | 45 | - | planned |
| toggle | radix_stateful | 77 | - | planned |
| toggle-group | radix_stateful | 111 | - | planned |
| tooltip | overlay | 76 | yes (see deviations/) | planned |

Deviations are registered in `DEVIATIONS.md`. Blockers: none open for components; see #27 for the port_state.rb per-name skip follow-up.

## Tooling fixes made during planning (planner findings, verified)

- `oracle_extract.rb`: `NO_DOM` now covers `MenubarPrimitive.Sub` and the `SheetPrimitive` alias (`menubar-sub`, `sheet` are non-rendered); oracle re-extracted, digest unchanged.
- `scenario_coverage.rb`: `SC_PART_UNUSED` only applies to parts the source exports (sheet's `SheetPortal`/`SheetOverlay` are not exported).
- `parity_run.mjs`: click/mousedown/mouseup steps accept `button` (context-menu scenarios use right click; before, they would have been left clicks and passed vacuously).

## DX helpers (added after the first review)

Compound components also expose generated, yielded-root helpers (`render Components::V2::Table.new do |table| table.header { table.row { table.head { "x" } } } end`) on top of the 1:1 nested classes. No re-planning was needed: helpers add no DOM or behavior, so `spec_helpers.rb --all` appended a derived "DX helpers" section to the 35 compound specs (15 single-part components have none). Gate G2b (`parity_run.mjs --dx helpers`) proves the helper path against React; the generator is part of the `_base` task, with a verified reference implementation in `.ai/skills/shadcn-port/references/dx-helpers-prototype.rb`.

## Notes for `/shadcn-run` (from planners; shared files are orchestrator-owned)

- Reference docs to correct: `radix-dom-contract.md` (trigger `aria-controls` only while open for dropdown/sub/accordion/popover/dialog; HoverCard trigger is an `<a>`; Select animates out and puts `data-radix-popper-*` on the trigger; Collapsible content has no role/labelledby; Popover title/description are plain elements), `api-mapping.md` (Slot merges `aria-describedby` child-first with dedupe), `primitives.md` (collection attribute must be `data-radix-collection-item`; direction reads the element's own `dir`, default `ltr`; add shared `collapsible_content` for accordion + collapsible), floating-ui pin note (catalog is 1.8.0, not 1.7.x).
- Ruby `cn` (tailwind_merge 1.5.0) must match the JS 2.6.1 config: `wrap-break-word` + `wrap-anywhere` both survive, duplicate `group` is kept (bubble, navigation-menu scenarios flag it).
- Harness needs: `htmlFor`->`for`, raw `_svg _img _ol _fieldset _legend _kbd` nodes, style objects -> style string, Tailwind scanning of scenario files, `data-*` boolean true rendered as `"true"`.
- Runner gaps (no scenario possible): wheel, touch/pen long-press, keyboard modifiers on click.
- Locale keys (en+es) may be needed for sr-only strings (breadcrumb "More", pagination labels).
- ORACLE_NOISE expected: `sidebar` menu-skeleton random width; `tooltip` `hover-leave-outside__closes` may be timing-sensitive.
- Scenario sizes above the ~120 guideline were kept (select, dropdown-menu, context-menu, menubar, sidebar, attachment, input-group).

## Next

`/shadcn-run all`
