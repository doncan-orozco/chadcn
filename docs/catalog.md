# Catalog

`Chadcn::Catalog` is a ready-made example of every ported component, for a host that wants a component gallery page ("design
system" page, living style guide). Each entry holds one representative example as a JSON tree, and
`Chadcn::Catalog::TreeRenderer` renders that tree with the real components. The examples are generated from the same scenarios the
1:1 parity gates check, so a gallery built on them cannot drift from the components, and a new component shows up on the next
release without the host doing anything.

The catalog is plain Phlex and loads only when used: it needs no Rails, no `dev/` directory and no extra gems.

## A gallery page

In the `view_template` of any Phlex view:

```ruby
Chadcn::Catalog.entries.each do |entry|
  section(id: entry.component) do
    h2 { entry.title }
    render Chadcn::Catalog::TreeRenderer.new(tree: entry.tree, component: entry.component)
  end
end
```

In a Rails app, render it from a controller like any Phlex view. The components need the engine's assets (Tailwind `@source`, the
importmap pins) exactly as everywhere else; see the README.

## API

- `Chadcn::Catalog.entries` returns the entries sorted by component name (a new Array per call).
- `Chadcn::Catalog.find(component)` returns the entry of one component (`"dialog"`, `:button_group`) or `nil`.
- `Chadcn::Catalog::Entry` has `component` (`"button-group"`), `title` (`"Button group"`), `scenario_id`, `scenario_count` (how many
  scenarios the parity gates run for the component) and `tree`. Entries and trees are frozen.
- `Chadcn::Catalog::TreeRenderer.new(tree:, component: nil, dx: nil)` is a Phlex view. `component:` names the root the tree belongs to,
  so a part name that exists on several roots resolves against it first. `dx: "helpers"` renders nested parts through the yielded root.
  It raises `Chadcn::Catalog::TreeRenderer::Error` for an unknown component or a malformed node, so a gallery should rescue per entry
  and keep rendering the rest.

## The tree format

A node is `{ "c" => name, "props" => {...}, "children" => [...] }`:

- `c` is a component name: `"Button"` is `Chadcn::Button`, `"DialogTrigger"` is `Chadcn::Dialog::Trigger` (the root prefix is
  stripped). `c` starting with `_` and a lowercase letter (`"_div"`, `"_a"`) is a raw HTML element, except `"_defs"`, `"_linearGradient"`, `"_radialGradient"` and `"_stop"`: inside a chart those are
  SVG elements (a gradient for an area), drawn in the chart's `<svg>`. Their props keep React's spelling (`gradientTransform`), except
  `stopColor` / `stopOpacity`, which are written `stop-color` / `stop-opacity` (and `className`, `class`); any other SVG tag raises.
- `props` use the React names: `className` is `class`, camelCase is snake_case, `data-*` and `aria-*` stay.
- `children` are nodes or strings. A string starting with `<icon:name>` renders that icon, the rest is text.
- `"asChild": true` makes the single child node the `as_child:` instance and its children the content.
- `{ "c": "_Each", "children": [...] }` renders its template once per element the parent yields; `"$item"` and `"$item.path"`
  in a string become that element. Used by `Combobox`.
- `c` starting with `_` and a capital letter is a node of the test harness, except the recharts parts of a chart (`"_BarChart"`, `"_Bar"`,
  `"_XAxis"`...), which are `Chadcn::Chart::BarChart`, `Chadcn::Chart::Bar`, `Chadcn::Chart::XAxis`...; `"ChartTooltipContent"` and
  `"ChartLegendContent"` are the chart's tooltip and legend content (as a `content` prop of `ChartTooltip` / `ChartLegend`, or as a node of
  their own), and a prop `{ "formatter": "slice", "args": [0, 3] }` is the named formatter of the chart classes.
- Prop strings `"$ref:<css selector>"`, `"$date:YYYY-MM-DD"` and `"$locale:es"` become the selector, the ISO date string and the
  locale tag.

## Where the data comes from

`lib/chadcn/catalog/entries.json` (about 40 KB, packaged with the gem) holds the first light default scenario of each component, without
the probe nodes the browser harness adds. It is generated from `dev/port/scenarios` by the repository, never edited by hand:

```bash
bundle exec rake catalog:generate   # after changing a scenario
bundle exec rake catalog:check      # fails when the committed file drifted (also part of rake test)
```

The full scenario files (variants, states, interactions) stay in the repository's dev kit and are not packaged.
