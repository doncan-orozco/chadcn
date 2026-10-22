# Kbd (`Components::V2::Kbd`, `Components::V2::Kbd::Group`)

Oracle: `dev/port/oracle/src/kbd.tsx` (style `new-york-v4`, source_sha `c0c0ae6a7d1adb77`), manifest `dev/port/oracle/manifest/kbd.json`. Tier `static`: no Stimulus controller, no primitive, no Radix import (`radix_primitives: []`, `use_client: false`). Exports `Kbd` and `KbdGroup`; data-slots `kbd` and `kbd-group`.

## API

```ruby
Components::V2::Kbd.new(class: nil, **attrs) { ... }          # React `Kbd`
Components::V2::Kbd::Group.new(class: nil, **attrs) { ... }   # React `KbdGroup` (name rule: strip root prefix)
```

| part | kwarg | default (tsx) | accepted values |
|---|---|---|---|
| `Kbd` | `class:` | `nil` (`className`) | any string; merged through `cn` (tailwind_merge) after the three base strings |
| `Kbd` | `**attrs` | (`...props`, `React.ComponentProps<"kbd">`) | every HTML attribute: `id`, `title`, `role`, `style`, `data: {}`, `aria: {}` / `"aria-*":` |
| `Kbd::Group` | `class:` | `nil` (`className`) | any string; merged through `cn` after the base string |
| `Kbd::Group` | `**attrs` | (`...props`, typed `React.ComponentProps<"div">` but rendered on a `<kbd>`) | every HTML attribute, same as above |

- No `variant:`, `size:`, `as_child:` or any other kwarg: the source destructures only `className` and `...props` for both parts (manifest `props.destructured`). The port must not add any; there is no `asChild` in the source, so `as_child:` is not part of the API.
- Block = `children`: text (`"K"`, `"⌘"`, `"Ctrl"`), lucide icons (`render Components::V2::Icon.new(name: "command")`), nested elements, or nothing (renders an empty `<kbd>`).
- Events: none dispatched. `ref`: no equivalent.

## Structure

Both parts are server-rendered in full; nothing is set by JS.

```html
<kbd data-slot="kbd" class="{cn(base1, base2, base3, className)}" ...attrs>children</kbd>
<kbd data-slot="kbd-group" class="{cn('inline-flex items-center gap-1', className)}" ...attrs>children</kbd>
```

- Tag: `kbd` for BOTH parts. `KbdGroup` is typed `React.ComponentProps<"div">` but returns `<kbd data-slot="kbd-group">` (tsx `function KbdGroup ... return (<kbd ...`); the port renders `kbd`, not `div` (manifest `renders: "kbd"`).
- Attribute order in the source: `data-slot`, `className`, then `{...props}`. Because `{...props}` comes last, a caller `data-slot` in `**attrs` overrides the component value (React spread semantics; scenario `api__kbd-data-slot-override`). `class` is not overridable that way (`className` is destructured into `cn`).
- No `role`, no `aria-*`, no ids, no `tabindex`, no sr-only text, no owned icons, no `data-state`/`data-variant`.
- `Kbd` class string, copied verbatim from the three `cn` arguments in order (tsx `Kbd`):
  1. `pointer-events-none inline-flex h-5 w-fit min-w-5 items-center justify-center gap-1 rounded-sm bg-muted px-1 font-sans text-xs font-medium text-muted-foreground select-none`
  2. `[&_svg:not([class*='size-'])]:size-3`
  3. `[[data-slot=tooltip-content]_&]:bg-background/20 [[data-slot=tooltip-content]_&]:text-background dark:[[data-slot=tooltip-content]_&]:bg-background/10`
  4. caller `class`
- `Kbd::Group` class string (tsx `KbdGroup`): `inline-flex items-center gap-1`, then caller `class`.
- Merge: `cn` (clsx + tailwind-merge). `class: "rounded-md"` drops `rounded-sm`; `class: "px-2"` drops `px-1`; `class: "bg-primary"` drops `bg-muted` but keeps the `[[data-slot=tooltip-content]_&]:bg-background/20` variant token (different modifier group). Same resolved set as the React DOM.
- State styling is pure CSS, no Stimulus:
  - `[&_svg:not([class*='size-'])]:size-3`: any descendant SVG (not only direct children) without a `size-*` class is 12px (`content-nested-svg-sized`). Lucide icons rendered by `Components::V2::Icon` carry `lucide lucide-<name>` classes and no `size-*`, so they are sized.
  - `[[data-slot=tooltip-content]_&]:*`: when any ancestor has `data-slot="tooltip-content"` (i.e. inside `Tooltip::Content`), background becomes `background/20` (dark: `background/10`) and text `text-background`.
  - `dark:` only on the tooltip-context background token; outside a tooltip, dark mode changes only the resolved `--muted` / `--muted-foreground` values.
  - `pointer-events-none` + `select-none`: no hover/active states exist; no `hover:`, `focus-visible:`, `aria-invalid:`, `disabled:`, `group-*`, `peer-*`, `has-*` or `data-[state=*]` tokens.
- `Kbd::Group` does not style its children; spacing between `Kbd`s comes from its `gap-1`. Non-`Kbd` children (`<span>+</span>` in `kbd-demo`) render as-is.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Kbd` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Kbd::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Kbd::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `kbd.group` | `Kbd::Group` | `KbdGroup` |


Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- None rendered by the component (`registry_dependencies: []`, no lucide import, `npm_dependencies: ["cn"]`).
- Needs `Components::V2::Base` for `cn` and attribute merge.
- Scenarios use lucide icons via `<icon:...>` (`command`, `arrow-big-up`, `search`).
- Example substitutions (scenario-level only, identical on both harnesses, not component deviations). Kbd has no registry dependency on `Button`, `ButtonGroup`, `Tooltip`, `InputGroup`, `Input`, so the coverage check rejects their exports here:
  - `kbd-button`: `Button variant="outline" size="sm" className="pr-2"` -> `_button` with `className="pr-2"` and the same children (`Accept <Kbd>⏎</Kbd>`, `Cancel <Kbd>Esc</Kbd>`).
  - `kbd-tooltip`: `ButtonGroup` -> `_div`, `TooltipTrigger asChild > Button` -> `_button`; each `TooltipContent` (closed and portaled in the oracle, so it would render no Kbd and the scenario would be an EMPTY_RENDER) is rendered visibly as the neutral tooltip-content stand-in `_div` described below, holding the demo's exact children (`Save Changes <Kbd>S</Kbd>` and `Print Document <KbdGroup><Kbd>Ctrl</Kbd><Kbd>P</Kbd></KbdGroup>`), so the scenario compares 3 Kbd + 1 KbdGroup nodes. The tooltip-content styling of Kbd is exercised by the `tooltip-context__*` scenarios, which wrap Kbd / KbdGroup in a neutral `_div` carrying `data-slot="tooltip-content"` and `className="bg-foreground text-background rounded-md px-3 py-1.5 text-xs w-fit"` (the TooltipContent tokens that set its colors, from `manifest/tooltip.json`). The wrapper exists only to satisfy the `[[data-slot=tooltip-content]_&]` ancestor selector on both sides.
  - `kbd-input-group`: `InputGroup` -> `_div`, `InputGroupInput` -> `_input placeholder="Search..."`, `InputGroupAddon` -> `_div` (the inline-end one with the two `Kbd`s), `SearchIcon` -> `<icon:search>`.
  - Full compositions (real `Tooltip::Content`, `Button`, `ButtonGroup`, `InputGroup`) belong to cross-component scenarios once those components are DONE.

## Deviations

None. No `deviations/kbd.json` is written.
