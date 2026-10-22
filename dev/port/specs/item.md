# Item (`Components::V2::Item`)

Oracle: `dev/port/oracle/src/item.tsx` (style `new-york-v4`, manifest `source_sha` `9ade8136f010284b`), manifest `dev/port/oracle/manifest/item.json`. Tier `static`: no `"use client"`, no hooks, no icons, no Stimulus controller. The only Radix import is `Slot` (used by `Item` for `asChild`, `@radix-ui/react-slot` 1.4.0, `mergeProps` at `dev/react-shadcn-catalog/node_modules/@radix-ui/react-slot/dist/index.mjs:81-103`). Exports `Item`, `ItemMedia`, `ItemContent`, `ItemActions`, `ItemGroup`, `ItemSeparator`, `ItemTitle`, `ItemDescription`, `ItemHeader`, `ItemFooter`. Ten parts, data-slots `item`, `item-media`, `item-content`, `item-actions`, `item-group`, `item-separator`, `item-title`, `item-description`, `item-header`, `item-footer`. Two cva tables, `itemVariants` and `itemMediaVariants`. Registry dependency: `separator` (`ItemSeparator` renders `Components::V2::Separator`). Registry examples fetched from `https://ui.shadcn.com/r/styles/new-york-v4/<name>.json`: `item-demo`, `item-size`, `item-variant`, `item-icon`, `item-avatar`, `item-image`, `item-group`, `item-header`, `item-link`, `item-dropdown`.

## API

```ruby
Components::V2::Item.new(variant: "default", size: "default", as_child: false, class: nil, **attrs) { ... }
Components::V2::Item::Media.new(variant: "default", class: nil, **attrs) { ... }
Components::V2::Item::Content.new(class: nil, **attrs) { ... }
Components::V2::Item::Actions.new(class: nil, **attrs) { ... }
Components::V2::Item::Group.new(class: nil, **attrs) { ... }
Components::V2::Item::Separator.new(class: nil, **attrs)          # forwards to Components::V2::Separator
Components::V2::Item::Title.new(class: nil, **attrs) { ... }
Components::V2::Item::Description.new(class: nil, **attrs) { ... }
Components::V2::Item::Header.new(class: nil, **attrs) { ... }
Components::V2::Item::Footer.new(class: nil, **attrs) { ... }

Components::V2::Item.variants(variant: "default", size: "default", class: nil)  # => class string (itemVariants)
Components::V2::Item::Media.variants(variant: "default", class: nil)            # => class string (itemMediaVariants)
```

| part (tsx function) | Ruby class | kwargs (default, source) |
|---|---|---|
| `Item` | `Components::V2::Item` | `variant:` (`"default"`, tsx `variant = "default"`, cva default), `size:` (`"default"`, tsx `size = "default"`), `as_child:` (`false`, tsx `asChild = false`), `class:`, `**attrs` |
| `ItemMedia` | `Components::V2::Item::Media` | `variant:` (`"default"`, tsx `variant = "default"`), `class:`, `**attrs` |
| `ItemContent` | `Components::V2::Item::Content` | `class:`, `**attrs` |
| `ItemActions` | `Components::V2::Item::Actions` | `class:`, `**attrs` |
| `ItemGroup` | `Components::V2::Item::Group` | `class:`, `**attrs` |
| `ItemSeparator` | `Components::V2::Item::Separator` | `class:`, `**attrs` (everything `Components::V2::Separator` accepts: `orientation:`, `decorative:`, `as_child:`...) |
| `ItemTitle` | `Components::V2::Item::Title` | `class:`, `**attrs` |
| `ItemDescription` | `Components::V2::Item::Description` | `class:`, `**attrs` |
| `ItemHeader` | `Components::V2::Item::Header` | `class:`, `**attrs` |
| `ItemFooter` | `Components::V2::Item::Footer` | `class:`, `**attrs` |

