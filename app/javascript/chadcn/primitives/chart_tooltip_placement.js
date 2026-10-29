// Where recharts puts the tooltip box: the translate in the chart and the side classes (pure functions).
// Ported from recharts 3.8 `es6/util/tooltip/translate.js`: `getTooltipTranslateXY` (:20-61), `getTransformStyle` (:62-71, the
// `translate()` form), `getTooltipTranslate` (:72-124) and `getTooltipCSSClassName` (:7-19).
// This is NOT floating-ui (`primitives/positioner.js` is Radix popper, a different algorithm): the chart tooltip follows the pointer
// inside the plot and flips at its edges the way recharts does.
// Known divergences: `useTranslate3d` is not offered (recharts' default is the 2D translate).
//
//   const { transform, classes } = tooltipPlacement({ coordinate: { x: 82, y: 40 }, box: { width: 120, height: 60 },
//     viewBox: { x: 5, y: 5, width: 310, height: 160 }, offset: { x: 10, y: 10 }, position: {},
//     allowEscapeViewBox: { x: false, y: false }, reverseDirection: { x: false, y: false } })

const PREFIX = "recharts-tooltip-wrapper"

/** The four side modifiers the controller owns on the wrapper (`getTooltipCSSClassName`). */
export const SIDE_CLASSES = Object.freeze([`${PREFIX}-right`, `${PREFIX}-left`, `${PREFIX}-top`, `${PREFIX}-bottom`])

const isNumber = (value) => typeof value === "number" && !Number.isNaN(value)

function translateAlong({ key, coordinate, offset, position, tooltipDimension, viewBox, viewBoxDimension, allowEscapeViewBox, reverseDirection }) {
  if (position && isNumber(position[key])) return position[key]

  const negative = coordinate[key] - tooltipDimension - (offset > 0 ? offset : 0)
  const positive = coordinate[key] + offset
  if (allowEscapeViewBox[key]) return reverseDirection[key] ? negative : positive

  const viewBoxKey = viewBox[key]
  if (viewBoxKey == null) return 0
  if (reverseDirection[key]) return negative < viewBoxKey ? Math.max(positive, viewBoxKey) : Math.max(negative, viewBoxKey)
  if (viewBoxDimension == null) return 0

  return positive + tooltipDimension > viewBoxKey + viewBoxDimension ? Math.max(negative, viewBoxKey) : Math.max(positive, viewBoxKey)
}

/**
 * @param {object} options
 * @param {{ x: number, y: number } | null} options.coordinate the active coordinate in chart pixels
 * @param {{ width: number, height: number }} options.box the measured tooltip box
 * @param {{ x: number, y: number, width: number, height: number }} options.viewBox the plot rectangle (`selectChartViewBox`)
 * @param {{ x: number, y: number }} options.offset distance from the coordinate
 * @param {{ x?: number, y?: number }} options.position a fixed position per axis
 * @param {{ x: boolean, y: boolean }} options.allowEscapeViewBox
 * @param {{ x: boolean, y: boolean }} options.reverseDirection
 * @returns {{ transform: string | null, classes: string[] }} `transform` is null (and `classes` empty) while the box has no size
 *   or there is no coordinate: the wrapper stays where it is and hidden (`translate.js:113-115`)
 */
export function tooltipPlacement({ coordinate, box, viewBox, offset, position, allowEscapeViewBox, reverseDirection }) {
  if (!(box.height > 0 && box.width > 0 && coordinate)) return { transform: null, classes: [] }

  const shared = { coordinate, position, viewBox, allowEscapeViewBox, reverseDirection }
  const x = translateAlong({ ...shared, key: "x", offset: offset.x, tooltipDimension: box.width, viewBoxDimension: viewBox.width })
  const y = translateAlong({ ...shared, key: "y", offset: offset.y, tooltipDimension: box.height, viewBoxDimension: viewBox.height })

  const classes = []
  if (isNumber(x) && isNumber(coordinate.x)) classes.push(x >= coordinate.x ? `${PREFIX}-right` : `${PREFIX}-left`)
  if (isNumber(y) && isNumber(coordinate.y)) classes.push(y >= coordinate.y ? `${PREFIX}-bottom` : `${PREFIX}-top`)
  return { transform: `translate(${x}px, ${y}px)`, classes }
}
