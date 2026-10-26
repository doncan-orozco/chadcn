# Pagination (`Chadcn::Pagination`)

Oracle: `dev/port/oracle/src/pagination.tsx` (style `new-york-v4`, source_sha `224843c4f509e8b8`), manifest `dev/port/oracle/manifest/pagination.json`. Tier `static`: no Stimulus controller, no primitive, no Radix primitive (`radix_primitives: []`). Seven exports; no own cva (`cva: {}`): `PaginationLink` styles itself with `buttonVariants` from the `button` registry dependency. Registry examples: only `pagination-demo` (`https://ui.shadcn.com/r/styles/new-york-v4/pagination-demo.json`).

## API

```ruby
Chadcn::Pagination.new(class: nil, **attrs) { ... }                                   # Pagination::Content children
Chadcn::Pagination::Content.new(class: nil, **attrs) { ... }                          # Pagination::Item children
Chadcn::Pagination::Item.new(**attrs) { ... }                                         # class NOT run through cn
Chadcn::Pagination::Link.new(is_active: nil, size: "icon", class: nil, **attrs) { ... }
Chadcn::Pagination::Previous.new(is_active: nil, size: "default", class: nil, **attrs) # block ignored
Chadcn::Pagination::Next.new(is_active: nil, size: "default", class: nil, **attrs)     # block ignored
Chadcn::Pagination::Ellipsis.new(class: nil, **attrs)                                 # block ignored
```

| Part (React export) | kwargs (tsx destructuring) | `**attrs` type (tsx) |
|---|---|---|
| `Pagination` | `class:` (`className`) | `React.ComponentProps<"nav">` |
| `Pagination::Content` (`PaginationContent`) | `class:` | `React.ComponentProps<"ul">` |
| `Pagination::Item` (`PaginationItem`) | none (`{ ...props }` only) | `React.ComponentProps<"li">` |
| `Pagination::Link` (`PaginationLink`) | `is_active:` (`isActive?: boolean`, no default), `size:` default `"icon"` (`size = "icon"`), `class:` | `React.ComponentProps<"a">` (`href`, `target`, `rel`, ...) |
| `Pagination::Previous` (`PaginationPrevious`) | `class:`; everything else (`is_active:`, `size:`, `aria-label`, `href`) flows to `Pagination::Link` through `...props` | `React.ComponentProps<typeof PaginationLink>` |
| `Pagination::Next` (`PaginationNext`) | same as Previous | same |
| `Pagination::Ellipsis` (`PaginationEllipsis`) | `class:` | `React.ComponentProps<"span">` |

- Name rule: strip the root prefix (`PaginationLink` -> `Pagination::Link`). `Pagination::Link` lives in the `Pagination` namespace; the builder must call Phlex's `a` tag explicitly and never clash with any top-level `Link` constant.
- `size:` is the Button size axis (`Pick<React.ComponentProps<typeof Button>, "size">`): `default`, `xs`, `sm`, `lg`, `icon`, `icon-xs`, `icon-sm`, `icon-lg` (button spec). Strings and symbols accepted, `:icon_sm` == `"icon-sm"` (shadcn-port R4); normalization and the unknown-option `ArgumentError` are delegated to `Chadcn::Button.variants`. `nil` means the default of the part (`"icon"` for Link; `"default"` for Previous/Next).
- `is_active:` tri-state, mirroring React: `nil` (undefined) -> no `data-active`, no `aria-current`, variant `ghost`; `false` -> `data-active="false"`, no `aria-current`, variant `ghost`; `true` -> `data-active="true"`, `aria-current="page"`, variant `outline` (tsx `aria-current={isActive ? "page" : undefined}`, `data-active={isActive}`, `variant: isActive ? "outline" : "ghost"`). Scenarios `part-link__default`, `part-link__active-false`, `part-link__active`.
- There is no `variant:` kwarg; the variant is derived from `is_active` only. A caller `variant:` would be an unknown HTML attribute in React (`...props` on `<a>`); the port does not accept it as an option.
- `Previous` / `Next`: in the tsx `aria-label` and `size="default"` are written BEFORE `{...props}`, so a caller `size:` or `"aria-label":` overrides them (scenarios `api__previous-size-override`, `api__previous-size-lg`, `api__next-size-sm`, `api__previous-aria-label-override`). `className` is destructured and becomes `cn("gap-1 px-2.5 sm:pl-2.5", className)` (Next: `sm:pr-2.5`), which Link then merges after `buttonVariants(...)`. The JSX children (icon + text span) are written after the spread, so a caller block is ignored (`api__previous-ignores-children`, `api__next-ignores-children`).
- `Ellipsis`: explicit JSX children override `children` in `...props`; a caller block is ignored (`api__ellipsis-ignores-children`).
- Events: none dispatched (no `on*Change`). `onClick` etc. are plain DOM events via `data: { action: ... }`. Navigation is plain `href`.
- `ref`: no equivalent, not part of the API. No `as_child:` on any part (no Slot in the source).

