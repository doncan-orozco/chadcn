# Decision: charts are a Phlex SVG that emits recharts' DOM, with the shadcn layer ported 1:1

Status: proposed by the spike (item #44 of the `chart` epic); built by the items #45 to #51, #63, #73 and #85 of the epic, the "As built" section at the end records where the build differs from this proposal.
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
  **Amendment (item #48, 2026-10-28):** this holds for the committed oracle (`oracle_ssr.mjs`). The G2 parity page is the shared runner page and is not font-pinned, so recharts measures a tick label 18px high there; the Phlex harness renders `ChartContainer` with `text_height: 18` (`ShadcnParity::TreeRenderer::PAGE_TEXT_HEIGHT`) and the gem default stays 16, locked by `test/chadcn/chart/cartesian/text_height_test.rb`. Pinning the runner page for chart scenarios (both sides) removes the assumption; it edits the shared gate, so it is a follow-up.

## Alternatives considered

- **Build the SVG in the browser** with a small hand-written engine (the same math in JavaScript, no server render): no first paint without JS, two implementations of the layout when
  the Ruby side is needed anyway for Turbo Stream renders; the math would still have to be tested against recharts, which Ruby can do without a browser (testing R18).
- **Server render through a Node sidecar running recharts**: renders empty (measured) and needs Node at runtime in a gem for Rails and plain Ruby apps.
- **Per-chart ad-hoc SVG without recharts' class names**: loses the `chart.tsx` selectors (the theme would need duplicate CSS), and nothing left to compare with the oracle.
- **Re-layout the chart in the controller on resize** (port `getTicks`, bar sizing, scales to JS as well): doubles the math; deferred. The deviation (layout once at `initial_dimension`) is recorded and
  the container takes the layout size as a kwarg; a later item may add the JS pass without changing the DOM contract. Measured and decided in
  "Resize and re-measure" below: a server re-layout at the measured size instead.

## Risks

- **Text measurement** is the one input Ruby cannot know. Mitigation above; a font that is not the pinned one can show a different label shift (<= half a line), or keep a label the measured font would collide (or ship in a `tickTemplate` a label it would fit) until the controller's post-font pass remounts the right set; the pass swaps nodes from templates, it never toggles visibility, because recharts omits hidden ticks and G2 compares the tree exactly. Superseded by "Resize and re-measure" below: the server re-lays out with the measured metrics; there is no template pass. `oracle_ssr.mjs --check` and the spike tests depend on the host's `monospace` font for the x-label widths (a different default monospace can move a clamped label): the drift alarm assumes the same machine class that committed the oracle.
- **Page weight of the tooltip templates**: one `Tooltip::Content` template per category, about 1.7 KB at two series (1,247 bytes of content in `oracle/bar.html` plus the `data-*` attributes), linear in categories and series; no cap in the gem (a `Tooltip` is optional).
- **recharts moves**: the oracle is pinned by `dev/react-shadcn-catalog/package-lock.json` (3.8.0); a bump regenerates `oracle/*.html` and the diff is the review. `oracle_ssr.mjs --check` is the drift alarm.
- **Size of the port** (six chart families, curves, sectors): bar and line cost about 600 lines of throwaway Ruby with all numerics exact; the families that remain reuse scales, ticks, curves and the shell.
- **Ruby floats vs JavaScript numbers**: identical doubles; the formatter (`Num.js`) covers the integer / shortest-repr cases; exponent notation (JS prints `1e-7` differently) raises in the spike and is a case for the gem's formatter.
- **Rational arithmetic** replaces `decimal.js-light` in `getNiceTickValues`; verified on two domains here, to be property-tested against the JS implementation over many domains by the ticks item.

## Not blocked

The split works: server-rendered DOM equal to recharts' within 0.0 px for the two hardest layouts (stacked rounded bars with legend and tooltip, monotone line with a y axis), a fixed gate contract and
a reproducible oracle. The only things a human must accept are the recorded deviations in `dev/port/deviations/chart.json` (R14 not followed, layout once at `initial_dimension`, no animation, named formatters in JSON scenarios,
server-assumed text metrics) and the choice of the oracle (settled client render in Chromium, because server rendering is empty).

## Resize and re-measure

Status: proposed by the spike of item #96 (`review-gaps` epic), 2026-11-10; merging this section approves the mechanism. Proof:
`dev/spikes/chart-resize/run.rb` (command and numbers in its [README](../spikes/chart-resize/README.md)). Contract: `dev/port/specs/chart.md`,
"Behavior", "Resize and re-measure". It replaces the "Re-layout the chart in the controller on resize" alternative above (deferred then) and the
tick-template design of the re-measure pass (spec "Behavior" as written by #44, never built).

### The question

What ships in 0.1.0 is laid out once at `initial_dimension` (320x200) and drawn at that pixel size, with assumed text metrics
(`text_height:` 16, `text_char_width:` 0.6em, `legend_height:` 28). recharts' `ResponsiveContainer` re-lays out on every resize and measures
its text in the DOM (`util/DOMUtils.js` `measureTextWithDOM`, `useElementOffset` for the legend). Two things are missing: following the size
of the container, and correcting the text metrics.

### Options and measurements

The spike draws the stacked bar and the monotone line of the first spike with the gem and with recharts 3.8.0 (Chromium), in 16:9 containers
of 320x180, 560x315 and 800x450, in the pinned oracle font (`12px/16px monospace`) and in a host font (`12px sans-serif`), and compares the DOM
(G2 `Compare`, exact tree, 1e-3 px) and the on-screen boxes.

| Option | DOM against recharts at the container's size | On screen | Cost |
|---|---|---|---|
| Today (`fixed`) | 47 to 120 differences | up to 480 px off; overflows a smaller box | nothing |
| **A. Scale the SVG** (`viewBox` is already on the `svg`; `.recharts-wrapper` and the inner div of the responsive container at 100%) | 48 to 121 differences (it still holds the 320x200 numbers) | glyphs at 0.90x, 1.57x, 2.25x (a 12 px label drawn 27 px high at 800 px); letterboxed outside 16:10; the HTML legend and tooltip keep their 320 px layout | 0 bytes, 0 ms, CSS only |
| **B. Re-layout in `chadcn--chart`** (port scales, ticks, paths, bar positions, tick collision to JavaScript) | 0 (same math: the `relayout` rows of the spike are its output) | 0 px | 3,129 lines of size-dependent Ruby to port (out of 5,404) against 342 lines of chart JavaScript today, plus a parity proof of the JavaScript against the Ruby; about recharts' own 28-38 ms per resize (an upper bound, frame-quantized) |
| **C. Server re-render at the measured size** | 0 with the default metrics in the pinned font; 0 in the host font **once the measured metrics are sent along** (58 differences without them: a 26 px legend instead of 28 moves every bar 2 px) | 0 px | 1.2 to 3.7 ms of gem rendering, 18 to 28 KB of HTML (2.5 to 3.2 KB gzipped) per re-layout, plus one request to the host and its round trip; the host must answer that request |

### Decision

- **Resize: C, opt-in per container, with A as the interim state.** A container given a `relayout_url:` re-lays itself out at the size of its
  box: `chadcn--chart` observes the element's size, waits until it has been stable for a moment (debounce), skips the request when the size
  (rounded to whole pixels) and the metrics equal what the server drew, requests the chart from the URL with the measured size and metrics as
  query parameters, and replaces the chart with the one of the same `data-chart` id in the response. While a request is pending the chart is
  scaled with its `viewBox` (A, CSS only), so it never overflows and never flashes empty. The host answers by rendering the same chart with the
  parameters, read through one helper of the container; any GET that returns the chart works (a dedicated action, or the page itself, of which
  the controller takes only the chart). Chosen because it is exact, it reuses the one implementation of the layout that G2 already proves, and it
  covers the six chart roots (cartesian and polar) at once; its price is a request per settled resize and a host that answers it.
  **C needs a recorded exception to `stimulus` R1 (a controller never fetches HTML) and R6 (targets over selectors):** `chadcn--chart` fetches
  HTML from the same-origin `relayout_url:` and swaps it in, and reads the tick labels, the legend wrapper (recharts nodes) and the response's
  chart by class selector. The exception is scoped to `chadcn--chart` fetching its own chart from its same-origin `relayout_url:` and swapping
  it; nothing else may fetch HTML or read by class. Merging this section approves the exception; item #107 records it in
  `.ai/skills/stimulus/SKILL.md` (scope, guard, removal condition).
- **Without `relayout_url:`** nothing changes: the chart is laid out once at `initial_dimension`, as in 0.1.0, and draws on a page without
  JavaScript, in a Turbo preview, an email or a PDF. The deviation "layout once at `initial_dimension`" is narrowed to charts without a URL,
  not removed.
- **Re-measure: the same request.** After `document.fonts.ready` (and on connect) the controller measures what recharts measures, the way it
  measures it: a `white-space: pre` span under `body` for the height of a line of tick text and the average glyph width of the tick labels,
  and the box of `.recharts-legend-wrapper`. When they differ from the metrics the server drew with, it requests the re-layout like a resize
  does (one request covers both). The server computes which tick labels exist, their positions and the plot area from the measured metrics, so
  the tick templates, the browser collision pass and the "the plot is not recomputed when the legend height differs" deviation of the first
  design are dropped; the `tickTemplate` exemption of G2 above becomes unused (left in `Compare` until the gate code is next edited). Without a
  URL the server's assumptions stay, and the kwargs stay the host's way to match its font.
- **Rejected: B.** Exact as well, and no request, but it is a second implementation of the layout: 3,129 lines of Ruby to port against 342 lines of chart JavaScript today,
  every recharts quirk the Ruby reproduces would need a JavaScript twin and a proof that both agree, and every later chart item would pay
  twice. It stays the fallback if the maintainer rules that charts must follow their container with no host work; the measurements above are
  its baseline.
- **Rejected as the mechanism: A.** It zooms instead of re-laying out (text scales with the box, the legend does not follow) and leaves the DOM
  at the 320x200 numbers. Kept only as the interim state of C.

### What stays a deviation

- Charts without `relayout_url:` (above), and every chart before its first re-layout and without JavaScript.
- Label width is estimated as length times the measured average glyph width; recharts measures each string. In `12px sans-serif` the estimate
  is off by up to 2.5 px for one month label, which changes nothing at the measured sizes, but a label within that margin of the collision
  threshold can be kept or dropped differently in a proportional font.
- Between a resize and the response the chart is the scaled previous layout (A), where recharts re-lays out in the next frames; the tooltip
  and keyboard state carry over the swap (spec), an in-flight request is aborted by the next resize and by disconnect.

### The follow-up items keep their split

- **#107 (chart-responsive)** builds the resize half: the `relayout_url:` kwarg and the values of the spec, the size observation, the
  debounce, the skip when nothing changed, the request, the swap with the interaction state carried over, the interim viewBox scaling, abort
  on disconnect, the Turbo cache, and the helper that turns the parameters into container keywords, and it records the `stimulus` R1 and R6
  exception of C in `.ai/skills/stimulus/SKILL.md` (amend its `owns` to include that file). Amend its acceptance: "a chart in a
  container resized from 320 to 640 px" applies to a chart with `relayout_url:` (the browser test answers the request with the gem's markup,
  e.g. through Playwright request interception, so no dummy route is needed); "the deviation is removed or narrowed" is "narrowed to charts
  without a URL".
- **#108 (chart-remeasure)** builds the re-measure half on top of it: the measurement after `document.fonts.ready`, the metrics in the request,
  `legend_height` taken from the request by the container. Amend its goal: the pass does not "correct what the server assumed" in the browser,
  it measures and asks the server to re-lay out; its acceptance stands as written for charts with `relayout_url:`, and "the re-measure pass is
  not built" sentences become "re-measure needs `relayout_url:`".

## As built

Each gem item of the `chart` epic records here where the build differs from this record. The first section is the whole epic (items, deviations, follow-ups), written by item #51; the sections after it are the items' own notes.

### The epic as built (item #51)

Items (GitHub issue numbers; the PRs are in each issue's `shared` note):

| Item | What landed |
|---|---|
| #44 | This record, the SSR spike and the committed oracle, the manifest, `dev/port/specs/chart.md` and the deviation register `dev/port/deviations/chart.json` |
| #45 | The shadcn layer: `Chart::Container`, `Style`, `Config`, `Tooltip` / `Tooltip::Content`, `Legend` / `Legend::Content`; `Chart` became a registered component (61 roots) |
| #46 | The private math in `lib/chadcn/chart/scale/**` and `shape/**` (linear, band and point scales, recharts' nice ticks, curves, sectors, stacks), with `THIRD_PARTY_NOTICES.md` |
| #47 | The parity harness: recharts registered in `Harness.tsx`, `dev/port/scenarios/chart.json` (57 scenarios), the numeric tolerance (1e-3) and `--only` in the gates |
| #48 | `BarChart`, `LineChart`, `AreaChart` and their parts (`Declaration` / `Declarations`), the Phlex side of the parity mapping (first in `dev/parity/lib/shadcn_parity/chart_scope.rb`, moved by #51 to `lib/chadcn/catalog/chart_scope.rb`), the tooltip templates |
| #49 | `PieChart`, `RadarChart`, `RadialBarChart` and the polar grid and axes |
| #50 | The `chadcn--chart` controller and the primitives `chart_pointer`, `chart_shapes`, `chart_tooltip_placement` |
| #63 | Tooling: the static gate reads nested parts and helper-function props, `work_board.rb item amend` |
| #73 | The catalog generator leaves out an entry whose preview uses harness-only nodes |
| #85 | Integration fix of #49 and #50: the polar charts publish the controller wiring |
| #51 | `docs/charts.md`, the README section, the CHANGELOG, the generated llms files, this section; the chart mapping moved into the gem (`Chadcn::Catalog::ChartScope`), the chart catalog entry, the standalone `parts__*` nodes |

Where the build differs from the proposal:

- **The post-font-load re-measure pass was not built** by this epic (the Decision's fourth bullet and the Risks paragraph describe it). The
  controller did not re-measure tick labels, the legend or the tooltip, there is no `tickTemplate`, the axes do not write a `value` for it, and
  the legend has no controller target. The server's assumptions (`Container text_height:` 16, `text_char_width:` 0.6, `Legend legend_height:` 28)
  stayed assumptions; the G2 gate pins them to the page (below). Superseded: the re-measure was built later as a re-layout request (item #108
  of the `review-gaps` epic, "Resize and re-measure" and its As built note); it needs `relayout_url:`.
- **`chadcn--chart` as built**: `Container` is always the controller element and carries 20 values (`layout`, `keyboardStep`, `accessibilityLayer`,
  `ticks`, `plot`, the four interaction states, `defaultIndex`, `tooltipEventType`, `trigger`, `tooltipActive`, `offset`, `allowEscape`,
  `reverseDirection`, `position`, `transition`, `transitionAuto`, `wrapperStyle`); the part wiring is `Cartesian::Wiring`. The controller handles
  axis tooltips only. An item tooltip (`shared: false` on a `BarChart` or a `RadialBarChart`, a pie) is not driven (a `LineChart`, `AreaChart` or `RadarChart` allows `axis` only, so `shared: false` keeps the axis tooltip: recharts 3.8.0 `state/selectors/selectTooltipEventType.js:4-13`, `chart/LineChart.js:5`, `chart/AreaChart.js:5`, `chart/RadarChart.js:11`): the controller is inert and the
  server-drawn tooltip is left alone, and no item-tooltip rendering exists (no templates, a hidden empty wrapper). The polar charts publish their values and no action (#85). A chart outside
  a `Container` is not wired.
- **`ReferenceLine` is implemented** although the spec and the deviations register (`api`, "Brush, ReferenceLine, ... are not ported") list it as not
  ported; `ReferenceArea`, `ErrorBar` and `Brush` are not. The register line is stale.
- **The G2 page is not font-pinned for charts** (amendment of item #48 above): the harness renders `ChartContainer` with `text_height: 18`
  (`ShadcnParity::TreeRenderer::PAGE_TEXT_HEIGHT`). Pinning the shared runner page for chart scenarios, on both sides, removes the assumption and is a follow-up.
- **Naming.** The roots keep the `Chart` suffix (`Chart::BarChart`), because `Chart::Bar` is the series; recorded in the register (naming exception, open
  for the maintainer). The yielded-root helpers of the declarations are `x_axis` / `y_axis` on the chart roots (`Chart::Declarations`), while the
  generated helpers of `Chadcn::Chart` itself, made by `Base.const_added`, are `xaxis` / `yaxis` (it splits only at a lowercase-then-uppercase boundary).
- **The chart mapping lives in the gem (item #51).** The first build left chart out of the catalog: the parity harness alone resolved the `_BarChart`
  nodes (`ShadcnParity::ChartScope`), so the generator (#73) skipped the entry. #51 moved the mapping (`RECHARTS_PARTS`, the content and formatter revival,
  the SVG nodes) to `Chadcn::Catalog::ChartScope`, prepended by `Chadcn::Catalog::TreeRenderer`; the harness keeps only its page text height
  (`ShadcnParity::TreeRenderer::PAGE_TEXT_HEIGHT`) and its stubs. The generator treats the recharts parts as renderable, so `entries.json` has the chart
  entry (`cartesian__bar-default`, 57 scenarios), and `ChartTooltipContent` / `ChartLegendContent` also resolve as nodes of their own, which turned
  the `parts__*` scenarios green: `parity_batch.rb --components chart` passes as a whole.

Follow-ups left open (none is owned by an item):

- **The reconnect helpers** of `test/javascript/hover_card.test.mjs` and `turbo_overlays.test.mjs` hold a promise pending across the disconnect, which V8
  can collect and Playwright reports as "Execution context was destroyed"; `calendar.test.mjs` had the same defect and #50 fixed it. They do not fail today.
- **The font pin** of the parity runner page for chart scenarios (above).
- **Hoisting** `Overlays`, `TooltipTemplates`, `Scope`, `Choice`, `Value`, `Text` and `Formatter` out of `Chart::Cartesian`, and a `Polar::Root` /
  `Cartesian::Root` hoist (#49).
- **Not ported**, from the register: item and `active_shape` tooltips of a radial bar chart, the hover mapping of polar charts, radar ranges,
  `stack_offset` and `hide:` on the polar axes, the polar scenario matrix (an oracle item).

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

### Item #107: the resize half of "Resize and re-measure" (`review-gaps` epic)

Built as the Decision above says (option C, opt-in with `relayout_url:`, A as the interim state); where the build is more precise:

- **The values exist only with a URL.** `relayoutUrl`, `dimension` and `textMetrics` are written on the container only when it has a
  `relayout_url:`, so a container without one renders byte for byte what 0.1.0 rendered (`test/chadcn/chart/container_relayout_test.rb`).
  The chart roots hand their legend box height to the container (`publish_legend_height`) for `textMetrics`.
- **`relayout_options` does not read `chart[legend_height]` yet** (read since #108): the container has no `legend_height:` keyword until #108, and a key
  it does not take would break the splat. The request already carries it when the chart has a legend.
- **Bounds and errors** (the open advisory of #96): a box under 1 px or over 4096 px is never requested and stays scaled into its box;
  `relayout_options` drops a value outside its bound or not written as a plain decimal number; a cross-origin `relayout_url:` is never
  requested (`relayout-error` with status 0); an error answer keeps the scaled chart and stops re-layout until the element reconnects.
- **The interim scaling starts with the first size that differs from `dimension`**, before the debounce, and stays after an error
  answer; `turbo:before-cache` removes it with the request, the restore observes the box again. No request leaves a Turbo preview.
- **Proof.** G2 compares the server render at 320, 480 and 640 px (`resize__bar-*`, `resize__pie-*` scenarios). The browser test
  (`test/javascript/chart_resize.test.mjs`; the lifecycle in `chart_resize_lifecycle.test.mjs`, apart from `chart.test.mjs` to keep each file within node:test's per-file timeout on CI) answers the request with the Phlex parity page at the requested width and compares the
  swapped chart with recharts resized in the browser from 320 to 480 and 640 px (bar) and to 640 px (pie), under G2's rules: 0 differences.
  The stimulus R1/R6 exception is recorded in `.ai/skills/stimulus/SKILL.md` ("Recorded exception: the chart re-layout").

### Item #108: the re-measure half of "Resize and re-measure" (`review-gaps` epic)

Built as the Decision above says (the same request as the resize, `relayout_url:` needed); where the build is more precise:

- **The measurement** is `app/javascript/chadcn/primitives/chart_measure.js`: each `.recharts-cartesian-axis-tick-value` label in recharts'
  `white-space: pre` span under `body`, at the font size and letter spacing of the first tick's computed style (recharts reads both from the
  tick, `cartesian/CartesianAxis.js`, the font family is the body's in both), rounded to 4 decimals; the legend box of
  `.recharts-legend-wrapper`. A chart without tick labels (a pie) keeps the served text metrics. The controller measures on every settled
  size, after `document.fonts.ready`, and sends the measured metrics with every request, so one request covers a resize and a font.
- **`Chart::Container legend_height:` wins over `Legend legend_height:`** (the spec first said the opposite): the request carries what was
  measured, and the other order would re-request forever when a `Legend` sets `legend_height:`. A numeric `Legend height:` still wins over
  both (the box has that height). The cartesian and polar `ChartSettings` carry it to the layouts (`legend_box_height`).
- **One metrics request per size** (`measuredAt`, written by `swap` on every answer): a host that
  ignores the metrics, or a label subset that flips the average glyph width between two layouts, costs one request, never a loop. Every
  answer carries it (each request sends the metrics measured after the fonts loaded); a resize still requests, so one change costs one
  request; what the new layout would measure differently (a legend that wraps at the new width, another tick subset) waits for the next
  change.
- **Proof.** `test/javascript/chart_remeasure.test.mjs` (its own file for CI's per-file timeout) opens a host action of the dummy app,
  `chart_relayouts#show`, which renders a parity scenario with `relayout_options(params)` like an application; in a font with 14 px lines
  and 14 px letter spacing (a 26 px legend, glyphs 1.77 em wide, every other month label dropped) the swapped `legend__bottom` chart equals
  recharts in the same font under G2's rules (0 differences), the same page without the re-measure differs, a page laid out at the measured
  metrics sends nothing, a pie (no ticks, no legend) sends nothing, and a host that ignores the metrics gets exactly one request. The
  resize tests (`chart_resize*.test.mjs`) write the page's measured metrics as the served ones, so they stay about the size.
