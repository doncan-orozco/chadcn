# Table (`Components::V2::Table`)

Oracle: `gems/chadcn/dev/port/oracle/src/table.tsx` (style `new-york-v4`, manifest `source_sha` `bd1a9fc83a5a2149`), manifest `gems/chadcn/dev/port/oracle/manifest/table.json`. Tier `static`: the file starts with `"use client"` but uses no hook, no Radix primitive, no cva, no icon, no text literal (manifest `radix_primitives: []`, `hooks: []`, `icons: []`, `cva: {}`). No Stimulus controller. Exports `Table`, `TableHeader`, `TableBody`, `TableFooter`, `TableHead`, `TableRow`, `TableCell`, `TableCaption`. Data-slots `table-container`, `table`, `table-header`, `table-body`, `table-footer`, `table-row`, `table-head`, `table-cell`, `table-caption`. Registry example: `table-demo` (`https://ui.shadcn.com/r/styles/new-york-v4/table-demo.json`).

## API

```ruby
Components::V2::Table.new(class: nil, **attrs) { ... }
Components::V2::Table::Header.new(class: nil, **attrs) { ... }
Components::V2::Table::Body.new(class: nil, **attrs) { ... }
Components::V2::Table::Footer.new(class: nil, **attrs) { ... }
Components::V2::Table::Row.new(class: nil, **attrs) { ... }
Components::V2::Table::Head.new(class: nil, **attrs) { ... }
Components::V2::Table::Cell.new(class: nil, **attrs) { ... }
Components::V2::Table::Caption.new(class: nil, **attrs) { ... }
```

| part (tsx function) | Ruby class | element props type | kwargs |
|---|---|---|---|
| `Table` | `Components::V2::Table` | `React.ComponentProps<"table">` | `class:`, `**attrs` |
| `TableHeader` | `Components::V2::Table::Header` | `React.ComponentProps<"thead">` | `class:`, `**attrs` |
| `TableBody` | `Components::V2::Table::Body` | `React.ComponentProps<"tbody">` | `class:`, `**attrs` |
| `TableFooter` | `Components::V2::Table::Footer` | `React.ComponentProps<"tfoot">` | `class:`, `**attrs` |
| `TableRow` | `Components::V2::Table::Row` | `React.ComponentProps<"tr">` | `class:`, `**attrs` |
| `TableHead` | `Components::V2::Table::Head` | `React.ComponentProps<"th">` | `class:`, `**attrs` |
| `TableCell` | `Components::V2::Table::Cell` | `React.ComponentProps<"td">` | `class:`, `**attrs` |
| `TableCaption` | `Components::V2::Table::Caption` | `React.ComponentProps<"caption">` | `class:`, `**attrs` |

- Every part destructures only `{ className, ...props }` (manifest `props.destructured`). The only kwarg is `class:` (default `nil`), merged through `cn` (tailwind_merge) after the part's base classes; caller wins conflicts (shadcn-port R6).
- **`Table` is special**: `className` and `...props` go to the inner `<table>`, NOT to the `table-container` div (tsx `Table`: the div has a fixed `className="relative w-full overflow-x-auto"` and no spread). So `class:` and every `**attrs` key (`id`, `aria-label`, `data-*`, `style`...) land on `<table data-slot="table">`; the container accepts nothing from the caller. Scenarios `class-merge__table`, `attrs__table-forwarded-to-table`.
- `**attrs`: any attribute of the part's element, deep-merged (`data: {}`, `aria: {}`, `"aria-*":`). React camelCase element props map to their HTML attribute names: `colSpan` -> `colspan:`, `rowSpan` -> `rowspan:`, `scope:`, `headers:`, `aria-sort`... (scenarios `cell__colspan`, `head__scope-and-colspan`, `attrs__parts-forwarded`).
- `data-state` is not a kwarg: the caller passes `data: { state: "selected" }` (or `"data-state": "selected"`) on `Table::Row` to trigger `data-[state=selected]:bg-muted`, exactly as React callers pass `data-state` (scenario `row__state-selected`).
- Block = `children`. No variants (R4 has nothing to map), no `as_child:` (the source never uses `Slot`), no `as:`, no events dispatched (no `on*` props), no class method, no `ref` equivalent.

## Structure

All markup is server-rendered; nothing is set client-side. No ids generated, no ARIA added, no `role`, no sr-only text. Native table semantics only.

```html
<div data-slot="table-container" class="relative w-full overflow-x-auto">
  <table data-slot="table" class="w-full caption-bottom text-sm">
    <caption data-slot="table-caption" class="mt-4 text-sm text-muted-foreground">...</caption>
    <thead data-slot="table-header" class="[&_tr]:border-b">
      <tr data-slot="table-row" class="border-b transition-colors hover:bg-muted/50 has-aria-expanded:bg-muted/50 data-[state=selected]:bg-muted">
        <th data-slot="table-head" class="h-10 px-2 text-left align-middle font-medium whitespace-nowrap text-foreground [&:has([role=checkbox])]:pr-0 [&>[role=checkbox]]:translate-y-[2px]">...</th>
      </tr>
    </thead>
    <tbody data-slot="table-body" class="[&_tr:last-child]:border-0">
      <tr data-slot="table-row" class="...">
        <td data-slot="table-cell" class="p-2 align-middle whitespace-nowrap [&:has([role=checkbox])]:pr-0 [&>[role=checkbox]]:translate-y-[2px]">...</td>
      </tr>
    </tbody>
    <tfoot data-slot="table-footer" class="border-t bg-muted/50 font-medium [&>tr]:last:border-b-0">...</tfoot>
  </table>
</div>
```

