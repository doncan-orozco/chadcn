# Display components

[chadcn](../README.md) docs, display family. Static building blocks: no Stimulus controller is needed except for `Avatar` (image
loading state) and `Toaster` (toasts). Conventions shared by every component: [api-conventions.md](api-conventions.md).

| Component | Root kwargs (besides `**attrs`) | Parts (class and generated helper) |
|---|---|---|
| `Alert` | `variant:` (`default`, `destructive`) | `Title` `alert.title`, `Description` `alert.description` |
| `AspectRatio` | `ratio:` (default 1), `as_child:`, `style:` | none |
| `Avatar` | `size:` (`default`, `sm`, `lg`), `as_child:` | `Image` (`src:`, `as_child:`) `avatar.image`, `Fallback` (`delay_ms:`, `as_child:`) `avatar.fallback`, `Badge` `avatar.badge`, `Group` `avatar.group`, `GroupCount` `avatar.group_count` |
| `Badge` | `variant:` (`default`, `secondary`, `destructive`, `outline`, `ghost`, `link`), `as_child:`; `Badge.variants(variant:, class:)` | none |
| `Bubble` | `variant:` (`default`, `secondary`, `muted`, `tinted`, `outline`, `ghost`, `destructive`), `align:` (`start`, `end`) | `Group` `bubble.group`, `Content` (`as_child:`) `bubble.content`, `Reactions` (`side:`, `align:`) `bubble.reactions` |
| `Card` | none | `Header` `card.header`, `Title` `card.title`, `Description` `card.description`, `Action` `card.action`, `Content` `card.content`, `Footer` `card.footer` |
| `Empty` | none | `Header` `empty.header`, `Media` (`variant:` `default`, `icon`) `empty.media`, `Title` `empty.title`, `Description` `empty.description`, `Content` `empty.content` |
| `Kbd` | none | `Group` `kbd.group` |
| `Marker` | `variant:`, `as_child:`; `Marker.variants` | `Icon` `marker.icon`, `Content` `marker.content` |
| `Message` | `align:` (`start`, `end`) | `Group` `message.group`, `Avatar` `message.avatar`, `Content` `message.content`, `Header` `message.header`, `Footer` `message.footer` |
| `Progress` | `value:`, `max:` | none |
| `Separator` | `orientation:` (`horizontal`, `vertical`), `decorative:` (true), `as_child:` | none |
| `Skeleton` | none | none |
| `Spinner` | none | none |
| `Toaster` (`Sonner::Toaster`; `Sonner` is the root that renders it and offers `sonner.toast`) | `position:`, `theme:`, `rich_colors:`, `expand:`, `close_button:`, `invert:`, `duration:`, `visible_toasts:`, `gap:`, `offset:`, `mobile_offset:`, `dir:`, `hotkey:`, `container_aria_label:`, `swipe_directions:`, `toast_options:`, `icons:`, `style:`, `toaster_id:`, `flash:`, `toasts:` | `Sonner::Toast` (`title:`, `description:`, `type:`, `id:`, `duration:`, `position:`, `dismissible:`, `close_button:`, `rich_colors:`, `invert:`, `icon:`, `action:`, `cancel:`, `toaster_id:`, `test_id:`), rendered inside the Toaster or appended to it |
| `Table` | none (attributes go to the inner `<table>`; the scroll container is fixed) | `Header` `table.header`, `Body` `table.body`, `Footer` `table.footer`, `Row` `table.row`, `Head` `table.head`, `Cell` `table.cell`, `Caption` `table.caption` |
| `Item` | `variant:` (`default`, `outline`, `muted`), `size:` (`default`, `sm`), `as_child:`; `Item.variants` | `Media` (`variant:`) `item.media`, `Content` `item.content`, `Actions` `item.actions`, `Group` `item.group`, `Title` `item.title`, `Description` `item.description`, `Header` `item.header`, `Footer` `item.footer`, `Separator` `item.separator` |
| `Attachment` | `state:` (`idle`, `uploading`, `processing`, `error`, `done`), `size:` (`default`, `sm`, `xs`), `orientation:` (`horizontal`, `vertical`) | `Group` `attachment.group`, `Media` (`variant:`) `attachment.media`, `Content` `attachment.content`, `Title` `attachment.title`, `Description` `attachment.description`, `Actions` `attachment.actions`, `Action` (`variant:`, `size:`) `attachment.action`, `Trigger` (`as_child:`, `type:`) `attachment.trigger` |

