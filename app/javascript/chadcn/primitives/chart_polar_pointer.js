// Maps a pointer on a polar chart to the category it is over, the way recharts' axis tooltip does on a RadarChart or a RadialBarChart
// (pure functions, no DOM state). Ported from recharts 3.8 `es6/`: `util/PolarUtils.js` (`polarToCartesian`, `getAngleOfPoint`,
// `formatAngleOfSector`, `reverseFormatAngleOfSector`, `inRangeOfSector`), `util/getActiveCoordinate.js` (`calculateActiveTickIndex`
// with its circular angle branch, `getActivePolarCoordinate`) and `util/ChartUtils.js:516` (`calculatePolarTooltipPos`: the angle on a
// centric layout, the radius on a radial one), as `state/selectors/selectors.js:76-91` (`combineActivePolarProps`) combines them.
// The pointer itself is `relativePointer` of `chart_pointer.js` (the mouse path of `getRelativeCoordinate`).
// Known divergence: `getActivePolarCoordinate` returns the whole polar view box with the point; only `x` and `y` are returned here
// (the cursor is the server's, drawn per category).
//
//   const polar = polarPointer({ x: 203, y: 75 }, viewBox)    // { radius: 49.74, angle: 30.17 } or null outside the sector
//   const index = polarTickIndex(polar.angle, ticks, { angleAxis: true, range: [90, -270] })
//   const at = polarActiveCoordinate("centric", ticks[index].coordinate, polar, viewBox)

import { nearestTickIndex } from "chadcn/primitives/chart_pointer"

const RADIAN = Math.PI / 180

/**
 * The point at `radius` from the center at `angle` degrees, counterclockwise from 3 o'clock (`polarToCartesian`).
 * @param {number} cx
 * @param {number} cy
 * @param {number} radius
 * @param {number} angle degrees
 * @returns {{ x: number, y: number }}
 */
export function polarToCartesian(cx, cy, radius, angle) {
  return { x: cx + Math.cos(-RADIAN * angle) * radius, y: cy + Math.sin(-RADIAN * angle) * radius }
}

function angleOfPoint({ x, y }, { cx, cy }) {
  const radius = Math.sqrt((x - cx) ** 2 + (y - cy) ** 2)
  if (radius <= 0) return { radius, angle: 0 }

  let radians = Math.acos((x - cx) / radius)
  if (y > cy) radians = 2 * Math.PI - radians
  return { radius, angle: radians / RADIAN }
}

// The sector's angles moved by whole turns so the smaller one lies in [0, 360) (`formatAngleOfSector`); `turns` is how far, which
// `reverseFormatAngleOfSector` adds back.
function formattedSector({ startAngle, endAngle }) {
  const turns = Math.min(Math.floor(startAngle / 360), Math.floor(endAngle / 360))
  return { startAngle: startAngle - turns * 360, endAngle: endAngle - turns * 360, turns }
}

/**
 * The pointer's radius and angle when it lies inside the sector of the polar view box, borders included (`inRangeOfSector`): null
 * outside the two radii, at the center, or outside the angles. The angle is in the sector's own turn (90 to -270 reaches 210 as -150).
 * @param {{ x: number, y: number }} pointer chart pixels
 * @param {{ cx: number, cy: number, innerRadius: number, outerRadius: number, startAngle: number, endAngle: number }} viewBox
 * @returns {{ radius: number, angle: number } | null}
 */
export function polarPointer(pointer, viewBox) {
  const { radius, angle } = angleOfPoint(pointer, viewBox)
  if (radius < viewBox.innerRadius || radius > viewBox.outerRadius || radius === 0) return null

  const { startAngle, endAngle, turns } = formattedSector(viewBox)
  const [low, high] = startAngle <= endAngle ? [startAngle, endAngle] : [endAngle, startAngle]
  let formatted = angle
  while (formatted > high) formatted -= 360
  while (formatted < low) formatted += 360
  if (formatted < low || formatted > high) return null

  return { radius, angle: formatted + turns * 360 }
}

const sign = (value) => (value === 0 ? 0 : value > 0 ? 1 : -1)

// The circular branch of `calculateActiveTickIndex` (`util/getActiveCoordinate.js`): angle ticks spread over a full turn, in their own
// order, where the band of a tick may wrap around the turn.
function circularTickIndex(coordinate, ticks, range) {
  const count = ticks.length
  const span = range[1] - range[0]
  for (let i = 0; i < count; i += 1) {
    const before = ticks[i > 0 ? i - 1 : count - 1].coordinate
    const current = ticks[i].coordinate
    const after = ticks[i >= count - 1 ? 0 : i + 1].coordinate
    if (sign(current - before) !== sign(after - current)) {
      let same
      let wrapped
      if (sign(after - current) === sign(span)) {
        same = after
        const shifted = current + span
        wrapped = [Math.min(shifted, (shifted + before) / 2), Math.max(shifted, (shifted + before) / 2)]
      } else {
        same = before
        const shifted = after + span
        wrapped = [Math.min(current, (shifted + current) / 2), Math.max(current, (shifted + current) / 2)]
      }
      const own = [Math.min(current, (same + current) / 2), Math.max(current, (same + current) / 2)]
      if ((coordinate > own[0] && coordinate <= own[1]) || (coordinate >= wrapped[0] && coordinate <= wrapped[1])) return ticks[i].index
    } else if (coordinate > (Math.min(before, after) + current) / 2 && coordinate <= (Math.max(before, after) + current) / 2) {
      return ticks[i].index
    }
  }
  return -1
}

/**
 * The `index` of the tick whose band holds `coordinate` (`calculateActiveTickIndex`): around the circle for an angle axis whose range is a
 * full turn, else along one direction (`nearestTickIndex`, the ticks sorted by coordinate). One tick or none answers 0.
 * @param {number} coordinate the pointer's angle (angle axis) or radius (radius axis)
 * @param {{ index: number, coordinate: number }[]} ticks the tooltip axis ticks, in their own order
 * @param {{ angleAxis: boolean, range: number[] }} axis whether the tooltip axis is the angle axis, and its range
 * @returns {number} -1 when no band holds the coordinate
 */
export function polarTickIndex(coordinate, ticks, { angleAxis, range }) {
  if (ticks.length <= 1 || coordinate == null) return 0

  const fullTurn = angleAxis && Array.isArray(range) && Math.abs(Math.abs(range[1] - range[0]) - 360) <= 1e-6
  return fullTurn ? circularTickIndex(coordinate, ticks, range) : nearestTickIndex(coordinate, ticks)
}

/**
 * Where the tooltip of a pointer activation anchors (`getActivePolarCoordinate`): on a centric layout (a radar) the pointer's radius
 * along the tick's angle, on a radial one (a radial bar chart) the tick's radius at the pointer's angle.
 * @param {"centric" | "radial"} layout
 * @param {number} tickCoordinate the active tick's angle (centric) or radius (radial)
 * @param {{ radius: number, angle: number }} pointer from `polarPointer`
 * @param {{ cx: number, cy: number }} viewBox
 * @returns {{ x: number, y: number }}
 */
export function polarActiveCoordinate(layout, tickCoordinate, pointer, viewBox) {
  return layout === "centric"
    ? polarToCartesian(viewBox.cx, viewBox.cy, pointer.radius, tickCoordinate)
    : polarToCartesian(viewBox.cx, viewBox.cy, tickCoordinate, pointer.angle)
}