- Options accept strings and symbols (shadcn-port R4): Item `variant:` `"default" | "outline" | "muted"`, `size:` `"default" | "sm"`; Media `variant:` `"default" | "icon" | "image"`. The string form is what lands in `data-variant` / `data-size`. `nil` behaves like the default (the tsx default parameter yields `"default"` for `undefined`, cva falls back to `defaultVariants`).
- `class:` goes through `cn` (tailwind_merge) after the part classes; caller wins (R6). For `Item` and `ItemMedia` the tsx passes `className` into the cva call and then `cn` (`cn(itemVariants({ variant, size, className }))`), so the Ruby equivalent is one `cn(BASE, VARIANT, SIZE, class)` merge (scenarios `class__merge-conflict`, `class__size-sm-merge-conflict`, `media__class-merge`).
- `as_child:` (Item only): `false` (renders `div`) | tag symbol (`as_child: :a`, renders that tag) | V2 component instance. Radix `Slot.Root` semantics via `Components::V2::Base#render_as_child` (api-mapping.md): the Item's computed attributes (`data-slot`, `data-variant`, `data-size`, merged class, `**attrs`) are the slot props, the child's own props win, and `class` is a PLAIN join `item classes + " " + child class` with no tailwind-merge (slot.mjs:99-100). Scenario `as-child__class-plain-join` pins this (`rounded-xl` merged into the item class by `cn`, then child `p-2` appended after `p-4`, both kept). No other part supports `as_child:` (no Slot in their source); no `as:`.
- `**attrs`: any attribute of the rendered tag (`id`, `role`, `title`, `tabindex`, `aria: {}` / `"aria-*":`, `data: {}`, `style`, `href` when `as_child: :a`...), deep-merged. `ItemDescription` is typed `React.ComponentProps<"p">` and renders a `p`.
- Block = `children`. `ItemSeparator` takes no block (shadcn never passes children).
- No events are dispatched (no `on*` props), no `ref` equivalent. `Item.variants` / `Item::Media.variants` mirror the module-level `itemVariants` / `itemMediaVariants` (not exported by the tsx; provided per the `Component.variants` rule in api-mapping.md).

## Structure

Every part is server-rendered; Stimulus sets nothing; no ids are generated, no sr-only text, no `data-state`. In each tsx part the fixed attributes come first and `{...props}` is spread last, so a caller `data-slot`, `data-variant`, `data-size` or `role` in `**attrs` overrides the component value while the cva classes still follow `variant:`/`size:` (scenarios `attrs__data-slot-override`, `attrs__data-variant-size-override`, `media__data-variant-override`, `group__role-override`, `separator__data-slot-override`).

```html
<div role="list" data-slot="item-group" class="group/item-group flex flex-col">
  <div data-slot="item" data-variant="default" data-size="default" class="group/item flex flex-wrap items-center rounded-md border border-transparent text-sm transition-colors duration-100 outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 [a]:transition-colors [a]:hover:bg-accent/50 bg-transparent gap-4 p-4">
    <div data-slot="item-header" class="flex basis-full items-center justify-between gap-2">...</div>
    <div data-slot="item-media" data-variant="icon" class="flex shrink-0 items-center justify-center gap-2 group-has-[[data-slot=item-description]]/item:translate-y-0.5 group-has-[[data-slot=item-description]]/item:self-start [&_svg]:pointer-events-none size-8 rounded-sm border bg-muted [&_svg:not([class*='size-'])]:size-4">...</div>
    <div data-slot="item-content" class="flex flex-1 flex-col gap-1 [&+[data-slot=item-content]]:flex-none">
      <div data-slot="item-title" class="flex w-fit items-center gap-2 text-sm leading-snug font-medium">...</div>
      <p data-slot="item-description" class="line-clamp-2 text-sm leading-normal font-normal text-balance text-muted-foreground [&>a]:underline [&>a]:underline-offset-4 [&>a:hover]:text-primary">...</p>
    </div>
    <div data-slot="item-actions" class="flex items-center gap-2">...</div>
    <div data-slot="item-footer" class="flex basis-full items-center justify-between gap-2">...</div>
  </div>
  <div data-orientation="horizontal" role="none" data-slot="item-separator" class="shrink-0 bg-border data-[orientation=horizontal]:h-px data-[orientation=horizontal]:w-full data-[orientation=vertical]:h-full data-[orientation=vertical]:w-px my-0"></div>
</div>
```

