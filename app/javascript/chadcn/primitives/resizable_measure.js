// DOM reads of react-resizable-panels 4.14.3 (spec: dev/port/specs/resizable.md): group and panel sizes, CSS units in pixels, the
// hit regions between panels and whether another element covers one (stacking order). Reads only; it writes nothing.
//
// An axis is the group record the controller builds: `{ element, orientation, items, separators, disabled, resizeTargetMinimumSize,
// resizePreviewMode, mutableState, id }`, where an item is `{ element, id, constraintProps, mutableValues, onResize }` and a
// separator `{ element, id, disabled, disableDoubleClick, preview }`.

import { assert, deriveConstraints, parseSize } from "chadcn/primitives/resizable_layout"
import { closestRect, expandRect, makeRect, nearestRegion, overlaps } from "chadcn/primitives/resizable_geometry"

// --- sizes -----------------------------------------------------------------------------------------------------------------

export function toPixels({ axisSize, element, value }) {
  const [number, unit] = parseSize(value)
  switch (unit) {
    case "%": return number / 100 * axisSize
    case "px": return number
    case "rem": return number * parseFloat(getComputedStyle(element.ownerDocument.documentElement).fontSize)
    case "em": return number * parseFloat(getComputedStyle(element).fontSize)
    case "vh": return number / 100 * window.innerHeight
    case "vw": return number / 100 * window.innerWidth
  }
}

export const itemPixels = (axis, item) => (axis.orientation === "horizontal" ? item.element.offsetWidth : item.element.offsetHeight)

export function axisSizeOf(axis) {
  return axis.items.reduce((total, item) => total + itemPixels(axis, item), 0)
}

// Size `value` (any size prop) of `item` in percent of the group, as the imperative resize takes it.
export function percentOfAxis(axis, item, value) {
  const axisSize = axisSizeOf(axis)
  return toPixels({ axisSize, element: item.element, value }) / axisSize * 100
}

export function measureConstraints(axis) {
  const axisSize = axisSizeOf(axis)
  return deriveConstraints({ items: axis.items, axisSize, toPixels: (value, item) => toPixels({ axisSize, element: item.element, value }) })
}

// --- order -----------------------------------------------------------------------------------------------------------------

export function documentOrder(a, b) {
  const position = a.compareDocumentPosition(b)
  return position & Node.DOCUMENT_POSITION_DISCONNECTED ? 0 : position & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : position & Node.DOCUMENT_POSITION_PRECEDING ? 1 : 0
}

// Records with an `element`, in visual order along `orientation`, document order on a tie.
export function sortByPosition(orientation, entries) {
  return Array.from(entries).sort((a, b) => {
    const delta = orientation === "horizontal" ? a.element.offsetLeft - b.element.offsetLeft || a.element.offsetWidth - b.element.offsetWidth
      : a.element.offsetTop - b.element.offsetTop || a.element.offsetHeight - b.element.offsetHeight
    return delta !== 0 ? delta : documentOrder(a.element, b.element)
  })
}

// React mounts a nested group before its parent (child effects run first), so the library lists inner groups first; Stimulus
// connects a parent first, hence the post-order sort. The first hit separator receives focus on pointerdown.
const postOrder = (a, b) => (a.element.contains(b.element) ? 1 : b.element.contains(a.element) ? -1 : documentOrder(a.element, b.element))

const isElement = (value) => value !== null && typeof value === "object" && "nodeType" in value && value.nodeType === Node.ELEMENT_NODE

// --- hit regions -----------------------------------------------------------------------------------------------------------

function minimumTargetSize(axis, expandHitTargets) {
  if (!expandHitTargets) return 0
  const coarse = typeof matchMedia === "function" ? !!matchMedia("(pointer:coarse)").matches : false
  return coarse ? axis.resizeTargetMinimumSize.coarse : axis.resizeTargetMinimumSize.fine
}

// The draggable regions of a group: `{ axis, axisSize, items: [before, after], separator, rect }`, one per separator, or the
// gap between two adjacent panels when there is no separator.
export function hitRegionsOf({ expandHitTargets = true, axis, includeDisabled = false }) {
  const { element, orientation, items, separators } = axis
  const minimum = minimumTargetSize(axis, expandHitTargets)
  const children = sortByPosition(
    orientation,
    Array.from(element.children).filter(isElement).filter((child) => !child.hasAttribute("data-resize-preview")).map((child) => ({ element: child }))
  ).map(({ element: child }) => child)
  const regions = []
  let skipNext = false
  let gapBetween = false
  let firstEnabled = -1
  let previous
  let lastEnabled = -1
  let enabledCount = 0
  let pending = []
  {
    let index = -1
    for (const child of children) {
      if (child.hasAttribute("data-panel")) {
        index++
        if (!child.hasAttribute("data-disabled")) {
          enabledCount++
          if (firstEnabled === -1) firstEnabled = index
          lastEnabled = index
        }
      }
    }
  }
  let axisSize
  if (includeDisabled || enabledCount > 1) {
    let index = -1
    for (const child of children) {
      if (child.hasAttribute("data-panel")) {
        index++
        const item = items.find((candidate) => candidate.element === child)
        if (!item) continue
        if (previous) {
          const previousRect = previous.element.getBoundingClientRect()
          const rect = child.getBoundingClientRect()
          let candidates
          if (gapBetween) {
            const end = orientation === "horizontal" ? makeRect(previousRect.right, previousRect.top, 0, previousRect.height) : makeRect(previousRect.left, previousRect.bottom, previousRect.width, 0)
            const start = orientation === "horizontal" ? makeRect(rect.left, rect.top, 0, rect.height) : makeRect(rect.left, rect.top, rect.width, 0)
            switch (pending.length) {
              case 0: candidates = [end, start]; break
              case 1: {
                const only = pending[0]
                const closest = closestRect({ orientation, rects: [previousRect, rect], targetRect: only.element.getBoundingClientRect() })
                candidates = [only, closest === previousRect ? start : end]
                break
              }
              default: candidates = pending
            }
          } else if (pending.length) {
            candidates = pending
          } else {
            candidates = [orientation === "horizontal" ? makeRect(previousRect.right, rect.top, rect.left - previousRect.right, rect.height)
              : makeRect(rect.left, previousRect.bottom, rect.width, rect.top - previousRect.bottom)]
          }
          for (const candidate of candidates) {
            const isRect = "width" in candidate
            const region = expandRect({ minimum, rect: isRect ? candidate : candidate.element.getBoundingClientRect() })
            const outside = index <= firstEnabled || index > lastEnabled
            if (includeDisabled || (!skipNext && !outside)) {
              axisSize ??= axisSizeOf(axis)
              regions.push({ axis, axisSize, items: [previous, item], separator: isRect ? undefined : candidate, rect: region })
            }
            skipNext = false
          }
        }
        gapBetween = false
        previous = item
        pending = []
      } else if (child.hasAttribute("data-separator")) {
        if (child.ariaDisabled !== null) skipNext = true
        const separator = separators.find((candidate) => candidate.element === child)
        if (separator) {
          pending.push(separator)
        } else {
          previous = undefined
          pending = []
        }
      } else {
        gapBetween = true
      }
    }
  }
  return regions
}