Classes, verbatim from the tsx base strings (each part is `cn("<base>", className)`, except the container which is a literal):

| part | data-slot | tag | classes |
|---|---|---|---|
| `Table` (outer) | `table-container` | `div` | `relative w-full overflow-x-auto` (literal, not mergeable) |
| `Table` (inner) | `table` | `table` | `w-full caption-bottom text-sm` |
| `TableHeader` | `table-header` | `thead` | `[&_tr]:border-b` |
| `TableBody` | `table-body` | `tbody` | `[&_tr:last-child]:border-0` |
| `TableFooter` | `table-footer` | `tfoot` | `border-t bg-muted/50 font-medium [&>tr]:last:border-b-0` |
| `TableRow` | `table-row` | `tr` | `border-b transition-colors hover:bg-muted/50 has-aria-expanded:bg-muted/50 data-[state=selected]:bg-muted` |
| `TableHead` | `table-head` | `th` | `h-10 px-2 text-left align-middle font-medium whitespace-nowrap text-foreground [&:has([role=checkbox])]:pr-0 [&>[role=checkbox]]:translate-y-[2px]` |
| `TableCell` | `table-cell` | `td` | `p-2 align-middle whitespace-nowrap [&:has([role=checkbox])]:pr-0 [&>[role=checkbox]]:translate-y-[2px]` |
| `TableCaption` | `table-caption` | `caption` | `mt-4 text-sm text-muted-foreground` |

- Attribute order in each tsx part: `data-slot`, `className`, then `{...props}`. The spread is last, so a caller `data-slot` in `**attrs` overrides the part's value (on `Table` it overrides the inner `table` slot only; `table-container` is untouchable). Scenario `attrs__data-slot-override`.
- `Table` always renders the wrapping `div`; the block is rendered inside `<table>`. DOM order is the caller's order; parts never reorder or inject children. `TableCaption` placed first in the DOM is still drawn below via `caption-bottom` (scenario `parts__caption-first-in-dom`); a caller `caption-top` flips it (scenario `class-merge__caption`).
- States and selectors pinned by scenarios (all pure CSS, no JS):
  - `hover:bg-muted/50` on every `TableRow`, including header and footer rows (`row__hover-*`).
  - `data-[state=selected]:bg-muted` when the caller sets `data-state="selected"`; any other value (`data-state="false"`) has no effect (`row__state-selected`, `row__state-unselected`, `row__state-selected__hover`).
  - `has-aria-expanded:bg-muted/50` when a descendant has `aria-expanded="true"` (`row__has-aria-expanded-true` / `-false`).
  - `[&:has([role=checkbox])]:pr-0` and `[&>[role=checkbox]]:translate-y-[2px]` on `TableHead`/`TableCell` with a direct `role="checkbox"` child (`checkbox__head-and-cell`; the checkbox is a raw `_button role="checkbox"` because Checkbox is not a registry dependency of table).
  - `[&_tr]:border-b` (header), `[&_tr:last-child]:border-0` (body), `[&>tr]:last:border-b-0` (footer, multiple rows: `footer__multiple-rows`).
  - `whitespace-nowrap` on head/cell plus `overflow-x-auto` on the container: wide tables scroll horizontally inside the container (`overflow__*`, `content__long-text-nowrap`).
  - `text-left` is physical, so `dir="rtl"` keeps heads left-aligned (`dir__rtl`).
- No `dark:` tokens; dark mode differs only through theme tokens (`--muted`, `--foreground`, `--muted-foreground`, `--border`), covered by `__dark` twins.
- No focusable element of its own; `interaction__tab-to-cell-link` checks that focus moves into cell content unchanged.

<!-- spec_helpers:begin -->
## DX helpers (derived from the oracle, do not edit)

`Chadcn::Table` MUST `yield self` from `view_template`; `Chadcn::Base` generates one helper per nested part (`const_added`), each exactly `render Table::<Part>.new(**attrs), &block`. The helpers are sugar: the nested classes stay the canonical API (scenarios, tests and the parity harness use them), and fully qualified calls (`render Chadcn::Table::Content.new`) stay valid.

| helper | part class | React export |
|---|---|---|
| `table.header` | `Table::Header` | `TableHeader` |
| `table.body` | `Table::Body` | `TableBody` |
| `table.footer` | `Table::Footer` | `TableFooter` |
| `table.head` | `Table::Head` | `TableHead` |
| `table.row` | `Table::Row` | `TableRow` |
| `table.cell` | `Table::Cell` | `TableCell` |
| `table.caption` | `Table::Caption` | `TableCaption` |

Names that shadow a Phlex HTML element inside `Table`'s OWN `view_template` (use `tag(:header)` there, never the bare method): `header`, `body`, `footer`, `head`, `caption`.

Acceptance (unit test): every row exists as a public method on the root instance and renders the same HTML as the explicit class call; no helper is defined by hand.
<!-- spec_helpers:end -->

## Dependencies

None (`registry_dependencies: []`, `icons: []`). The component renders no other `Components::V2` component.

Examples: `table-demo` is reproduced 1:1 (`example__table-demo`, `__dark`, `overflow__narrow-viewport-demo`). `data-table-demo` (TanStack Table + Checkbox, DropdownMenu, Button, Input) is a separate registry item, not a `table-*` example, and depends on components that are not registry dependencies of `table`; it belongs to a later data-table composition, not this component. Its table-specific behaviors (checkbox column padding, `data-state="selected"` rows, `has-aria-expanded` rows) are covered here with raw `_button` stand-ins.

## Deviations

None.
