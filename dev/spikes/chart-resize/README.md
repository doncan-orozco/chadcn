# Spike: how a server-drawn chart follows its container

Question (board item #96 of the `review-gaps` epic): `Chadcn::Chart` is laid out once at `initial_dimension` (320x200) and drawn at that
pixel size, with the text metrics the server assumes (`text_height:` 16, `text_char_width:` 0.6em, `legend_height:` 28). recharts'
`ResponsiveContainer` re-lays out on every resize and measures its text in the DOM. Which mechanism should make the port do the same,
and what does each cost? The decision is in [dev/decisions/chart.md](../../decisions/chart.md), section "Resize and re-measure"; the
contract in [dev/port/specs/chart.md](../../port/specs/chart.md), "Behavior". The spike is throwaway: the gem code is written from the spec.

## Run it

```bash
(cd dev/react-shadcn-catalog && npm ci)      # esbuild, react, recharts 3.8.0, playwright; Chromium from `npx playwright install chromium`
env -u BUNDLE_GEMFILE LANG=en_US.UTF-8 bundle exec ruby -Ilib dev/spikes/chart-resize/run.rb
```

About 30 seconds. It prints the tables below and leaves the rendered markup in `tmp/chart-resize/` (ignored): `oracle.json` (recharts per
chart, font and size), `phlex/*.html` (the gem's markup per option) and `phlex.json` (their on-screen boxes).

## What it does

- **Charts**: the two examples of the first chart spike, [`../chart/examples.tsx`](../chart/examples.tsx) (stacked `BarChart` with grid, x
  axis, legend and a `default_index` tooltip; monotone `LineChart` with dots and a y axis), written with the gem in [`examples.rb`](examples.rb).
  At 320x200 the gem's markup equals the committed `../chart/oracle/{bar,line}.html` (0 differences, 152 and 140 numeric attributes; the first lines `run.rb` prints).
- **Sizes**: three containers in the 16:9 ratio of `ChartContainer`'s `aspect-video`: 320x180, 560x315, 800x450.
- **Fonts**: `mono` is the pinned page of the chart oracle (`12px/16px monospace`, the font the server's defaults describe); `sans` is a host
  font (`12px sans-serif`, line height `normal`), whose metrics differ from the defaults.
- **Oracle** ([`browser.mjs`](browser.mjs) `oracle`): recharts 3.8.0 with shadcn's `ChartContainer` in headless Chromium, settled, at each
  size and font. It also measures the text the way recharts does (`util/DOMUtils.js` `measureTextWithDOM`: a `white-space: pre` span under
  body), the legend box, and the time recharts itself takes to settle again after its container goes from 320x180 to the larger sizes (an upper bound: the
  spike polls by frames, so it is quantized).
- **Options**, rendered by [`run.rb`](run.rb):
  - `fixed`: what ships in 0.1.0, laid out at 320x200 and drawn at that pixel size in whatever box it gets.
  - `viewbox`: the same markup with `.recharts-wrapper` and the inner `width: 0px; height: 0px; overflow: visible` div of the responsive container (the
    outer shell div is already at 100%) at 100% of the container. The `svg` already carries
    `viewBox="0 0 320 200"` and `width/height: 100%`, so it scales uniformly (`xMidYMid meet`), text included; the HTML legend and tooltip
    keep their pixel positions. A CSS-only change.
  - `relayout`: laid out again at the container's size with the default metrics. This is the markup a server re-render at the measured size
    returns, and the markup a JavaScript port of the layout in `chadcn--chart` would have to produce (the same math: its DOM result is this
    row; its cost is the code to port, measured below).
  - `measured`: `relayout` with the metrics measured in the page (`text_height`, `text_char_width`, `legend_height`): what a re-measure pass
    hands the layout.
- **Metrics**: `DOM` is the G2 comparison of the first spike ([`../chart/compare.rb`](../chart/compare.rb): exact tree, numbers within 1e-3
  px) against recharts at that size and font; `boxes` is the largest on-screen deviation (`getBoundingClientRect` relative to the chart) of
  the surface, grid lines, tick labels, bars, cursor, curve, dots and legend, with the count of missing or extra nodes in brackets; `text` is
  the on-screen width of the tick labels divided by recharts' (the glyph scale the reader sees).

## Numbers (2026-11-10, Apple Silicon laptop, Ruby 4.0, Chromium of Playwright 1.61, recharts 3.8.0)

### Fidelity

| Chart, font, size | `fixed` DOM / boxes / text | `viewbox` DOM / boxes / text | `relayout` DOM / boxes | `measured` DOM / boxes |
|---|---|---|---|---|
| bar mono 320x180 | 62 errors / 20 px / 1.00 | 63 / 31 px / 0.90 | **0** / 0 | (= relayout) |
| bar mono 560x315 | 120 / 240 px / 1.00 | 121 / 240 px / 1.57 | **0** / 0 | (= relayout) |
| bar mono 800x450 | 120 / 480 px / 1.00 | 121 / 480 px / 2.25 | **0** / 0 | (= relayout) |
| line mono 320x180 | 47 / 20 px / 1.00 | 48 / 23.6 px / 0.90 | **0** / 0 | (= relayout) |
| line mono 560x315 | 88 / 240 px / 1.00 | 89 / 104.3 px / 1.57 | **0** / 0 | (= relayout) |
| line mono 800x450 | 88 / 480 px / 1.00 | 89 / 185 px / 2.25 | **0** / 0 | (= relayout) |
| bar sans 320x180 | 62 / 20 px / 1.00 | 63 / 31 px / 0.90 | 58 / 2 px | **0** / 0 |
| bar sans 560x315 | 120 / 240 px / 1.00 | 121 / 240 px / 1.57 | 58 / 2 px | **0** / 0 |
| bar sans 800x450 | 120 / 480 px / 1.00 | 121 / 480 px / 2.25 | 58 / 2 px | **0** / 0 |
| line sans 320x180 | 48 / 20 px / 1.00 | 49 / 23.6 px / 0.90 | 1 / 1 px | **0** / 0 |
| line sans 560x315 | 89 / 240 px / 1.00 | 90 / 104.3 px / 1.57 | 1 / 1 px | **0** / 0 |
| line sans 800x450 | 89 / 480 px / 1.00 | 90 / 185 px / 2.25 | 1 / 1 px | **0** / 0 |

Read it as:

- **A re-layout at the measured size is exact** at every size (0 DOM differences, 0 px on screen), and with the measured metrics also in a font
  the defaults do not describe. Without the measured metrics a host font moves the plot: the legend box is 26 px in `12px sans-serif`, not 28,
  so every bar is 2 px off (58 numeric differences), and the last y label of the line chart is shifted by half of a 14 px line instead of a 16
  px one (1 difference, 1 px).
- **Scaling the viewBox does not follow the container, it zooms it**: the glyphs are drawn at 0.90, 1.57 and 2.25 times their size (a 12 px
  label becomes 27 px at 800 px), the chart is letterboxed when the box is not 16:10, the HTML legend stays at its 320 px layout (the 240 and 480
  px box deviations of the bar chart are the legend), and the DOM still holds the 320x200 numbers. It only avoids the overflow `fixed` has in a
  smaller box.
- **Measured text metrics** (`sans`): `text_height` 14 (default 16), `text_char_width` 0.5622 em for the month labels of the bar chart and
  0.5599 em with the y labels of the line chart (default 0.6), `legend_height` 26 (default 28). The server estimates a label's width as its
  length times the average glyph width; recharts measures each string: in `sans` the estimate is off by up to 2.5 px for one label
  (`May` +2.43 px, `Apr` -1.55 px at 560x315). No tick collision depends on it at these sizes; a label within 2.5 px of the collision threshold
  could still be kept or dropped differently in a proportional font.

### Cost

| | Measured |
|---|---|
| recharts' own re-layout after a resize from 320x180 (reference) | 28 to 38 ms until the DOM is stable again (an upper bound, two-frame granularity), 1.7 MB of recharts + React for the two examples (production build, not minified) |
| `viewbox` | 0 bytes and 0 ms: one CSS change on `.recharts-wrapper` and the inner div of the responsive container |
| server re-layout, per resize | the gem renders the bar chart in 2.1 to 3.7 ms and the line chart in 1.2 to 2.2 ms (mean of 50); 27.5 KB of HTML for the bar chart (3.2 KB gzipped), 18.2 KB for the line chart (2.5 KB gzipped); plus one request to the host and its round trip, which the spike does not measure (it depends on the host) |
| JavaScript re-layout in `chadcn--chart` | the size-dependent Ruby layout it would duplicate is 3,129 lines (scales, curves, sector and rectangle paths, bar positions, tick collision, label positions, the cartesian and polar surfaces), against 1,107 lines of size-independent code (domains, nice ticks, stacks, formatters, tooltip content) that could travel as data; the whole chart is 5,404 lines of Ruby; a JavaScript re-layout is 3,129 lines of Ruby to port against 342 lines of chart JavaScript today (`chart_controller.js` and `primitives/chart_*.js`, non-blank non-comment lines, 9.1 times; `run.rb` prints both). Its runtime would be close to recharts' (same work, no React) |

## Conclusions the record draws from these numbers

1. The resize mechanism is a **server re-layout at the measured size**: it is the only one that is exact without a second implementation of
   the layout, and it costs 1 to 4 ms of rendering and 2.5 to 3.2 KB gzipped per re-layout. A JavaScript re-layout would be exact too, but
   would port 3,129 lines of Ruby against 342 lines of chart JavaScript today (9.1 times) and needs its own parity proof against the Ruby; the viewBox zooms text and is rejected.
2. The **re-measure pass** is the same request: the controller measures what recharts measures and sends it with the size. The tick-template
   design of the first record cannot correct the legend height, which moves the whole plot (the 58 differences above).
