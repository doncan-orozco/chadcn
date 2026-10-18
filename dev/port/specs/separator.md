# Separator

Oracle: `gems/phlex-shadcn/dev/port/oracle/src/separator.tsx` (manifest `source_sha` ad7d5403fe337160, tier `radix_stateful`), wrapping `SeparatorPrimitive.Root` from `radix-ui` 1.7.0 -> `@radix-ui/react-separator` 1.1.16 (`gems/phlex-shadcn/dev/react-shadcn-catalog/node_modules/@radix-ui/react-separator/dist/index.mjs`, cited as `sep.mjs:<line>`), whose element is `Primitive.div` from `@radix-ui/react-primitive` 2.1.11 (`react-primitive/dist/index.mjs`, cited as `primitive.mjs:<line>`). Registry example: `separator-demo` (fetched from `https://ui.shadcn.com/r/styles/new-york-v4/separator-demo.json`; the registry index lists only `separator` and `separator-demo`).

## API

One export, one Ruby class, no nested parts.

```ruby
Components::V2::Separator.new(
  orientation: "horizontal", # "horizontal" | "vertical", strings or symbols (:horizontal, :vertical). Default from separator.tsx `orientation = "horizontal"` (also sep.mjs:13 DEFAULT_ORIENTATION)
  decorative: true,          # Boolean. Default from separator.tsx `decorative = true` (shadcn overrides Radix's undefined default)
  as_child: false,           # false | tag symbol | V2 component instance (primitive.mjs:32-33, Primitive.div supports asChild via Radix Slot)
  class: nil,                # merged through cn (tailwind_merge) AFTER the base classes, caller wins (separator.tsx `cn(base, className)`)
  **attrs                    # id, title, role, aria: {}, data: {}, aria-*/data-* pass through and WIN over the computed role/aria-orientation/data-orientation
)
```

- Base class string, verbatim (separator.tsx, manifest `class_tokens`): `shrink-0 bg-border data-[orientation=horizontal]:h-px data-[orientation=horizontal]:w-full data-[orientation=vertical]:h-full data-[orientation=vertical]:w-px`. No cva (manifest `cva: {}`), no variants.
- `orientation:` is normalized with `to_s`. Any value other than `"horizontal"`/`"vertical"` falls back to `"horizontal"` (sep.mjs:18 `isValidOrientation(orientationProp) ? orientationProp : DEFAULT_ORIENTATION`, sep.mjs:32-34). `nil` behaves like the default. Scenario `orientation-invalid-falls-back`.
- `decorative:` is truthy/falsy exactly like the JS prop (sep.mjs:20 `decorative ? ... : ...`).
- Children: the oracle does not destructure `children`; Radix would render them inside the `div`. The port renders a given block inside the element for API parity, but no scenario relies on it (shadcn never passes children).
- No events are dispatched (Radix Separator has no `onXChange`). `ref` has no equivalent.

Attribute precedence (load-bearing; it follows the JSX spread order):
1. sep.mjs:24-26 renders `{ "data-orientation": orientation, ...semanticProps, ...domProps }`, so everything the caller passes (including shadcn's own `data-slot`, `className`) is spread AFTER `data-orientation`, `role` and `aria-orientation`.
2. separator.tsx writes `data-slot="separator"` BEFORE `{...props}`, so a caller `data: { slot: "x" }` wins (scenario `data-slot-override`).
3. A caller `role:` / `aria: { orientation: }` / `data: { orientation: }` therefore overrides the computed value (scenarios `role-override__decorative`, `aria-orientation-override`). Note `orientation:` itself is the kwarg; only an explicit `data-orientation` attr overrides the data attribute.

## Structure

```html
<!-- decorative: true (default), any orientation -->
<div data-orientation="horizontal" role="none" data-slot="separator"
     class="shrink-0 bg-border data-[orientation=horizontal]:h-px data-[orientation=horizontal]:w-full data-[orientation=vertical]:h-full data-[orientation=vertical]:w-px" ...attrs></div>

<!-- decorative: false, orientation: "vertical" -->
<div data-orientation="vertical" aria-orientation="vertical" role="separator" data-slot="separator" class="..."></div>

<!-- decorative: false, orientation: "horizontal" -->
<div data-orientation="horizontal" role="separator" data-slot="separator" class="..."></div>
```

Part `Separator` (`data-slot="separator"`):
- tag `div` (sep.mjs:22 `Primitive.div`, primitive.mjs:13), or the `as_child` element. It is NOT an `<hr>`.
- `data-orientation`: always present, `"horizontal"` or `"vertical"` (the normalized value, sep.mjs:24). The base classes key off it.
- `role` / `aria-orientation` (sep.mjs:19-20):
  - `decorative: true` -> `role="none"`, no `aria-orientation`.
  - `decorative: false` -> `role="separator"`; `aria-orientation="vertical"` only when the orientation is vertical; for horizontal the attribute is omitted (`ariaOrientation` is `undefined`, the implicit ARIA value of a separator is horizontal).
- `data-slot="separator"`, `class`, caller attrs (precedence above). No ids, no `data-state`, no `tabindex` (not focusable).
- `as_child:` (primitive.mjs:30-37, Radix Slot): the `div` is replaced by the single child; `data-orientation`, `role`, `aria-orientation`, `data-slot`, classes and attrs are merged with `Components::V2::Base#render_as_child` semantics (class plain-joined slot-then-child, child attrs win). Scenarios `as-child-span`, `as-child-li-vertical`.
- DOM order: one element, no children. Server renders everything; Stimulus sets nothing.

## Behavior

No runtime behavior. `sep.mjs` has no state, no effects, no event handlers, no timers: it only computes attributes during render (sep.mjs:17-20). The tier `radix_stateful` comes from the manifest's classification of the Radix import, not from behavior.

- No Stimulus controller is written (`shadcn--separator` does not exist); attaching one would add DOM attributes the oracle lacks.
- Keyboard: none. The element is never focusable; `Tab` skips it (scenario `focus-skip__tab`, which tabs between two links around a non-decorative vertical separator).
- Pointer: none; no hover/focus/disabled classes in the source, so no hover scenarios.
- Sizing: horizontal is `h-px w-full`; vertical is `h-full w-px`, which only has height when the parent has a definite height (demo uses `h-5`) or the separator is a stretched flex item (scenario `vertical-in-stretch-row`). `shrink-0` keeps it from collapsing in flex rows/columns (scenario `in-flex-column`). Width follows the container on resize (scenario `resize__full-width`, `viewport` steps).
- Direction: Radix Separator does not read `dir`; no RTL scenario.
- Dismissal, scroll lock, Presence, positioning: none. Primitives composed: none.

## Dependencies

None (`registry_dependencies: []`, manifest `icons: []`). Scenarios use raw `_div`/`_h4`/`_p`/`_a`/`_span`/`_ul`/`_li` elements only. `separator-demo` is reproduced verbatim (scenario `example__separator-demo` + dark twin).

## Deviations

None. No `deviations/separator.json` is written.
