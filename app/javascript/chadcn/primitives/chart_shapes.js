// Builds the tooltip cursor and the active dots of a chart from the JSON the server writes on the tooltip templates
// (dev/port/specs/chart.md, "Tooltip"). The templates are HTML-parsed, so an SVG fragment cannot live in them unwrapped; the
// JSON route builds SVG-namespace nodes with `createElementNS`. Nothing here parses markup: a tag outside TAGS is ignored and an
// attribute outside ATTRIBUTES is dropped (never `on*`, `href`, `style`), so a hostile `data-cursor` cannot script the page.
// Shapes follow recharts 3.8: the cursor is one `<path>` (`es6/component/Cursor.js:63-96`, the guard is :60-62), the active dot is a
// `<g class="recharts-active-dot">` (`es6/component/ActivePoints.js:55`; the `recharts-layer` class is the layer wrapper's) around
// one `<circle class="recharts-dot">` (`es6/shape/Dot.js:24`).
// Known divergences: an active dot never carries the `clipPath` recharts sets on its layer when the series clips
// (`es6/component/ActivePoints.js:54-57`); the z-index layer wrapper (`es6/component/Cursor.js:106-112`) is not built here, the
// controller picks the layer group; only `path` cursors (no Cross or Sector: polar charts are a later item); a `class` in an active-dot spec is replaced by
// `recharts-dot` whereas recharts' Dot does `clsx('recharts-dot', className)` (`es6/shape/Dot.js:24`).
//
//   const cursor = cursorElement({ tag: "path", layer: 200, attrs: { d: "M 0,0 h 5", class: "recharts-rectangle recharts-tooltip-cursor" } })
//   const dots = activeDotElements([{ cx: "5", cy: "6", r: "4", fill: "red" }])

const SVG_NAMESPACE = "http://www.w3.org/2000/svg"
const TAGS = new Set(["path", "circle"])

/** The SVG presentation and geometry attributes a cursor or dot may carry (the server's SHAPE_ATTRIBUTES plus the geometry it writes). */
const ATTRIBUTES = new Set([
  "class", "d", "x", "y", "width", "height", "radius", "cx", "cy", "r", "fill", "fill-opacity", "stroke", "stroke-width",
  "stroke-dasharray", "stroke-opacity", "stroke-linecap", "stroke-linejoin", "opacity", "pointer-events",
])

/**
 * One SVG element of `tag` (path or circle) with the whitelisted attributes of `attrs`.
 * @param {string} tag
 * @param {Record<string, string | number> | null} attrs
 * @returns {SVGElement | null} null for a tag outside TAGS or attrs that is not an object
 */
function shapeElement(tag, attrs) {
  if (!TAGS.has(tag) || attrs === null || typeof attrs !== "object") return null

  const element = document.createElementNS(SVG_NAMESPACE, tag)
  for (const [name, value] of Object.entries(attrs)) {
    if (ATTRIBUTES.has(name) && (typeof value === "string" || typeof value === "number")) element.setAttribute(name, String(value))
  }
  return element
}

/**
 * @param {{ tag: string, layer?: number, attrs: Record<string, string | number> } | null} spec the parsed `data-cursor`
 *   (`layer` is not read here: the controller reads it to choose the z-index layer group)
 * @returns {SVGElement | null} null for an unknown tag or a missing spec
 * @example
 * cursorElement({ tag: "path", layer: 200, attrs: { d: "M 0,0 h 5" } }) // <path d="M 0,0 h 5"> in the SVG namespace
 */
export function cursorElement(spec) {
  return spec ? shapeElement(spec.tag, spec.attrs) : null
}

/**
 * @param {Record<string, string | number>[] | null} specs the parsed `data-active-dots`, one attribute Hash per dot
 * @returns {SVGGElement[]} one `g.recharts-active-dot` per dot (an entry that is not an object is skipped)
 * @example
 * activeDotElements([{ cx: "5", cy: "6", r: "4" }]) // [<g class="recharts-layer recharts-active-dot"><circle class="recharts-dot" ...>]
 */
export function activeDotElements(specs) {
  if (!Array.isArray(specs)) return []

  return specs.flatMap((attrs) => {
    const circle = shapeElement("circle", attrs)
    if (!circle) return []

    circle.setAttribute("class", "recharts-dot")
    const group = document.createElementNS(SVG_NAMESPACE, "g")
    group.setAttribute("class", "recharts-layer recharts-active-dot")
    group.append(circle)
    return [group]
  })
}
