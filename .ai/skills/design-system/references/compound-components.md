# Compound components: nested part classes

shadcn exposes compound components as sibling exports (`Dialog`, `DialogTrigger`, `DialogContent`...). The port mirrors them 1:1 as **one class per export, parts nested under the root class**: in the root's file for small roots, one part per file under `lib/chadcn/<name>/` for large ones. Views compose them with explicit `render`, like JSX.

> The nested classes below are the canonical API. The "parent yields self" helpers (`card.header`, `dropdown.trigger`) exist too, but as GENERATED sugar over those classes (see "DX helpers"), never hand-written.

## Naming rule (single source: `shadcn-port` references/api-mapping.md)

`<Root><Part>` -> `Chadcn::<Root>::<Part>`; strip the root prefix once.

| React | Phlex |
|---|---|
| `Dialog` | `Chadcn::Dialog` |
| `DialogTrigger` | `Chadcn::Dialog::Trigger` |
| `DialogContent` | `Chadcn::Dialog::Content` |
| `DropdownMenuCheckboxItem` | `Chadcn::DropdownMenu::CheckboxItem` |
| `CardHeader`, `CardAction` | `Chadcn::Card::Header`, `Card::Action` |
| `SelectScrollUpButton` | `Chadcn::Select::ScrollUpButton` |
| `buttonVariants(...)` | `Chadcn::Button.variants(...)` (class method, returns the class string) |

## File layout

```ruby
# lib/chadcn/dialog.rb  (Zeitwerk: Chadcn::Dialog); compact class form on purpose (.rubocop.yml: same constant lookup as the port)
class Chadcn::Dialog < Chadcn::Base
  def initialize(open: nil, default_open: false, modal: true, **attrs) = ...
  def view_template(&block) = ...   # data-slot="dialog", controller chadcn--dialog
end

# lib/chadcn/dialog/trigger.rb  (a large root keeps one part per file under lib/chadcn/<name>/)
class Chadcn::Dialog::Trigger < Chadcn::Base ... end   # data-slot="dialog-trigger"

# small roots keep their parts in the root's file (lib/chadcn/table.rb: `class Header < Chadcn::Base` inside `class Chadcn::Table`)
```

- Every part is a `Chadcn::Base` subclass with its own `initialize(..., **attrs)` and `view_template`. Parts that would push the file past ~250 lines move to `lib/chadcn/dialog/content.rb` (still `Dialog::Content`; Zeitwerk reopens the namespace).
- Parts never reach into the parent's instance. Shared state travels through the DOM (the root renders `data-controller="chadcn--dialog"` and ids; parts use Stimulus targets/outlets and the ids from `aria-*` wiring). Cross-part ids come from the `id:` kwarg or a deterministic helper in the root class (`Dialog.ids(id)` -> `{ trigger:, content:, title:, description: }`), so server-rendered `aria-labelledby/controls` resolve before JS.
- Parts are order-independent in Ruby; DOM order is the order the caller renders them, as in React.

## Usage

```ruby
render Chadcn::Card.new do
  render Chadcn::Card::Header.new do
    render Chadcn::Card::Title.new { "Settings" }
    render Chadcn::Card::Description.new { "Manage your account" }
    render Chadcn::Card::Action.new { render Chadcn::Button.new(variant: "link") { "Edit" } }
  end
  render Chadcn::Card::Content.new { render_form }
  render Chadcn::Card::Footer.new(class: "justify-end") { render Chadcn::Button.new { "Save" } }
end
```

Without Rails the same tree renders with `Chadcn::Card.new { ... }.call` (README, "Without Rails"); the classes are the whole API, no view-level shorthand is needed.

## `as_child`

React `asChild` -> `as_child:` (see api-mapping.md). `false` by default; `as_child: :a` renders that tag; `as_child: Chadcn::Button.new(variant: "outline")` merges the part's attributes into the given component with Radix Slot semantics (child props win, classes plainly joined with no conflict resolution, `data-action` concatenated child first). All of it lives in `Chadcn::Base#render_as_child`; parts call it, never reimplement it.

```ruby
render Chadcn::Dialog::Trigger.new(as_child: Chadcn::Button.new(variant: "outline")) { "Edit profile" }
```

## DX helpers (generated, equivalent to the explicit classes)

```ruby
render Chadcn::Table.new do |table|
  table.header do
    table.row do
      table.head { "Article" }
      table.head(class: "text-right") { "Actions" }
    end
  end
  table.body do
    @articles.each { |article| render Row.new(table: table, article: article) }
  end
end
```

- **Contract:** the root `view_template` calls `yield self`; every class nested under the root and inheriting `Chadcn::Base` gets a public instance method named after it (`Header` -> `header`, `CheckboxItem` -> `checkbox_item`, `ScrollUpButton` -> `scroll_up_button`), defined automatically (`const_added`). `table.header(**attrs, &block)` is exactly `render Table::Header.new(**attrs), &block`.
- **Same rule as the class names:** strip the root prefix once from the React export (`TableHead` -> `head`); a capitalized export without the prefix keeps its name (`ScrollBar` -> `scroll_bar`). The list per component is in each spec ("DX helpers" section, derived).
- **Passing the root around** (`Row.new(table: table, ...)` in the usage above) works: the helpers live on the yielded instance.
- **Shadowing:** 22 components have a part whose helper name equals a Phlex HTML element (`header`, `footer`, `title`, `label`, `link`...). Harmless for callers; inside the root's own `view_template` use `tag(:header)` instead of the bare method. A name that collides with a Ruby core or Phlex API method is refused when the class loads.
- **Verification:** each component's unit test asserts every helper exists and renders the same HTML as the explicit class; the parity runner can render the whole scenario set through the helpers (`parity_run.mjs --dx helpers`, gate G2b) and compare it to React.

## Common mistakes

- Hand-writing a helper (`def content(**attrs, &b) = render Content.new(**attrs, &b)`): helpers are generated by `Chadcn::Base`; a hand-written one can drift from the class (and the `--dx helpers` parity gate would no longer prove them).
- Calling a bare element name inside a root's own `view_template` when a part helper shadows it (`header`, `title`, `footer`, `label`, `link`, `menu`, `sub`, `input`, ...): use `tag(:header)` there.
- Wrapping parts in extra divs: breaks `has-data-[slot=...]` / `[&>svg]` selectors that the shadcn classes rely on.
- Putting `Button` inside `Trigger` as content: nested interactive elements. Use `as_child:` (design-system R8).
- Adding wrapper elements for layout: use `class:` on the part.
- Reading request or application state inside a part (a current user, params, a record): the gem has no domain knowledge (design-system R12); pass values in.
