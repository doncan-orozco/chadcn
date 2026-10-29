// Builds the tooltip cursor and the active dots of a chart from the JSON the server writes on the tooltip templates
// (dev/port/specs/chart.md, "Tooltip"). The templates are HTML-parsed, so an SVG fragment cannot live in them unwrapped; the
// JSON route builds SVG-namespace nodes with `createElementNS`. Nothing here parses markup: a tag outside TAGS is ignored and an
// attribute outside ATTRIBUTES is dropped (never `on*`, `href`, `style`), so a hostile `data-cursor` cannot script the page.
// Shapes follow recharts 3.8: the cursor is one `<path>` (`es6/component/Cursor.js:66-94`), the active dot is a `<g class="recharts-active-dot">` (`es6/component/ActivePoints.js:55`; the
// `recharts-layer` class is the layer wrapper's) around one `<circle class="recharts-dot">` (`es6/shape/Dot.js:24`).
// Known divergences: none.
//
//   const cursor = cursorElement({ tag: "path", layer: 200, attrs: { d: "M 0,0 h 5", class: "recharts-rectangle recharts-tooltip-cursor" } })
//   const dots = activeDotElements([{ cx: "5", cy: "6", r: "4", fill: "red" }])

const SVG_NAMESPACE = "http://www.w3.org/2000/svg"
const TAGS = new Set(["path", "circle"])

/** The SVG presentation and geometry attributes a cursor or dot may carry (the server's SHAPE_ATTRIBUTES plus the geometry it writes). */
export const ATTRIBUTES = new Set([
  "class", "d", "x", "y", "width", "height", "radius", "cx", "cy", "r", "fill", "fill-opacity", "stroke", "stroke-width",
  "stroke-dasharray", "stroke-opacity", "stroke-linecap", "stroke-linejoin", "opacity", "pointer-events",
])

function shapeElement(tag, attrs) {
  if (!TAGS.has(tag) || attrs === null || typeof attrs !== "object") return null

  const element = document.createElementNS(SVG_NAMESPACE, tag)
  for (const [name, value] of Object.entries(attrs)) {
    if (ATTRIBUTES.has(name) && (typeof value === "string" || typeof value === "number")) element.setAttribute(name, String(value))
  }
  return element
}

/**
 * @param {{ tag: string, attrs: Record<string, string | number> } | null} spec the parsed `data-cursor`
 * @returns {SVGElement | null} null for an unknown tag or a missing spec
 */
export function cursorElement(spec) {
  return spec ? shapeElement(spec.tag, spec.attrs) : null
}

/**
 * @param {Record<string, string | number>[] | null} specs the parsed `data-active-dots`, one attribute Hash per dot
 * @returns {SVGGElement[]} one `g.recharts-active-dot` per dot (an entry that is not an object is skipped)
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
