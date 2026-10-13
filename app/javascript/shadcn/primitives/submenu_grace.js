// submenu_grace: pointer-grace geometry of Radix menus and tooltips.
// Sources: @radix-ui/react-menu (MenuContentImpl pointerDirRef / pointerGraceIntentRef, MenuSubTrigger onPointerLeave) and
// @radix-ui/react-tooltip (TooltipContentHoverable hull grace area). Spec: .ai/skills/radix-stimulus/references/primitives.md.
// Parity: docs/shadcn-port/scenarios/_primitives-submenu-grace.json.
//
// Known divergences: none.
//
// Menu (sub menus):
//   const grace = submenuGrace(menuContent, { timeout: 300 })       // tracks the pointer direction on the menu content
//   subTrigger pointermove (mouse)  -> if (grace.isPointerMovingToSubmenu(event)) return   // else start the 100 ms open timer
//   subTrigger pointerleave (mouse) -> grace.subTriggerLeave(event, subContentOrNull)
//   item pointermove  -> skip focusing when grace.isPointerMovingToSubmenu(event)
//   item pointerleave -> skip refocusing the content when grace.isPointerMovingToSubmenu(event)
//   release() on disconnect / when the sub trigger goes away
// Tooltip / hover card (hoverable content): `hoverGrace(trigger, content, { onInTransitChange, onClose })`.

export const GRACE_TIMEOUT = 300
export const GRACE_PADDING = 5

export function isPointInPolygon(point, polygon) {
  const { x, y } = point
  let inside = false
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const { x: xi, y: yi } = polygon[i]
    const { x: xj, y: yj } = polygon[j]
    const intersect = yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi
    if (intersect) inside = !inside
  }
  return inside
}

export function isPointerInGraceArea(event, area) {
  if (!area) return false
  return isPointInPolygon({ x: event.clientX, y: event.clientY }, area)
}

export function getExitSideFromRect(point, rect) {
  const top = Math.abs(rect.top - point.y)
  const bottom = Math.abs(rect.bottom - point.y)
  const right = Math.abs(rect.right - point.x)
  const left = Math.abs(rect.left - point.x)
  switch (Math.min(top, bottom, right, left)) {
    case left:
      return "left"
    case right:
      return "right"
    case top:
      return "top"
    case bottom:
      return "bottom"
  }
}

export function getPaddedExitPoints(exitPoint, exitSide, padding = GRACE_PADDING) {
  switch (exitSide) {
    case "top":
      return [{ x: exitPoint.x - padding, y: exitPoint.y + padding }, { x: exitPoint.x + padding, y: exitPoint.y + padding }]
    case "bottom":
      return [{ x: exitPoint.x - padding, y: exitPoint.y - padding }, { x: exitPoint.x + padding, y: exitPoint.y - padding }]
    case "left":
      return [{ x: exitPoint.x + padding, y: exitPoint.y - padding }, { x: exitPoint.x + padding, y: exitPoint.y + padding }]
    case "right":
      return [{ x: exitPoint.x - padding, y: exitPoint.y - padding }, { x: exitPoint.x - padding, y: exitPoint.y + padding }]
  }
}

export function getPointsFromRect({ top, right, bottom, left }) {
  return [{ x: left, y: top }, { x: right, y: top }, { x: right, y: bottom }, { x: left, y: bottom }]
}

// Andrew's monotone chain, exactly as Radix writes it.
export function getHull(points) {
  const sorted = points.slice().sort((a, b) => a.x - b.x || a.y - b.y)
  if (sorted.length <= 1) return sorted
  const upperHull = []
  for (const p of sorted) {
    while (upperHull.length >= 2) {
      const q = upperHull[upperHull.length - 1]
      const r = upperHull[upperHull.length - 2]
      if ((q.x - r.x) * (p.y - r.y) >= (q.y - r.y) * (p.x - r.x)) upperHull.pop()
      else break
    }
    upperHull.push(p)
  }
  upperHull.pop()
  const lowerHull = []
  for (let i = sorted.length - 1; i >= 0; i--) {
    const p = sorted[i]
    while (lowerHull.length >= 2) {
      const q = lowerHull[lowerHull.length - 1]
      const r = lowerHull[lowerHull.length - 2]
      if ((q.x - r.x) * (p.y - r.y) >= (q.y - r.y) * (p.x - r.x)) lowerHull.pop()
      else break
    }
    lowerHull.push(p)
  }
  lowerHull.pop()
  if (upperHull.length === 1 && lowerHull.length === 1 && upperHull[0].x === lowerHull[0].x && upperHull[0].y === lowerHull[0].y) return upperHull
  return upperHull.concat(lowerHull)
}

