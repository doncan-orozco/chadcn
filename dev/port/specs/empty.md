# Empty (`Components::V2::Empty`)

Oracle: `gems/chadcn/dev/port/oracle/src/empty.tsx` (style `new-york-v4`, manifest `source_sha` `54f529ccf72c18c4`), manifest `gems/chadcn/dev/port/oracle/manifest/empty.json`. Tier `static`: no `"use client"`, no Radix primitive, no hooks, no icons, no Stimulus controller. Exports `Empty`, `EmptyHeader`, `EmptyTitle`, `EmptyDescription`, `EmptyContent`, `EmptyMedia`. Six parts, data-slots `empty`, `empty-header`, `empty-icon` (on `EmptyMedia`), `empty-title`, `empty-description`, `empty-content`. One cva table, `emptyMediaVariants`. Registry examples (`https://ui.shadcn.com/r/styles/new-york-v4/<name>.json`): `empty-demo`, `empty-icon`, `empty-avatar`, `empty-avatar-group`, `empty-input-group`, `empty-outline`, `empty-background`.

## API

```ruby
Components::V2::Empty.new(class: nil, **attrs) { ... }
Components::V2::Empty::Header.new(class: nil, **attrs) { ... }
Components::V2::Empty::Media.new(variant: "default", class: nil, **attrs) { ... }
Components::V2::Empty::Title.new(class: nil, **attrs) { ... }
Components::V2::Empty::Description.new(class: nil, **attrs) { ... }
Components::V2::Empty::Content.new(class: nil, **attrs) { ... }

Components::V2::Empty::Media.variants(variant: "default", class: nil) # => class string (emptyMediaVariants)
```

| part (tsx function) | Ruby class | kwargs (default) |
|---|---|---|
| `Empty` | `Components::V2::Empty` | `class:` (nil), `**attrs` |
| `EmptyHeader` | `Components::V2::Empty::Header` | `class:` (nil), `**attrs` |
| `EmptyMedia` | `Components::V2::Empty::Media` | `variant:` (`"default"`, tsx `variant = "default"` and cva `defaultVariants.variant: "default"`), `class:` (nil), `**attrs` |
| `EmptyTitle` | `Components::V2::Empty::Title` | `class:` (nil), `**attrs` |
| `EmptyDescription` | `Components::V2::Empty::Description` | `class:` (nil), `**attrs` |
| `EmptyContent` | `Components::V2::Empty::Content` | `class:` (nil), `**attrs` |

- `variant:` accepts `"default"`, `:default`, `"icon"`, `:icon` (shadcn-port R4); the string form is what lands in `data-variant`. `variant: nil` behaves like the default (cva falls back to `defaultVariants`; the tsx default parameter also yields `"default"` for `undefined`).
- `class:` is merged through `cn` (tailwind_merge) after the part's classes; caller wins conflicts (R6). For `EmptyMedia` the tsx passes `className` into the cva call and then `cn` (`cn(emptyMediaVariants({ variant, className }))`), so the Ruby equivalent is `cn(BASE, VARIANTS[variant], class)` as one merge.
- `**attrs`: any `div` attribute (`id`, `role`, `title`, `aria: {}` / `"aria-*":`, `data: {}`, `style`, `hidden`), deep-merged. `EmptyDescription` is typed `React.ComponentProps<"p">` but renders a `div`; the Ruby part accepts the same attrs and renders `div`.
- Block = `children`. No `as_child:` (no `Slot` in the source), no `as:`, no events dispatched (no `on*` props), no `ref` equivalent. `Media.variants` is the only class method; it mirrors the module-level `emptyMediaVariants` (not exported by the tsx, provided for parity with the `Component.variants` rule in api-mapping.md).

## Structure

Every part is one server-rendered `div`; nothing is set client-side. No ids generated, no ARIA added, no `role`, no `data-state`, no sr-only text. Attribute order in each tsx part: `data-slot`, (`data-variant` for Media), `className`, then `{...props}`; the spread is last, so a caller `data-slot` or `data-variant` in `**attrs` overrides the component value (scenarios `attrs__data-slot-override`, `attrs__data-variant-override`; in the latter the cva classes still follow `variant:`).

```html
<div data-slot="empty" class="flex min-w-0 flex-1 flex-col items-center justify-center gap-6 rounded-lg border-dashed p-6 text-center text-balance md:p-12">
  <div data-slot="empty-header" class="flex max-w-sm flex-col items-center gap-2 text-center">
    <div data-slot="empty-icon" data-variant="icon" class="mb-2 [&_svg]:pointer-events-none [&_svg]:shrink-0 flex size-10 shrink-0 items-center justify-center rounded-lg bg-muted text-foreground [&_svg:not([class*='size-'])]:size-6">...</div>
    <div data-slot="empty-title" class="text-lg font-medium tracking-tight">...</div>
    <div data-slot="empty-description" class="text-sm/relaxed text-muted-foreground [&>a]:underline [&>a]:underline-offset-4 [&>a:hover]:text-primary">...</div>
  </div>
  <div data-slot="empty-content" class="flex w-full max-w-sm min-w-0 flex-col items-center gap-4 text-sm text-balance">...</div>
</div>
```

Classes, verbatim from the tsx:

