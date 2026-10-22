# Card (`Components::V2::Card`)

Oracle: `dev/port/oracle/src/card.tsx` (style `new-york-v4`, manifest `source_sha` `ef8305b12c3112da`), manifest `dev/port/oracle/manifest/card.json`. Tier `static`: no `"use client"`, no Radix primitive, no Stimulus controller, no hooks, no icons, no cva. Exports `Card`, `CardHeader`, `CardFooter`, `CardTitle`, `CardAction`, `CardDescription`, `CardContent`. Seven parts, data-slots `card`, `card-header`, `card-title`, `card-description`, `card-action`, `card-content`, `card-footer`. Registry examples: `card-demo`, `card-with-form` (`https://ui.shadcn.com/r/styles/new-york-v4/<name>.json`).

## API

```ruby
Components::V2::Card.new(class: nil, **attrs) { ... }
Components::V2::Card::Header.new(class: nil, **attrs) { ... }
Components::V2::Card::Title.new(class: nil, **attrs) { ... }
Components::V2::Card::Description.new(class: nil, **attrs) { ... }
Components::V2::Card::Action.new(class: nil, **attrs) { ... }
Components::V2::Card::Content.new(class: nil, **attrs) { ... }
Components::V2::Card::Footer.new(class: nil, **attrs) { ... }
```

| part (tsx function) | Ruby class | kwargs |
|---|---|---|
| `Card` | `Components::V2::Card` | `class:`, `**attrs` |
| `CardHeader` | `Components::V2::Card::Header` | `class:`, `**attrs` |
| `CardTitle` | `Components::V2::Card::Title` | `class:`, `**attrs` |
| `CardDescription` | `Components::V2::Card::Description` | `class:`, `**attrs` |
| `CardAction` | `Components::V2::Card::Action` | `class:`, `**attrs` |
| `CardContent` | `Components::V2::Card::Content` | `class:`, `**attrs` |
| `CardFooter` | `Components::V2::Card::Footer` | `class:`, `**attrs` |

- Every part destructures only `{ className, ...props }` typed `React.ComponentProps<"div">` (manifest `props.destructured`). So the only kwarg is `class:` (default `nil`), merged through `cn` (tailwind_merge) after the part's classes, caller wins conflicts (shadcn-port R6).
- `**attrs`: any `div` attribute (`id`, `role`, `title`, `tabindex`, `style`, `dir`, `hidden`, `data: {}`, `aria: {}` / `"aria-*":`), deep-merged. No option strings/symbols exist (no variants), so R4 has nothing to map.
- Block = `children`. No `as_child:` (the source never uses `Slot`), no `as:`, no events dispatched (no `on*` props), no class method (no exported cva), no `ref` equivalent.

## Structure

Every part is one server-rendered `div`; nothing is set client-side. No ids generated, no ARIA added, no `role`, no `data-state`, no sr-only text. Attribute order in each tsx part: `data-slot`, `className`, then `{...props}`; since the spread is last, a caller `data-slot` (or any other key) in `**attrs` overrides the component value (React spread semantics; scenario `attrs__data-slot-override`).

```html
<div data-slot="card" class="flex flex-col gap-6 rounded-xl border bg-card py-6 text-card-foreground shadow-sm">
  <div data-slot="card-header" class="@container/card-header grid auto-rows-min grid-rows-[auto_auto] items-start gap-2 px-6 has-data-[slot=card-action]:grid-cols-[1fr_auto] [.border-b]:pb-6">
    <div data-slot="card-title" class="leading-none font-semibold">...</div>
    <div data-slot="card-description" class="text-sm text-muted-foreground">...</div>
    <div data-slot="card-action" class="col-start-2 row-span-2 row-start-1 self-start justify-self-end">...</div>
  </div>
  <div data-slot="card-content" class="px-6">...</div>
  <div data-slot="card-footer" class="flex items-center px-6 [.border-t]:pt-6">...</div>
</div>
```

Classes, verbatim from the tsx base strings (each part is `cn("<base>", className)`):

| part | data-slot | tag | classes |
|---|---|---|---|
| `Card` | `card` | `div` | `flex flex-col gap-6 rounded-xl border bg-card py-6 text-card-foreground shadow-sm` |
| `CardHeader` | `card-header` | `div` | `@container/card-header grid auto-rows-min grid-rows-[auto_auto] items-start gap-2 px-6 has-data-[slot=card-action]:grid-cols-[1fr_auto] [.border-b]:pb-6` |
| `CardTitle` | `card-title` | `div` | `leading-none font-semibold` |
| `CardDescription` | `card-description` | `div` | `text-sm text-muted-foreground` |
| `CardAction` | `card-action` | `div` | `col-start-2 row-span-2 row-start-1 self-start justify-self-end` |
| `CardContent` | `card-content` | `div` | `px-6` |
| `CardFooter` | `card-footer` | `div` | `flex items-center px-6 [.border-t]:pt-6` |

- Tags: `CardTitle` and `CardDescription` are `div` (not `h3`/`p`), as in the source.
- DOM order is the caller's order; parts never reorder, wrap, or inject children. `CardAction` is placed visually by grid (`col-start-2 row-start-1 row-span-2`) regardless of DOM position (scenario `header__action-first-in-dom`).
- Composition semantics the port must not alter (pinned by scenarios):
  - `has-data-[slot=card-action]:grid-cols-[1fr_auto]`: the header becomes two columns only when a descendant carries `data-slot="card-action"`, so `Card::Action` must emit exactly that data-slot.
  - `[.border-b]:pb-6` / `[.border-t]:pt-6`: padding appears only when the caller adds `class: "border-b"` to the Header / `class: "border-t"` to the Footer. tailwind_merge must keep these tokens next to `border-b` / `border-t` (they are different utilities), exactly as React's `cn` does.
  - `@container/card-header`: names a container that caller classes (`@[250px]/card-header:...`) query (scenarios `container-query__*`).
- States: none in the source (no `hover:`, `focus-visible:`, `disabled:`, `aria-invalid:`, `data-[state]`, `dark:` tokens; manifest `data_attrs: []`). Dark mode differs only through theme tokens (`--card`, `--card-foreground`, `--muted-foreground`, `--border`), covered by `__dark` twins.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Card` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Card::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Card::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `card.header` | `Card::Header` | `CardHeader` |
| `card.footer` | `Card::Footer` | `CardFooter` |
| `card.title` | `Card::Title` | `CardTitle` |
| `card.action` | `Card::Action` | `CardAction` |
| `card.description` | `Card::Description` | `CardDescription` |
| `card.content` | `Card::Content` | `CardContent` |

Names that shadow a Phlex HTML element inside `Card`'s OWN `view_template` (use `tag(:header)` there, never the bare method): `header`, `footer`, `title`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

None (`registry_dependencies: []`, `icons: []`). The component renders no other `Components::V2` component.

Example substitutions (scenario-level, identical on both harnesses, not component deviations): `card-demo` composes `Button`, `Input`, `Label`; `card-with-form` composes `Button`, `Input`, `Label`, `Select`. Card has no registry dependency on them, so the scenario coverage check rejects their exports here. They are rendered as neutral raw elements (`_button`, `_input`, `_label`, a native `_select` with the same options) carrying the example's own `className`/`id`/`type`/`placeholder`/`required`/`htmlFor`. The full compositions belong to cross-component scenarios once `button`, `input`, `label` and `select` are DONE.

## Deviations

None.
