// The re-layout of a server-drawn chart (dev/port/specs/chart.md, "Behavior", "Resize and re-measure"; decision: dev/decisions/chart.md).
// recharts' ResponsiveContainer re-lays the chart out on every resize (component/ResponsiveContainer.js); the port asks the server for
// the chart at the size of its box and swaps it in. This module holds what that needs apart from the controller: the settled size of
// the box, whether it differs from the size the server drew, the request URL, the chart in the answer, and the interim scaling of the
// drawn chart until the answer arrives. chadcn--chart composes them with the request, the swap and the events.
//
// Not a Radix port: Radix has no charts. Known divergences: the chart between a resize and the answer is the previous layout scaled
// into the box, where recharts re-lays out in the next frames (spec, "Stays a deviation").

/** How long the box must stay at one size before the chart is requested again, in ms. */
export const RELAYOUT_DEBOUNCE_MS = 150

/** Largest width and height the server lays a chart out at (`Chart::Container::RELAYOUT_MAX_SIZE`). */
export const RELAYOUT_MAX_SIZE = 4096

const FLUID = { width: "100%", height: "100%" }

/**
 * A box size rounded to whole pixels.
 *
 * @param {{ width: number, height: number }} box a `contentRect` or any rect with a width and a height
 * @returns {{ width: number, height: number }}
 */
export function roundedSize({ width, height }) {
  return { width: Math.round(width), height: Math.round(height) }
}

const drawable = (length) => Number.isFinite(length) && length >= 1 && length <= RELAYOUT_MAX_SIZE

/**
 * Whether a chart drawn at `dimension` must be requested again for a box of `size`: the sizes differ and the box is one the server
 * lays out (1 to 4096 px each way; beyond that the chart stays scaled into its box).
 *
 * @param {{ width: number, height: number }} size the rounded size of the box
 * @param {{ width?: number, height?: number }} dimension the size the server laid the chart out at
 * @returns {boolean}
 */
export function relayoutNeeded(size, dimension) {
  if (!drawable(size.width) || !drawable(size.height)) return false

  return size.width !== dimension.width || size.height !== dimension.height
}

/**
 * The URL of the re-layout request: `url` (resolved against the page) with the chart parameters added to its own query, or null
 * when it is not same-origin (a cross-origin URL is never requested) or not a URL at all.
 *
 * @param {string} url the container's `relayout_url:`
 * @param {object} request
 * @param {string} request.id the container's `id:`, without the `chart-` prefix
 * @param {{ width: number, height: number }} request.size
 * @param {{ textHeight?: number, textCharWidth?: number, legendHeight?: number }} request.metrics
 * @param {string} [base] the page URL
 * @returns {URL | null}
 */
export function relayoutRequestUrl(url, { id, size, metrics }, base = window.location.href) {
  let target
  try {
    target = new URL(url, base)
  } catch {
    return null
  }
  if (target.origin !== new URL(base).origin) return null

  const parameters = {
    id,
    width: size.width,
    height: size.height,
    text_height: metrics.textHeight,
    text_char_width: metrics.textCharWidth,
    legend_height: metrics.legendHeight,
  }
  for (const [name, value] of Object.entries(parameters)) {
    if (value !== undefined && value !== null && (typeof value !== "number" || Number.isFinite(value))) target.searchParams.set(`chart[${name}]`, String(value))
  }
  target.hash = ""
  return target
}

/**
 * The chart named `name` (`data-chart`) in an HTML answer, parsed inert (DOMParser: no script runs, no image loads), or null.
 * Adopt it with `document.importNode` before inserting it.
 *
 * @param {string} html
 * @param {string} name `chart-<id>`
 * @returns {Element | null}
 */
export function chartInResponse(html, name) {
  const doc = new DOMParser().parseFromString(html, "text/html")
  return [...doc.querySelectorAll('div[data-slot="chart"]')].find((chart) => chart.getAttribute("data-chart") === name) ?? null
}

/**
 * Whether a chart was laid out at `size`, read from its dimension value.
 *
 * @param {Element} chart
 * @param {{ width: number, height: number }} size
 * @param {string} attribute the dimension value attribute (`data-chadcn--chart-dimension-value`)
 * @returns {boolean}
 */
export function laidOutAt(chart, size, attribute) {
  try {
    const dimension = JSON.parse(chart.getAttribute(attribute) ?? "null")
    return dimension?.width === size.width && dimension?.height === size.height
  } catch {
    return false
  }
}

/**
 * Observes the content box of `element` and reports its rounded size once it has not changed for `delay` ms (also its first size).
 * `onChange` hears every change at once, before the debounce.
 *
 * @param {Element} element
 * @param {(size: { width: number, height: number }) => void} onSettle
 * @param {{ delay?: number, onChange?: (size: { width: number, height: number }) => void }} [options]
 * @returns {{ disconnect: () => void }}
 */
export function observeSettledSize(element, onSettle, { delay = RELAYOUT_DEBOUNCE_MS, onChange = null } = {}) {
  let timer = null
  let latest = null
  const observer = new ResizeObserver((entries) => {
    const entry = entries[entries.length - 1]
    latest = roundedSize(entry.contentRect)
    onChange?.(latest)
    clearTimeout(timer)
    timer = setTimeout(() => {
      timer = null
      onSettle(latest)
    }, delay)
  })
  observer.observe(element)
  return {
    disconnect() {
      observer.disconnect()
      clearTimeout(timer)
      timer = null
    },
  }
}

/**
 * Scales the drawn chart into its box: `.recharts-wrapper` and the inner `width: 0px; height: 0px` div of the responsive shell at 100%,
 * so the svg (which has a viewBox and width/height 100%) follows the box instead of overflowing it. Returns the function that puts both
 * styles back (idempotent; a no-op when the chart has no wrapper).
 *
 * @param {Element} chart the `div[data-slot="chart"]`
 * @returns {() => void}
 */
export function scaleToBox(chart) {
  const wrapper = chart.querySelector(".recharts-wrapper")
  const inner = wrapper?.parentElement
  if (!wrapper || !inner || inner === chart) return () => {}

  const saved = [wrapper, inner].map((node) => [node, node.getAttribute("style")])
  for (const [node] of saved) Object.assign(node.style, FLUID)
  let restored = false
  return () => {
    if (restored) return
    restored = true
    for (const [node, style] of saved) style === null ? node.removeAttribute("style") : node.setAttribute("style", style)
  }
}
