# AspectRatio

Oracle: `dev/port/oracle/src/aspect-ratio.tsx` (manifest `source_sha` b1c157886236782c, tier `radix_stateful`), wrapping `AspectRatioPrimitive.Root` from `radix-ui` 1.7.0 -> `@radix-ui/react-aspect-ratio` 1.1.16 (`dev/react-shadcn-catalog/node_modules/@radix-ui/react-aspect-ratio/dist/index.mjs`, cited below as `ar.mjs:<line>`), whose inner element is `Primitive.div` from `@radix-ui/react-primitive` 2.1.11 (`primitive.mjs`). Registry example: `aspect-ratio-demo` (fetched from `https://ui.shadcn.com/r/styles/new-york-v4/aspect-ratio-demo.json`).

## API

One export, one Ruby class, no nested parts.

```ruby
Chadcn::AspectRatio.new(
  ratio: 1,            # Numeric (Integer, Float, Rational: 16/9r, 16.0/9). Default from ar.mjs:11 `ratio = 1 / 1`
  as_child: false,     # false | tag symbol | Chadcn component instance (primitive.mjs:32-33, Primitive.div supports asChild)
  style: nil,          # String ("opacity: 0.5") or Hash ({ opacity: 0.5 } / { "backgroundColor" => "red" }; camelCase or snake_case keys -> kebab-case CSS)
  class: nil,          # passed through VERBATIM (see below)
  **attrs              # id, role, title, aria: {}, data: {}, aria-*/data-* pass through to the inner element
) { children }
```

- shadcn's `AspectRatio` destructures only `...props` (aspect-ratio.tsx) and adds `data-slot="aspect-ratio"` BEFORE the spread, so a caller `data-slot` would win (attrs merge order: `data-slot` first, caller attrs after).
- There are no base classes and no `cn` call in the oracle: `className` reaches the DOM unchanged. The port must emit `class:` exactly as given (no tailwind_merge; `"rounded-md rounded-lg"` stays both tokens; nil -> no `class` attribute). Scenario `class-verbatim-no-merge`.
- `ratio:` is required to be a positive finite number; only the formatted `100 / ratio` reaches the DOM (see Structure). No string forms ("16/9") are accepted because the React prop is a number.
- No events, no `ref`, no Stimulus controller (see Behavior).

## Structure

Radix renders TWO elements (ar.mjs:13-40); only the inner one carries `data-slot`:

```html
<div style="position: relative; width: 100%; padding-bottom: 56.25%;" data-radix-aspect-ratio-wrapper="">
  <div data-slot="aspect-ratio" class="rounded-lg bg-muted" ...attrs
       style="<caller style>; position: absolute; top: 0px; right: 0px; bottom: 0px; left: 0px;">
    ...children
  </div>
</div>
```

Wrapper (no data-slot, not a shadcn part), ar.mjs:15-24:
- tag `div`, attributes exactly `style` and `data-radix-aspect-ratio-wrapper=""`. Nothing from the caller lands here (no class, id, attrs).
- style in Radix order: `position: relative; width: 100%; padding-bottom: <100 / ratio>%`. The number is formatted like JS `Number#toString` for `100 / ratio` computed in IEEE double: integral values without `.0` (`ratio: 1` -> `100%`, `2` -> `50%`, `4.0/3` -> `75%`), otherwise shortest round-trip digits (`16.0/9` -> `56.25%`, `9.0/16` -> `177.77777777777777%`, `21.0/9` -> `42.857142857142854%`, `1.5` -> `66.66666666666667%`). Ruby `Float#to_s` gives the same digits in this range; strip a trailing `.0`. Rational ratios are converted with `to_f` before dividing, so `16/9r` equals `16.0/9`.

Part `AspectRatio` (inner element, `data-slot="aspect-ratio"`), ar.mjs:25-37:
- tag `div` (or the `as_child` element), `data-slot="aspect-ratio"`, caller `class`, caller attrs.
- style: caller style first, then the forced keys `position: absolute; top: 0; right: 0; bottom: 0; left: 0` (ar.mjs:30-36 spreads `...style` first, so the forced keys always win; a caller `position: static` or `top: 20px` is overridden). As a CSS string, emitting the caller declarations then the forced ones gives the same computed style. React serializes the numeric `0` as `0`/`0px`; the gate ignores the `style` attribute text (parity_run.mjs IGNORED_ATTR) and compares computed style and boxes, so either spelling is fine.
- `as_child:` (primitive.mjs:30-33, Radix Slot): the inner element is replaced by the child; `data-slot`, `class`, attrs and the forced style are merged onto it with `Chadcn::Base#render_as_child` semantics (class plain-joined slot-then-child; style slot-then-child, so a child's own style keys win over the forced ones, matching Radix Slot `mergeProps` `{...slotStyle, ...childStyle}`). The wrapper div is still rendered around it.
- DOM order: wrapper > part > children. No ids, no ARIA, no `data-state`.

Server vs Stimulus: the server renders everything. Nothing is set on the client.

## Behavior

No runtime behavior. `ar.mjs` has no state, no effects, no event handlers, no timers and no `ResizeObserver`: the ratio is pure CSS (padding-bottom percentage resolves against the container width, the inner element is absolutely positioned over it). The tier `radix_stateful` comes from the manifest's classification of the Radix import, not from behavior.

- No Stimulus controller is written (`chadcn--aspect-ratio` does not exist); attaching one would add DOM attributes the oracle lacks (radix-stimulus R11).
- Keyboard: none. Focus: only native focus of focusable children or an `as_child` focusable element (scenarios `focusable-child__tab`, `as-child-a-focus`).
- Pointer: none (hover only matters for children classes).
- Resize: the box follows the container width natively; scenarios `resize__fluid-width` and `resize__fixed-wrapper` replay `viewport` steps to prove it.
- No dismissal, scroll lock, presence, positioning or direction handling. Primitives composed: none.

## Dependencies

None. The scenarios use raw `_div`/`_img`/`_a` elements only. The registry demo uses `next/image` with `fill`; the scenario replaces it by a raw `_img` with the same `alt` and `className` (`h-full w-full` already fills the absolutely positioned part, so `fill`'s inline absolute positioning has the same geometry) and an inline `data:` SVG `src` instead of the Unsplash URL, so both harnesses render without the network. This is a scenario choice, not a component deviation.

## Deviations

None. No `deviations/aspect-ratio.json` is written.