## Structure

All server-rendered; nothing set by Stimulus; no ids generated. Attribute order follows the source: component attributes first, `{...props}` spread last, so a caller attribute with the same name overrides the component one (including `data-slot`, `role`, `aria-label`, `aria-current`, `data-active`, `aria-hidden`), except `class` on the parts that destructure `className` (merged through `cn`, caller last).

`pagination-demo` output (`href="#"` everywhere):

```html
<nav role="navigation" aria-label="pagination" data-slot="pagination" class="mx-auto flex w-full justify-center">
  <ul data-slot="pagination-content" class="flex flex-row items-center gap-1">
    <li data-slot="pagination-item">
      <a aria-label="Go to previous page" data-slot="pagination-link" class="{cn(buttonVariants({variant:'ghost',size:'default'}), 'gap-1 px-2.5 sm:pl-2.5')}" href="#">
        <svg class="lucide lucide-chevron-left" aria-hidden="true" .../><span class="hidden sm:block">Previous</span>
      </a>
    </li>
    <li data-slot="pagination-item"><a data-slot="pagination-link" class="{cn(buttonVariants({variant:'ghost',size:'icon'}))}" href="#">1</a></li>
    <li data-slot="pagination-item"><a aria-current="page" data-slot="pagination-link" data-active="true" class="{cn(buttonVariants({variant:'outline',size:'icon'}))}" href="#">2</a></li>
    <li data-slot="pagination-item"><a data-slot="pagination-link" class="..." href="#">3</a></li>
    <li data-slot="pagination-item">
      <span aria-hidden="true" data-slot="pagination-ellipsis" class="flex size-9 items-center justify-center">
        <svg class="lucide lucide-ellipsis size-4" aria-hidden="true" .../><span class="sr-only">More pages</span>
      </span>
    </li>
    <li data-slot="pagination-item">
      <a aria-label="Go to next page" data-slot="pagination-link" class="{cn(buttonVariants({variant:'ghost',size:'default'}), 'gap-1 px-2.5 sm:pr-2.5')}" href="#">
        <span class="hidden sm:block">Next</span><svg class="lucide lucide-chevron-right" aria-hidden="true" .../>
      </a>
    </li>
  </ul>
</nav>
```

| Part | Tag | data-slot | Fixed attributes (overridable by `**attrs`) | Classes (verbatim, tsx) |
|---|---|---|---|---|
| Pagination | `nav` | `pagination` | `role="navigation"`, `aria-label="pagination"` | `mx-auto flex w-full justify-center` |
| Pagination::Content | `ul` | `pagination-content` | - | `flex flex-row items-center gap-1` |
| Pagination::Item | `li` | `pagination-item` | - | none |
| Pagination::Link | `a` | `pagination-link` | `aria-current="page"` (only when `is_active` truthy), `data-active` (only when `is_active` is not nil, value `"true"`/`"false"`) | `Button.variants(variant: is_active ? "outline" : "ghost", size:, class:)` |
| Pagination::Previous | `a` (via Link) | `pagination-link` | `aria-label="Go to previous page"`, size `"default"` | Link classes + `gap-1 px-2.5 sm:pl-2.5` |
| Pagination::Next | `a` (via Link) | `pagination-link` | `aria-label="Go to next page"`, size `"default"` | Link classes + `gap-1 px-2.5 sm:pr-2.5` |
| Pagination::Ellipsis | `span` | `pagination-ellipsis` | `aria-hidden="true"` | `flex size-9 items-center justify-center` |

