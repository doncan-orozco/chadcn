// Rectangle and pointer math of react-resizable-panels 4.14.3 (spec: dev/port/specs/resizable.md). Pure: numbers and plain rects
// in, numbers and plain rects out; no DOM, no Stimulus. A rect is anything with `x, y, width, height, left, top, right, bottom`
// (a DOMRect from getBoundingClientRect, or `makeRect`).

import { assert, near } from "chadcn/primitives/resizable_layout"

// A plain rect with the DOMRect fields (left/right/top/bottom normalised for a negative width or height, like DOMRect).
export function makeRect(x, y, width, height) {
  return {
    x, y, width, height,
    left: Math.min(x, x + width), right: Math.max(x, x + width), top: Math.min(y, y + height), bottom: Math.max(y, y + height)
  }
}

// Grows a thin separator rect to `minimum` pixels on each axis, centred (resizeTargetMinimumSize).
export function expandRect({ minimum, rect }) {
  if (rect.width < minimum) {
    const missing = minimum - rect.width
    rect = makeRect(rect.x - missing / 2, rect.y, rect.width + missing, rect.height)
  }
  if (rect.height < minimum) {
    const missing = minimum - rect.height
    rect = makeRect(rect.x, rect.y - missing / 2, rect.width, rect.height + missing)
  }
  return rect
}

export function pointerDistance(point, rect) {
  return {
    x: point.x >= rect.left && point.x <= rect.right ? 0 : Math.min(Math.abs(point.x - rect.left), Math.abs(point.x - rect.right)),
    y: point.y >= rect.top && point.y <= rect.bottom ? 0 : Math.min(Math.abs(point.y - rect.top), Math.abs(point.y - rect.bottom))
  }
}

// The rect of `rects` nearest the centre of `targetRect` along `orientation`.
export function closestRect({ orientation, rects, targetRect }) {
  const center = { x: targetRect.x + targetRect.width / 2, y: targetRect.y + targetRect.height / 2 }
  let closest
  let best = Number.MAX_VALUE
  for (const rect of rects) {
    const { x, y } = pointerDistance(center, rect)
    const distance = orientation === "horizontal" ? x : y
    if (distance < best) {
      best = distance
      closest = rect
    }
  }
  assert(closest, "No rect found")
  return closest
}

// The region (anything with a `rect`) nearest `point`, the main axis first, the last one on a tie; `hit` when the point is
// inside it.
export function nearestRegion({ orientation, point, regions }) {
  let found
  let best = { x: Infinity, y: Infinity }
  for (const region of regions) {
    const distance = pointerDistance(point, region.rect)
    const better = orientation === "horizontal" ? distance.x < best.x || (distance.x === best.x && distance.y <= best.y)
      : distance.y < best.y || (distance.y === best.y && distance.x <= best.x)
    if (better) {
      found = region
      best = distance
    }
  }
  return { region: found, hit: !!found && best.x <= 0 && best.y <= 0 }
}

// The pointer move since pointerdown in percent of the group. Without a pointerdown point (the pointer left the window) the
// drag goes to the limit on the side the pointer left.
export function pointerDelta({ orientation, point, origin, axisSize }) {
  const horizontal = orientation === "horizontal"
  if (origin) return horizontal ? (point.x - origin.x) / axisSize * 100 : (point.y - origin.y) / axisSize * 100
  return (horizontal ? point.x : point.y) < 0 ? -100 : 100
}

// Pixel offset of each separator preview (resize_preview_mode "separator"): the running sum of the panels' growth.
export function previewOffsets({ itemIds, layout, initialLayout, axisSize }) {
  let offset = 0
  return itemIds.map((id) => {
    offset += layout[id] - initialLayout[id]
    return offset * (axisSize / 100)
  })
}

// Where a separator preview sits inside the group: separators keep their rect; a gap between two panels becomes a zero-width
// line at its centre. `bounds` is the group rect, `scroll` its `{ left, top, clientLeft, clientTop }`.
export function previewRect({ horizontal, rect, separator, bounds, scroll }) {
  const center = horizontal ? rect.left + rect.width / 2 : rect.top + rect.height / 2
  return makeRect(
    (horizontal && !separator ? center : rect.left) - bounds.left - scroll.clientLeft + scroll.left,
    (!horizontal && !separator ? center : rect.top) - bounds.top - scroll.clientTop + scroll.top,
    horizontal && !separator ? 0 : rect.width,
    !horizontal && !separator ? 0 : rect.height
  )
}

// Same gap: two rects whose centres along the main axis round to the same value.
export const sameCenter = ({ horizontal, a, b }) =>
  near(horizontal ? a.left + a.width / 2 : a.top + a.height / 2, horizontal ? b.left + b.width / 2 : b.top + b.height / 2)

export const overlaps = (a, b) => a.x < b.x + b.width && a.x + a.width > b.x && a.y < b.y + b.height && a.y + a.height > b.y
