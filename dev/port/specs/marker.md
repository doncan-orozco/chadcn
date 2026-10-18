# Marker (`Components::V2::Marker`)

Oracle: `gems/phlex-shadcn/dev/port/oracle/src/marker.tsx` (style `new-york-v4`, source_sha `036277635df058b8`), manifest `gems/phlex-shadcn/dev/port/oracle/manifest/marker.json`, registry item `gems/phlex-shadcn/dev/port/oracle/registry/marker.json` (`registry:ui`, dependencies `cn`, `radix-ui`, no registry dependencies). Tier `static`: no Stimulus controller, no primitive. Exports `Marker`, `MarkerIcon`, `MarkerContent`, `markerVariants`; data-slots `marker`, `marker-icon`, `marker-content`. Radix primitive used: `Slot` only (`import { Slot } from "radix-ui"`, `const Comp = asChild ? Slot.Root : "div"` in `function Marker`).

## API

```ruby
Components::V2::Marker.new(variant: "default", as_child: false, class: nil, **attrs) { ... }   # Marker
Components::V2::Marker::Icon.new(class: nil, **attrs) { ... }                                  # MarkerIcon
Components::V2::Marker::Content.new(class: nil, **attrs) { ... }                               # MarkerContent
Components::V2::Marker.variants(variant: "default", class: nil) # => String                  # markerVariants
```

Name mapping (api-mapping.md, strip the root prefix): `MarkerIcon` -> `Marker::Icon`, `MarkerContent` -> `Marker::Content`; `Marker` is the root class itself; the exported cva `markerVariants` -> class method `Marker.variants`.

| part | kwarg | default (tsx) | accepted values |
|---|---|---|---|
| `Marker` | `variant:` | `"default"` (`variant = "default"` in `function Marker({ ... })`; the cva has NO `defaultVariants`, manifest `cva.markerVariants.defaults: {}`) | `default`, `separator`, `border` |
| `Marker` | `as_child:` | `false` (`asChild = false`) | `false` \| tag symbol (`:a`, `:button`, `:span`) \| a V2 component instance |
| all | `class:` | `nil` (`className`) | any string; merged through `cn` (tailwind_merge) after the part's own classes |
| `Marker` | `**attrs` | `...props` (`React.ComponentProps<"div">`) | any HTML attribute: `id`, `role` (examples use `role="status"`), `title`, `style`, `tabindex`, `data: {}`, `aria: {}` / `"aria-*":` |
| `Marker::Icon`, `Marker::Content` | `**attrs` | `...props` (`React.ComponentProps<"span">`) | same |

