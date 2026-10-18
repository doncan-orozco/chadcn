# Spinner (`Components::V2::Spinner`)

Oracle: `gems/phlex-shadcn/dev/port/oracle/src/spinner.tsx` (style `new-york-v4`, source_sha `5d040fc49cb54c02`), manifest `gems/phlex-shadcn/dev/port/oracle/manifest/spinner.json`. Tier `static`: no Stimulus controller, no primitive, no Radix import (`radix_primitives: []`, `use_client: false`). Single export `Spinner`. The source sets **no `data-slot`** (manifest `data_slot: null`, `data_slots: []`): R5 has nothing to apply and the port must not add one.

## API

```ruby
Components::V2::Spinner.new(class: nil, **attrs) { ... }   # React `Spinner`
```

| kwarg | default (tsx) | accepted values |
|---|---|---|
| `class:` | `nil` (`className`) | any string; goes through `cn("size-4 animate-spin", class)` (tailwind_merge), caller wins |
| `**attrs` | (`...props`, `React.ComponentProps<"svg">`) | every SVG/HTML attribute: `id`, `style`, `data: {}`, `aria: {}` / `"aria-*":`, `role:` |

- No `variant:`, `size:`, `as_child:`: the source destructures only `className` and `...props` (manifest `props.destructured`), no cva (`uses_cva: false`, `cva: {}`), so no string/symbol option handling applies.
- `role:` and `aria-label` / `aria: { label: }` override the component values (`role="status"`, `aria-label="Loading"`), because in the tsx `{...props}` comes after them.
- lucide-consumed props (the `...props` reach lucide's `Icon`, `lucide-react@0.577.0` `dist/esm/Icon.js`, which destructures them instead of forwarding them): `color:` sets the `stroke` attribute (default `currentColor`) and emits no `color` attribute; `stroke_width:` (React `strokeWidth`, default `2`) sets `stroke-width`. Scenarios `api__lucide-color-prop`, `api__lucide-stroke-width-prop`. `size`/`absoluteStrokeWidth` are not in `ComponentProps<"svg">` and are not part of the API.
- Block = `children` (optional, normally empty): lucide appends it inside the `svg` after the icon path.
- Events: none dispatched. `ref`: no equivalent.

## Structure

Fully server-rendered; nothing is set by JS. Exact React output (lucide-react 0.577.0: `Loader2Icon` is an alias of `icons/loader-circle.js`, `createLucideIcon("loader-circle", ...)`):

```html
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none"
     stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
     class="lucide lucide-loader-circle {cn('size-4 animate-spin', className)}"
     role="status" aria-label="Loading" ...attrs>
  <path d="M21 12a9 9 0 1 1-6.219-8.56"></path>
</svg>
```

- Tag: `svg` (manifest `renders: "Loader2Icon"`), one `path` child.
- Class: lucide `mergeClasses("lucide", mergeClasses("lucide-loader-circle", "lucide-loader-circle", cnResult))` = `lucide lucide-loader-circle` followed by the `cn` result. The `lucide*` prefix is a plain join (deduplicated by whole string), never tailwind-merged; only `size-4 animate-spin` + caller class go through `cn`. So `class: "size-8"` gives `lucide lucide-loader-circle animate-spin size-8` (same set as React; `api__class-merge-size`).
- **No `aria-hidden`.** lucide `Icon.js` adds `aria-hidden="true"` only when `!children && !hasA11yProp(rest)`; `hasA11yProp` is true for any `aria-*`, `role` or `title` prop, and Spinner always passes `role` and `aria-label`. If the caller passes `aria-hidden: "true"` it is forwarded as-is (`api__aria-hidden-forwarded`).
- `role="status"`, `aria-label="Loading"` (literal English string from the tsx; not translated, to keep DOM parity). No sr-only text, no ids, no `data-state`, no `data-slot`.
- No state classes: no `hover:`, `focus-visible:`, `aria-invalid:`, `disabled:`, `group-*`, `peer-*`, `has-*`, `data-[state=*]`, `dark:` tokens. Colour comes from `currentColor`, so dark mode only changes the inherited `color` (scenarios `context__inherits-current-color`, `api__class-merge-text-token`).
- `animate-spin` is Tailwind's `spin` keyframe (rotate 360deg, 1s linear infinite). Scenarios run with motion disabled except `motion__spin` (`animations: true`).
- Parity observation: because there is no `data-slot`, every scenario sets `"observe": ["svg.animate-spin"]` so the runner compares the spinner svg(s) under the synthetic slot `observe:svg.animate-spin[<i>]` (one node per Spinner in the tree; `animate-spin` is kept by every `cn` result, also with `role`/`aria-hidden` overrides).

## Dependencies

- `Components::V2::Icon` (infra `_icons`) with `name: "loader-circle"`, if it reproduces lucide's `Icon` exactly: the `lucide lucide-loader-circle` class prefix, `color` -> `stroke`, `stroke_width`, and the `hasA11yProp` rule that suppresses `aria-hidden` when `role`/`aria-*`/`title` is present. If `Icon` always emits `aria-hidden`, Spinner must not use it as is (G2 would fail on the extra attribute); the builder then renders the same `svg` through the shared icon data, not a hand-drawn path.
- `Components::V2::Base` for `cn` and attribute merge. `registry_dependencies: []`.
- Registry examples: `spinner-basic`, `spinner-size`, `spinner-color` become `example__*` scenarios (layout wrappers `_div` only). `spinner-demo`/`spinner-item` (Item, Progress, Button), `spinner-button` (Button), `spinner-badge` (Badge), `spinner-empty` (Empty, Button) and `spinner-input-group` (InputGroup) compose components that are not dependencies of spinner, so the coverage check rejects their exports; they belong in those components' scenario files (button/badge/marker currently substitute `<icon:loader-circle>` for Spinner). `spinner-custom` defines its own local `Spinner` around `LoaderIcon` and never renders the oracle export, so it has no scenario here.

## Deviations

None. No `deviations/spinner.json` is written.
