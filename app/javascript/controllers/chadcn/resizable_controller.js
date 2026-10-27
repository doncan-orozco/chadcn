import { Controller } from "@hotwired/stimulus"
import { mountTemplate } from "chadcn/primitives/template_mount"

// react-resizable-panels 4.14.3 (Group, Panel, Separator) behind shadcn Resizable. Spec: dev/port/specs/resizable.md.
// The functions below are a literal port of the library (same float operations and rounding, because aria values and flex-grow
// are compared as strings); the spec cites each one by its line in dist/react-resizable-panels.js. The host element is the
// group div; its panels and separators are its direct children (a nested group is a separate controller). The pointer
// listeners and the cursor sheet are shared by all groups of a document, like the library's module state.

const assert = (condition, message) => {
  if (!condition) throw new Error(message)
}

// --- numbers ---------------------------------------------------------------------------------------------------------------

const round = (value) => parseFloat(value.toFixed(3))
const near = (a, b, tolerance = 0) => Math.abs(round(a) - round(b)) <= tolerance
const compare = (a, b) => (near(a, b) ? 0 : a > b ? 1 : -1)

function layoutsEqual(a, b) {
  if (Object.keys(a).length !== Object.keys(b).length) return false
  for (const id in a) if (b[id] === undefined || compare(a[id], b[id]) !== 0) return false
  return true
}

function arraysLooselyEqual(a, b) {
  if (a.length !== b.length) return false
  for (let index = 0; index < a.length; index++) if (a[index] != b[index]) return false
  return true
}

function recordsEqual(a, b) {
  if (Object.keys(a).length !== Object.keys(b).length) return false
  for (const key in a) if (a[key] !== b[key]) return false
  return true
}

// --- sizes -----------------------------------------------------------------------------------------------------------------

function parseSize(value) {
  switch (typeof value) {
    case "number": return [value, "px"]
    case "string": {
      const number = parseFloat(value)
      return value.endsWith("%") ? [number, "%"] : value.endsWith("px") ? [number, "px"] : value.endsWith("rem") ? [number, "rem"]
        : value.endsWith("em") ? [number, "em"] : value.endsWith("vh") ? [number, "vh"] : value.endsWith("vw") ? [number, "vw"] : [number, "%"]
    }
  }
}