// Menu content: pointer direction (mouse only) + the grace intent of the sub trigger that was just left.
export function submenuGrace(content, { timeout = GRACE_TIMEOUT } = {}) {
  let intent = null // { area, side }
  let direction = "right"
  let lastX = 0
  let timer = 0

  const track = (event) => {
    if (event.pointerType !== "mouse") return
    if (content.contains(event.target) && lastX !== event.clientX) {
      direction = event.clientX > lastX ? "right" : "left"
      lastX = event.clientX
    }
  }
  content.addEventListener("pointermove", track)

  const clearIntent = () => {
    intent = null
  }
  const isPointerMovingToSubmenu = (event) => direction === intent?.side && isPointerInGraceArea(event, intent?.area)

  return {
    isPointerMovingToSubmenu,
    clearIntent,
    // Sub trigger pointerleave. Returns true when the pointer is heading into the sub content (the caller must not refocus the menu).
    subTriggerLeave(event, subContent) {
      if (!subContent) {
        clearIntent()
        return false
      }
      const rect = subContent.getBoundingClientRect()
      const side = subContent.dataset.side
      const rightSide = side === "right"
      const bleed = rightSide ? -5 : 5
      const nearEdge = rect[rightSide ? "left" : "right"]
      const farEdge = rect[rightSide ? "right" : "left"]
      intent = {
        // Bleed on clientX keeps the exit point inside the polygon.
        area: [
          { x: event.clientX + bleed, y: event.clientY },
          { x: nearEdge, y: rect.top },
          { x: farEdge, y: rect.top },
          { x: farEdge, y: rect.bottom },
          { x: nearEdge, y: rect.bottom }
        ],
        side
      }
      window.clearTimeout(timer)
      timer = window.setTimeout(clearIntent, timeout)
      return isPointerMovingToSubmenu(event)
    },
    release() {
      content.removeEventListener("pointermove", track)
      window.clearTimeout(timer)
      clearIntent()
    }
  }
}

// Tooltip / hover card hoverable content: when the pointer leaves `trigger` (or `content`) build the hull between the padded exit
// point and the other element's rect; while the pointer stays in the hull it is "in transit", leaving it calls onClose.
export function hoverGrace(trigger, content, { onInTransitChange, onClose, padding = GRACE_PADDING } = {}) {
  let area = null
  let stopTracking = null

  const remove = () => {
    area = null
    stopTracking?.()
    stopTracking = null
    onInTransitChange?.(false)
  }

  const track = (event) => {
    const hasEnteredTarget = trigger.contains(event.target) || content.contains(event.target)
    if (hasEnteredTarget) return remove()
    if (!isPointInPolygon({ x: event.clientX, y: event.clientY }, area)) {
      remove()
      onClose?.()
    }
  }

  const create = (event, hoverTarget) => {
    const exitPoint = { x: event.clientX, y: event.clientY }
    const exitSide = getExitSideFromRect(exitPoint, event.currentTarget.getBoundingClientRect())
    area = getHull([...getPaddedExitPoints(exitPoint, exitSide, padding), ...getPointsFromRect(hoverTarget.getBoundingClientRect())])
    onInTransitChange?.(true)
    if (!stopTracking) {
      // Radix attaches the document listener in an effect, i.e. after the pointer event that created the area: the very
      // pointermove that follows the leave never reaches it. A zero timeout reproduces that ordering.
      const attach = window.setTimeout(() => document.addEventListener("pointermove", track), 0)
      stopTracking = () => {
        window.clearTimeout(attach)
        document.removeEventListener("pointermove", track)
      }
    }
  }

  const onTriggerLeave = (event) => create(event, content)
  const onContentLeave = (event) => create(event, trigger)
  trigger.addEventListener("pointerleave", onTriggerLeave)
  content.addEventListener("pointerleave", onContentLeave)

  return {
    release() {
      trigger.removeEventListener("pointerleave", onTriggerLeave)
      content.removeEventListener("pointerleave", onContentLeave)
      remove()
    }
  }
}