- Options accept strings and symbols (shadcn-port R4): `variant: :separator` == `"separator"`. `nil` means the default (`"default"`). An option outside the cva keys raises `ArgumentError` (TS `VariantProps<typeof markerVariants>` forbids it; cva would silently emit no variant classes). React `variant={null}` (allowed by `VariantProps`) would skip the destructuring default and omit `data-variant`; the Ruby API has no equivalent and no scenario passes `null`.
- No `size:` axis, no `as:` kwarg (only `as_child:`), no compound variants.
- `Marker.variants(variant:, class:)` returns exactly `cn(base, variants.variant[variant], class)` like `markerVariants({ variant, className })`. Note: the React component passes `className` INTO `markerVariants` (`cn(markerVariants({ variant, className }))`), so the caller class is merged in the same `cn` pass, last.
- Block = `children`. `Marker`: any content (normally `Marker::Icon` + `Marker::Content`, a plain text child, or nothing). `Marker::Icon`: an icon (`render Components::V2::Icon.new(name: "git-branch")`) or any SVG/element. `Marker::Content`: text, inline elements, `<a>` links.
- `as_child:` (Marker only; `Marker::Icon` and `Marker::Content` have no `asChild`): Radix `Slot.Root` through `Components::V2::Base#render_as_child`, Radix `mergeProps` semantics (`@radix-ui/react-slot/dist/index.mjs` `mergeProps`): child props win (a child `data-slot` replaces `"marker"`, scenario `api__as-child-child-data-slot-wins`; a child `data-variant` replaces the slot's, `api__as-child-child-data-variant-wins`), `class` is a PLAIN join slot-first-then-child with NO tailwind_merge (`api__as-child-anchor-classname`: the slot's `gap-4` (already merged over `gap-2` by `cn` inside Marker) AND the child's `gap-1`, plus `[a]:underline` AND the child's `no-underline`, all stay in the DOM), `style` merged slot-then-child with child keys winning (`api__as-child-style-merge`), `data-action` child first then slot. With `as_child: :a` the part renders `<a>` with its own classes, `data-slot="marker"`, `data-variant` and attrs. Scenario harness: `"asChild": true` with one `_a`, `_button` or `_span` child.
- `as_child` matters for styling: the base tokens `[a]:underline [a]:underline-offset-3 [a]:hover:text-foreground` compile to `.\[a\]\:underline:is(a)` (verified with the catalog's Tailwind v4.3.3 `@tailwindcss/node` compile), i.e. they apply only when the marker element ITSELF is an `<a>` (as_child anchor). A `<div>` marker or an `as_child` `<button>` gets no underline and no hover color from the base (scenarios `div__hover-no-effect`, `api__as-child-button__no-hover-class`); the `marker-link-button` example adds `hover:text-foreground` on the button child itself.
- Events: none dispatched (no `on*Change` in the source). `onClick` in `marker-link-button` (a sonner toast) is caller behavior, not part of the component.
- `ref`: no equivalent, not part of the API.

## Structure

All parts are server-rendered in full; no Stimulus, nothing set on the client. No ids, no `aria-*` wiring, no sr-only text, no icons owned by the component.

```html
<div data-slot="marker" data-variant="{variant}" class="{cn(markerVariants({variant, className}))}" ...attrs>
  <span data-slot="marker-icon" aria-hidden="true" class="{cn('size-4 shrink-0 [&_svg:not([class*=size-])]:size-4', className)}" ...attrs>svg</span>
  <span data-slot="marker-content" class="{cn('min-w-0 wrap-break-word ...', className)}" ...attrs>text</span>
</div>
```

### `Marker` (data-slot `marker`)
- Tag `div` (`const Comp = asChild ? Slot.Root : "div"`); with `as_child` the child's tag.
- Attribute order in the source: `data-slot`, `data-variant`, `className`, then `{...props}`. Because the spread comes last, a caller `data-slot` or `data-variant` in `**attrs` overrides the component value (React spread semantics; scenarios `api__data-slot-override`, `api__data-variant-override`). `class` is not overridable this way (`className` is destructured into `cn`). `api__data-variant-override` is observable: `data-variant="separator"` on a default marker switches the content's `group-data-[variant=separator]/marker:` styles on while the `before:`/`after:` lines (variant classes) stay absent.
- `data-variant` always carries the resolved option string (`data-variant={variant}` with `variant = "default"`), so defaults render `data-variant="default"`.
- Classes, verbatim from `markerVariants`:
  - base: `group/marker relative flex min-h-4 w-full items-center gap-2 text-left text-sm text-muted-foreground [&_svg:not([class*='size-'])]:size-4 [a]:underline [a]:underline-offset-3 [a]:hover:text-foreground`
  - `default`: `""` (no class; the extractor's token list contains no `default` token and the port must not emit one)
  - `separator`: `before:mr-1 before:h-px before:min-w-0 before:flex-1 before:bg-border after:ml-1 after:h-px after:min-w-0 after:flex-1 after:bg-border` (Tailwind `before:`/`after:` add `content: var(--tw-content)`, so two 1px lines flank the children: `::before`, children, `::after`)
  - `border`: `border-b border-border pb-2`
  - `defaultVariants`: none; `compoundVariants`: none.
- `[&_svg:not([class*='size-'])]:size-4` sizes every descendant SVG without a `size-*` class, including an SVG placed directly in the marker without `Marker::Icon` (`content__svg-direct-child`).
- `text-left`, `before:mr-1`, `after:ml-1` are physical: under `dir="rtl"` the lines keep their physical margins and the text stays left-aligned (scenarios `rtl__*`).

### `Marker::Icon` (data-slot `marker-icon`)
- Tag `span`, `aria-hidden="true"` set BEFORE `{...props}`, so a caller `aria-hidden` overrides it (`api__icon-aria-hidden-override`).
- Classes: `size-4 shrink-0 [&_svg:not([class*='size-'])]:size-4`; caller `class: "size-6"` replaces `size-4` via tailwind_merge (`api__icon-class-merge`), while the arbitrary `[&_svg...]` token remains, so the inner SVG stays 16px.

### `Marker::Content` (data-slot `marker-content`)
- Tag `span`, no ARIA.
- Classes: `min-w-0 wrap-break-word group-data-[variant=separator]/marker:flex-none group-data-[variant=separator]/marker:text-center *:[a]:underline *:[a]:underline-offset-3 *:[a]:hover:text-foreground`.
- `group-data-[variant=separator]/marker:` matches any ancestor with class `group/marker` and `data-variant="separator"` (compiled `:is(:where(.group\/marker)[data-variant="separator"] *)`), not only a Marker (`context__separator-outside-marker-group`).
- `*:[a]:` compiles to `:is(.x > *):is(a)`: only DIRECT `<a>` children of the content are underlined and get the hover color (`content__link-child*`); a nested anchor is not (`content__link-nested-not-direct`).
- `shimmer` used by the examples (`className="shimmer"`) is the shadcn `@utility shimmer` (present in `app/assets/tailwind/vendor/shadcn-tailwind.css` and in the catalog via `shadcn/tailwind.css`); it is a caller class, not a component token.

### States
Pure CSS, no `data-state`, `disabled:`, `aria-invalid:`, `focus-visible:`, `peer-*`, `has-*` or `dark:` tokens. Only interaction states are hover on an anchor marker / direct anchor child, and the UA focus outline on an anchor/button marker (no `outline-none` in the base; same in both renderers). Dark mode changes only the semantic tokens (`--muted-foreground`, `--border`, `--foreground`).

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Phlex::Shadcn::Marker` MUST `yield self` from `view_template`; `Phlex::Shadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Marker::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Phlex::Shadcn::Marker::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `marker.icon` | `Marker::Icon` | `MarkerIcon` |
| `marker.content` | `Marker::Content` | `MarkerContent` |


Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- None rendered by the component (`registry_dependencies: []`, manifest `icons: []`, no lucide import in the source).
- Needs `Components::V2::Base` for `cn`, attribute merge and `render_as_child` (Slot).
- Scenarios use lucide icons through the `<icon:...>` child convention (`Components::V2::Icon` on the Phlex side): `git-branch`, `search`, `file-text`, `book-open-check`, `rotate-ccw`, `loader-circle`.
- Registry examples: upstream `apps/v4/examples/radix/marker-{border,demo,icon,link-button,separator,shimmer,status,variants}.tsx` (the `/r/styles/new-york-v4/marker-demo.json` endpoint returns 404; examples import from `@/styles/radix-rhea/ui/marker` and are rendered here with the new-york-v4 oracle), each as `example__marker-<slug>` plus a `__dark` twin. Scenario-level substitutions (identical on both harnesses, not component deviations): `Spinner` (registry dependency of the examples, not of marker, so the coverage check rejects its export) -> `<icon:loader-circle>` (Spinner renders lucide `Loader2Icon` = `loader-circle` with `role="status" aria-label="Loading" className="size-4 animate-spin"`; those attributes are dropped, the SVG is sized by MarkerIcon's `[&_svg...]:size-4`, motion is disabled anyway); `marker-link-button`'s `onClick={() => toast(...)}` is dropped (sonner, no visual effect without a Toaster).

## Deviations

None. No `deviations/marker.json` is written.
