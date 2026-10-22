# Breadcrumb (`Components::V2::Breadcrumb`)

Oracle: `gems/chadcn/dev/port/oracle/src/breadcrumb.tsx` (style `new-york-v4`, source_sha `c75fcd3d9e847018`), manifest `gems/chadcn/dev/port/oracle/manifest/breadcrumb.json`. Tier `static`: no Stimulus controller, no primitive. Seven exports, each one element with its own data-slot; no cva, no `data-[state=*]` tokens, no `non_rendered_slots`. The only Radix primitive is `Slot` (BreadcrumbLink `asChild`).

## API

```ruby
Components::V2::Breadcrumb.new(**attrs) { ... }                                   # BreadcrumbList children
Components::V2::Breadcrumb::List.new(class: nil, **attrs) { ... }                 # BreadcrumbItem / BreadcrumbSeparator children
Components::V2::Breadcrumb::Item.new(class: nil, **attrs) { ... }
Components::V2::Breadcrumb::Link.new(as_child: false, class: nil, **attrs) { ... }
Components::V2::Breadcrumb::Page.new(class: nil, **attrs) { ... }
Components::V2::Breadcrumb::Separator.new(class: nil, **attrs) { ... }            # block optional; default ChevronRight icon
Components::V2::Breadcrumb::Ellipsis.new(class: nil, **attrs)                     # block ignored
```

| Part (React export) | kwargs (tsx) | `**attrs` type (tsx) |
|---|---|---|
| `Breadcrumb` | none destructured (`{ ...props }`); `class:` is NOT run through `cn` (see Structure) | `React.ComponentProps<"nav">` |
| `Breadcrumb::List` (`BreadcrumbList`) | `class:` (`className`) | `React.ComponentProps<"ol">` |
| `Breadcrumb::Item` (`BreadcrumbItem`) | `class:` | `React.ComponentProps<"li">` |
| `Breadcrumb::Link` (`BreadcrumbLink`) | `as_child:` default `false` (`asChild?: boolean`, falsy = `"a"`), `class:` | `React.ComponentProps<"a">` (`href`, `target`, `rel`, ...) |
| `Breadcrumb::Page` (`BreadcrumbPage`) | `class:` | `React.ComponentProps<"span">` |
| `Breadcrumb::Separator` (`BreadcrumbSeparator`) | `class:`; block = `children` | `React.ComponentProps<"li">` |
| `Breadcrumb::Ellipsis` (`BreadcrumbEllipsis`) | `class:` | `React.ComponentProps<"span">` |

- Name rule: strip the root prefix (`BreadcrumbList` -> `Breadcrumb::List`). `Breadcrumb::Link` lives inside the `Breadcrumb` namespace, so the builder must reference Phlex helpers explicitly to avoid clashing with any top-level `Link` constant.
- No options/enums (no cva), so R4 has no axis to normalize.
- `as_child:` on `Breadcrumb::Link` only: `false` | tag symbol (`:span`, `:a`) | V2 component instance. Radix `Slot.Root` (`const Comp = asChild ? Slot.Root : "a"`). Merge per `@radix-ui/react-slot` 1.4.0 `dist/index.mjs` `mergeProps` lines 81-106: child props win (`{ ...slotProps, ...overrideProps }`, line 105), so a child `data-slot` / `title` / `href` replaces the slot's; `className` is a plain join slot-first-then-child with no tailwind-merge (line 100), so `"transition-colors hover:text-foreground underline font-medium hover:text-primary"` keeps both `hover:` colors; `style` slot-then-child (line 98); `aria-describedby` = `concatAriaDescribedby(child, slot)` (line 102); `on*` handlers / `data-action` child first then slot (lines 86-96). Slot side `class` is the already-`cn`-merged `cn("transition-colors hover:text-foreground", className)`. Implemented once in `Components::V2::Base#render_as_child`.
- `Separator` block: `{children ?? <ChevronRight />}`. No block (nil) renders the icon; any block (icon, text `"/"`) replaces it. A block that yields an empty string is not nullish in React either, so it renders nothing (no icon).
- `Ellipsis` block: the source destructures only `className`, and the explicit JSX children (`<MoreHorizontal/>` + sr-only span) override any `children` in `...props`, so a caller block is ignored (scenario `api__ellipsis-ignores-children`).
- Events: none dispatched (no `on*Change`). `onClick` etc. are plain DOM events via `data: { action: ... }`.
- `ref`: no equivalent, not part of the API.

