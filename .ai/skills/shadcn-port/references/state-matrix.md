# State matrix and scenario format

`dev/port/scenarios/<name>.json` is the single description of "what the component can be". Both harnesses render it; the parity runner replays its steps on both. It is written by `shadcn-port-planner` (never by the builder), derived from the manifest + the registry's examples. A renderless component (e.g. `direction`) may add a top-level `"composes": ["select", ...]` (max 8 names, each in the oracle manifests and `state.json`, never itself) to allow those components' exports in its trees; anything else fails `SC_COMPOSES_INVALID`/`SC_UNKNOWN_COMPONENT`.

## Format

```json
{
  "component": "button",
  "scenarios": [
    {
      "id": "variant-outline__size-sm",
      "tree": { "c": "Button", "props": { "variant": "outline", "size": "sm" }, "children": ["Click me"] },
      "steps": [ { "do": "hover", "target": "[data-slot=button]" }, { "do": "tab" } ],
      "dark": false,
      "viewport": { "width": 900, "height": 700 },
      "animations": false
    }
  ]
}
```

- `tree.c`: the React export name (`Dialog`, `DialogTrigger`...). A name starting with `_` is a raw HTML element (`_a`, `_div`, `_span`, `_p`): `props` become its attributes. Use it only for `asChild` children (`<a href>`), layout wrappers and neutral siblings; never to stand in for a shadcn part. `props`: React prop names (camelCase, `className`, `asChild`), JSON-safe values only. `children`: strings or nested nodes. A string child starting with `<icon:x>` renders the lucide icon `x`. A `style` prop is always an object with camelCase keys (`{"width": "120px"}`), never a CSS string: React throws on a string `style` and renders nothing (the Phlex TreeRenderer kebab-cases the keys).
- `observe` (optional): array of 1-5 CSS selectors for oracle elements that render no `data-slot` (shadcn Spinner is a bare lucide `svg role=status`). Besides the `[data-slot]` elements the runner also snapshots and diffs the elements matching these selectors (document order, de-duplicated) under the synthetic slot `observe:<selector>[<index>]`; EMPTY_RENDER counts them, so the scenario is not vacuous (unlike `allowEmpty`). Prefer it over `allowEmpty`.
- `steps.do`: `click | dblclick | hover | focus | fill | press | type | tab | viewport | snapshot | wait | mousedown | mouseup`. `wait` takes `ms` (real timers, for Radix delays such as the 100ms sub-menu open, 300ms pointer grace and 1000ms typeahead reset; the runner waits the same on both sides). `mousedown`/`mouseup` move to `target` (optional `position`) and press/release the button, which is how press-drag-release selection (Select, menus) is expressed. `click` accepts `position: { x, y }` (pixels from the target's top-left) for cases like an overlay click that must land outside the content. A scenario tree may use the exports of the components the component depends on (`Button` in a `dialog` scenario), not only its own. `target` is any Playwright selector (prefer `[data-slot=...]` or `role=button[name="Open"]`). The runner snapshots **after every step** and diffs both sides. A step may set `"snapshot": false`: it still runs on both sides (and counts for the animation clock) but is not snapshotted or compared; the next snapshotted step compares the resulting state. Use it only for steps whose immediate state is timing-dependent (e.g. a hover that starts a 50 ms autoscroll interval), followed by a `wait`. Every step settles first (macrotask turns + 2 rAF, see parity-gates.md "Settle"), so deferred `setTimeout(0)` work is already applied at the snapshot; real timers still need a `wait`. The LAST step cannot be `snapshot:false` (HARNESS_ERROR); step names of recorded snapshots keep their original index.
- `animations: true` only for scenarios whose purpose is enter/exit animation; all others run with motion disabled.
- Scenario trees must be valid HTML (no `li` in `li`, block element in `_p`, `a` in `a`, `button` in `button`, `tr` straight in `table`...), because the Phlex side is server HTML repaired by the browser parser while React builds the DOM in JS and keeps the invalid nesting; when a shadcn docs example nests invalidly, write the valid equivalent and note it in the spec.
- Ids are `kebab__kebab`, stable, unique per file.

## Derivation rules (the planner must cover all of these)

1. **cva cross product**: every `variant` x every `size` (full product up to 48 cells; above that, every variant at default size + every size at default variant + all `compoundVariants`). Include `defaultVariants` with no props.
2. **Content permutations**: text only; icon + text; text + icon; icon only (+ `aria-label`); long text that wraps; empty.
3. **Interaction states**: rest, hover, `focus-visible` (via keyboard `tab`), active (mouse down is not captured; use `:active` only if the class set has it, via `press` on Space/Enter), disabled (and hover on disabled), `aria-invalid`, `data-state` for every Radix state, loading/pending where the React source has one.
4. **Radix state machines**: every state and every transition: Accordion single/multiple + collapsible; Checkbox checked/unchecked/indeterminate; Tabs horizontal/vertical, manual/automatic; Dialog open via trigger, close via X, Esc, overlay click; Select with groups/separators/disabled item/scroll buttons; Tooltip delay and skip-delay; Slider range/step/vertical/inverted; Toggle group single/multiple; Menu: sub-menus, checkbox/radio items, shortcuts, typeahead, disabled items.
5. **Placement**: for floating content every `side` x `align` pair that the source or examples expose, plus a collision case (trigger at the viewport edge via `viewport` step).
6. **Orientation / direction**: horizontal and vertical wherever a prop exists; `dir="rtl"` for components that read direction.
7. **Dark mode**: duplicate the base scenarios of every variant with `dark: true`.
8. **API-shape scenarios**: `className` merge conflict (`class: "rounded-full"` vs base `rounded-md`), `asChild`/`as`, forwarded `aria-*`/`data-*`/`id`, `disabled`, controlled `open`/`value` where the source supports it.
9. **Registry examples**: every example in the registry (`/r/styles/new-york-v4/<name>-demo*.json`, `examples/*`) becomes one scenario under id `example__<slug>`.

## Size budget

Typical component 15-40 scenarios; heavy ones (select, menus, calendar, sidebar) up to ~120. Scenarios are cheap (two page loads), so completeness beats thrift; but do not duplicate cells that cannot differ (e.g. hover on a component with no hover class).

## Coverage check (mechanical)

`ruby .claude/scripts/shadcn/scenario_coverage.rb --component <name>` fails when a cva axis option, a Radix `data-state` value, a part with a `data-slot`, or a dark-mode twin has no scenario. The planner runs it before handing off.
