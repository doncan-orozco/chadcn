// The re-measure of a server-drawn chart (dev/port/specs/chart.md, "Behavior", "Resize and re-measure", Measure; decision:
// dev/decisions/chart.md). The server lays a chart out with assumed text metrics (`text_height:` 16, `text_char_width:` 0.6em,
// `legend_height:` 28); recharts measures its text in the DOM (util/DOMUtils.js `measureTextWithDOM`) and the legend box
// (`useElementOffset`). This module measures the same things the same way, and says whether they ask for a re-layout; chadcn--chart
// sends them with the re-layout request (primitives/chart_relayout.js).
//
// Not a Radix port: Radix has no charts. Known divergence: recharts measures each label, the server estimates a label as its length
// times the average glyph width measured here (spec, "Stays a deviation").

import { drawable } from "chadcn/primitives/chart_relayout"

/** The font size the server's `text_char_width` is in em of (`Chart::Cartesian::Text`). */
const TICK_FONT_SIZE = 12
const DECIMALS = 1e4
// recharts' measurement span (util/DOMUtils.js SPAN_STYLE).
const SPAN_STYLE = { position: "absolute", top: "-20000px", left: "0", padding: "0", margin: "0", border: "none", whiteSpace: "pre" }

const rounded = (number) => Math.round(number * DECIMALS) / DECIMALS

/**
 * The text metrics of a drawn chart, measured like recharts: each tick label in a `white-space: pre` span appended to `body` (and
 * removed again) at the font size and letter spacing of the tick text; `textHeight` the height of a line, `textCharWidth` the summed
 * width over the summed length of the labels in em of 12px, `legendHeight` the height of the `.recharts-legend-wrapper` box. Without
 * tick labels the text metrics are the served ones (nothing to measure); without a legend there is no `legendHeight`. Rounded to 4
 * decimals.
 *
 * @param {Element} chart the `div[data-slot="chart"]`
 * @param {{ textHeight?: number, textCharWidth?: number }} served the metrics the server laid the chart out with
 * @returns {{ textHeight: number, textCharWidth: number, legendHeight?: number }}
 */
export function measureTextMetrics(chart, served) {
  const metrics = { textHeight: served.textHeight, textCharWidth: served.textCharWidth, ...measureTicks(chart) }
  const legend = chart.querySelector(".recharts-legend-wrapper")
  if (legend) metrics.legendHeight = rounded(legend.getBoundingClientRect().height)
  return metrics
}

function measureTicks(chart) {
  const ticks = [...chart.querySelectorAll(".recharts-cartesian-axis-tick-value")]
  const labels = ticks.map((tick) => tick.textContent).filter((text) => text.length > 0)
  if (labels.length === 0) return {}

  const { fontSize, letterSpacing } = getComputedStyle(ticks[0])
  const span = document.createElement("span")
  span.setAttribute("aria-hidden", "true")
  Object.assign(span.style, SPAN_STYLE, { fontSize, letterSpacing })
  document.body.appendChild(span)
  try {
    let width = 0
    let height = 0
    for (const label of labels) {
      span.textContent = label
      const rect = span.getBoundingClientRect()
      width += rect.width
      height ||= rect.height
    }
    const characters = labels.reduce((count, label) => count + label.length, 0)
    return { textHeight: rounded(height), textCharWidth: rounded(width / characters / TICK_FONT_SIZE) }
  } finally {
    span.remove()
  }
}

const differs = (a, b) => typeof a !== "number" || typeof b !== "number" || rounded(a) !== rounded(b)

/**
 * Whether measured metrics differ from the served ones (to 4 decimals). `legendHeight` counts only when one was measured.
 *
 * @param {{ textHeight: number, textCharWidth: number, legendHeight?: number }} measured
 * @param {{ textHeight?: number, textCharWidth?: number, legendHeight?: number }} served
 * @returns {boolean}
 */
export function metricsDiffer(measured, served) {
  if (differs(measured.textHeight, served.textHeight) || differs(measured.textCharWidth, served.textCharWidth)) return true

  return measured.legendHeight !== undefined && differs(measured.legendHeight, served.legendHeight)
}

/**
 * Whether a chart at `size` must be requested again for its metrics alone: they differ from the served ones, the size is drawable, and
 * the chart is not already laid out with browser metrics at this size (`measuredAt`, written on every answer). That last rule keeps a
 * host that ignores the metrics, or a label set that flips between two layouts, to one request per size.
 *
 * @param {object} state
 * @param {{ textHeight: number, textCharWidth: number, legendHeight?: number }} state.measured
 * @param {{ textHeight?: number, textCharWidth?: number, legendHeight?: number }} state.served
 * @param {{ width: number, height: number }} state.size the rounded size of the box
 * @param {{ width?: number, height?: number } | undefined} state.measuredAt the size an answer laid this chart out at, if any
 * @returns {boolean}
 */
export function remeasureNeeded({ measured, served, size, measuredAt }) {
  if (!drawable(size.width) || !drawable(size.height)) return false
  if (measuredAt?.width === size.width && measuredAt?.height === size.height) return false

  return metricsDiffer(measured, served)
}