## Structure

All server-rendered; nothing set by Stimulus; no ids generated. Attribute order follows the source (component attributes first, `{...props}` spread last), so a caller attribute with the same name overrides the component one, except `class` on the parts that destructure `className` (merged through `cn`, caller last).

```html
<nav aria-label="breadcrumb" data-slot="breadcrumb" ...attrs>
  <ol data-slot="breadcrumb-list" class="flex flex-wrap items-center gap-1.5 text-sm break-words text-muted-foreground sm:gap-2.5">
    <li data-slot="breadcrumb-item" class="inline-flex items-center gap-1.5">
      <a data-slot="breadcrumb-link" class="transition-colors hover:text-foreground" href="#">Home</a>
    </li>
    <li data-slot="breadcrumb-separator" role="presentation" aria-hidden="true" class="[&>svg]:size-3.5"><svg class="lucide lucide-chevron-right" .../></li>
    <li data-slot="breadcrumb-item" class="inline-flex items-center gap-1.5">
      <span data-slot="breadcrumb-ellipsis" role="presentation" aria-hidden="true" class="flex size-9 items-center justify-center">
        <svg class="lucide lucide-ellipsis size-4" aria-hidden="true" .../><span class="sr-only">More</span>
      </span>
    </li>
    <li data-slot="breadcrumb-item" class="inline-flex items-center gap-1.5">
      <span data-slot="breadcrumb-page" role="link" aria-disabled="true" aria-current="page" class="font-normal text-foreground">Breadcrumb</span>
    </li>
  </ol>
</nav>
```

| Part | Tag | data-slot | Fixed attributes (overridable by `**attrs`) | Classes (verbatim, tsx) |
|---|---|---|---|---|
| Breadcrumb | `nav` | `breadcrumb` | `aria-label="breadcrumb"` | none |
| Breadcrumb::List | `ol` | `breadcrumb-list` | - | `flex flex-wrap items-center gap-1.5 text-sm break-words text-muted-foreground sm:gap-2.5` |
| Breadcrumb::Item | `li` | `breadcrumb-item` | - | `inline-flex items-center gap-1.5` |
| Breadcrumb::Link | `a` (or as_child tag) | `breadcrumb-link` | - | `transition-colors hover:text-foreground` |
| Breadcrumb::Page | `span` | `breadcrumb-page` | `role="link"`, `aria-disabled="true"`, `aria-current="page"` | `font-normal text-foreground` |
| Breadcrumb::Separator | `li` | `breadcrumb-separator` | `role="presentation"`, `aria-hidden="true"` | `[&>svg]:size-3.5` |
| Breadcrumb::Ellipsis | `span` | `breadcrumb-ellipsis` | `role="presentation"`, `aria-hidden="true"` | `flex size-9 items-center justify-center` |