| part | tag | fixed attrs (tsx order) | classes (verbatim from item.tsx) |
|---|---|---|---|
| `ItemGroup` | `div` | `role="list"`, `data-slot="item-group"` | `group/item-group flex flex-col` |
| `ItemSeparator` | `Components::V2::Separator` (`div`) | `data-slot="item-separator"`, `orientation="horizontal"` | `my-0` (passed as Separator `className`) |
| `Item` | `div` or `as_child` element | `data-slot="item"`, `data-variant`, `data-size` | `itemVariants` |
| `ItemMedia` | `div` | `data-slot="item-media"`, `data-variant` | `itemMediaVariants` |
| `ItemContent` | `div` | `data-slot="item-content"` | `flex flex-1 flex-col gap-1 [&+[data-slot=item-content]]:flex-none` |
| `ItemTitle` | `div` | `data-slot="item-title"` | `flex w-fit items-center gap-2 text-sm leading-snug font-medium` |
| `ItemDescription` | `p` | `data-slot="item-description"` | `line-clamp-2 text-sm leading-normal font-normal text-balance text-muted-foreground` + `[&>a]:underline [&>a]:underline-offset-4 [&>a:hover]:text-primary` (two `cn` arguments, then `className`) |
| `ItemActions` | `div` | `data-slot="item-actions"` | `flex items-center gap-2` |
| `ItemHeader` | `div` | `data-slot="item-header"` | `flex basis-full items-center justify-between gap-2` |
| `ItemFooter` | `div` | `data-slot="item-footer"` | `flex basis-full items-center justify-between gap-2` |

Note: `role="list"` on `ItemGroup` is in the tsx but missing from the manifest `data_attrs` (the extractor only records `data-*`); it must be rendered.

`itemVariants` (manifest `cva.itemVariants`):
- base: `group/item flex flex-wrap items-center rounded-md border border-transparent text-sm transition-colors duration-100 outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 [a]:transition-colors [a]:hover:bg-accent/50`
- `variant.default`: `bg-transparent`; `variant.outline`: `border-border` (tailwind-merge drops the base `border-transparent`); `variant.muted`: `bg-muted/50`
- `size.default`: `gap-4 p-4`; `size.sm`: `gap-2.5 px-4 py-3`
- defaultVariants `{ variant: "default", size: "default" }`; compoundVariants none.

`itemMediaVariants` (manifest `cva.itemMediaVariants`):
- base: `flex shrink-0 items-center justify-center gap-2 group-has-[[data-slot=item-description]]/item:translate-y-0.5 group-has-[[data-slot=item-description]]/item:self-start [&_svg]:pointer-events-none`
- `variant.default`: `bg-transparent`; `variant.icon`: `size-8 rounded-sm border bg-muted [&_svg:not([class*='size-'])]:size-4`; `variant.image`: `size-10 overflow-hidden rounded-sm [&_img]:size-full [&_img]:object-cover`
- defaultVariants `{ variant: "default" }`; compoundVariants none.

The port must produce the exact class strings by merging through `cn` (React `cn` = clsx + tailwind-merge), never by hand-deduplicating.

