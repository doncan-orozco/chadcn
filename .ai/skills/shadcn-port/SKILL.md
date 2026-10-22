---
name: shadcn-port
description: "Contract for the 1:1 shadcn/ui -> Phlex port: oracle-first, identical API, verbatim Tailwind classes, data-slot, variants and states, and theme compatibility. Use when creating, editing or auditing `lib/chadcn/*` as part of the shadcn port, `dev/port/**`, or running /shadcn-plan, /shadcn-run, /shadcn-audit."
---

# shadcn -> Phlex port contract

The React shadcn component (registry style `new-york-v4`, Radix base) is the **oracle**. A Phlex component is correct only if it is indistinguishable from it: same API, same DOM, same computed style, same behavior, same theme response. "Looks similar" is a failure.

## Quick Rules

Cite as `shadcn-port R<n>`.

R1. **Oracle first.** Never write a class string, variant, default or prop from memory, and never from the legacy `app/components/ui/*`. Read `dev/port/oracle/src/<name>.tsx` and `manifest/<name>.json`. → references/api-mapping.md
R2. **Verbatim classes.** Every Tailwind token of the React source appears unchanged in the port and no other token is added. Variant tables are copied key for key (`"icon-sm"` stays `"icon-sm"`). Deviations are only allowed through `dev/port/deviations/<name>.json` with a reason. → references/parity-gates.md (G1)
R3. **Same API, mechanically mapped.** `className`->`class:`, camelCase props->snake_case kwargs, `children`->block, `asChild`->`as_child:` (false | tag symbol | component instance, Radix Slot merge in `Chadcn::Base`), `defaultX`->`default_x:`, `onXChange`->dispatched `x-change` event, compound exports `DialogContent`->`Dialog::Content` (the name rule lives in one place). → references/api-mapping.md
R4. **Accept both string and symbol options.** `variant: :outline` and `variant: "outline"`, `size: "icon-sm"` and `size: :icon_sm` behave identically; defaults equal `defaultVariants`.
R5. **`data-slot` on every part,** with the exact value of the React source, on the same element.
R6. **`**attrs` pass through on every part** (merged, never overwritten): `class` goes through `cn` (tailwind_merge) last so callers win; `data`/`aria` hashes deep-merge with required component data.
R7. **Same DOM, not same look.** Tag, role, aria-*, `data-state/side/align/orientation/disabled/...`, id wiring (`aria-labelledby`, `aria-controls`) and DOM order match the Radix output, including portal content and hidden parts. → references/radix-dom-contract.md
R8. **Every state in the matrix.** Each cva variant x size, each Radix state (`open/closed`, `checked/unchecked/indeterminate`, `active/inactive`, `on/off`, `disabled`, `aria-invalid`, orientation, side/align), with/without icon, dark mode. The scenario file lists them; none may be skipped. → references/state-matrix.md
R9. **Theme-neutral.** Only semantic tokens/CSS variables from the shadcn v4 contract (`--background`, `--primary`, `--radius`, `--chart-*`, `--sidebar-*`...) via `@theme inline`. Pasting any theme from ui.shadcn.com/themes into the host stylesheet must restyle the port with no code change. → references/theme-contract.md
R10. **Behavior lives in Stimulus, shared logic in primitives.** One controller per interactive component under `app/javascript/controllers/chadcn/`, built on the shared primitives (`app/javascript/chadcn/primitives/*`). No inline JS, no per-component copies of focus-trap/positioning/dismiss logic. Rules for the controller itself: see `stimulus`; Radix behavior map: see `radix-stimulus`.
R11. **Scenario file is the shared truth.** `dev/port/scenarios/<name>.json` is rendered by BOTH the React harness and the Phlex harness. A component without a complete scenario file is not done.
R12. **Gates decide, not opinion.** A component is DONE only when G1 static, G2 DOM/style, G3 behavior and G4 theme gates pass (G5 house gate per wave). Reviewers triage gate output; they do not overrule it. → references/parity-gates.md
R13. **Ownership.** A builder touches only its component's files (`lib/chadcn/<name>*.rb`, `app/javascript/controllers/chadcn/<name>_controller.js`, its scenario file, its deviations file, tests). Shared files (importmap, catalog index, locales, stylesheets, primitives) are changed only by the orchestrator or the infra wave.
R14. **Third-party parts are wrapped, not rewritten.** Where shadcn wraps a library (cmdk, sonner, embla, react-day-picker, vaul, input-otp, react-resizable-panels, recharts), use a pinned JS equivalent behind a Stimulus controller and document the mapping in the spec.
R15. **From scratch, in `Chadcn`.** The port lives in `lib/chadcn/` (namespace `Chadcn`, Stimulus identifiers `chadcn--<name>`, events `chadcn--<name>:<event>`, primitives `app/javascript/chadcn/`). The legacy `app/components/ui/*` and `controllers/ui/*` are frozen: planners and builders never open, copy or import them, so none of their errors carry over. Port components may only depend on other `Chadcn` components, Phlex and tailwind_merge (never on host constants). Migrating callers from `Ui` to `V2` is a separate, later step (`CALLERS.md`), never part of a component task.
R16. **DX helpers are generated, never written.** Every compound root `yield self`s and `Chadcn::Base` generates one helper per nested part (`table.header`, `dialog.content`...), equal to the explicit class call. Specs carry the derived list (`spec_helpers.rb`); the unit test asserts each helper renders the same HTML as its class; gate G2b (`parity_run.mjs --dx helpers`) proves the helper path against React. → references/api-mapping.md

