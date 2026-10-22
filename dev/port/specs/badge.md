# Badge (`Components::V2::Badge`)

Oracle: `gems/chadcn/dev/port/oracle/src/badge.tsx` (style `new-york-v4`, source_sha `13a9380dfff853ee`), manifest `gems/chadcn/dev/port/oracle/manifest/badge.json`. Tier `static`: no Stimulus controller, no primitive. Exports `Badge` and `badgeVariants`; one part, data-slot `badge`. Radix primitive used: `Slot` only (`import { Slot } from "radix-ui"`, `const Comp = asChild ? Slot.Root : "span"`).

## API

```ruby
Components::V2::Badge.new(variant: "default", as_child: false, class: nil, **attrs) { ... }
Components::V2::Badge.variants(variant: "default", class: nil) # => String  (React `badgeVariants`)
```

| kwarg | default (tsx) | accepted values |
|---|---|---|
| `variant:` | `"default"` (`variant = "default"` in `function Badge({ ... })`; cva `defaultVariants.variant`) | `default`, `secondary`, `destructive`, `outline`, `ghost`, `link` |
| `as_child:` | `false` (`asChild = false`) | `false` \| tag symbol (`:a`) \| a V2 component instance |
| `class:` | `nil` (`className`) | any string; merged through `cn` (tailwind_merge) after the cva output |
| `**attrs` | (`...props`, `React.ComponentProps<"span">`) | every HTML attribute: `id`, `title`, `role`, `tabindex`, `style`, `data: {}`, `aria: {}` / `"aria-*":` |

- Options accept strings and symbols (shadcn-port R4): `variant: :outline` == `"outline"`. `nil` means the default. An unknown option raises `ArgumentError` (the TS type `VariantProps<typeof badgeVariants>` forbids it; cva would silently emit no variant classes).
- No `size:` axis exists in the oracle (cva has only `variant`); the port must not add one.
- `variants(...)` is the Ruby mapping of the exported `badgeVariants` (api-mapping.md, "Exceptions ... map to class methods"): returns `cn(base, variant[variant], class)` exactly like `badgeVariants({ variant, className })`.
- Block = `children`: text, icons (`render Components::V2::Icon.new(name: "badge-check")`), other components, or nothing (empty badge renders an empty `<span>`).
- `as_child:`: Radix `Slot.Root`. With `as_child: :a` the part renders `<a>` with its own classes, `data-slot="badge"`, `data-variant` and attrs. With a component instance it calls `Components::V2::Base#render_as_child` (Radix `mergeProps`, `gems/chadcn/dev/react-shadcn-catalog/node_modules/@radix-ui/react-slot/dist/index.mjs` lines 81-106): child props win (a child `data-slot` replaces `"badge"`, scenario `api__as-child-child-data-slot-wins`), `class` is a plain join slot-first-then-child without tailwind_merge (`[slotPropValue, childPropValue].filter(Boolean).join(" ")`, scenario `api__as-child-anchor-classname`), `style` merged slot-then-child, child keys win (`api__as-child-style-merge`), `aria-describedby` = `concatAriaDescribedby(childPropValue, slotPropValue)` (`api__as-child-aria-describedby-merge`), `on*` / `data-action` run child first then slot. The scenario harness expresses this as `"asChild": true` with one `_a` (or `_button`) child.
- `as_child` matters for styling: every hover token in the variant table is scoped `[a&]:hover:` (only matches when the badge element itself is an `<a>`). A `<span>` badge or an `as_child` `<button>` gets no hover style (scenarios `span__hover-no-effect`, `api__as-child-button__hover`).
- Events: none dispatched (no `on*Change` in the source).
- `ref`: no equivalent, not part of the API.

## Structure

Single element, server-rendered in full (no Stimulus sets anything):

```html
<span data-slot="badge" data-variant="{variant}" class="{cn(badgeVariants({variant}), className)}" ...attrs>children</span>
```