`ItemSeparator` composition (tsx `ItemSeparator` + `separator.tsx`, see `specs/separator.md`): it renders `Components::V2::Separator.new(data: { slot: "item-separator" }, orientation: "horizontal", class: cn("my-0", class), **attrs)`. Consequences pinned by scenarios:
- `data-slot` is `item-separator` (Separator puts its own `data-slot="separator"` before `{...props}`, so ItemSeparator's wins); a caller `data-slot` in turn wins over `item-separator` (`separator__data-slot-override`).
- `decorative` defaults to `true` (shadcn Separator) -> `role="none"`, `data-orientation="horizontal"`; `decorative: false` -> `role="separator"` (`separator__decorative-false`).
- The caller's `orientation:` is spread after `orientation="horizontal"` and wins (`separator__orientation-override-vertical`).
- Final class = `cn(SEPARATOR_BASE, cn("my-0", class))`; caller `my-2` replaces `my-0` (`separator__class-merge`).

Composition semantics the port must not alter (pinned by scenarios):
- `Item` is a wrapping flex row (`flex-wrap`); `ItemHeader`/`ItemFooter` use `basis-full` to take full rows (`content__header-and-footer`, `content__footer-only`, `example__item-header`, `layout__narrow-viewport-wraps`).
- `group-has-[[data-slot=item-description]]/item:*` on Media only applies when the enclosing Item contains an `ItemDescription` (`media__variant-*` vs `media__variant-*__no-description`).
- `[&_svg:not([class*='size-'])]:size-4` (icon variant) leaves an svg that already has a `size-*` class alone (`media__variant-icon__svg-with-size-class`, raw `_svg`). `[&_img]:*` (image variant) sizes a descendant img (`media__variant-image`, `example__item-image`).
- `[&+[data-slot=item-content]]:flex-none` makes the second of two adjacent `ItemContent` not grow (`content__two-contents-second-flex-none`, `example__item-image`).
- `line-clamp-2` + `text-balance` on Description (`content__description-long-clamps`); `[&>a]:*` / `[&>a:hover]:text-primary` style only direct child links (`content__description-with-link`, `state__description-link-hover`, `content__description-nested-link-not-direct-child`).
- States: `focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50` on Item, visible only when the Item element itself is focusable (`as_child: :a`, `as_child: :button`, or `tabindex: 0`): `state__as-child-a__focus-visible`, `state__div-tabindex__focus-visible`, `as-child__button`; mouse click does not show it (`state__as-child-a__click-focus-not-visible`). `[a]:transition-colors [a]:hover:bg-accent/50` apply only when the Item IS an `<a>` (`state__as-child-a__hover`, per-variant hover scenarios); a `div` Item has no hover style (`state__div__hover-no-effect`). No `disabled:`, `aria-invalid:`, `data-[state]` or `dark:` tokens; dark mode differs only through theme tokens (`--border`, `--muted`, `--accent`, `--ring`, `--muted-foreground`, `--primary`), covered by `__dark` twins for every `variant` option of both cva tables and every Item `variant x size` cell.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Item` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Item::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Item::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `item.media` | `Item::Media` | `ItemMedia` |
| `item.content` | `Item::Content` | `ItemContent` |
| `item.actions` | `Item::Actions` | `ItemActions` |
| `item.group` | `Item::Group` | `ItemGroup` |
| `item.separator` | `Item::Separator` | `ItemSeparator` |
| `item.title` | `Item::Title` | `ItemTitle` |
| `item.description` | `Item::Description` | `ItemDescription` |
| `item.header` | `Item::Header` | `ItemHeader` |
| `item.footer` | `Item::Footer` | `ItemFooter` |

Names that shadow a Phlex HTML element inside `Item`'s OWN `view_template` (use `tag(:title)` there, never the bare method): `title`, `header`, `footer`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

- `Components::V2::Separator` (`ItemSeparator`; spec `dev/port/specs/separator.md`).
- No icons rendered by the component itself (manifest `icons: []`); icons in scenarios are caller content (`<icon:...>` markers).

Example substitutions (scenario-level, identical on both harnesses, not component deviations), because the scenario coverage check only admits Item's exports and its registry dependency `Separator`:
- `Button` (`item-demo`, `item-size`, `item-variant`, `item-icon`, `item-avatar`, `item-group`, `item-dropdown`) is a raw `_button type="button"` (its `className`/`aria-label` kept, `variant`/`size` dropped).
- `Avatar`/`AvatarImage`/`AvatarFallback` (`item-avatar`, `item-group`, `item-dropdown`) become a `_span data-slot="avatar"` showing the fallback text, keeping the example's `className` (`size-10`, `hidden sm:flex`, `size-8`); the `*:data-[slot=avatar]:*` wrapper of `item-avatar` is kept verbatim. No remote images.
- `next/image` (`item-image`, `item-header`) becomes `_img` with the same `alt`, `width`, `height`, `className` and a local `data:image/svg+xml` source (deterministic snapshots).
- `DropdownMenu`/`DropdownMenuTrigger`/`DropdownMenuContent`/`DropdownMenuItem` (`item-dropdown`) become the open-state markup in static form: the trigger is `_button className="w-fit"`, the content a `_div role="menu" className="w-72 [--radius:0.65rem]"`, each item a `_div role="menuitem" className="p-0"` around the verbatim `Item size="sm" className="w-full p-2"`. The real dropdown composition belongs to cross-component scenarios once DropdownMenu is DONE.
- lucide icons with an example `className` (`BadgeCheckIcon className="size-5"`, `ChevronRightIcon className="size-4"`, `ExternalLinkIcon className="size-4"`) are emitted as `<icon:badge-check>`, `<icon:chevron-right>`, `<icon:external-link>` without that class (the marker carries no props); `ShieldAlertIcon`, `Plus`/`PlusIcon` kept as `<icon:shield-alert>`, `<icon:plus>`.

## Deviations

None. No `deviations/item.json` is written.