- Attribute order per tsx: nav `role`, `aria-label`, `data-slot`, `class`; Link `aria-current`, `data-slot`, `data-active`, `class`; Previous/Next put `aria-label` before Link's own attributes (they are props of Link); Ellipsis `aria-hidden`, `data-slot`, `class`. Attribute order is not observable in G2 beyond override semantics; the override semantics are.
- `Pagination::Item`: `className` is not destructured, it travels inside `...props` untouched. The port must emit the caller's `class` verbatim, NOT through `cn`/tailwind_merge (`class: "p-2 p-4 border"` stays `p-2 p-4 border`; scenario `api__item-class-not-merged`), and with no class the `li` has no `class` attribute. A caller `data-slot` replaces `pagination-item` (`api__item-forwarded-attrs`).
- `Pagination::Link` classes: `buttonVariants({ variant, size })` then `className` through `cn`, i.e. exactly `Chadcn::Button.variants(variant:, size:, class:)` (button spec "Structure"; base + `ghost`/`outline` + size tables copied there verbatim). The anchor does NOT get `data-variant` / `data-size` (those are written by the `Button` component, not by `buttonVariants`), and never `role`, `tabindex`, `type` or `href` unless the caller passes them (`part-link__no-href` renders `<a>` with no href, not focusable).
- Previous/Next merged class: `cn(buttonVariants({variant, size:"default"}), cn("gap-1 px-2.5 sm:pl-2.5", caller))`; tailwind-merge drops base `gap-2` and size `px-4`, keeps `has-[>svg]:px-3` and `py-2`. Caller `px-4 gap-2 sm:pl-4` then drops `px-2.5 gap-1 sm:pl-2.5` (`api__previous-class-merge-conflict`).
- Previous children, in order: `ChevronLeftIcon` (no className) then `<span class="hidden sm:block">Previous</span>`. Next: `<span class="hidden sm:block">Next</span>` then `ChevronRightIcon`. Below 640px the text spans are `display:none` (`responsive__below-sm`).
- Ellipsis children: `MoreHorizontalIcon className="size-4"` then `<span class="sr-only">More pages</span>`. `aria-hidden` is a bare JSX boolean -> `aria-hidden="true"`; a caller `"aria-hidden": "false"` overrides (`api__ellipsis-forwarded-attrs`).
- Icons (lucide-react 0.577.0, `dev/react-shadcn-catalog/node_modules/lucide-react/dist/esm/lucide-react.js` lines 85, 542-543; same set as `Chadcn::Icon`): `ChevronLeftIcon` -> `chevron-left`, `class="lucide lucide-chevron-left"`; `ChevronRightIcon` -> `chevron-right`, `class="lucide lucide-chevron-right"`; `MoreHorizontalIcon` is an alias of `Ellipsis` -> name `ellipsis`, `class="lucide lucide-ellipsis size-4"`. All `width/height=24`, `aria-hidden="true"` (`Icon.js` line 33), sized by `[&_svg:not([class*='size-'])]:size-4` of the button base where no size class is present.
- Text literals: `Previous`, `Next` (visible from `sm`), sr-only `More pages`, aria-labels `Go to previous page`, `Go to next page`, nav `aria-label="pagination"`. The DOM in the `en` locale must contain exactly these strings (G2 runs in `en`). If the builder localizes them (house rule: en + es), the keys and `es` entries are added by the orchestrator (locales are shared files, shadcn-port R13); defaults stay the English oracle strings.
- State styling is pure CSS from the button tables: `hover:` (ghost `hover:bg-accent hover:text-accent-foreground dark:hover:bg-accent/50`; outline `hover:bg-accent ...`), `focus-visible:` ring, `aria-invalid:`, `dark:`, `has-[>svg]:`, `sm:` (Previous/Next). `disabled:` tokens never match an `<a>`; `aria-disabled` has no styling (forwarded only, `state-link__aria-disabled`). No `data-[state=*]` tokens; `data-active` is not styled by the source.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Pagination` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Pagination::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Pagination::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `pagination.content` | `Pagination::Content` | `PaginationContent` |
| `pagination.link` | `Pagination::Link` | `PaginationLink` |
| `pagination.item` | `Pagination::Item` | `PaginationItem` |
| `pagination.previous` | `Pagination::Previous` | `PaginationPrevious` |
| `pagination.next` | `Pagination::Next` | `PaginationNext` |
| `pagination.ellipsis` | `Pagination::Ellipsis` | `PaginationEllipsis` |

Names that shadow a Phlex HTML element inside `Pagination`'s OWN `view_template` (use `tag(:link)` there, never the bare method): `link`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Chadcn::Button` (registry dependency `button`): only `Chadcn::Button.variants(variant:, size:, class:)` (the `buttonVariants` mapping), never the Button component itself.
- `Chadcn::Icon`: `chevron-left` (Previous), `chevron-right` (Next), `ellipsis` with `class: "size-4"` (Ellipsis).
- `Chadcn::Base` for `cn` and attribute merge.
- Scenarios use icons `chevrons-left`, `chevrons-right` via the `<icon:...>` child convention.

## Deviations

None. No `deviations/pagination.json` is written.