- `Breadcrumb` (nav): `className` is not destructured, it travels inside `...props` untouched. The port must emit the caller's `class` verbatim, NOT through `cn`/tailwind_merge (`class: "p-2 p-4 border"` stays `p-2 p-4 border`; scenario `api__breadcrumb-class-not-merged`), and with no class supplied the `nav` has no `class` attribute at all. `aria-label: "You are here"` replaces `"breadcrumb"` (spread after).
- `data-slot` is written before `{...props}` on every part, so a caller `data-slot` would override it (React spread); with `as_child` the child's `data-slot` wins (Slot).
- `Breadcrumb::Link` without `as_child`: `<a>` with no `href` unless given (scenario `part-link__plain-anchor-no-href`); the port must not add `href`, `role` or `tabindex`.
- `Breadcrumb::Page`: `aria-disabled="true"` is the string `"true"` (tsx literal); `aria-current: "location"`, `aria-disabled: "false"` override (scenario `api__page-aria-override`).
- Icons (lucide-react 0.577.0, same set as `Components::V2::Icon`): `ChevronRight` -> `chevron-right`, rendered with no className, so `class="lucide lucide-chevron-right"`, `aria-hidden="true"`, `width/height=24`, sized by the parent's `[&>svg]:size-3.5`. `MoreHorizontal` is an alias of `Ellipsis` (`createLucideIcon("ellipsis", ...)`, export `default as MoreHorizontal`) -> name `ellipsis`, `class="lucide lucide-ellipsis size-4"`, `aria-hidden="true"`.
- sr-only text: `More` inside Ellipsis (`<span className="sr-only">More</span>`, after the svg). The DOM in the `en` locale must contain exactly `More` (G2 runs in `en`). If the builder localizes it (house rule: en + es), the key and its `es` entry are added by the orchestrator (locales are shared files, shadcn-port R13); the default text stays `More`.
- State styling is pure CSS: `hover:text-foreground` (Link), `transition-colors`, `sm:gap-2.5` (List, >= 640px), dark mode via semantic tokens only (`text-muted-foreground`, `text-foreground`). No `data-state`, `aria-invalid`, `disabled` or `focus-visible` tokens; focus ring on links is the UA default and must match because the DOM is identical.
- `Breadcrumb::Separator` is an `li` and must be a sibling of `Breadcrumb::Item` inside `Breadcrumb::List`, never nested in an Item: the shadcn `breadcrumb-responsive` docs example nests it (`<li>` in `<li>`, invalid HTML that React keeps because it builds the DOM in JS, while the browser parser auto-closes the outer `li` of the server-rendered Phlex page), so scenarios `example__breadcrumb-responsive` and `example__breadcrumb-responsive__below-md` render it as the sibling right after its item.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Breadcrumb` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Breadcrumb::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Breadcrumb::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `breadcrumb.list` | `Breadcrumb::List` | `BreadcrumbList` |
| `breadcrumb.item` | `Breadcrumb::Item` | `BreadcrumbItem` |
| `breadcrumb.link` | `Breadcrumb::Link` | `BreadcrumbLink` |
| `breadcrumb.page` | `Breadcrumb::Page` | `BreadcrumbPage` |
| `breadcrumb.separator` | `Breadcrumb::Separator` | `BreadcrumbSeparator` |
| `breadcrumb.ellipsis` | `Breadcrumb::Ellipsis` | `BreadcrumbEllipsis` |

Names that shadow a Phlex HTML element inside `Breadcrumb`'s OWN `view_template` (use `tag(:link)` there, never the bare method): `link`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Components::V2::Icon` (`chevron-right` in Separator default, `ellipsis` in Ellipsis).
- `Components::V2::Base` for `cn`, attribute merge and `render_as_child` (Slot).
- No registry dependencies (`registry_dependencies: []`).
- Scenarios also use icons `slash`, `house`, `chevron-down` via the `<icon:...>` child convention.
- Example substitutions (scenario-level, identical on both harnesses, not component deviations): Next `Link` -> `_a`. `breadcrumb-demo`, `breadcrumb-dropdown` and `breadcrumb-responsive` compose `DropdownMenu` (and `Drawer` below 768px in `responsive`); breadcrumb has no registry dependency on them, so the scenario coverage check rejects their exports in this file. Those examples are rendered with the `DropdownMenuTrigger` replaced by a closed `_button` carrying the example's className/aria-label and the menu content omitted; `breadcrumb-responsive` is rendered as its desktop (`isDesktop`) branch only, with the `items` map unrolled (slice(1,-2) is the menu; last two crumbs shown). The full dropdown compositions belong to a cross-component scenario once `dropdown-menu` is DONE (noted in the receipt).

## Deviations

None. No `deviations/breadcrumb.json` is written.