// The hit region under the pointer of `event` in each enabled group of `axes` (a Map keyed by axis), inner groups first.
export function pointerHits(event, axes) {
  const hits = []
  const point = { x: event.clientX, y: event.clientY }
  Array.from(axes.keys()).sort(postOrder).forEach((axis) => {
    if (axis.disabled) return
    const { region, hit } = nearestRegion({ orientation: axis.orientation, point, regions: hitRegionsOf({ axis }) })
    if (hit && isReachable({ axisElement: axis.element, hitRegion: region.rect, pointerEventTarget: event.target })) hits.push(region)
  })
  return hits
}

// --- stacking order (is the region covered by another element?) ------------------------------------------------------------

const parentOf = (node) => (node.parentNode?.nodeType === Node.DOCUMENT_FRAGMENT_NODE ? node.parentNode.host : node.parentNode)

function ancestorsOf(node) {
  const list = []
  for (; node; node = parentOf(node)) list.push(node)
  return list
}

const STACKING_PROPERTIES = /\b(?:position|zIndex|opacity|transform|webkitTransform|mixBlendMode|filter|webkitFilter|isolation)\b/

function isFlexItem(element) {
  const display = getComputedStyle(parentOf(element) ?? element).display
  return display === "flex" || display === "inline-flex"
}

function createsStackingContext(element) {
  const style = getComputedStyle(element)
  return !!(style.position === "fixed" || (style.zIndex !== "auto" && (style.position !== "static" || isFlexItem(element))) || +style.opacity < 1 ||
    ("transform" in style && style.transform !== "none") || ("webkitTransform" in style && style.webkitTransform !== "none") ||
    ("mixBlendMode" in style && style.mixBlendMode !== "normal") || ("filter" in style && style.filter !== "none") ||
    ("webkitFilter" in style && style.webkitFilter !== "none") || ("isolation" in style && style.isolation === "isolate") ||
    STACKING_PROPERTIES.test(style.willChange) || style.webkitOverflowScrolling === "touch")
}

function stackingContextOf(path) {
  for (let index = path.length; index--;) {
    const node = path[index]
    assert(node, "Missing node")
    if (createsStackingContext(node)) return node
  }
  return null
}

const zIndexOf = (element) => (element && Number(getComputedStyle(element).zIndex)) || 0

// 1 when `a` paints above `b`, -1 below (rrp.js stacking order, after the `stacking-order` package).
export function compareStacking(a, b) {
  if (a === b) throw new Error("Cannot compare node with itself")
  const paths = { a: ancestorsOf(a), b: ancestorsOf(b) }
  let common
  while (paths.a.at(-1) === paths.b.at(-1)) {
    common = paths.a.pop()
    paths.b.pop()
  }
  assert(common, "Stacking order can only be calculated for elements with a common ancestor")
  const zIndexes = { a: zIndexOf(stackingContextOf(paths.a)), b: zIndexOf(stackingContextOf(paths.b)) }
  if (zIndexes.a === zIndexes.b) {
    const children = common.childNodes
    const branches = { a: paths.a.at(-1), b: paths.b.at(-1) }
    let index = children.length
    while (index--) {
      const child = children[index]
      if (child === branches.a) return 1
      if (child === branches.b) return -1
    }
  }
  return Math.sign(zIndexes.a - zIndexes.b)
}

function isModal(dialog) {
  try { return dialog.matches(":modal") } catch { return false }
}

// False when the pointer target sits in a modal dialog outside the group, or paints above the hit region and covers it.
export function isReachable({ axisElement, hitRegion, pointerEventTarget }) {
  if (isElement(pointerEventTarget)) {
    const dialog = pointerEventTarget.closest("dialog")
    if (dialog && !dialog.contains(axisElement) && isModal(dialog)) return false
  }
  if (!isElement(pointerEventTarget) || pointerEventTarget.contains(axisElement) || axisElement.contains(pointerEventTarget)) return true
  if (compareStacking(pointerEventTarget, axisElement) > 0) {
    for (let node = pointerEventTarget; node; node = node.parentElement) {
      if (node.contains(axisElement)) return true
      if (overlaps(node.getBoundingClientRect(), hitRegion)) return false
    }
  }
  return true
}