The exact accepted values of every option are the keys of the component's `VARIANTS` / `SIZES` tables in the YARD documentation;
passing a symbol (`variant: :destructive`) is the same as the string.

## Example: a card, both forms

```ruby
# explicit classes
render Chadcn::Card.new(class: "w-full max-w-sm") do
  render Chadcn::Card::Header.new do
    render Chadcn::Card::Title.new { "Login to your account" }
    render Chadcn::Card::Description.new { "Enter your email below to login to your account" }
    render Chadcn::Card::Action.new { render Chadcn::Button.new(variant: "link") { "Sign Up" } }
  end
  render Chadcn::Card::Content.new { render Chadcn::Input.new(type: "email", placeholder: "m@example.com") }
  render Chadcn::Card::Footer.new(class: "flex-col gap-2") do
    render Chadcn::Button.new(type: "submit", class: "w-full") { "Login" }
  end
end

# generated helpers
render Chadcn::Card.new(class: "w-full max-w-sm") do |card|
  card.header do
    card.title { "Login to your account" }
    card.description { "Enter your email below to login to your account" }
    card.action { render Chadcn::Button.new(variant: "link") { "Sign Up" } }
  end
  card.content { render Chadcn::Input.new(type: "email", placeholder: "m@example.com") }
  card.footer(class: "flex-col gap-2") { render Chadcn::Button.new(type: "submit", class: "w-full") { "Login" } }
end
```

## Example: a table

```ruby
render Chadcn::Table.new do |table|
  table.caption { "A list of your recent invoices." }
  table.header do
    table.row do
      table.head(class: "w-[100px]") { "Invoice" }
      table.head(class: "text-right") { "Amount" }
    end
  end
  table.body do
    invoices.each do |invoice|
      table.row do
        table.cell(class: "font-medium") { invoice.number }
        table.cell(class: "text-right") { invoice.amount }
      end
    end
  end
end
```

`table.row`, `table.cell`... are available on the yielded instance wherever you pass it, so a row can be its own component that
receives `table:`.

## Toasts: the Toaster

`Toaster` is the shadcn export of sonner. Render it once, in the layout; toasts reach it three ways, with no JavaScript dependency (the
`chadcn--sonner` controller and `app/assets/tailwind/chadcn/sonner.css` do what the sonner library does):

```ruby
# layout: the flash is shown as toasts (notice and success -> success, alert and error -> error, warning, info, anything else plain)
render Chadcn::Toaster.new(flash: { notice: "Saved", alert: "Could not send" }, close_button: true, position: "top-center")

# any server response: a Turbo Stream appends a toast to the Toaster's id ("toaster" unless you pass id:)
Chadcn::Sonner::Toast.new(type: :success, title: "Saved", description: "All changes stored", action: { label: "Undo", event: "undo" })
```

```javascript
// any script: the same function as sonner's toast
window.Toaster.success("Saved", { description: "All changes stored", action: { label: "Undo", onClick: () => {} } })
window.Toaster.promise(fetch("/save"), { loading: "Saving", success: "Saved", error: "Failed" })
document.dispatchEvent(new CustomEvent("chadcn--sonner:show", { detail: { message: "Hello", type: "info" } }))
```

In a Rails controller, `turbo_stream.append "toaster", Chadcn::Sonner::Toast.new(type: :success, title: "Saved")` renders the
`<template data-chadcn--sonner-toast>` the Toaster turns into a toast. Titles and descriptions are text, never markup. Types:
`default` (no icon), `success`, `info`, `warning`, `error`, `loading` (no timer until it is updated). A toast with the same `id`
updates instead of stacking.

- The `<section>` is an `aria-live="polite"` region labelled `Notifications alt+T` (the hotkey, `hotkey:`, expands the stack and focuses
  it; Escape collapses it). An `error` toast is also written to a hidden `role="alert"` element so it interrupts.