| part | data-slot | tag | classes |
|---|---|---|---|
| `Empty` | `empty` | `div` | `flex min-w-0 flex-1 flex-col items-center justify-center gap-6 rounded-lg border-dashed p-6 text-center text-balance md:p-12` |
| `EmptyHeader` | `empty-header` | `div` | `flex max-w-sm flex-col items-center gap-2 text-center` |
| `EmptyMedia` | `empty-icon` + `data-variant` | `div` | `emptyMediaVariants` (below) |
| `EmptyTitle` | `empty-title` | `div` | `text-lg font-medium tracking-tight` |
| `EmptyDescription` | `empty-description` | `div` | `text-sm/relaxed text-muted-foreground [&>a]:underline [&>a]:underline-offset-4 [&>a:hover]:text-primary` |
| `EmptyContent` | `empty-content` | `div` | `flex w-full max-w-sm min-w-0 flex-col items-center gap-4 text-sm text-balance` |

`emptyMediaVariants` (manifest `cva.emptyMediaVariants`):

- base: `mb-2 flex shrink-0 items-center justify-center [&_svg]:pointer-events-none [&_svg]:shrink-0`
- `variant.default`: `bg-transparent`
- `variant.icon`: `flex size-10 shrink-0 items-center justify-center rounded-lg bg-muted text-foreground [&_svg:not([class*='size-'])]:size-6`
- defaultVariants: `{ variant: "default" }`; compoundVariants: none.

The `icon` variant repeats `flex shrink-0 items-center justify-center` from the base; tailwind-merge (in React `cn`) keeps the last occurrence of each, so the rendered class for `variant="icon"` is `mb-2 [&_svg]:pointer-events-none [&_svg]:shrink-0 flex size-10 shrink-0 items-center justify-center rounded-lg bg-muted text-foreground [&_svg:not([class*='size-'])]:size-6`, and for `default` it is the base plus `bg-transparent`. The port must produce the same string by merging through `cn`, not by hand-deduplicating.

- Note the data-slot of `EmptyMedia` is `empty-icon` (not `empty-media`) in the source; keep it.
- DOM order is the caller's order; parts never reorder, wrap or inject children. Parts may be used outside `EmptyHeader` (scenario `content__parts-outside-header`).
- Composition semantics the port must not alter (pinned by scenarios):
  - `border-dashed` sets only the border style; a border appears only when the caller adds `border` (`class__border-dashed-needs-border`, `example__empty-outline`).
  - `flex-1` grows the root only inside a flex parent (`layout__flex-1-in-flex-parent`); `md:p-12` vs `p-6` depends on the viewport (`layout__viewport-below-md`, `layout__viewport-resize-across-md`).
  - `[&_svg]:*` targets any descendant svg of Media; `[&_svg:not([class*='size-'])]:size-6` (icon variant only) leaves an svg that already has a `size-*` class alone (`media__variant-icon__svg-with-size-class`, uses a raw `_svg` node).
  - `[&>a]:*` / `[&>a:hover]:text-primary` style only direct child links of Description (`content__description-with-link`, `state__description-link-hover`, `content__description-nested-link-not-direct-child`).
- States: no `hover:`/`focus-visible:`/`disabled:`/`aria-invalid:`/`data-[state]`/`dark:` tokens on the parts themselves; the only interactive state is the `:hover` of a direct child `<a>` of Description. Dark mode differs only through theme tokens (`--muted`, `--foreground`, `--muted-foreground`, `--primary`, `--border`), covered by `__dark` twins (both `variant` options have one).

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Empty` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Empty::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Empty::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `empty.header` | `Empty::Header` | `EmptyHeader` |
| `empty.title` | `Empty::Title` | `EmptyTitle` |
| `empty.description` | `Empty::Description` | `EmptyDescription` |
| `empty.content` | `Empty::Content` | `EmptyContent` |
| `empty.media` | `Empty::Media` | `EmptyMedia` |

Names that shadow a Phlex HTML element inside `Empty`'s OWN `view_template` (use `tag(:header)` there, never the bare method): `header`, `title`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

None (`registry_dependencies: []`, `icons: []`). The component renders no other `Components::V2` component; icons inside Media are caller content.

Example substitutions (scenario-level, identical on both harnesses, not component deviations), because the scenario coverage check only admits Empty's own exports when `registry_dependencies` is empty:
- `Button` (`empty-demo`, `empty-avatar`, `empty-avatar-group`, `empty-outline`, `empty-background`) is rendered as a raw `_button type="button"`; the `Button variant="link" asChild` around `<a>` in `empty-demo` becomes the bare `_a href="#" className="text-muted-foreground"`.
- `Avatar`/`AvatarImage`/`AvatarFallback` (`empty-avatar`, `empty-avatar-group`) become a `_span data-slot="avatar"` showing the fallback text (no remote images, so snapshots are deterministic); the `*:data-[slot=avatar]:*` wrapper classes of `empty-avatar-group` are kept verbatim.
- `InputGroup`/`InputGroupInput`/`InputGroupAddon`/`Kbd` (`empty-input-group`) become a `_div` (keeping `sm:w-3/4`) with `<icon:search>`, `_input placeholder` and `_kbd`.
- Tabler icons (`IconFolderCode`, `IconInbox`, `IconStar`, `IconHeart`, `IconBookmark`, `IconCloud`, `IconBell`) are replaced by the lucide icons of the same name (`folder-code`, `inbox`, `star`, `heart`, `bookmark`, `cloud`, `bell`); lucide `ArrowUpRightIcon`, `PlusIcon`, `RefreshCcwIcon`, `SearchIcon` are kept.
Full compositions with the real `Button`, `Avatar`, `InputGroup`, `Kbd` belong to cross-component scenarios once those are DONE.

## Deviations

None.