- Tag: `span` (tsx `const Comp = asChild ? Slot.Root : "span"`); with `as_child` the child's tag (`<a href>`).
- Attribute order in the source: `data-slot`, `data-variant`, `className`, then `{...props}` spread. Because `{...props}` comes last, a caller-supplied `data-slot` or `data-variant` in `**attrs` overrides the component value (React spread semantics, scenario `api__data-slot-override`); `class` is NOT overridable this way because `className` is destructured and passed to `cn`.
- `data-variant` carries the resolved option string and is always present (defaults render `data-variant="default"`; tsx `data-variant={variant}` with `variant = "default"`).
- No `role`, no ids, no `tabindex`, no sr-only text, no icons owned by the component. A span is not focusable: focus-visible styling is only reachable through `as_child: :a` or a caller `tabindex` (`span__not-focusable-tab`, `span__tabindex-focus-visible`).
- `aria-invalid: true` renders `aria-invalid="true"` and triggers the `aria-invalid:` tokens.
- Class string (cva, copied verbatim, keys identical):
  - base: `inline-flex w-fit shrink-0 items-center justify-center gap-1 overflow-hidden rounded-full border border-transparent px-2 py-0.5 text-xs font-medium whitespace-nowrap transition-[color,box-shadow] focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 [&>svg]:pointer-events-none [&>svg]:size-3`
  - variant `default`: `bg-primary text-primary-foreground [a&]:hover:bg-primary/90`
  - variant `secondary`: `bg-secondary text-secondary-foreground [a&]:hover:bg-secondary/90`
  - variant `destructive`: `bg-destructive text-white focus-visible:ring-destructive/20 dark:bg-destructive/60 dark:focus-visible:ring-destructive/40 [a&]:hover:bg-destructive/90`
  - variant `outline`: `border-border text-foreground [a&]:hover:bg-accent [a&]:hover:text-accent-foreground`
  - variant `ghost`: `[a&]:hover:bg-accent [a&]:hover:text-accent-foreground`
  - variant `link`: `text-primary underline-offset-4 [a&]:hover:underline`
  - `compoundVariants`: none. `defaultVariants`: `{ variant: "default" }`.
  - The manifest's `class_tokens` lists `default`: that is the cva variant key picked up by the extractor, not a class; the port must not emit a `default` class.
- Merge order: base, variant, caller `class`, all through `cn` (clsx + tailwind-merge). tailwind-merge resolves `border-transparent` (base) vs `border-border` (outline) to `border-border`, and `focus-visible:ring-ring/50` vs `focus-visible:ring-destructive/20` (destructive) to the destructive one; the React DOM has the same resolved set. `class: "rounded-md"` drops `rounded-full`; `class: "px-1"` drops `px-2`.
- No `outline-none` in the base: a focused `<a>` badge also shows the UA focus outline in both renderers (same DOM, same computed style).
- `[&>svg]:size-3` / `[&>svg]:pointer-events-none` only hit direct-child SVGs; an icon wrapped in another element keeps its own size (`content-nested-svg-not-sized`).
- State styling is pure CSS: `focus-visible:`, `aria-invalid:`, `dark:`, `[a&]:hover:`, `[&>svg]`. No `data-[state=*]`, `disabled:`, `group-*`, `peer-*` or `has-*` tokens.

## Dependencies

- None rendered by the component (`registry_dependencies: []`, no lucide import in the source).
- Needs `Components::V2::Base` for `cn`, attribute merge and `render_as_child` (Slot).
- Scenarios use lucide icons via the `<icon:...>` child convention (`Components::V2::Icon` on the Phlex side): `badge-check`, `circle-alert`, `arrow-right`, `check`, `x`, `loader-circle`.
- Example substitutions (scenario-level only, identical on both harnesses, not component deviations): `spinner-badge` renders `Spinner` (registry dependency of the example, not of badge; Spinner is not yet ported) -> lucide `loader-circle` icon child. `badge-demo`'s unused `AlertCircleIcon`/`CheckIcon` imports are dropped (they are never rendered).

## Deviations

None. No `deviations/badge.json` is written.
