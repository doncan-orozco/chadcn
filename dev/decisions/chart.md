# Decision: charts are a Phlex SVG that emits recharts' DOM, with the shadcn layer ported 1:1

Status: proposed by the spike (item #44 of the `chart` epic); the gem items of the epic build it, "As built" at the end records where the build differs.
Proof: `dev/spikes/chart/bar_chart_test.rb` and `line_chart_test.rb` against the committed oracle `dev/spikes/chart/oracle/{bar,line}.html`
(reproducible with `cd dev/react-shadcn-catalog && node ../spikes/chart/oracle_ssr.mjs --check`). Spec: `dev/port/specs/chart.md`. Register entry: `dev/port/deviations/chart.json`.

## Decision

shadcn's `chart.tsx` has two layers: its own (ChartContainer, ChartStyle, ChartTooltipContent, ChartLegendContent, `ChartConfig`, the Tailwind classes) and
recharts (`BarChart`, `XAxis`, `Tooltip`, ... drawn by React). We split them:

- **The shadcn layer is ported 1:1**: `Chadcn::Chart::Container`, `Style`, `Tooltip::Content`, `Legend::Content`, `Config` with the classes of the oracle
  (shadcn-port R1/R2), `data-slot="chart"`, the `--color-<key>` variables from the config, light and dark.
- **recharts is replaced by Phlex SVG that emits the DOM recharts produces** once the browser has settled it: the same `recharts-*` class names, group
  order (z-index layers), attributes and numbers (spec: "recharts DOM contract"). The theme CSS of `chart.tsx` targets those class names
  (`[&_.recharts-cartesian-axis-tick_text]:fill-muted-foreground`, `[&_.recharts-rectangle.recharts-tooltip-cursor]:fill-muted`...), so emitting
  them is what makes the shadcn look appear with no new CSS.
- **The d3/recharts math is ported to Ruby** (plain Ruby, in core, no Rails): recharts' `getNiceTickValues` (not d3 `ticks`/`nice`, see below), linear / band / point
  scales, `stack`, `curveMonotoneX` and the other `d3-shape` curves recharts uses (`natural`, `step`, `basis`, ...), recharts' own `getSectorPath` for pie /
  radial bar / radar, `Rectangle`'s rounded-corner path, tick collision (`getTicks`), bar sizing (`combineAllBarPositions`).
- **Behavior lives only in `chadcn--chart`** (tooltip follow + cursor, the `accessibility_layer` keyboard model, tooltip position, the post-font-load tick
  collision pass), composed from the shared primitives, reading `data-*` attributes the server wrote. No third-party JavaScript, no new importmap pin.

Rejected:

- **A vendored JS engine** (ship recharts + React, or a smaller charting library, behind a controller; shadcn-port R14 as written). It breaks the maintainer
  constraint "no third-party JavaScript" that the sonner port also honors, adds hundreds of KB to every host, and, measured by this spike, does not render on
  the server at all (below), so the first paint would be an empty box and the chart would not exist for Turbo cache previews, email, PDF or no-JS clients.
- **Container-only** (port `ChartContainer`/`ChartStyle`/tooltip/legend content and leave the chart to the host's own JS). It ports the half of the file that
  is a few `div`s and none of the half users come for; there would be nothing to compare against React, and every host would solve layout differently.

## What the spike proved

Environment: recharts 3.8.0, react-dom 19.3, Chromium (Playwright 1.61) for the oracle; Ruby 4.0 / Phlex 2.4 / Nokogiri for the spike. The spike is throwaway; the gem code is written from the spec.
The proof ran on Ruby 4.0 / Phlex 2.4 while the gem floor is Ruby 3.3 / Phlex 2.3: the gem items' own tests (`bundle exec rake test`) prove the floor, the spike proves the DOM and the numbers.

### The oracle cannot be `renderToStaticMarkup`

| Probe | Result |
|---|---|
| `ChartContainer` + `BarChart` / `LineChart` through `react-dom/server` `renderToStaticMarkup` at `initialDimension` | markup of 1333 and 1268 bytes, **0 `<svg>`**: an empty `<div class="recharts-wrapper" width="320" height="200">` |
| `BarChart width=320 height=200` (no ResponsiveContainer) through `renderToStaticMarkup` | the same empty wrapper |
| the same elements with `react-dom/client` in headless Chromium, effects settled | 12.4 KB / 9.0 KB of DOM: grid, bars / curve, axes, tooltip, legend |

Cause: recharts 3 keeps every chart in a redux store that `ReportMainChartProps`, `ReportChartProps`, `SetGraphicalItem`, the axis components and `Legend` fill from
`useEffect` (`node_modules/recharts/es6/state/ReportMainChartProps.js:27-32`, `context/chartLayoutContext.js:190,205`); effects never run in `renderToStaticMarkup`,
so no item is registered and `RechartsWrapper` (`chart/RechartsWrapper.js:323`) renders no children; the `svg` itself is dropped too, because the root surface returns `null` until the chart width and height are positive (`container/RootSurface.js:33-35`). `oracle_ssr.mjs --probe-ssr` prints that measurement.
The deliverable keeps the script's name; its oracle is the settled client render of the same examples with the page pinned for determinism (below). The premise "recharts 3 renders
at `initialDimension` when ResponsiveContainer cannot measure" is true of the container (`component/ResponsiveContainer.js`, the `useState` of `initialDimension`)
and false of the chart inside it.

Determinism of the committed oracle: container fixed at 320x200 (equal to `initialDimension`, so the measured size equals the initial one), `* { font: 12px/16px monospace }` with
`html { font-size: 16px }`, the Tailwind utilities of the legend inlined (recharts subtracts the measured legend height from the plot), `isAnimationActive={false}`, fixed example
ids, and one normalization: the tooltip wrapper's `transform` (positioned from the measured content size) becomes `TOOLTIP_POSITION` and its `recharts-tooltip-wrapper-{left,right,top,bottom}` class modifiers are dropped (both are the controller's output). `--check` regenerates in memory and exits 1 on any
difference (tested by tampering with a committed file). React `useId` values (`recharts-bar-_r_1_`) are deterministic per fresh page but not reproducible by Ruby, so the comparison maps ids by order of appearance.

### The Phlex SVG reproduces the DOM

| Case | Source of truth | Compared | Largest numeric deviation | Tag / class / non-numeric attributes |
|---|---|---|---|---|
| Stacked `BarChart` (2 stacked `Bar` with `radius`, `CartesianGrid vertical={false}`, `XAxis` with `tickFormatter`, `Tooltip defaultIndex={1}` + `ChartTooltipContent hideLabel`, `Legend` + `ChartLegendContent`) | `oracle/bar.html` | 152 numeric attributes (`d` of 12 bars + cursor, `x`/`y`/`width`/`height` of bars, grid, cursor, tick text, `x1`..`y2` of 5 grid lines, `style` lengths) | **0.0 px** | exact (full tree, 0 differences) |
| Monotone `LineChart` (`dot`, `XAxis`, `YAxis`, `CartesianGrid vertical={false}`, `Tooltip cursor={false}`, margin `{left: 12, right: 12}`) | `oracle/line.html` | 140 numeric attributes (curve `d` with 3-decimal rounding, 6 dots `cx`/`cy`, ticks, grid, y labels) | **0.0 px** | exact (full tree, 0 differences) |

Zero is believable, not vacuous: the Ruby float expressions are the same operations in the same order as d3 / recharts (`a * (1 - t) + b * t`, `Math.round` half-up rounding to 4 and
3 decimals), IEEE doubles are identical in Ruby and JavaScript, and the tests assert that a bar one pixel too tall, a renamed class, a swapped tag, a moved Bezier control point or
a changed `text-anchor` are reported. The comparison counts 152 / 140 numeric attributes and the tests print the largest deviation and where it is.

### Where the plan was wrong (measured)

| Assumption in the item | Measured | Consequence |
|---|---|---|
| The numeric axis uses d3 `ticks` / `nice` | recharts 3.8 uses its own `getNiceTickValues` (decimal arithmetic, `cartesian` default `tickCount: 5`, `state/selectors/axisSelectors.js:730-759`, `util/scale/getNiceTickValues.js`). For a max of 305: recharts **0, 80, 160, 240, 320**; d3 `nice(0, 305, 5)` gives **0..350**; for 505 both give 0..600 | the spec ports recharts' algorithm; d3's is documented only as the non-equivalent |
| Bars are positioned by a band scale | the band is only the coordinate of the category; width and offset come from `combineAllBarPositions` (`barCategoryGap` 10 % of the band, `originalSize >> 0` truncates the width to an integer: 41 of 41.33) | ported; a pixel-snapped width is part of the contract |
| Everything is computable on the server | three inputs are **measured by the browser**: text size (`util/DOMUtils.js` `getStringSize`: last y label is moved by half its measured height, 8 px; label collision), the legend box height (`useElementOffset`: 28 px = `pt-3` + one 16 px line; it shrinks the plot), the tooltip size (position, `-top`/`-right` classes) | the server assumes (kwargs `text_height`, `text_char_width`, `legend_height`), `chadcn--chart` re-measures after fonts load; G2 pins the font so both sides measure the same |
| `ResponsiveContainer` re-lays out on resize | the server cannot | recorded deviation: layout once at `initial_dimension` and drawn at that pixel size (fixed `width`/`height` px on `.recharts-wrapper`, as recharts writes it at that container size); the host chooses the size |

Families other than bar and line were probed only for structure (area natural + stacked, pie donut, radar, radial bar, horizontal bar with `LabelList`; recharts 3.8 in the same
page; class names and group order are in the spec). Their numbers (sector arcs, polar grid) were not reproduced here; the items that build them add oracle renders to the same script.

## The G2 contract for charts

Fixed here so every chart item uses the same one (`Compare` in `dev/spikes/chart/compare.rb` is the reference implementation; the gate script is a later item, #47, which moves `Compare` into the harness and deletes the spike then).

- **Tolerance: 1e-3 px**, chosen before measuring. Below a thousandth of a CSS pixel, above float noise (observed 0.0; expected 1e-13 when a value goes through a different
  operation order) and above half of d3-path's 3-digit rounding (5e-4), so a path formatted with a different rounding mode still passes while a 0.01 px drift fails.
- **Numeric attributes** (number by number, the text between the numbers must be identical): `d`, `points`, `x`, `y`, `width`, `height`, `transform`, `x1`, `x2`, `y1`, `y2`, `cx`, `cy`,
  `r`, and the lengths inside `style` (`left`, `bottom`, `width`, `height`). Adding `radius`, `innerRadius`, `outerRadius`, `startAngle`, `endAngle`, `stroke-width`, `rx` etc. for polar charts is a one-line change to this list, made by the item that needs it.
- **Exact**: tag names, element tree and order, text nodes, attribute name sets, every attribute not in the list (class, fill, stroke, role, tabindex, `data-*`, `aria-*`, `text-anchor`, `dy`).
- **Normalized**: `id` values are compared by order of appearance (React ids), and `url(#...)` references go through the same id-order table (`Compare#normalize_references`), so a reference to an id that does not exist on the other side fails; it is not a presence check.
- **Not compared (the controller's output)**: the style and the `-top/-right/-bottom/-left` class modifiers of `.recharts-tooltip-wrapper`; its content is compared.
- **Not compared (Stimulus wiring)**: recharts has neither, so they are exempt from "exact": (a) the attributes that `.claude/scripts/shadcn/parity_run.mjs` already ignores for the wiring (the `data-*` part of `IGNORED_ATTR`, lines 66-69:
  `data-controller`, `data-action`, `data-turbo*`, `data-*-target`, `data-*-value`, `data-*-class`, `data-parity*`, and `data-chadcn--*` through `STIMULUS_PREFIX`; its `class`, `style`, `id` and `aria-*` entries are not wiring and stay compared here), so `data-controller="chadcn--chart"` and
  every `data-chadcn--chart-*-value` (all of them on `div[data-slot="chart"]`, the controller element, the only place Stimulus reads values from), the `data-chadcn--chart-target` of the `svg` and the `data-action` of `.recharts-wrapper` do not count against the attribute-name set; (b) the inert `<template>` children of
  `div[data-slot="chart"]` whose `data-chadcn--chart-target` is `tooltipTemplate` (spec: "Tooltip"; their content is compared once activated, through `.recharts-tooltip-wrapper`) or `tickTemplate` (spec: "Behavior", the tick labels the server hid: recharts omits hidden ticks, so the controller mounts them from the template and never toggles visibility; they are not in the settled recharts DOM). A `<template>` with another target, or not a direct child of the chart root, stays a difference. Everything else under `[data-slot="chart"]` stays exact.
  `Compare` implements this (`STIMULUS_ATTRIBUTE` = `/\A(?:data-controller|data-action|data-turbo.*|data-.*-target|data-.*-value|data-.*-class|data-parity.*|data-chadcn--.*)\z/`, `CHART_TEMPLATES` / `chart_template?`) and tests prove both the exemption (including `data-turbo*`, `data-parity*` and both template targets) and that it is no wider than that.
- **`observe` selectors** (the recharts DOM nodes the scenarios compare; each scenario lists the ones it needs):
  `[data-slot="chart"]`, `.recharts-wrapper`, `.recharts-surface`, `[class^="recharts-zIndex-layer_"]` (group order), `.recharts-cartesian-grid-horizontal line`,
  `.recharts-cartesian-grid-vertical line`, `.recharts-cartesian-axis`, `.recharts-cartesian-axis-tick-value` (text and `tspan`), `.recharts-bar-rectangle path`,
  `.recharts-tooltip-cursor`, `.recharts-curve` (line / area), `.recharts-line-dot`, `.recharts-area-dot`, `.recharts-sector`, `.recharts-polar-grid`, `.recharts-polygon`,
  `.recharts-radial-bar-sector`, `.recharts-pie-sector`, `.recharts-legend-wrapper` (and its content), `.recharts-tooltip-wrapper` (content only), `.recharts-label`.
- **Pinned page**: the same CSS as `oracle_ssr.mjs` (12px/16px, `html` 16px) on both sides, container `width x height` = `initial_dimension`, animation off.
  **Amendment (item #48, 2026-10-28):** this holds for the committed oracle (`oracle_ssr.mjs`). The G2 parity page is the shared runner page and is not font-pinned, so recharts measures a tick label 18px high there; the Phlex harness renders `ChartContainer` with `text_height: 18` (`ShadcnParity::ChartScope::PAGE_TEXT_HEIGHT`) and the gem default stays 16, locked by `test/chadcn/chart/cartesian/text_height_test.rb`. Pinning the runner page for chart scenarios (both sides) removes the assumption; it edits the shared gate, so it is a follow-up.

## Alternatives considered

- **Build the SVG in the browser** with a small hand-written engine (the same math in JavaScript, no server render): no first paint without JS, two implementations of the layout when
  the Ruby side is needed anyway for Turbo Stream renders; the math would still have to be tested against recharts, which Ruby can do without a browser (testing R18).
- **Server render through a Node sidecar running recharts**: renders empty (measured) and needs Node at runtime in a gem for Rails and plain Ruby apps.
- **Per-chart ad-hoc SVG without recharts' class names**: loses the `chart.tsx` selectors (the theme would need duplicate CSS), and nothing left to compare with the oracle.
- **Re-layout the chart in the controller on resize** (port `getTicks`, bar sizing, scales to JS as well): doubles the math; deferred. The deviation (layout once at `initial_dimension`) is recorded and
  the container takes the layout size as a kwarg; a later item may add the JS pass without changing the DOM contract.

## Risks

- **Text measurement** is the one input Ruby cannot know. Mitigation above; a font that is not the pinned one can show a different label shift (<= half a line), or keep a label the measured font would collide (or ship in a `tickTemplate` a label it would fit) until the controller's post-font pass remounts the right set; the pass swaps nodes from templates, it never toggles visibility, because recharts omits hidden ticks and G2 compares the tree exactly. `oracle_ssr.mjs --check` and the spike tests depend on the host's `monospace` font for the x-label widths (a different default monospace can move a clamped label): the drift alarm assumes the same machine class that committed the oracle.
- **Page weight of the tooltip templates**: one `Tooltip::Content` template per category, about 1.7 KB at two series (1,247 bytes of content in `oracle/bar.html` plus the `data-*` attributes), linear in categories and series; no cap in the gem (a `Tooltip` is optional).
- **recharts moves**: the oracle is pinned by `dev/react-shadcn-catalog/package-lock.json` (3.8.0); a bump regenerates `oracle/*.html` and the diff is the review. `oracle_ssr.mjs --check` is the drift alarm.
- **Size of the port** (six chart families, curves, sectors): bar and line cost about 600 lines of throwaway Ruby with all numerics exact; the families that remain reuse scales, ticks, curves and the shell.
- **Ruby floats vs JavaScript numbers**: identical doubles; the formatter (`Num.js`) covers the integer / shortest-repr cases; exponent notation (JS prints `1e-7` differently) raises in the spike and is a case for the gem's formatter.
- **Rational arithmetic** replaces `decimal.js-light` in `getNiceTickValues`; verified on two domains here, to be property-tested against the JS implementation over many domains by the ticks item.

## Not blocked

The split works: server-rendered DOM equal to recharts' within 0.0 px for the two hardest layouts (stacked rounded bars with legend and tooltip, monotone line with a y axis), a fixed gate contract and
a reproducible oracle. The only things a human must accept are the recorded deviations in `dev/port/deviations/chart.json` (R14 not followed, layout once at `initial_dimension`, no animation, named formatters in JSON scenarios,
server-assumed text metrics) and the choice of the oracle (settled client render in Chromium, because server rendering is empty).

## As built

Each gem item of the `chart` epic records here where the build differs from this record.

### Item #49: the polar charts (`PieChart`, `RadarChart`, `RadialBarChart`)

- **Reuse over rewrite.** The polar axes do not re-implement domains, nice ticks and scales: `Polar::Axis` wraps the cartesian axis resolution (recharts' polar
  selectors are the same functions as the cartesian ones, `state/selectors/polarAxisSelectors.js`), mapping the angle axis to its `x` and the radius axis to its `y`
  with the polar differences (no nice ticks on the angle axis, no stacks in the domain, the tick shifts). The bar positions of a radial bar are the cartesian
  `BarPositions` over the radius band. The tooltip wrappers and the templates are the cartesian `Overlays` and `TooltipTemplates`; `Polar::Overlays` only replaces the
  legend payload (a pie lists its sectors) and `Polar::TooltipPlan` extends the cartesian plan. The cartesian files stay as they were, with one exception:
  `Overlays#legend_items` was extracted from `#legend_content` so a subclass can supply the payload. A follow-up could move `Overlays`, `TooltipTemplates`, `Scope`,
  `Choice`, `Value`, `Text` and `Formatter` out of `Chart::Cartesian` (they are not cartesian).
- **Drawing is split per family** (`Polar::Drawer::Pie`, `PieLabels`, `Radar`, `RadialBar`, `Grid`, `AngleAxis`, `RadiusAxis`, `LabelList`, `Label`), each a
  `Phlex::SVG` component that says which z-index layers it draws in (`LAYERS`); `Polar::Surface` is only the frame: the layers in order, the clip path and the
  things recharts leaves in place (an empty pie) after it. This answers the criticism of the 669-line cartesian `Surface`.
- **Probes.** Every behavior beyond the nine `polar__*` scenarios (labels, label lines, cells, classes, hidden and empty series, clockwise and half circles, padding
  and corner radii, min point size, stacks, legend, default index, axis options, numeric angle axis) was compared with the oracle DOM, line by line, with scratch
  scenarios that were not committed (`scenarios/chart.json` is not this item's to edit); the committed tests carry the resulting values.
- **Quirks kept on purpose** (they are recharts' DOM): the `undefined` class suffix of a radial bar sector; `class:` of an axis replacing the class of its line and
  tick lines; `class:` of a pie landing on every sector; the default-index anchor of a radar or radial bar tooltip (x the middle of the chart, y the tick's angle or
  radius); a radial bar with no data still drawn as its two empty groups; the empty pie written in place after the clip path.
- **Not ported**, see `deviations/chart.json`: radar ranges, `active_shape`, the polar tooltip cursor and item tooltips of a radial bar chart, the hover mapping of
  `chadcn--chart` for polar charts, `stack_offset`, `hide:` and children of the polar axes, `tick_count:` of the angle axis.