## Where things live

| Thing | Path |
|---|---|
| Oracle (generated, committed) | `dev/port/oracle/{registry,src,manifest}/`, `graph.json` |
| Spec per component | `dev/port/specs/<name>.md` |
| Scenarios (shared) | `dev/port/scenarios/<name>.json` |
| Deviations | `dev/port/deviations/<name>.json` + register in `dev/port/DEVIATIONS.md` |
| Theme (developer-edited) / tokens / presets | `app/assets/tailwind/chadcn/{theme.css,tokens.css,presets/*.css}` |
| Run state | `dev/port/state.json`, reports in `tmp/shadcn-port/<component>/` |
| React catalog (oracle renderer) | `dev/react-shadcn-catalog/` |
| Phlex port | `lib/chadcn/<name>.rb` (+ `lib/chadcn/<name>/` for large parts); nested parts like `Dialog::Content` live in the same file |
| Stimulus | `app/javascript/controllers/chadcn/<name>_controller.js`, primitives in `app/javascript/chadcn/primitives/` |

Path authority: `.claude/scripts/shadcn/layout.rb` (`ShadcnLayout`) is the single place that resolves every location above; scripts and agents never hard-code them. `ruby .claude/scripts/shadcn/layout.rb --json` prints the resolved paths, and the `SHADCN_*` environment variables (`SHADCN_GEM_DIR`, `SHADCN_DEV_DIR`, `SHADCN_PORT_DIR`, ...) override them. The Phlex side of the parity runs is served by the dummy app (`ParityScenariosController` -> `ShadcnParity::Page` -> `ShadcnParity::TreeRenderer`, same `/design-system/parity/<component>/<scenario>` URL); boot both servers with `ruby .claude/scripts/shadcn/servers.rb start`.

## References (load on demand)

- `references/api-mapping.md`: React -> Ruby mapping table and examples (Button, Dialog, controlled/uncontrolled).
- `references/state-matrix.md`: how scenarios are derived (variants x sizes x states) and the scenario JSON format.
- `references/parity-gates.md`: gates G1-G5, finding codes, pass criteria, tools, harness contract.
- `references/theme-contract.md`: CSS variable set, `@theme inline`, dark mode, theme gate.
- `references/radix-dom-contract.md`: DOM/ARIA each Radix primitive emits that the port must reproduce.
