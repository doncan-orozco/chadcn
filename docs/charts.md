# Charts

`Chadcn::Chart` is shadcn's [chart](https://ui.shadcn.com/docs/components/chart) without React and without a charting library. The
bar, line, area, pie, radar and radial charts are drawn on the server, from Ruby, as the SVG that [recharts](https://recharts.org) 3.8
produces once the browser has settled it (its `recharts-*` class names, layers, attributes and numbers), inside shadcn's own
`ChartContainer`, so the theme classes of `chart.tsx` apply with no new CSS. The tooltip, the cursor, the active dots and the keyboard
are the `chadcn--chart` Stimulus controller; no JavaScript library is added. The decision record is
[dev/decisions/chart.md](../dev/decisions/chart.md) and the 1:1 spec [dev/port/specs/chart.md](../dev/port/specs/chart.md) (both in the
repository only).

The reference for every part and keyword is the YARD documentation of `Chadcn::Chart::*` (and [display](display.md#charts-cartesian)
for the two keyword tables); this page is the guide: how a chart is put together, one example per family next to its React source,
the tooltip and the legend, the interaction, and what is different from recharts.

## The shape of a chart

A chart is three levels, each one a Phlex component:

```ruby
config = { desktop: { label: "Desktop", color: "var(--chart-1)" } }
rows = [ { month: "January", desktop: 186 }, { month: "February", desktop: 305 }, { month: "March", desktop: 237 } ]

render Chadcn::Chart::Container.new(config: config, id: "sales") do
  render Chadcn::Chart::BarChart.new(data: rows) do |chart|
    chart.x_axis(data_key: :month)
    chart.bar(data_key: :desktop, fill: "var(--color-desktop)")
  end
end
```

1. **`Chart::Container`** is `ChartContainer`: the `div[data-slot="chart"]` that holds the config, the `--color-<key>` variables and the
   `chadcn--chart` controller. It is required: a chart outside a container is not wired and its colors are not defined.
2. **A chart root** (`BarChart`, `LineChart`, `AreaChart`, `PieChart`, `RadarChart`, `RadialBarChart`) takes the `data:` and the
   layout options and draws the SVG.
3. **Parts** (`Bar`, `XAxis`, `CartesianGrid`, `Tooltip`, `Legend`...) are declared in the root's block. A part renders nothing where it
   is written: the block runs first, every part registers with its chart, and then the chart is laid out in one pass. Each part has a
   generated helper on the yielded root (`chart.bar(...)` is `render Chadcn::Chart::Bar.new(...)`); the nested class form works too.

Nested classes keep the recharts names with the `Chart` suffix on the roots (`Chart::BarChart`, because `Chart::Bar` is the series, as
in recharts); everything else is the recharts name in Ruby style: `dataKey` is `data_key:`, `tickFormatter` is `tick_formatter:`.

### The config and the colors

`config:` is shadcn's `ChartConfig`: for each series key a `label`, an `icon` (a Lucide icon name or a component instance) and either
one `color` or a `theme: { light:, dark: }`, never both. Each color becomes the variable `--color-<key>` on the container, which is
what `fill: "var(--color-desktop)"` reads, for light and for dark. A config key that does not name a series is still useful: the tooltip
and the legend look the label up in it (the `visitors` entry of the pie below).

```ruby
config = {
  desktop: { label: "Desktop", color: "var(--chart-1)" },
  mobile: { label: "Mobile", theme: { light: "#2563eb", dark: "#60a5fa" } }
}
render Chadcn::Chart::Container.new(config: config, id: "themed") do
  render Chadcn::Chart::LineChart.new(data: [ { month: "January", desktop: 186, mobile: 80 }, { month: "February", desktop: 305, mobile: 200 } ]) do |chart|
    chart.line(data_key: :desktop, stroke: "var(--color-desktop)")
    chart.line(data_key: :mobile, stroke: "var(--color-mobile)")
  end
end
```

A key or an `id:` is letters, digits, `_` and `-`, and a color has none of `< > { } ; \` or `/*`, because they are written into a
`<style>` element; `ArgumentError` otherwise (React writes them raw). Pass an explicit `id:` when the page is cached or compared:
without one the container takes a random token per render.

## One example per family

Each example is a shadcn chart of that family adapted to what the port supports, with the React source first. The data arrays are the
ones of the shadcn examples (the months with `desktop` and `mobile`, the five browsers) and each example is also a scenario of the parity
gates (`dev/port/scenarios/chart.json`), where the React original renders next to this DOM. The site's examples add classes to the container
that only size the box (see [Sizing](#sizing)), and a title, a footer and an interactive variant, which are left out. `className` becomes `class:`, an inline function (`tickFormatter`) becomes a named formatter (see
[Formatters](#formatters)), and the chart is drawn at the size of the container (see [Sizing](#sizing)).

### Bar

```tsx
<ChartContainer config={chartConfig}>
  <BarChart accessibilityLayer data={chartData}>
    <CartesianGrid vertical={false} />
    <XAxis dataKey="month" tickLine={false} tickMargin={10} axisLine={false}
      tickFormatter={(value) => value.slice(0, 3)} />
    <ChartTooltip cursor={false} content={<ChartTooltipContent indicator="dashed" />} />
    <Bar dataKey="desktop" fill="var(--color-desktop)" radius={4} />
    <Bar dataKey="mobile" fill="var(--color-mobile)" radius={4} />
  </BarChart>
</ChartContainer>
```

```ruby
rows = [
  { month: "January", desktop: 186, mobile: 80 }, { month: "February", desktop: 305, mobile: 200 },
  { month: "March", desktop: 237, mobile: 120 }, { month: "April", desktop: 73, mobile: 190 },
  { month: "May", desktop: 209, mobile: 130 }, { month: "June", desktop: 214, mobile: 140 }
]
config = { desktop: { label: "Desktop", color: "var(--chart-1)" }, mobile: { label: "Mobile", color: "var(--chart-2)" } }

render Chadcn::Chart::Container.new(config: config, id: "bar") do
  render Chadcn::Chart::BarChart.new(data: rows) do |chart|
    chart.cartesian_grid(vertical: false)
    chart.x_axis(data_key: :month, tick_line: false, tick_margin: 10, axis_line: false, tick_formatter: { slice: [ 0, 3 ] })
    chart.tooltip(cursor: false, content: Chadcn::Chart::Tooltip::Content.new(indicator: :dashed))
    chart.bar(data_key: :desktop, fill: "var(--color-desktop)", radius: 4)
    chart.bar(data_key: :mobile, fill: "var(--color-mobile)", radius: 4)
  end
end
```

`stack_id:` stacks bars, `layout: :vertical` (with `chart.x_axis(type: :number)` and a category `chart.y_axis`) draws them sideways,
`bar.label_list(position: :top)` writes the values, `radius:` takes a number or `[top_left, top_right, bottom_right, bottom_left]`
and `bar.cell(fill: ...)` colors one bar. [display](display.md#charts-cartesian) lists every keyword.

### Line

```tsx
<ChartContainer config={chartConfig}>
  <LineChart accessibilityLayer data={chartData} margin={{ left: 12, right: 12 }}>
    <CartesianGrid vertical={false} />
    <XAxis dataKey="month" tickLine={false} axisLine={false} tickMargin={8}
      tickFormatter={(value) => value.slice(0, 3)} />
    <ChartTooltip cursor={false} content={<ChartTooltipContent hideLabel />} />
    <Line dataKey="desktop" type="natural" stroke="var(--color-desktop)" strokeWidth={2} dot={false} />
  </LineChart>
</ChartContainer>
```

```ruby
rows = [
  { month: "January", desktop: 186 }, { month: "February", desktop: 305 }, { month: "March", desktop: 237 },
  { month: "April", desktop: 73 }, { month: "May", desktop: 209 }, { month: "June", desktop: 214 }
]

render Chadcn::Chart::Container.new(config: { desktop: { label: "Desktop", color: "var(--chart-1)" } }, id: "line") do
  render Chadcn::Chart::LineChart.new(data: rows, margin: { left: 12, right: 12 }) do |chart|
    chart.cartesian_grid(vertical: false)
    chart.x_axis(data_key: :month, tick_line: false, axis_line: false, tick_margin: 8, tick_formatter: { slice: [ 0, 3 ] })
    chart.tooltip(cursor: false, content: Chadcn::Chart::Tooltip::Content.new(hide_label: true))
    chart.line(data_key: :desktop, type: :natural, stroke: "var(--color-desktop)", stroke_width: 2, dot: false)
  end
end
```

`type:` is any curve recharts has (`linear`, `monotone`, `natural`, `step`, `basis`...); `dot:` is `false` or a Hash of the attributes of
the dots.

### Area

```tsx
<ChartContainer config={chartConfig}>
  <AreaChart accessibilityLayer data={chartData} margin={{ left: 12, right: 12 }}>
    <CartesianGrid vertical={false} />
    <XAxis dataKey="month" tickLine={false} axisLine={false} tickMargin={8}
      tickFormatter={(value) => value.slice(0, 3)} />
    <ChartTooltip cursor={false} content={<ChartTooltipContent indicator="line" />} />
    <Area dataKey="desktop" type="natural" fill="var(--color-desktop)" fillOpacity={0.4} stroke="var(--color-desktop)" />
  </AreaChart>
</ChartContainer>
```

```ruby
rows = [
  { month: "January", desktop: 186 }, { month: "February", desktop: 305 }, { month: "March", desktop: 237 },
  { month: "April", desktop: 73 }, { month: "May", desktop: 209 }, { month: "June", desktop: 214 }
]

render Chadcn::Chart::Container.new(config: { desktop: { label: "Desktop", color: "var(--chart-1)" } }, id: "area") do
  render Chadcn::Chart::AreaChart.new(data: rows, margin: { left: 12, right: 12 }) do |chart|
    chart.cartesian_grid(vertical: false)
    chart.x_axis(data_key: :month, tick_line: false, axis_line: false, tick_margin: 8, tick_formatter: { slice: [ 0, 3 ] })
    chart.tooltip(cursor: false, content: Chadcn::Chart::Tooltip::Content.new(indicator: :line))
    chart.area(data_key: :desktop, type: :natural, fill: "var(--color-desktop)", fill_opacity: 0.4, stroke: "var(--color-desktop)")
  end
end
```

`stack_id:` stacks areas. A gradient fill is a `<defs>` the block writes itself; the SVG a chart's block renders is placed in the `svg` after
the clip path, where recharts renders its non-chart children, and the area's `fill:` points at it:

```ruby
rows = [ { month: "January", desktop: 186 }, { month: "February", desktop: 305 }, { month: "March", desktop: 237 } ]

render Chadcn::Chart::Container.new(config: { desktop: { label: "Desktop", color: "var(--chart-1)" } }, id: "gradient") do
  render Chadcn::Chart::AreaChart.new(data: rows) do |chart|
    render(Phlex::SVG.new { |svg| svg.defs { svg.linearGradient(id: "fillDesktop", x1: "0", y1: "0", x2: "0", y2: "1") { svg.stop(offset: "5%", stop_color: "var(--color-desktop)", stop_opacity: 0.8); svg.stop(offset: "95%", stop_color: "var(--color-desktop)", stop_opacity: 0.1) } } })
    chart.area(data_key: :desktop, type: :natural, fill: "url(#fillDesktop)", stroke: "var(--color-desktop)")
  end
end
```

### Pie

```tsx
<ChartContainer config={chartConfig}>
  <PieChart>
    <ChartTooltip cursor={false} content={<ChartTooltipContent hideLabel />} />
    <Pie data={chartData} dataKey="visitors" nameKey="browser" innerRadius={60} strokeWidth={5}>
      <Label value="Visitors" position="center" />
    </Pie>
  </PieChart>
</ChartContainer>
```

```ruby
browsers = [
  { browser: "chrome", visitors: 275, fill: "var(--color-chrome)" }, { browser: "safari", visitors: 200, fill: "var(--color-safari)" },
  { browser: "firefox", visitors: 187, fill: "var(--color-firefox)" }, { browser: "edge", visitors: 173, fill: "var(--color-edge)" },
  { browser: "other", visitors: 90, fill: "var(--color-other)" }
]
config = {
  visitors: { label: "Visitors" }, chrome: { label: "Chrome", color: "var(--chart-1)" }, safari: { label: "Safari", color: "var(--chart-2)" },
  firefox: { label: "Firefox", color: "var(--chart-3)" }, edge: { label: "Edge", color: "var(--chart-4)" }, other: { label: "Other", color: "var(--chart-5)" }
}

render Chadcn::Chart::Container.new(config: config, id: "pie") do
  render Chadcn::Chart::PieChart.new do |chart|
    chart.tooltip(cursor: false, content: Chadcn::Chart::Tooltip::Content.new(hide_label: true))
    chart.pie(data: browsers, data_key: :visitors, name_key: :browser, inner_radius: 60, stroke_width: 5) do |pie|
      pie.label(value: "Visitors", position: :center)
    end
  end
end
```

The sectors take their color from the row's `fill` (the `--color-<browser>` variables of the config). Angles are degrees, counterclockwise
from 3 o'clock, and a radius is a number of pixels or a percent string. In shadcn's donut-with-text example `Label` takes a function that
draws the total with `<text>` elements; a function is not portable, so the port takes a `value:` (as above) or a `Cell`/`LabelList`.

### Radar

```tsx
<ChartContainer config={chartConfig}>
  <RadarChart data={chartData}>
    <ChartTooltip cursor={false} content={<ChartTooltipContent />} />
    <PolarAngleAxis dataKey="month" />
    <PolarGrid gridType="circle" />
    <Radar dataKey="desktop" fill="var(--color-desktop)" fillOpacity={0.6} dot={{ r: 4, fillOpacity: 1 }} />
  </RadarChart>
</ChartContainer>
```

```ruby
rows = [
  { month: "January", desktop: 186 }, { month: "February", desktop: 305 }, { month: "March", desktop: 237 },
  { month: "April", desktop: 73 }, { month: "May", desktop: 209 }, { month: "June", desktop: 214 }
]

render Chadcn::Chart::Container.new(config: { desktop: { label: "Desktop", color: "var(--chart-1)" } }, id: "radar") do
  render Chadcn::Chart::RadarChart.new(data: rows) do |chart|
    chart.tooltip(cursor: false, content: Chadcn::Chart::Tooltip::Content.new)
    chart.polar_angle_axis(data_key: :month)
    chart.polar_grid(grid_type: :circle)
    chart.radar(data_key: :desktop, fill: "var(--color-desktop)", fill_opacity: 0.6, dot: { r: 4, fill_opacity: 1 })
  end
end
```

### Radial

```tsx
<ChartContainer config={chartConfig}>
  <RadialBarChart data={chartData} endAngle={180} innerRadius={80} outerRadius={130}>
    <ChartTooltip cursor={false} content={<ChartTooltipContent hideLabel />} />
    <RadialBar dataKey="desktop" stackId="a" cornerRadius={5} fill="var(--color-desktop)" className="stroke-transparent stroke-2" />
    <RadialBar dataKey="mobile" stackId="a" cornerRadius={5} fill="var(--color-mobile)" className="stroke-transparent stroke-2" />
  </RadialBarChart>
</ChartContainer>
```

```ruby
config = { desktop: { label: "Desktop", color: "var(--chart-1)" }, mobile: { label: "Mobile", color: "var(--chart-2)" } }

render Chadcn::Chart::Container.new(config: config, id: "radial") do
  render Chadcn::Chart::RadialBarChart.new(data: [ { month: "january", desktop: 1260, mobile: 570 } ], end_angle: 180, inner_radius: 80, outer_radius: 130) do |chart|
    chart.tooltip(cursor: false, content: Chadcn::Chart::Tooltip::Content.new(hide_label: true))
    chart.radial_bar(data_key: :desktop, stack_id: "a", corner_radius: 5, fill: "var(--color-desktop)", class: "stroke-transparent stroke-2")
    chart.radial_bar(data_key: :mobile, stack_id: "a", corner_radius: 5, fill: "var(--color-mobile)", class: "stroke-transparent stroke-2")
  end
end
```

## Tooltip and legend

Both are declarations in the chart's block, with the shadcn content as their `content:`:

```ruby
rows = [ { month: "January", desktop: 186, mobile: 80 }, { month: "February", desktop: 305, mobile: 200 } ]
config = { desktop: { label: "Desktop", color: "var(--chart-1)" }, mobile: { label: "Mobile", color: "var(--chart-2)" } }

render Chadcn::Chart::Container.new(config: config, id: "tooltip") do
  render Chadcn::Chart::BarChart.new(data: rows) do |chart|
    chart.x_axis(data_key: :month)
    chart.tooltip(default_index: 1, content: Chadcn::Chart::Tooltip::Content.new(indicator: :line, hide_label: true))
    chart.legend(content: Chadcn::Chart::Legend::Content.new, vertical_align: :top)
    chart.bar(data_key: :desktop, fill: "var(--color-desktop)")
    chart.bar(data_key: :mobile, fill: "var(--color-mobile)")
  end
end
```

**`Chart::Tooltip`** (`ChartTooltip`): `content:`, `cursor:` (`true`, `false` or a Hash of SVG attributes), `default_index:` (the category shown
before any interaction), `active:` (`true` keeps it visible, `false` never shows it), `shared:`, `trigger:` (`:hover` or `:click`),
`offset:`, `position:`, `allow_escape_view_box:`, `reverse_direction:`, `wrapper_style:`, `filter_null:`, `include_hidden:`, and `formatter:` /
`label_formatter:` which override the ones of the content. `separator:`, `content_style:` and `item_sorter:` are accepted and ignored, as they only
reach recharts' default content, which is not ported.

**`Tooltip::Content`** (`ChartTooltipContent`): `indicator:` (`:dot`, `:line`, `:dashed`), `hide_label:`, `hide_indicator:`, `label:`,
`label_formatter:`, `label_class_name:`, `formatter:`, `color:`, `name_key:`, `label_key:`, and `**attrs` on its root div (a chadcn
addition). `Tooltip::Content` and `Legend::Content` can also be rendered on their own with a `payload:`, as in the unit tests.

**`Chart::Legend`** (`ChartLegend`): `content:`, `vertical_align:` (`:top`, `:middle`, `:bottom`), `align:`, `layout:`, `width:`, `height:`,
`wrapper_style:`, `item_sorter:` (`:value` sorts the entries by name, `nil` keeps the series order). **`Legend::Content`**: `hide_icon:`,
`name_key:`. A series with `legend_type: :none` is left out. The legend takes room from the plot, and the server cannot measure it: `legend_height:`
(28 px, a `pt-3` plus a 16 px line) is the assumption, so change it if your legend wraps or your font is taller.

Where the tooltip *shows* depends on the chart: a bar, line, area, radar and radial chart have an axis tooltip (all series of the hovered
category), a pie has an item tooltip (the hovered sector). `shared: false` asks recharts for item tooltips: on a `BarChart` or a
`RadialBarChart` that is not drawn (the wrapper stays empty and the controller stays inert); on a `LineChart`, `AreaChart` or `RadarChart` the
tooltip stays an axis tooltip. The server writes one inert `<template>` per category (per sector for a pie) holding the content, so the page
weight is linear in categories and series; a chart with a hundred categories and five series ships a hundred templates.

## Formatters

React props that take a function (`tickFormatter`, `labelFormatter`, `formatter`) take here a callable or a named formatter that holds no
code, which is what the parity scenarios (JSON) use too:

- `{ slice: [0, 3] }` is `value.slice(0, 3)`, `:locale` is `value.toLocaleString("en-US")` and `:percent` multiplies by 100 and adds `%`.
- A callable runs on the server, at render time: `tick_formatter: ->(value, index) { "Q#{index + 1}" }`,
  `label_formatter: ->(label, payload) { ... }` (a String or a component), and the content's `formatter:` is called with
  `(value, name, item, index, row)` and returns what to render in place of the default item.

```ruby
rows = [ { month: "January", desktop: 1860 }, { month: "February", desktop: 3050 } ]
render Chadcn::Chart::Container.new(config: { desktop: { label: "Desktop", color: "var(--chart-1)" } }, id: "formatted") do
  render Chadcn::Chart::LineChart.new(data: rows) do |chart|
    chart.x_axis(data_key: :month, tick_formatter: ->(value, index) { "#{index + 1}. #{value.to_s[0, 3]}" })
    chart.y_axis(tick_formatter: :locale)
    chart.tooltip(content: Chadcn::Chart::Tooltip::Content.new(formatter: :locale))
    chart.line(data_key: :desktop, stroke: "var(--color-desktop)")
  end
end
```

## Interaction

`Chart::Container` is always the `chadcn--chart` controller element, and the chart root hands it every value (`data-chadcn--chart-*-value`);
nothing is drawn in JavaScript. The controller mounts the template of the active category into the tooltip wrapper, draws the cursor and
the active dots from the template's data, and places the wrapper with recharts' own algorithm (`offset`, `position`,
`allow_escape_view_box`, `reverse_direction`, `wrapper_style`).

- **Pointer.** `pointermove` (and touch) activates the nearest category; leaving the plot clears it. `trigger: :click` follows clicks instead.
- **Keyboard** (`accessibility_layer: true`, the default; it puts `role="application"` and `tabindex="0"` on the `svg`). Focusing the chart
  activates the first category; the arrow keys move the tooltip, Enter toggles it, Escape hides it until the active position changes. A vertical layout or
  a reversed `x_axis` makes ArrowRight go backward, as in recharts (the controller's `keyboardStep`).
- **Precedence.** The pointer wins while it is active, then the keyboard, then `default_index`, which only holds until the pointer has first
  activated a category.
- **Events** (bubbling): `chadcn--chart:activate` and `chadcn--chart:deactivate`, with `detail: { index, label, payload }`.
- **Turbo.** The snapshot taken for the page cache holds the server state (the `default_index` tooltip or none), and the live interaction is
  restored when the cached page is shown again.

`accessibility_layer: false` removes the focus and the keys and leaves the pointer. A polar chart publishes its tooltip values but the
controller maps the pointer and the keys for the cartesian charts only: a pie, radar or radial chart shows the `default_index` tooltip and
nothing moves it. The controller is `app/javascript/controllers/chadcn/chart_controller.js`, registered like every other `chadcn--*` controller.

## Sizing

A chart is laid out **once**, at `initial_dimension:` (320 x 200 px by default), and drawn at that pixel size: the `svg` carries that
`width`, `height` and `viewBox`, and `.recharts-wrapper` that size in px. The `class:` of the container only sizes the box around it
(`flex aspect-video justify-center` by default), so choose the size with `initial_dimension: { width: 480, height: 280 }`, not with
Tailwind width classes. There is no `ResponsiveContainer` re-layout on window resize.

The server also has to *assume* what only a browser can measure: `Container text_height:` (16) and `text_char_width:` (0.6 em), which decide
how far the last tick of a vertical axis moves inside the plot and which tick labels collide, and `Legend legend_height:` (28). With a font
other than the page's 12 px text, a label can shift by up to half a line. The post-font-load re-measure pass of the original plan was not
built, so these stay assumptions.

## What is different from recharts

The full list is `dev/port/deviations/chart.json`; in prose:

- **No third-party JavaScript.** recharts is not shipped (the maintainer constraint of the sonner port too), so shadcn-port's rule of a pinned JS
  equivalent behind a controller does not apply. recharts also renders an empty wrapper on the server, so the SVG is written by Ruby and the
  numbers (scales, nice ticks, curves, sector paths, bar sizes) are ported to Ruby and checked against the recharts DOM within a thousandth of a pixel.
- **Layout once, no animation.** No responsive re-layout; `is_animation_active:` and the `animation_*` keywords are accepted and ignored, the
  settled state is rendered (the tooltip wrapper keeps its 400 ms transition, switched off under `prefers-reduced-motion`).
- **Callables and named formatters** instead of inline JavaScript functions; React elements as `content:`, `label:` or `tick:` are not supported
  (use the content classes).
- **Parts are declarations** in the block of the chart rather than React children, so their order is the z-order and a part works inside the
  block of the root it belongs to.
- **Validation.** A config key or color that cannot go into the stylesheet raises; React writes it untouched.
- **chadcn additions.** `**attrs` and `class:` on the tooltip and legend wrappers and contents, which React's components do not spread.

Not ported: `Brush`, `ReferenceArea`, `ErrorBar`, `Customized`, `syncId`, `ref` and the mouse and touch callback props; `portal:`, `use_translate3d:`,
`item_style:` and `label_style:` of the tooltip; a radar range (`[low, high]` values), `active_shape:` / `active_bar:` other than `false`, `stack_offset:`
and `hide:` on the polar axes, `tick_count:` of the angle axis; the hover and key mapping for polar charts. `ReferenceLine` *is* ported
(`chart.reference_line(y: 200)`), though the deviations file still lists it as not ported.

## Trying it

`bin/demo` in the repository serves the component catalog of the dummy app, and the pages `/design-system/chart-demo/{bar,line,area,pie,radar,radial}`
render one interactive chart of each family (the pages `test/javascript/chart.test.mjs` drives). The dev kit compares the cartesian and
polar charts, the tooltips and the legends with the React original in a browser, scenario by scenario (`ruby .claude/scripts/shadcn/parity_batch.rb --components chart`).