function toPixels({ axisSize, element, value }) {
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

function axisSizeOf(axis) {
  return axis.items.reduce((total, item) => total + (axis.orientation === "horizontal" ? item.element.offsetWidth : item.element.offsetHeight), 0)
}

function deriveConstraints(axis) {
  const { items } = axis
  const axisSize = axisSizeOf(axis)
  if (axisSize === 0) {
    return items.map((item) => ({
      groupResizeBehavior: item.constraintProps.groupResizeBehavior,
      collapsedSize: 0,
      collapsible: item.constraintProps.collapsible === true,
      defaultSize: undefined,
      disabled: item.constraintProps.disabled,
      minSize: 0,
      maxSize: 100,
      itemId: item.id
    }))
  }
  return items.map((item) => {
    const { element, constraintProps } = item
    const percent = (value) => round(toPixels({ axisSize, element, value }) / axisSize * 100)
    return {
      groupResizeBehavior: constraintProps.groupResizeBehavior,
      collapsedSize: constraintProps.collapsedSize === undefined ? 0 : percent(constraintProps.collapsedSize),
      collapsedThreshold: constraintProps.collapsedThreshold === undefined ? undefined : percent(constraintProps.collapsedThreshold),
      collapsible: constraintProps.collapsible === true,
      defaultSize: constraintProps.defaultSize === undefined ? undefined : percent(constraintProps.defaultSize),
      disabled: constraintProps.disabled,
      minSize: constraintProps.minSize === undefined ? 0 : percent(constraintProps.minSize),
      maxSize: constraintProps.maxSize === undefined ? 100 : percent(constraintProps.maxSize),
      itemId: item.id
    }
  })
}

// --- layout math -----------------------------------------------------------------------------------------------------------

function validateSize({ overrideDisabledItems, itemConstraints, prevSize, size }) {
  const { collapsedSize = 0, collapsedThreshold, collapsible, disabled, maxSize = 100, minSize = 0 } = itemConstraints
  if (disabled && !overrideDisabledItems) return prevSize
  if (compare(size, minSize) < 0) {
    if (collapsible) {
      const threshold = collapsedThreshold ?? (minSize - collapsedSize) / 2
      const wasCollapsed = compare(prevSize, collapsedSize) <= 0
      const limit = wasCollapsed ? collapsedSize + threshold : minSize - threshold
      const against = compare(size, limit)
      size = compare(size, collapsedSize) <= 0 || against < 0 || (collapsedThreshold !== undefined && wasCollapsed && against === 0) ? collapsedSize : minSize
    } else {
      size = minSize
    }
  }
  return round(Math.min(maxSize, size))
}

function resizeByDelta({ delta, initialLayout, itemConstraints, pivotIndices, prevLayout, trigger }) {
  if (near(delta, 0)) return initialLayout
  const override = trigger === "imperative-api"
  const initial = itemConstraints.map(({ itemId }) => initialLayout[itemId])
  const previous = itemConstraints.map(({ itemId }) => prevLayout[itemId])
  const next = [...initial]
  const [first, second] = pivotIndices
  assert(first != null, "Invalid first pivot index")
  assert(second != null, "Invalid second pivot index")
  let consumed = 0
  switch (trigger) {
    case "keyboard": {
      {
        const index = delta < 0 ? second : first
        const constraints = itemConstraints[index]
        assert(constraints, `Panel constraints not found for index ${index}`)
        const { collapsedSize = 0, collapsible, minSize = 0 } = constraints
        if (collapsible) {
          const size = initial[index]
          assert(size != null, `Previous layout not found for panel index ${index}`)
          if (near(size, collapsedSize)) {
            const gap = minSize - size
            if (compare(gap, Math.abs(delta)) > 0) delta = delta < 0 ? 0 - gap : gap
          }
        }
      }
      {
        const index = delta < 0 ? first : second
        const constraints = itemConstraints[index]
        assert(constraints, `No panel constraints found for index ${index}`)
        const { collapsedSize = 0, collapsible, minSize = 0 } = constraints
        if (collapsible) {
          const size = initial[index]
          assert(size != null, `Previous layout not found for panel index ${index}`)
          if (near(size, minSize)) {
            const gap = size - collapsedSize
            if (compare(gap, Math.abs(delta)) > 0) delta = delta < 0 ? 0 - gap : gap
          }
        }
      }
      break
    }
    default: {
      const index = delta < 0 ? second : first
      const constraints = itemConstraints[index]
      assert(constraints, `Panel constraints not found for index ${index}`)
      const size = initial[index]
      const { collapsedSize, collapsedThreshold, collapsible, minSize } = constraints
      if (collapsible && compare(size, minSize) < 0) {
        const span = minSize - collapsedSize
        const threshold = collapsedThreshold ?? span / 2
        const grown = size + Math.abs(delta)
        if (compare(grown, minSize) < 0) {
          const against = compare(Math.abs(delta), threshold)
          const rounding = collapsedThreshold === undefined && delta < 0
          delta = against > 0 || (against === 0 && rounding) ? (delta < 0 ? -span : span) : 0
        }
      }
      break
    }
  }
  {
    const step = delta < 0 ? 1 : -1
    let index = delta < 0 ? second : first
    let room = 0
    for (;;) {
      const size = initial[index]
      assert(size != null, `Previous layout not found for panel index ${index}`)
      room += validateSize({ overrideDisabledItems: override, itemConstraints: itemConstraints[index], prevSize: size, size: 100 }) - size
      index += step
      if (index < 0 || index >= itemConstraints.length) break
    }
    const limit = Math.min(Math.abs(delta), Math.abs(room))
    delta = delta < 0 ? 0 - limit : limit
  }
  {
    let index = delta < 0 ? first : second
    while (index >= 0 && index < itemConstraints.length) {
      const remaining = Math.abs(delta) - Math.abs(consumed)
      const size = initial[index]
      assert(size != null, `Previous layout not found for panel index ${index}`)
      const shrunk = validateSize({ overrideDisabledItems: override, itemConstraints: itemConstraints[index], prevSize: size, size: size - remaining })
      if (!near(size, shrunk)) {
        consumed += size - shrunk
        next[index] = shrunk
        if (consumed.toFixed(3).localeCompare(Math.abs(delta).toFixed(3), undefined, { numeric: true }) >= 0) break
      }
      if (delta < 0) index--
      else index++
    }
  }
  if (arraysLooselyEqual(previous, next)) return prevLayout
  {
    const index = delta < 0 ? second : first
    const size = initial[index]
    assert(size != null, `Previous layout not found for panel index ${index}`)
    const grown = size + consumed
    const accepted = validateSize({ overrideDisabledItems: override, itemConstraints: itemConstraints[index], prevSize: size, size: grown })
    next[index] = accepted
    if (!near(accepted, grown)) {
      let overflow = grown - accepted
      let outward = delta < 0 ? second : first
      while (outward >= 0 && outward < itemConstraints.length) {
        const current = next[outward]
        assert(current != null, `Previous layout not found for panel index ${outward}`)
        const pushed = validateSize({ overrideDisabledItems: override, itemConstraints: itemConstraints[outward], prevSize: current, size: current + overflow })
        if (!near(current, pushed)) {
          overflow -= pushed - current
          next[outward] = pushed
        }
        if (near(overflow, 0)) break
        if (delta > 0) outward--
        else outward++
      }
    }
  }
  const total = Object.values(next).reduce((sum, size) => size + sum, 0)
  return near(total, 100, 0.1) ? next.reduce((layout, size, index) => { layout[itemConstraints[index].itemId] = size; return layout }, {}) : prevLayout
}

function validateLayout({ layout, itemConstraints }) {
  const original = itemConstraints.map(({ itemId }) => layout[itemId])
  const sizes = [...original]
  const total = sizes.reduce((sum, size) => sum + size, 0)
  if (Object.keys(layout).length !== itemConstraints.length) {
    throw new Error(`Invalid ${itemConstraints.length} panel layout: ${Object.values(layout).map((size) => `${size}%`).join(", ")}`)
  }
  if (!near(total, 100) && sizes.length > 0) {
    for (let index = 0; index < itemConstraints.length; index++) {
      assert(sizes[index] != null, `No layout data found for index ${index}`)
      sizes[index] = 100 / total * sizes[index]
    }
  }
  let remainder = 0
  for (let index = 0; index < itemConstraints.length; index++) {
    assert(original[index] != null, `No layout data found for index ${index}`)
    const size = sizes[index]
    assert(size != null, `No layout data found for index ${index}`)
    const valid = validateSize({ overrideDisabledItems: true, itemConstraints: itemConstraints[index], prevSize: original[index], size })
    if (size != valid) {
      remainder += size - valid
      sizes[index] = valid
    }
  }
  if (!near(remainder, 0)) {
    for (let index = 0; index < itemConstraints.length; index++) {
      const size = sizes[index]
      assert(size != null, `No layout data found for index ${index}`)
      const valid = validateSize({ overrideDisabledItems: true, itemConstraints: itemConstraints[index], prevSize: size, size: size + remainder })
      if (size !== valid) {
        remainder -= valid - size
        sizes[index] = valid
        if (near(remainder, 0)) break
      }
    }
  }
  return sizes.reduce((result, size, index) => { result[itemConstraints[index].itemId] = size; return result }, {})
}

function ariaValues({ layout, itemConstraints, itemId, itemIndex }) {
  let valueMax
  let valueMin
  const valueNow = layout[itemId]
  const constraints = itemConstraints.find((candidate) => candidate.itemId === itemId)
  if (constraints) {
    const upper = constraints.maxSize
    const lower = constraints.collapsible ? constraints.collapsedSize : constraints.minSize
    const pivots = [itemIndex, itemIndex + 1]
    valueMin = validateLayout({
      layout: resizeByDelta({ delta: lower - valueNow, initialLayout: layout, itemConstraints, pivotIndices: pivots, prevLayout: layout }),
      itemConstraints
    })[itemId]
    valueMax = validateLayout({
      layout: resizeByDelta({ delta: upper - valueNow, initialLayout: layout, itemConstraints, pivotIndices: pivots, prevLayout: layout }),
      itemConstraints
    })[itemId]
  }
  return { valueControls: itemId, valueMax, valueMin, valueNow }
}

function defaultItemLayout(constraints) {
  let withDefault = 0
  let sum = 0
  const layout = {}
  for (const item of constraints) {
    if (item.defaultSize !== undefined) {
      withDefault++
      const size = round(item.defaultSize)
      sum += size
      layout[item.itemId] = size
    } else {
      layout[item.itemId] = undefined
    }
  }
  const rest = constraints.length - withDefault
  if (rest !== 0) {
    const share = round((100 - sum) / rest)
    for (const item of constraints) if (item.defaultSize === undefined) layout[item.itemId] = share
  }
  return layout
}

function namesAllPanels(items, layout) {
  const ids = items.map((item) => item.id)
  const keys = Object.keys(layout)
  return ids.length === keys.length && ids.every((id) => keys.includes(id))
}

function initialLayoutOf({ axis, itemConstraints }) {
  const key = axis.items.map(({ id }) => id).join(",")
  const given = axis.mutableState.defaultLayout
  return axis.mutableState.layouts[key] ?? (given && namesAllPanels(axis.items, given) ? given : defaultItemLayout(itemConstraints))
}

function looseLayout({ itemIds, layout }) {
  return validateLayout({
    layout,
    itemConstraints: itemIds.map((itemId) => ({ collapsedSize: 0, collapsible: false, defaultSize: undefined, disabled: undefined, itemId, maxSize: 100, minSize: 0 }))
  })
}

function rescaleForGroupSize({ axis, nextAxisSize, prevAxisSize, prevLayout }) {
  if (prevAxisSize <= 0 || nextAxisSize <= 0 || prevAxisSize === nextAxisSize) return prevLayout
  let pixelTotal = 0
  let relativeTotal = 0
  let preservesPixels = false
  const pixels = new Map()
  const relative = []
  for (const item of axis.items) {
    const size = prevLayout[item.id] ?? 0
    switch (item.constraintProps.groupResizeBehavior) {
      case "preserve-pixel-size": {
        preservesPixels = true
        const kept = round(size / 100 * prevAxisSize / nextAxisSize * 100)
        pixels.set(item.id, kept)
        pixelTotal += kept
        break
      }
      default: {
        relative.push(item.id)
        relativeTotal += size
      }
    }
  }
  if (!preservesPixels || relative.length === 0) return prevLayout
  const available = 100 - pixelTotal
  const result = { ...prevLayout }
  pixels.forEach((size, id) => { result[id] = size })
  if (relativeTotal > 0) {
    for (const id of relative) result[id] = round((prevLayout[id] ?? 0) / relativeTotal * available)
  } else {
    const share = round(available / relative.length)
    for (const id of relative) result[id] = share
  }
  return result
}

function recordExpandedSize({ derivedItemConstraints, axis, layout, prevLayout, requestedLayout }) {
  axis.mutableState.layouts[axis.items.map(({ id }) => id).join(",")] = requestedLayout
  if (!prevLayout) return
  derivedItemConstraints.forEach((constraints) => {
    if (!constraints.collapsible) return
    const collapsedNow = near(constraints.collapsedSize, layout[constraints.itemId])
    const collapsedBefore = near(constraints.collapsedSize, prevLayout[constraints.itemId])
    if (collapsedNow && !collapsedBefore) axis.mutableState.expandedItemSizes[constraints.itemId] = prevLayout[constraints.itemId]
  })
}

// --- shared state ----------------------------------------------------------------------------------------------------------

class Emitter {
  #listeners = []
  add(listener) {
    this.#listeners.push(listener)
    return () => { this.#listeners = this.#listeners.filter((candidate) => candidate !== listener) }
  }
  emit(payload) {
    for (const listener of [...this.#listeners]) listener(payload)
  }
}

let interaction = { cursorFlags: 0, state: "inactive" }
const interactionChanges = new Emitter()
const axisChanges = new Emitter()
let mountedAxes = new Map()
const documentRefs = new Map()
const cursorSheets = new WeakMap()

const CURSOR_LEFT = 1
const CURSOR_RIGHT = 2
const CURSOR_UP = 4
const CURSOR_DOWN = 8
const CURSOR_HORIZONTAL = 3
const CURSOR_VERTICAL = 12

function setInteraction(next) {
  const prev = interaction
  interaction = next
  if (prev.state === "active" && next.state !== "active" && prev.didPointerMove) {
    prev.hitRegions.forEach(({ separator }) => {
      if (separator && separator.element.ownerDocument.activeElement === separator.element) separator.element.blur()
    })
  }
  interactionChanges.emit({ prev, next })
}

function updateDrag(cursorFlags, previews = [], previewLayoutMap, didPointerMove = false) {
  const prev = interaction
  const next = { ...interaction }
  next.cursorFlags = cursorFlags
  if (next.state === "active") {
    next.didPointerMove ||= didPointerMove
    next.previews = previews
    if (previewLayoutMap) next.previewLayoutMap = previewLayoutMap
  }
  interaction = next
  interactionChanges.emit({ prev, next })
}

function dropAxisFromInteraction(axis) {
  if (interaction.state === "inactive") return false
  const regions = interaction.hitRegions.filter((region) => region.axis !== axis)
  const hadPreview = interaction.state === "active" && interaction.previews.some((preview) => preview.axis === axis)
  if (regions.length === interaction.hitRegions.length && !hadPreview) return false
  if (regions.length === 0) {
    setInteraction({ cursorFlags: 0, state: "inactive" })
  } else if (interaction.state === "active") {
    const initial = new Map(interaction.initialLayoutMap)
    const previewLayouts = new Map(interaction.previewLayoutMap)
    initial.delete(axis)
    previewLayouts.delete(axis)
    setInteraction({
      ...interaction,
      cursorFlags: 0,
      hitRegions: regions,
      initialLayoutMap: initial,
      previewLayoutMap: previewLayouts,
      previews: interaction.previews.filter((preview) => preview.axis !== axis)
    })
  } else {
    setInteraction({ ...interaction, hitRegions: regions })
  }
  return true
}

function storeAxisState(axis, state, options) {
  const prev = mountedAxes.get(axis)
  mountedAxes = new Map(mountedAxes)
  mountedAxes.set(axis, state)
  axisChanges.emit({ axis, isUserInteraction: options?.isUserInteraction === true, prev, next: state })
}

function stateOfAxis(id, required) {
  for (const [axis, state] of mountedAxes) if (axis.id === id) return state
  if (required) throw new Error(`Could not find data for Group with id ${id}`)
}

function onAxisChange(id, listener) {
  return axisChanges.add((change) => { if (change.axis.id === id) listener(change) })
}

// --- cursor ----------------------------------------------------------------------------------------------------------------

const chromiumLike = () => window.navigator.userAgent.includes("Chrome") || window.navigator.userAgent.includes("Firefox")

function cursorFor({ cursorFlags, axes, state }) {
  let horizontal = 0
  let vertical = 0
  if (state === "active" || state === "hover") {
    axes.forEach((axis) => {
      if (axis.mutableState.disableCursor) return
      if (axis.orientation === "horizontal") horizontal++
      else vertical++
    })
  }
  if (horizontal === 0 && vertical === 0) return undefined
  if (state === "active" && cursorFlags && chromiumLike()) {
    const left = (cursorFlags & CURSOR_LEFT) !== 0
    const right = (cursorFlags & CURSOR_RIGHT) !== 0
    const up = (cursorFlags & CURSOR_UP) !== 0
    const down = (cursorFlags & CURSOR_DOWN) !== 0
    if (left) return up ? "se-resize" : down ? "ne-resize" : "e-resize"
    if (right) return up ? "sw-resize" : down ? "nw-resize" : "w-resize"
    if (up) return "s-resize"
    if (down) return "n-resize"
  }
  if (chromiumLike()) return horizontal > 0 && vertical > 0 ? "move" : horizontal > 0 ? "ew-resize" : "ns-resize"
  return horizontal > 0 && vertical > 0 ? "grab" : horizontal > 0 ? "col-resize" : "row-resize"
}

function updateCursor(document) {
  if (!document.defaultView || !document.adoptedStyleSheets) return
  let { previousRule, sheet } = cursorSheets.get(document) ?? {}
  if (sheet === undefined) {
    sheet = new document.defaultView.CSSStyleSheet()
    if (Object.isExtensible(document.adoptedStyleSheets)) document.adoptedStyleSheets.push(sheet)
    else document.adoptedStyleSheets = [...document.adoptedStyleSheets, sheet]
  }
  switch (interaction.state) {
    case "active":
    case "hover": {
      const cursor = cursorFor({ cursorFlags: interaction.cursorFlags, axes: interaction.hitRegions.map((region) => region.axis), state: interaction.state })
      const rule = `*, *:hover {cursor: ${cursor} !important; }`
      if (previousRule === rule) return
      previousRule = rule
      if (cursor) {
        if (sheet.cssRules.length === 0) sheet.insertRule(rule)
        else sheet.replaceSync(rule)
      } else if (sheet.cssRules.length === 1) {
        sheet.deleteRule(0)
      }
      break
    }
    case "inactive": {
      previousRule = undefined
      if (sheet.cssRules.length === 1) sheet.deleteRule(0)
      break
    }
  }
  cursorSheets.set(document, { previousRule, sheet })
}

function releaseCursorSheet(document) {
  const record = cursorSheets.get(document)
  if (!record) return
  document.adoptedStyleSheets = [...document.adoptedStyleSheets].filter((sheet) => sheet !== record.sheet)
  cursorSheets.delete(document)
}

// --- geometry --------------------------------------------------------------------------------------------------------------

let coarsePointer
function isCoarsePointer() {
  if (coarsePointer === undefined) coarsePointer = typeof matchMedia === "function" ? !!matchMedia("(pointer:coarse)").matches : false
  return coarsePointer
}

function expandRect({ expandHitTargets, axis, rect }) {
  const minimum = expandHitTargets ? (isCoarsePointer() ? axis.resizeTargetMinimumSize.coarse : axis.resizeTargetMinimumSize.fine) : 0
  if (rect.width < minimum) {
    const missing = minimum - rect.width
    rect = new DOMRect(rect.x - missing / 2, rect.y, rect.width + missing, rect.height)
  }
  if (rect.height < minimum) {
    const missing = minimum - rect.height
    rect = new DOMRect(rect.x, rect.y - missing / 2, rect.width, rect.height + missing)
  }
  return rect
}

function documentOrder(a, b) {
  const position = a.compareDocumentPosition(b)
  return position & Node.DOCUMENT_POSITION_DISCONNECTED ? 0 : position & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : position & Node.DOCUMENT_POSITION_PRECEDING ? 1 : 0
}

function sortByPosition(orientation, entries) {
  return Array.from(entries).sort((a, b) => {
    const delta = orientation === "horizontal" ? a.element.offsetLeft - b.element.offsetLeft || a.element.offsetWidth - b.element.offsetWidth
      : a.element.offsetTop - b.element.offsetTop || a.element.offsetHeight - b.element.offsetHeight
    return delta !== 0 ? delta : documentOrder(a.element, b.element)
  })
}

const isElement = (value) => value !== null && typeof value === "object" && "nodeType" in value && value.nodeType === Node.ELEMENT_NODE

function pointerDistance(point, rect) {
  return {
    x: point.x >= rect.left && point.x <= rect.right ? 0 : Math.min(Math.abs(point.x - rect.left), Math.abs(point.x - rect.right)),
    y: point.y >= rect.top && point.y <= rect.bottom ? 0 : Math.min(Math.abs(point.y - rect.top), Math.abs(point.y - rect.bottom))
  }
}

function closestRect({ orientation, rects, targetRect }) {
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

function hitRegionsOf({ expandHitTargets = true, axis, includeDisabled = false }) {
  const { element, orientation, items, separators } = axis
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
            const end = orientation === "horizontal" ? new DOMRect(previousRect.right, previousRect.top, 0, previousRect.height) : new DOMRect(previousRect.left, previousRect.bottom, previousRect.width, 0)
            const start = orientation === "horizontal" ? new DOMRect(rect.left, rect.top, 0, rect.height) : new DOMRect(rect.left, rect.top, rect.width, 0)
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
            candidates = [orientation === "horizontal" ? new DOMRect(previousRect.right, rect.top, rect.left - previousRect.right, rect.height)
              : new DOMRect(rect.left, previousRect.bottom, rect.width, rect.top - previousRect.bottom)]
          }
          for (const candidate of candidates) {
            const region = expandRect({ expandHitTargets, axis, rect: "width" in candidate ? candidate : candidate.element.getBoundingClientRect() })
            const outside = index <= firstEnabled || index > lastEnabled
            if (includeDisabled || (!skipNext && !outside)) {
              axisSize ??= axisSizeOf(axis)
              regions.push({ axis, axisSize, items: [previous, item], separator: "width" in candidate ? undefined : candidate, rect: region })
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

function pointerHits(event, axes) {
  const hits = []
  axes.forEach((_state, axis) => {
    if (axis.disabled) return
    const regions = hitRegionsOf({ axis })
    let found
    let best = { x: Infinity, y: Infinity }
    const point = { x: event.clientX, y: event.clientY }
    for (const region of regions) {
      const distance = pointerDistance(point, region.rect)
      const better = axis.orientation === "horizontal" ? distance.x < best.x || (distance.x === best.x && distance.y <= best.y)
        : distance.y < best.y || (distance.y === best.y && distance.x <= best.x)
      if (better) {
        found = region
        best = distance
      }
    }
    if (found && best.x <= 0 && best.y <= 0 && isReachable({ axisElement: axis.element, hitRegion: found.rect, pointerEventTarget: event.target })) hits.push(found)
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

function compareStacking(a, b) {
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

const overlaps = (a, b) => a.x < b.x + b.width && a.x + a.width > b.x && a.y < b.y + b.height && a.y + a.height > b.y

function isModal(dialog) {
  try { return dialog.matches(":modal") } catch { return false }
}

function isReachable({ axisElement, hitRegion, pointerEventTarget }) {
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

// --- pointer ---------------------------------------------------------------------------------------------------------------

function applyPointer({ commit, document, event, hitRegions, initialLayoutMap, axes, pointerDownAtPoint, prevCursorFlags }) {
  let flags = 0
  const current = interaction
  let previews = current.state === "active" ? current.previews : []
  const previewLayouts = new Map(current.state === "active" ? current.previewLayoutMap : undefined)
  hitRegions.forEach((region) => {
    const { axis, axisSize } = region
    const { orientation, items } = axis
    if (commit && axis.resizePreviewMode !== "separator") return
    const { disableCursor } = axis.mutableState
    let delta = 0
    if (pointerDownAtPoint) {
      delta = orientation === "horizontal" ? (event.clientX - pointerDownAtPoint.x) / axisSize * 100 : (event.clientY - pointerDownAtPoint.y) / axisSize * 100
    } else if (orientation === "horizontal") {
      delta = event.clientX < 0 ? -100 : 100
    } else {
      delta = event.clientY < 0 ? -100 : 100
    }
    const initialLayout = initialLayoutMap.get(axis)
    const state = axes.get(axis)
    if (!initialLayout || !state) return
    const { defaultLayoutDeferred, derivedItemConstraints, axisSize: stateAxisSize, layout, separatorToItems } = state
    if (!(derivedItemConstraints && layout && separatorToItems)) return
    const base = axis.resizePreviewMode === "separator" ? previewLayouts.get(axis) ?? layout : layout
    const resized = resizeByDelta({
      delta,
      initialLayout,
      itemConstraints: derivedItemConstraints,
      pivotIndices: region.items.map((item) => items.indexOf(item)),
      prevLayout: base,
      trigger: "mouse-or-touch"
    })
    if (axis.resizePreviewMode === "separator" && !commit && !layoutsEqual(resized, base)) {
      previewLayouts.set(axis, resized)
      let offset = 0
      const offsets = items.map((item) => {
        offset += resized[item.id] - initialLayout[item.id]
        return offset * (axisSize / 100)
      })
      previews = previews.map((preview) => {
        if (preview.axis !== axis) return preview
        const next = offsets[preview.itemIndex]
        return next === preview.offset ? preview : { ...preview, offset: next }
      })
    }
    if (layoutsEqual(resized, base) && delta !== 0 && !disableCursor) {
      switch (orientation) {
        case "horizontal": flags |= delta < 0 ? CURSOR_LEFT : CURSOR_RIGHT; break
        case "vertical": flags |= delta < 0 ? CURSOR_UP : CURSOR_DOWN; break
      }
    }
    if ((axis.resizePreviewMode !== "separator" || commit) && !layoutsEqual(resized, layout)) {
      storeAxisState(region.axis, {
        defaultLayoutDeferred,
        derivedItemConstraints,
        axisSize: stateAxisSize,
        layout: resized,
        requestedAxisSize: stateAxisSize,
        requestedLayout: resized,
        separatorToItems
      })
    }
  })
  let cursorFlags = 0
  cursorFlags |= event.movementX === 0 ? prevCursorFlags & CURSOR_HORIZONTAL : flags & CURSOR_HORIZONTAL
  cursorFlags |= event.movementY === 0 ? prevCursorFlags & CURSOR_VERTICAL : flags & CURSOR_VERTICAL
  const moved = current.state === "active" && (event.clientX !== current.pointerDownAtPoint.x || event.clientY !== current.pointerDownAtPoint.y)
  updateDrag(cursorFlags, previews, previewLayouts, moved)
  updateCursor(document)
}

function finishDrag(document, event) {
  const current = interaction
  let handled = false
  if (current.state === "active") {
    applyPointer({
      commit: true,
      document,
      event,
      hitRegions: current.hitRegions,
      initialLayoutMap: current.initialLayoutMap,
      axes: mountedAxes,
      pointerDownAtPoint: current.pointerDownAtPoint,
      prevCursorFlags: current.cursorFlags
    })
    setInteraction({ cursorFlags: 0, state: "inactive" })
    if (current.hitRegions.length > 0) {
      updateCursor(document)
      handled = true
      current.hitRegions.forEach((region) => {
        if (!mountedAxes.has(region.axis)) return
        storeAxisState(region.axis, stateOfAxis(region.axis.id, true), { isUserInteraction: true })
      })
    }
  }
  return handled
}

function cancelDrag(document) {
  const current = interaction
  if (current.state !== "active") return false
  current.previewLayoutMap.forEach((layout, axis) => {
    const state = mountedAxes.get(axis)
    if (axis.resizePreviewMode === "separator" && state && !layoutsEqual(layout, state.layout)) {
      storeAxisState(axis, { ...state, layout, requestedAxisSize: state.axisSize, requestedLayout: layout })
    }
  })
  setInteraction({ cursorFlags: 0, state: "inactive" })
  current.hitRegions.forEach((region) => {
    if (!mountedAxes.has(region.axis)) return
    storeAxisState(region.axis, stateOfAxis(region.axis.id, true), { isUserInteraction: true })
  })
  updateCursor(document)
  return true
}

function previewsOf(axis, hitRegions) {
  const { element, orientation, items } = axis
  const bounds = element.getBoundingClientRect()
  const horizontal = orientation === "horizontal"
  return hitRegionsOf({ expandHitTargets: false, axis, includeDisabled: true }).map(({ items: pair, rect, separator }, index) => {
    const itemIndex = items.indexOf(pair[0])
    const center = horizontal ? rect.left + rect.width / 2 : rect.top + rect.height / 2
    return {
      active: hitRegions.some((hit) => {
        if (hit.axis !== axis || hit.items[0] !== pair[0]) return false
        if (separator || hit.separator) return hit.separator === separator
        return near(center, horizontal ? hit.rect.left + hit.rect.width / 2 : hit.rect.top + hit.rect.height / 2)
      }),
      axis,
      key: separator ? `separator-${separator.id}` : `panel-${pair[0].id}-${index}`,
      offset: 0,
      itemIndex,
      rect: new DOMRect(
        (horizontal && !separator ? center : rect.left) - bounds.left - element.clientLeft + element.scrollLeft,
        (!horizontal && !separator ? center : rect.top) - bounds.top - element.clientTop + element.scrollTop,
        horizontal && !separator ? 0 : rect.width,
        !horizontal && !separator ? 0 : rect.height
      ),
      separator
    }
  })
}

function onPointerDown(event) {
  if (event.defaultPrevented) return
  if (event.pointerType === "mouse" && event.button > 0) return
  const hits = pointerHits(event, mountedAxes)
  if (hits.length === 0) return
  const layouts = new Map()
  let focused = false
  hits.forEach((hit) => {
    if (hit.separator && !focused) {
      focused = true
      hit.separator.element.focus({ focusVisible: false, preventScroll: true })
    }
    const state = mountedAxes.get(hit.axis)
    if (state) layouts.set(hit.axis, state.layout)
  })
  const previews = Array.from(layouts.keys()).flatMap((axis) => (axis.resizePreviewMode === "separator" ? previewsOf(axis, hits) : []))
  setInteraction({
    cursorFlags: 0,
    didPointerMove: false,
    hitRegions: hits,
    initialLayoutMap: layouts,
    pointerDownAtPoint: { x: event.clientX, y: event.clientY },
    previewLayoutMap: new Map(layouts),
    previews,
    state: "active"
  })
  event.preventDefault()
}

function onPointerLeave(event) {
  if (interaction.state !== "active") return
  applyPointer({
    commit: false,
    document: event.currentTarget,
    event,
    hitRegions: interaction.hitRegions,
    initialLayoutMap: interaction.initialLayoutMap,
    axes: mountedAxes,
    prevCursorFlags: interaction.cursorFlags
  })
}

function onPointerMove(event) {
  if (event.defaultPrevented) return
  const current = interaction
  switch (current.state) {
    case "active": {
      if (event.buttons === 0) {
        cancelDrag(event.currentTarget)
        return
      }
      for (const region of current.hitRegions) {
        if (!region.separator) continue
        const { element } = region.separator
        if (element.isConnected && !element.hasPointerCapture?.(event.pointerId)) element.setPointerCapture?.(event.pointerId)
      }
      applyPointer({
        commit: false,
        document: event.currentTarget,
        event,
        hitRegions: current.hitRegions,
        initialLayoutMap: current.initialLayoutMap,
        axes: mountedAxes,
        pointerDownAtPoint: current.pointerDownAtPoint,
        prevCursorFlags: current.cursorFlags
      })
      break
    }
    default: {
      const hits = pointerHits(event, mountedAxes)
      if (hits.length === 0) {
        if (current.state !== "inactive") setInteraction({ cursorFlags: 0, state: "inactive" })
      } else {
        setInteraction({ cursorFlags: 0, hitRegions: hits, state: "hover" })
      }
      updateCursor(event.currentTarget)
    }
  }
}

function onPointerOut(event) {
  if (event.relatedTarget instanceof HTMLIFrameElement && interaction.state === "hover") setInteraction({ cursorFlags: 0, state: "inactive" })
}

function onPointerUp(event) {
  if (event.defaultPrevented) return
  if (event.pointerType === "mouse" && event.button > 0) return
  if (finishDrag(event.currentTarget, event)) event.preventDefault()
}

function onContextMenu(event) {
  if (!event.defaultPrevented) finishDrag(event.currentTarget, event)
}

function onLostPointerCapture(event) {
  const current = interaction
  if (current.state !== "active") return
  const elements = current.hitRegions.flatMap(({ separator }) => (separator ? [separator.element] : []))
  if (!elements.some((element) => element === event.target) || elements.some((element) => element.hasPointerCapture?.(event.pointerId))) return
  cancelDrag(event.currentTarget)
}

function onPointerCancel(event) {
  cancelDrag(event.currentTarget)
}

function onWindowBlur(event) {
  if (event.target === event.currentTarget) cancelDrag(event.currentTarget.document)
}

function onDoubleClick(event) {
  if (event.defaultPrevented) return
  pointerHits(event, mountedAxes).forEach((region) => {
    if (!region.separator || region.separator.disableDoubleClick) return
    const item = region.items.find((candidate) => candidate.constraintProps.defaultSize !== undefined)
    if (!item) return
    const size = item.constraintProps.defaultSize
    panelApi({ axisId: region.axis.id, itemId: item.id }).resize(size)
    event.preventDefault()
  })
}

const DOCUMENT_LISTENERS = [
  ["contextmenu", onContextMenu, true], ["dblclick", onDoubleClick, true], ["lostpointercapture", onLostPointerCapture, true],
  ["pointercancel", onPointerCancel, true], ["pointerdown", onPointerDown, true], ["pointerleave", onPointerLeave, false],
  ["pointermove", onPointerMove, false], ["pointerout", onPointerOut, false], ["pointerup", onPointerUp, true]
]

function retainDocument(document) {
  const count = (documentRefs.get(document) ?? 0) + 1
  documentRefs.set(document, count)
  if (count !== 1) return
  DOCUMENT_LISTENERS.forEach(([type, listener, capture]) => document.addEventListener(type, listener, capture))
  document.defaultView?.addEventListener("blur", onWindowBlur)
}

function releaseDocument(document) {
  const count = Math.max(0, (documentRefs.get(document) ?? 0) - 1)
  documentRefs.set(document, count)
  if (count) return
  DOCUMENT_LISTENERS.forEach(([type, listener, capture]) => document.removeEventListener(type, listener, capture))
  document.defaultView?.removeEventListener("blur", onWindowBlur)
  releaseCursorSheet(document)
}

// --- imperative api --------------------------------------------------------------------------------------------------------

function panelApi({ axisId, itemId }) {
  const stateOf = () => {
    for (const [axis, state] of mountedAxes) if (axis.id === axisId) return { ...state, axis }
    throw new Error(`Group ${axisId} not found`)
  }
  const constraintsOf = () => {
    const found = stateOf().derivedItemConstraints.find((candidate) => candidate.itemId === itemId)
    if (found !== undefined) return found
    throw new Error(`Panel constraints not found for Panel ${itemId}`)
  }
  const itemOf = () => {
    const found = stateOf().axis.items.find((candidate) => candidate.id === itemId)
    if (found !== undefined) return found
    throw new Error(`Layout not found for Panel ${itemId}`)
  }
  const sizeOf = () => {
    const found = stateOf().layout[itemId]
    if (found !== undefined) return found
    throw new Error(`Layout not found for Panel ${itemId}`)
  }
  const nextLayoutFor = ({ nextSize, items, prevLayout, derivedItemConstraints }) => {
    const size = sizeOf()
    const index = items.findIndex((candidate) => candidate.id === itemId)
    const first = index === 0
    const last = index === items.length - 1
    if (last && nextSize < size && (first || items.slice(0, index).every((_item, position) => {
      const constraints = derivedItemConstraints[position]
      return constraints?.collapsible && near(constraints.collapsedSize, prevLayout[constraints.itemId])
    }))) {
      const before = items.slice(0, index).reduce((total, item) => total + prevLayout[item.id], 0)
      return { ...prevLayout, [itemId]: round(100 - before) }
    }
    return resizeByDelta({
      delta: last ? size - nextSize : nextSize - size,
      initialLayout: prevLayout,
      itemConstraints: derivedItemConstraints,
      pivotIndices: last ? [index - 1, index] : [index, index + 1],
      prevLayout,
      trigger: "imperative-api"
    })
  }
  const resizeTo = (nextSize) => {
    if (nextSize === sizeOf()) return
    const { defaultLayoutDeferred, derivedItemConstraints, axis, axisSize, layout, separatorToItems } = stateOf()
    const nextLayout = nextLayoutFor({ nextSize, items: axis.items, prevLayout: layout, derivedItemConstraints })
    const valid = validateLayout({ layout: nextLayout, itemConstraints: derivedItemConstraints })
    if (!layoutsEqual(layout, valid)) {
      storeAxisState(axis, { defaultLayoutDeferred, derivedItemConstraints, axisSize, layout: valid, requestedAxisSize: axisSize, requestedLayout: valid, separatorToItems })
    }
  }
  return {
    collapse() {
      const { collapsible, collapsedSize } = constraintsOf()
      const { mutableValues } = itemOf()
      const size = sizeOf()
      if (collapsible && size !== collapsedSize) {
        mutableValues.expandToSize = size
        resizeTo(collapsedSize)
      }
    },
    expand() {
      const { collapsible, collapsedSize, minSize } = constraintsOf()
      const { mutableValues } = itemOf()
      if (collapsible && sizeOf() === collapsedSize) {
        let size = mutableValues.expandToSize ?? minSize
        if (size === 0) size = 1
        resizeTo(size)
      }
    },
    getSize() {
      const { axis } = stateOf()
      const { element } = itemOf()
      return { asPercentage: sizeOf(), inPixels: axis.orientation === "horizontal" ? element.offsetWidth : element.offsetHeight }
    },
    isCollapsed() {
      const { collapsible, collapsedSize } = constraintsOf()
      return collapsible && near(collapsedSize, sizeOf())
    },
    resize(size) {
      const { axis } = stateOf()
      const { element } = itemOf()
      const axisSize = axisSizeOf(axis)
      resizeTo(round(toPixels({ axisSize, element, value: size }) / axisSize * 100))
    }
  }
}

function groupApi(axisId) {
  const stateOf = () => {
    for (const [axis, state] of mountedAxes) if (axis.id === axisId) return { axis, ...state }
    throw new Error(`Could not find Group with id "${axisId}"`)
  }
  return {
    getLayout() {
      const { defaultLayoutDeferred, layout } = stateOf()
      return defaultLayoutDeferred ? {} : layout
    },
    setLayout(layout) {
      const { defaultLayoutDeferred, derivedItemConstraints, axis, axisSize, layout: current, separatorToItems } = stateOf()
      const valid = validateLayout({ layout, itemConstraints: derivedItemConstraints })
      if (defaultLayoutDeferred) return current
      if (!layoutsEqual(current, valid)) {
        storeAxisState(axis, { defaultLayoutDeferred, derivedItemConstraints, axisSize, layout: valid, requestedAxisSize: axisSize, requestedLayout: valid, separatorToItems })
      }
      return valid
    }
  }
}

// --- keyboard --------------------------------------------------------------------------------------------------------------

function axisOfSeparator(element) {
  for (const [axis] of mountedAxes) if (axis.separators.some((separator) => separator.element === element)) return axis
  throw new Error("Could not find parent Group for separator element")
}

function resizeFromKeyboard(element, delta) {
  const axis = axisOfSeparator(element)
  const state = stateOfAxis(axis.id, true)
  const separator = axis.separators.find((candidate) => candidate.element === element)
  assert(separator, "Matching separator not found")
  const pair = state.separatorToItems.get(separator)
  assert(pair, "Matching panels not found")
  const pivots = pair.map((item) => axis.items.indexOf(item))
  const layout = groupApi(axis.id).getLayout()
  const resized = resizeByDelta({ delta, initialLayout: layout, itemConstraints: state.derivedItemConstraints, pivotIndices: pivots, prevLayout: layout, trigger: "keyboard" })
  const valid = validateLayout({ layout: resized, itemConstraints: state.derivedItemConstraints })
  if (!layoutsEqual(layout, valid)) {
    storeAxisState(axis, {
      defaultLayoutDeferred: state.defaultLayoutDeferred,
      derivedItemConstraints: state.derivedItemConstraints,
      axisSize: state.axisSize,
      layout: valid,
      requestedAxisSize: state.axisSize,
      requestedLayout: valid,
      separatorToItems: state.separatorToItems
    }, { isUserInteraction: true })
  }
}

function onSeparatorKeydown(event) {
  if (event.defaultPrevented) return
  const element = event.currentTarget
  const axis = axisOfSeparator(element)
  if (axis.disabled || axis.separators.find((separator) => separator.element === element)?.disabled) return
  switch (event.key) {
    case "ArrowDown":
      event.preventDefault()
      if (axis.orientation === "vertical") resizeFromKeyboard(element, 5)
      break
    case "ArrowLeft":
      event.preventDefault()
      if (axis.orientation === "horizontal") resizeFromKeyboard(element, -5)
      break
    case "ArrowRight":
      event.preventDefault()
      if (axis.orientation === "horizontal") resizeFromKeyboard(element, 5)
      break
    case "ArrowUp":
      event.preventDefault()
      if (axis.orientation === "vertical") resizeFromKeyboard(element, -5)
      break
    case "End":
      event.preventDefault()
      resizeFromKeyboard(element, 100)
      break
    case "Enter": {
      event.preventDefault()
      const { derivedItemConstraints, layout, separatorToItems } = stateOfAxis(axis.id, true)
      const separator = axis.separators.find((candidate) => candidate.element === element)
      assert(separator, "Matching separator not found")
      const pair = separatorToItems.get(separator)
      assert(pair, "Matching panels not found")
      const item = pair[0]
      const constraints = derivedItemConstraints.find((candidate) => candidate.itemId === item.id)
      assert(constraints, "Panel metadata not found")
      if (constraints.collapsible) {
        const size = layout[item.id]
        const target = constraints.collapsedSize === size ? axis.mutableState.expandedItemSizes[item.id] ?? constraints.minSize : constraints.collapsedSize
        resizeFromKeyboard(element, target - size)
      }
      break
    }
    case "F6": {
      event.preventDefault()
      const elements = axis.separators.map((separator) => separator.element)
      const index = elements.findIndex((candidate) => candidate === event.currentTarget)
      const next = event.shiftKey ? (index > 0 ? index - 1 : elements.length - 1) : index + 1 < elements.length ? index + 1 : 0
      elements[next].focus({ preventScroll: true })
      break
    }
    case "Home":
      event.preventDefault()
      resizeFromKeyboard(element, -100)
      break
  }
}

// --- mounting an axis ------------------------------------------------------------------------------------------------------

function mountAxis(axis) {
  let live = true
  assert(axis.element.ownerDocument.defaultView, "Cannot register an unmounted Group")
  const ResizeObserverClass = axis.element.ownerDocument.defaultView.ResizeObserver
  const panelIds = new Set()
  const separatorIds = new Set()
  const observer = new ResizeObserverClass((entries) => {
    for (const entry of entries) {
      const { borderBoxSize, target } = entry
      if (target === axis.element) {
        if (!live) continue
        const axisSize = axisSizeOf(axis)
        if (axisSize === 0) return
        const state = stateOfAxis(axis.id)
        if (!state) return
        const constraints = deriveConstraints(axis)
        let requestedAxisSize = state.requestedAxisSize
        let requestedLayout = state.requestedLayout
        if (state.defaultLayoutDeferred) {
          requestedAxisSize = axisSize
          requestedLayout = looseLayout({ itemIds: axis.items.map(({ id }) => id), layout: initialLayoutOf({ axis, itemConstraints: constraints }) })
        }
        const rescaled = rescaleForGroupSize({ axis, nextAxisSize: axisSize, prevAxisSize: requestedAxisSize, prevLayout: requestedLayout })
        const layout = validateLayout({ layout: rescaled, itemConstraints: constraints })
        if (!state.defaultLayoutDeferred && layoutsEqual(state.layout, layout) &&
          state.derivedItemConstraints.length === constraints.length && state.derivedItemConstraints.every((previous, index) => recordsEqual(previous, constraints[index])) &&
          state.axisSize === axisSize) continue
        storeAxisState(axis, {
          defaultLayoutDeferred: false,
          derivedItemConstraints: constraints,
          axisSize,
          layout,
          requestedAxisSize,
          requestedLayout,
          separatorToItems: state.separatorToItems
        })
      } else {
        reportPanelSize(axis, target, borderBoxSize)
      }
    }
  })
  observer.observe(axis.element)
  axis.items.forEach((item) => {
    assert(!panelIds.has(item.id), `Panel ids must be unique; id "${item.id}" was used more than once`)
    panelIds.add(item.id)
    if (item.onResize) observer.observe(item.element)
  })
  const axisSize = axisSizeOf(axis)
  const constraints = deriveConstraints(axis)
  const initial = initialLayoutOf({ axis, itemConstraints: constraints })
  const layout = validateLayout({ layout: initial, itemConstraints: constraints })
  const document = axis.element.ownerDocument
  const separatorToItems = new Map()
  retainDocument(document)
  hitRegionsOf({ axis, includeDisabled: true }).forEach((region) => {
    if (region.separator) separatorToItems.set(region.separator, region.items)
  })
  storeAxisState(axis, {
    defaultLayoutDeferred: axisSize === 0,
    derivedItemConstraints: constraints,
    axisSize,
    layout,
    requestedAxisSize: axisSize,
    requestedLayout: looseLayout({ itemIds: axis.items.map(({ id }) => id), layout: initial }),
    separatorToItems
  })
  axis.separators.forEach((separator) => {
    assert(!separatorIds.has(separator.id), `Separator ids must be unique; id "${separator.id}" was used more than once`)
    separatorIds.add(separator.id)
    separator.element.addEventListener("keydown", onSeparatorKeydown)
  })
  return () => {
    live = false
    mountedAxes = new Map(mountedAxes)
    mountedAxes.delete(axis)
    if (dropAxisFromInteraction(axis)) updateCursor(document)
    axis.separators.forEach((separator) => separator.element.removeEventListener("keydown", onSeparatorKeydown))
    releaseDocument(document)
    observer.disconnect()
  }
}

function reportPanelSize(axis, element, borderBoxSize) {
  if (!borderBoxSize[0]) return
  const item = axis.items.find((candidate) => candidate.element === element)
  if (!item || !item.onResize) return
  const total = axisSizeOf(axis)
  const pixels = axis.orientation === "horizontal" ? item.element.offsetWidth : item.element.offsetHeight
  const prevSize = item.mutableValues.prevSize
  const size = { asPercentage: round(pixels / total * 100), inPixels: pixels }
  item.mutableValues.prevSize = size
  item.onResize(size, item.id, prevSize)
}

// --- preview overlays (resize_preview_mode: "separator") ------------------------------------------------------------------

// Deep clone of the separator with every computed style inline (react-resizable-panels `so`).
function cloneSeparator(separator) {
  const { element } = separator
  const clone = element.cloneNode(true)
  const originals = [element, ...element.querySelectorAll("*")]
  const copies = [clone, ...clone.querySelectorAll("*")]
  const view = element.ownerDocument.defaultView
  originals.forEach((original, index) => {
    const copy = copies[index]
    if (copy instanceof view.HTMLElement || copy instanceof view.SVGElement) {
      const computed = view.getComputedStyle(original)
      for (let property = 0; property < computed.length; property++) {
        const name = computed.item(property)
        copy.style.setProperty(name, computed.getPropertyValue(name))
      }
    }
    copy.removeAttribute("data-testid")
    copy.removeAttribute("id")
  })
  Object.assign(clone.style, { boxSizing: "border-box", height: "100%", margin: "0", position: "static", transform: "none", width: "100%" })
  const wrapper = element.ownerDocument.createElement("div")
  Object.assign(wrapper.style, { height: "100%", opacity: "0.65", pointerEvents: "none", width: "100%" })
  wrapper.append(clone)
  return wrapper
}

// --- the controller --------------------------------------------------------------------------------------------------------

export default class extends Controller {
  static values = {
    orientation: { type: String, default: "horizontal" },
    disabled: Boolean,
    disableCursor: Boolean,
    defaultLayout: Object,
    resizePreviewMode: { type: String, default: "panel" },
    resizeTargetMinimumSize: { type: Object, default: { coarse: 20, fine: 10 } }
  }

  connect() {
    const element = this.element
    const orientation = this.orientationValue
    const items = sortByPosition(orientation, [...element.querySelectorAll(":scope > [data-panel]")].map((panel) => this.#panelItem(panel)))
    const separators = sortByPosition(orientation, [...element.querySelectorAll(":scope > [data-separator]")].map((handle) => this.#separatorRecord(handle)))
    let defaultLayout
    if (this.hasDefaultLayoutValue && Object.keys(this.defaultLayoutValue).length === items.length) {
      defaultLayout = {}
      for (const item of items) {
        const size = this.defaultLayoutValue[item.id]
        if (size !== undefined) defaultLayout[item.id] = size
      }
    }
    this.axis = {
      disabled: this.disabledValue,
      element,
      id: element.id,
      mutableState: { defaultLayout, disableCursor: this.disableCursorValue, expandedItemSizes: {}, layouts: {} },
      orientation,
      items,
      resizePreviewMode: this.resizePreviewModeValue,
      resizeTargetMinimumSize: this.resizeTargetMinimumSizeValue,
      separators
    }
    this.lastLayoutChange = {}
    this.lastLayoutChanged = {}
    this.previewNodes = new Map()
    this.focused = new Set()
    this.unmount = mountAxis(this.axis)
    const { defaultLayoutDeferred, derivedItemConstraints, layout, requestedLayout } = stateOfAxis(this.axis.id, true)
    if (!defaultLayoutDeferred && derivedItemConstraints.length > 0) {
      this.#emitLayoutChange(layout)
      this.#emitLayoutChanged(layout, false, requestedLayout)
    }
    this.stopAxisChanges = onAxisChange(this.axis.id, (change) => this.#axisChanged(change))
    this.stopInteractionChanges = interactionChanges.add(() => this.#interactionChanged())
    this.#bindSeparators()
    this.#paint()
    this.#paintSeparators()
  }

  disconnect() {
    this.stopAxisChanges?.()
    this.stopInteractionChanges?.()
    this.unmount?.()
    this.axis?.separators.forEach(({ element, onFocus, onBlur }) => {
      element.removeEventListener("focus", onFocus)
      element.removeEventListener("blur", onBlur)
    })
    this.previewNodes?.forEach(({ node, mount }) => {
      mount?.unmount()
      node.remove()
    })
    this.previewNodes = undefined
    this.axis = undefined
  }

  getLayout() {
    return groupApi(this.axis.id).getLayout()
  }

  setLayout(layout) {
    return groupApi(this.axis.id).setLayout(layout)
  }

  collapse(panelId) {
    this.#panel(panelId).collapse()
  }

  expand(panelId) {
    this.#panel(panelId).expand()
  }

  getSize(panelId) {
    return this.#panel(panelId).getSize()
  }

  isCollapsed(panelId) {
    return this.#panel(panelId).isCollapsed()
  }

  resize(panelId, size) {
    this.#panel(panelId).resize(size)
  }

  #panel(itemId) {
    return panelApi({ axisId: this.axis.id, itemId })
  }

  #panelItem(element) {
    const constraintProps = JSON.parse(element.getAttribute("data-chadcn--resizable-constraints") || "{}")
    const { id: givenId, ...props } = constraintProps
    return {
      element,
      id: element.id,
      mutableValues: { expandToSize: undefined, prevSize: undefined },
      onResize: (size, _id, prevSize) => {
        element.dispatchEvent(new CustomEvent("chadcn--resizable:resize", { bubbles: true, detail: { size, id: givenId, prevSize } }))
      },
      constraintProps: { groupResizeBehavior: "preserve-relative-size", collapsedSize: "0%", collapsible: false, maxSize: "100%", minSize: "0%", ...props, disabled: props.disabled === true }
    }
  }

  #separatorRecord(element) {
    return {
      disabled: element.hasAttribute("aria-disabled"),
      disableDoubleClick: element.hasAttribute("data-chadcn--resizable-disable-double-click"),
      element,
      id: element.id,
      preview: element.querySelector(":scope > template[data-chadcn--resizable-target=preview]")
    }
  }

  #bindSeparators() {
    this.axis.separators.forEach((separator) => {
      separator.onFocus = () => {
        this.focused.add(separator)
        this.#paintSeparators()
      }
      separator.onBlur = () => {
        this.focused.delete(separator)
        this.#paintSeparators()
      }
      separator.element.addEventListener("focus", separator.onFocus)
      separator.element.addEventListener("blur", separator.onBlur)
      if (separator.element.matches(":focus")) this.focused.add(separator)
    })
  }

  #axisChanged(change) {
    const { derivedItemConstraints, layout, requestedLayout } = change.next
    this.#paint()
    if (change.next.defaultLayoutDeferred || derivedItemConstraints.length === 0) return
    recordExpandedSize({ derivedItemConstraints, axis: this.axis, layout, prevLayout: change.prev?.layout, requestedLayout })
    const current = interaction
    const notDragging = current.state !== "active" || !current.hitRegions.some((region) => region.axis === this.axis)
    this.#emitLayoutChange(layout)
    if (notDragging) this.#emitLayoutChanged(layout, change.isUserInteraction, requestedLayout)
  }

  #emitLayoutChange(layout) {
    if (layoutsEqual(this.lastLayoutChange, layout)) return
    this.lastLayoutChange = layout
    this.dispatch("layout-change", { detail: { layout }, cancelable: false })
  }

  #emitLayoutChanged(layout, isUserInteraction, requestedLayout) {
    if (layoutsEqual(this.lastLayoutChanged, layout)) return
    this.lastLayoutChanged = layout
    this.dispatch("layout-changed", { detail: { layout, isUserInteraction, requestedLayout }, cancelable: false })
  }

  // Panel flex-grow and handle ARIA values from the layout (the library renders them from state).
  #paint() {
    const state = stateOfAxis(this.axis.id)
    if (!state) return
    const { derivedItemConstraints, layout, separatorToItems } = state
    this.axis.items.forEach(({ element, id }) => {
      element.style.flexBasis = "0"
      element.style.flexShrink = "1"
      element.style.flexGrow = String(layout[id] ?? 1)
    })
    this.axis.separators.forEach((separator) => {
      const pair = separatorToItems.get(separator)
      if (!pair) return
      const first = pair[0]
      const index = derivedItemConstraints.findIndex((constraints) => constraints.itemId === first.id)
      const values = ariaValues({ layout, itemConstraints: derivedItemConstraints, itemId: first.id, itemIndex: index })
      setAttribute(separator.element, "aria-controls", values.valueControls)
      setAttribute(separator.element, "aria-valuemax", values.valueMax)
      setAttribute(separator.element, "aria-valuemin", values.valueMin)
      setAttribute(separator.element, "aria-valuenow", values.valueNow)
    })
  }

  #interactionChanged() {
    this.#paintSeparators()
    this.#paintPreviews()
  }

  // data-separator: disabled, active (a drag involving it), focus, hover or inactive.
  #paintSeparators() {
    if (!this.axis) return
    this.axis.separators.forEach((separator) => {
      const involved = interaction.state !== "inactive" && interaction.hitRegions.some((region) => region.separator === separator)
      const pointer = involved ? interaction.state : "inactive"
      const state = separator.disabled ? "disabled" : pointer === "active" ? "active" : this.focused.has(separator) ? "focus" : pointer
      separator.element.setAttribute("data-separator", state)
    })
  }

  #paintPreviews() {
    if (this.axis.resizePreviewMode !== "separator") return
    const wanted = interaction.state === "active" ? interaction.previews.filter((preview) => preview.axis === this.axis && (preview.active || !near(preview.offset, 0))) : []
    const keep = new Set(wanted.map((preview) => preview.key))
    this.previewNodes.forEach((entry, key) => {
      if (keep.has(key)) return
      entry.mount?.unmount()
      entry.node.remove()
      this.previewNodes.delete(key)
    })
    wanted.forEach((preview) => {
      let entry = this.previewNodes.get(preview.key)
      if (!entry) {
        entry = this.#createPreview(preview)
        this.previewNodes.set(preview.key, entry)
        this.element.append(entry.node)
        entry.content?.(entry)
      }
      const { rect, offset } = preview
      const horizontal = this.axis.orientation === "horizontal"
      Object.assign(entry.node.style, {
        height: `${rect.height}px`,
        left: `${rect.left}px`,
        top: `${rect.top}px`,
        transform: horizontal ? `translateX(${offset}px)` : `translateY(${offset}px)`,
        width: `${rect.width}px`
      })
    })
  }

  #createPreview(preview) {
    const node = this.element.ownerDocument.createElement("div")
    node.setAttribute("aria-hidden", "true")
    node.setAttribute("data-resize-preview", "true")
    node.setAttribute("inert", "")
    Object.assign(node.style, { pointerEvents: "none", position: "absolute" })
    const entry = { node, mount: undefined }
    const { separator } = preview
    if (separator?.preview) entry.content = (self) => { self.mount = mountTemplate(separator.preview, { into: node }) }
    else if (separator) entry.content = () => node.append(cloneSeparator(separator))
    return entry
  }
}

function setAttribute(element, name, value) {
  if (value === undefined) element.removeAttribute(name)
  else element.setAttribute(name, String(value))
}
