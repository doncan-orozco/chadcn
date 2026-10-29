// Maps a pointer on a chart to the category it is over, the way recharts' axis tooltip does (pure functions, no DOM state).
// Ported from recharts 3.8 `es6/`: `util/getRelativeCoordinate.js:62-89,93` (the mouse path: the pointer relative to the chart root),
// `util/getActiveCoordinate.js:78-84` (`isInCartesianRange`) and `:85-92,131-150` (`calculateActiveTickIndex` with its `len <= 1`
// guard, the single direction branch).
// Known divergences: the angle-axis branch (polar charts, a later item) is not ported; an SVG `currentTarget` (recharts scales with
// `getBBox()`) is not supported because the chart root is always the HTML `.recharts-wrapper` div; the touch-event branch
// (`getRelativeCoordinate.js:90-92`, `event.touches`) is not ported: a touch arrives as a pointer event with `clientX`/`clientY`.
//
//   const pointer = relativePointer(event)               // { x, y } in chart pixels, rounded
//   pointerInPlot(pointer, { x: 5, y: 5, width: 310, height: 160 })
//   nearestTickIndex(pointer.x, [{ index: 0, coordinate: 30 }, { index: 1, coordinate: 82 }])

/**
 * The pointer position relative to the top-left corner of `event.currentTarget`, rounded to whole pixels and corrected for a CSS
 * `transform: scale()` (recharts `getRelativeCoordinate`, `util/getRelativeCoordinate.js:62-89,93`).
 * @example
 * relativePointer({ currentTarget: wrapper, clientX: 110, clientY: 70 }) // { x: 100, y: 60 } for a wrapper at left 10, top 10
 * @param {{ currentTarget: HTMLElement, clientX: number, clientY: number }} event
 * @returns {{ x: number, y: number }}
 */
export function relativePointer(event) {
  const element = event.currentTarget
  const rect = element.getBoundingClientRect()
  const scaleX = element.offsetWidth > 0 ? rect.width / element.offsetWidth : 1
  const scaleY = element.offsetHeight > 0 ? rect.height / element.offsetHeight : 1
  return {
    x: Math.round((event.clientX - rect.left) / scaleX),
    y: Math.round((event.clientY - rect.top) / scaleY),
  }
}

/**
 * Whether the pointer is inside the plot rectangle, borders included (`isInCartesianRange`, `util/getActiveCoordinate.js:78-84`).
 * @param {{ x: number, y: number }} pointer
 * @param {{ x: number, y: number, width: number, height: number }} plot
 * @returns {boolean}
 */
export function pointerInPlot(pointer, plot) {
  return pointer.x >= plot.x && pointer.x <= plot.x + plot.width && pointer.y >= plot.y && pointer.y <= plot.y + plot.height
}

/**
 * The `index` of the tick whose band holds `coordinate`: the bands are bounded by the midpoints between ticks sorted by coordinate,
 * a coordinate exactly on a midpoint belongs to the lower tick (every band includes its upper midpoint and excludes its lower
 * one; the first band has no lower bound and the last none above; `calculateActiveTickIndex`,
 * `util/getActiveCoordinate.js:131-150`, the comparisons at `:140-148`; the ticks are sorted by coordinate first, `state/selectors/selectors.js:28`
 * `selectOrderedTooltipTicks`). With one tick or fewer, or a null coordinate, the answer is 0 (`:85-92`), which is not necessarily a
 * tick `index`.
 * @example
 * nearestTickIndex(60, [{ index: 0, coordinate: 30 }, { index: 1, coordinate: 82 }]) // 1 (the midpoint is 56)
 * @param {number} coordinate x for a horizontal layout, y for a vertical one
 * @param {{ index: number, coordinate: number }[]} ticks
 * @returns {number} -1 when no band holds the coordinate (a degenerate tick list)
 */
export function nearestTickIndex(coordinate, ticks) {
  if (ticks.length <= 1 || coordinate == null) return 0

  const ordered = [...ticks].sort((a, b) => a.coordinate - b.coordinate)
  const last = ordered.length - 1
  for (let i = 0; i <= last; i += 1) {
    const current = ordered[i]
    const previous = ordered[i - 1]
    const next = ordered[i + 1]
    if (i === 0 && next && coordinate <= (current.coordinate + next.coordinate) / 2) return current.index
    if (i === last && previous && coordinate > (current.coordinate + previous.coordinate) / 2) return current.index
    if (i > 0 && i < last && coordinate > (current.coordinate + previous.coordinate) / 2 && coordinate <= (current.coordinate + next.coordinate) / 2) return current.index
  }
  return -1
}