- Toasts pause while the stack is hovered, focused or expanded and when the tab is hidden; a swipe towards the edge of `position:`
  dismisses; `dismissible: false` stops swipe, close button and cancel.
- Events on the section: `chadcn--sonner:dismiss`, `:auto-close`, `:action` and `:cancel` (`detail.id`, and `detail.name` for the toast's `event:`).
  An action with `href:` visits that http(s) URL.
- With `data: { turbo_permanent: true }` the Toaster survives Turbo visits (and its toasts stay), but then a page that renders `flash:`
  is not re-read: send the flash as a Turbo Stream instead. Without it, toasts disappear with the page, and a Turbo cache snapshot never
  contains them.
- `toast_options: { class_names: { toast: "...", error: "..." } }`, `class:` (added to the lists) and `style:` customise the look; the
  colors come from the theme (`--popover`, `--popover-foreground`, `--border`, `--radius`).

## Charts (cartesian)

`Chadcn::Chart::BarChart`, `LineChart` and `AreaChart` draw the SVG of [recharts](https://recharts.org) 3.8 (its class names, layers and
numbers) from Ruby, with no JavaScript library. Put one inside a `Chart::Container` (the shadcn `ChartContainer`: the config colors as
`--color-<key>` variables and the size, `initial_dimension:`, 320x200 by default). The chart is laid out once at that size.

The block of a chart declares what is in it; it runs first, then everything is laid out in one pass. Each part renders nothing where it
is written and registers with its chart; the generated helper of a part (`chart.bar`) is `render Chadcn::Chart::Bar.new(...)`.

| Part | Keywords (besides `**attrs`) |
|---|---|
| `BarChart`, `LineChart`, `AreaChart` | `data:` (rows), `layout:` (`horizontal`, `vertical`), `margin:` (a side not given is 0), `bar_category_gap:` (`"10%"`), `bar_gap:` (4), `bar_size:`, `max_bar_size:`, `stack_offset:` (`none`, `expand`), `reverse_stack_order:`, `accessibility_layer:` (true), `title:`, `desc:`, `role:`, `tab_index:`; `AreaChart` also `base_value:`. `class:` and `style:` go on `.recharts-wrapper`, other attributes on the `svg` |
| `Bar` `chart.bar` | `data_key:`, `stack_id:`, `fill:`, `stroke:`, `radius:` (number or `[tl, tr, br, bl]`), `bar_size:`, `max_bar_size:`, `min_point_size:`, `background:`, `label:`, `hide:`, `legend_type:`, `tooltip_type:`, `x_axis_id:`, `y_axis_id:`, `name:`, `unit:`; its block takes `bar.cell` and `bar.label_list` |
| `Line` `chart.line` | `data_key:`, `type:` (`linear`, `monotone`, `natural`, `step`, ...), `stroke:`, `stroke_width:`, `stroke_dasharray:`, `fill:`, `dot:`, `connect_nulls:`, `label:`, ... |
| `Area` `chart.area` | `data_key:`, `type:`, `stack_id:`, `fill:`, `fill_opacity:`, `stroke:`, `stroke_width:`, `dot:`, `base_value:`, `connect_nulls:`, `label:`, ... |
| `XAxis` `chart.x_axis`, `YAxis` `chart.y_axis` | `data_key:`, `type:`, `hide:`, `height:` / `width:`, `orientation:`, `tick:`, `tick_line:`, `axis_line:`, `tick_size:`, `tick_margin:`, `tick_count:`, `tick_formatter:`, `interval:`, `min_tick_gap:`, `mirror:`, `reversed:`, `padding:`, `domain:`, `allow_decimals:`, `allow_data_overflow:`, `nice_ticks:`, `angle:`, `unit:`, `ticks:`, `x_axis_id:` / `y_axis_id:` |
| `CartesianGrid` `chart.cartesian_grid` | `horizontal:`, `vertical:`, `stroke:`, `stroke_dasharray:`, `horizontal_fill:`, `vertical_fill:`, `sync_with_ticks:` |
| `ReferenceLine` `chart.reference_line` | `x:` or `y:`, `stroke:`, `stroke_dasharray:`, `if_overflow:` (`discard`, `hidden`, `visible`, `extend_domain`) |
| `LabelList` `bar.label_list`, `Label` `chart.label`, `Cell` `bar.cell` | `position:`, `offset:`, `formatter:`, `fill:`, `angle:`, `data_key:`; `Cell` takes `fill:`, `stroke:` and any attribute of its shape |

`tick_formatter:`, `formatter:` and `label_formatter:` take a callable (`->(value, index) { ... }`) or a named formatter that holds no code:
`{ slice: [0, 3] }`, `:locale`, `:percent`.

```ruby
rows = [ { month: "January", desktop: 186, mobile: 80 }, { month: "February", desktop: 305, mobile: 200 }, { month: "March", desktop: 237, mobile: 120 } ]
config = { desktop: { label: "Desktop", color: "var(--chart-1)" }, mobile: { label: "Mobile", color: "var(--chart-2)" } }

render Chadcn::Chart::Container.new(config: config, id: "sales") do
  render Chadcn::Chart::BarChart.new(data: rows) do |chart|
    chart.cartesian_grid(vertical: false)
    chart.x_axis(data_key: :month, tick_line: false, tick_margin: 10, axis_line: false, tick_formatter: { slice: [ 0, 3 ] })
    chart.bar(data_key: :desktop, stack_id: "a", fill: "var(--color-desktop)", radius: [ 0, 0, 4, 4 ])
    chart.bar(data_key: :mobile, stack_id: "a", fill: "var(--color-mobile)", radius: [ 4, 4, 0, 0 ]) do |bar|
      bar.label_list(position: :top, offset: 12, class: "fill-foreground")
    end
  end
end
```

A `<defs>` of gradients (or any SVG the block writes itself, e.g. by rendering a `Phlex::SVG` component) is placed in the `svg` after the clip
path, where recharts renders its non-chart children.

`chart.tooltip` and `chart.legend` draw recharts' wrappers inside `.recharts-wrapper`, in front of the svg:

- `chart.legend(content: Chart::Legend::Content.new, vertical_align: :top)` writes `.recharts-legend-wrapper` with the series as the payload (declaration
  order, sorted by name unless `item_sorter: nil`, `legend_type: :none` dropped by the content) and reserves its room in the plot. Where it sits and how
  big it is follow `Legend.js` (`width:`, `height:`, `align:`, `layout:`, `wrapper_style:`); the height it takes is `legend_height:` (28, a `pt-3`
  plus a 16px line), because the server cannot measure it.
- `chart.tooltip(content: Chart::Tooltip::Content.new, default_index: 1)` writes the empty `.recharts-tooltip-wrapper`, one inert
  `<template data-chadcn--chart-target="tooltipTemplate" data-index data-label data-coordinate data-cursor data-active-dots>` per category (children of
  the chart's `div[data-slot="chart"]`, after its shell) holding the content for that category's payload, and, with `default_index:`, the wrapper
  visible with that category's content and the cursor (a rectangle behind the bars of a bar chart, a line on a line or area chart) and the active dots
  in the svg. A series is left out of the payload with `tooltip_type: :none` (the content drops it), a nil value or a hidden series by `filter_null`.
  Where the wrapper sits and the hover itself belong to the `chadcn--chart` controller; `shared: false` (item tooltips) is not drawn.

## Notes

- `Avatar::Image` ships its `<img>` in an inert `<template>` and the `chadcn--avatar` controller mounts it once it has loaded (Radix
  `Avatar.Image` semantics, event `chadcn--avatar:loading-status-change`); `Avatar::Fallback` shows meanwhile, after `delay_ms:` when given.
- `Badge`, `Item`, `Marker` and `Empty::Media` expose `.variants(...)` returning the class string, like React's cva helpers, to
  style another element the same way.
- `Progress` renders the Radix progressbar DOM (`role="progressbar"`, `aria-valuemin` / `aria-valuemax`, `data-state`, `data-max`; no
  `aria-valuenow`, like shadcn) with the indicator translated by `value:` out of `max:`.
