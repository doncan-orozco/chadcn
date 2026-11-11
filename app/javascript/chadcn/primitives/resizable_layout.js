// Layout engine of react-resizable-panels 4.14.3 behind shadcn Resizable (spec: dev/port/specs/resizable.md, cited `rrp.js:<line>`).
// Pure: numbers and plain records in, numbers and plain records out; no DOM, no Stimulus. A literal port of the library (same
// float operations and rounding, because aria values and flex-grow are compared as strings).
//
// Records: an item is `{ id, constraintProps }` (the panel's constraints JSON with the library defaults applied); item
// constraints are `{ itemId, collapsedSize, collapsedThreshold, collapsible, defaultSize, disabled, groupResizeBehavior, maxSize,
// minSize }` in percent; a layout is `{ itemId => percent }`; `mutableState` is the group's `{ defaultLayout, expandedItemSizes,
// layouts }`.

export const assert = (condition, message) => {
  if (!condition) throw new Error(message)
}

// --- numbers ---------------------------------------------------------------------------------------------------------------

export const round = (value) => parseFloat(value.toFixed(3))
export const near = (a, b, tolerance = 0) => Math.abs(round(a) - round(b)) <= tolerance
export const compare = (a, b) => (near(a, b) ? 0 : a > b ? 1 : -1)

export function layoutsEqual(a, b) {
  if (Object.keys(a).length !== Object.keys(b).length) return false
  for (const id in a) if (b[id] === undefined || compare(a[id], b[id]) !== 0) return false
  return true
}

function arraysLooselyEqual(a, b) {
  if (a.length !== b.length) return false
  for (let index = 0; index < a.length; index++) if (a[index] != b[index]) return false
  return true
}

export function recordsEqual(a, b) {
  if (Object.keys(a).length !== Object.keys(b).length) return false
  for (const key in a) if (a[key] !== b[key]) return false
  return true
}

export function constraintListsEqual(a, b) {
  return a.length === b.length && a.every((previous, index) => recordsEqual(previous, b[index]))
}

// --- sizes -----------------------------------------------------------------------------------------------------------------

// A size prop as [number, unit]: a number is pixels, a string is parseFloat with its suffix (none = percent).
export function parseSize(value) {
  switch (typeof value) {
    case "number": return [value, "px"]
    case "string": {
      const number = parseFloat(value)
      return value.endsWith("%") ? [number, "%"] : value.endsWith("px") ? [number, "px"] : value.endsWith("rem") ? [number, "rem"]
        : value.endsWith("em") ? [number, "em"] : value.endsWith("vh") ? [number, "vh"] : value.endsWith("vw") ? [number, "vw"] : [number, "%"]
    }
  }
}

// Item constraints in percent of `axisSize`. `toPixels(value, item)` converts one size prop (the caller knows fonts and viewport).
export function deriveConstraints({ items, axisSize, toPixels }) {
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
    const { constraintProps } = item
    const percent = (value) => round(toPixels(value, item) / axisSize * 100)
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

export function validateSize({ overrideDisabledItems, itemConstraints, prevSize, size }) {
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

// trigger: "keyboard" | "mouse-or-touch" | "imperative-api" (the last one may move disabled panels).
export function resizeByDelta({ delta, initialLayout, itemConstraints, pivotIndices, prevLayout, trigger }) {
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

export function validateLayout({ layout, itemConstraints }) {
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

// aria-valuemin/max/now of the separator after `itemId` (the library computes min and max by resizing to the limits).
export function ariaValues({ layout, itemConstraints, itemId, itemIndex }) {
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

export function defaultItemLayout(constraints) {
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

function namesAllPanels(itemIds, layout) {
  const keys = Object.keys(layout)
  return itemIds.length === keys.length && itemIds.every((id) => keys.includes(id))
}

// The remembered layout of this panel set, else a default layout that names every panel, else one from the default sizes.
export function rememberedOrDefaultLayout({ itemIds, mutableState, itemConstraints }) {
  const given = mutableState.defaultLayout
  return mutableState.layouts[itemIds.join(",")] ?? (given && namesAllPanels(itemIds, given) ? given : defaultItemLayout(itemConstraints))
}

// The layout validated against no constraints (only normalised to 100).
export function looseLayout({ itemIds, layout }) {
  return validateLayout({
    layout,
    itemConstraints: itemIds.map((itemId) => ({ collapsedSize: 0, collapsible: false, defaultSize: undefined, disabled: undefined, itemId, maxSize: 100, minSize: 0 }))
  })
}

// When the group itself changes size, "preserve-pixel-size" panels keep their pixels and the others share the rest.
export function rescaleForGroupSize({ items, nextAxisSize, prevAxisSize, prevLayout }) {
  if (prevAxisSize <= 0 || nextAxisSize <= 0 || prevAxisSize === nextAxisSize) return prevLayout
  let pixelTotal = 0
  let relativeTotal = 0
  let preservesPixels = false
  const pixels = new Map()
  const relative = []
  for (const item of items) {
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

// Remembers the requested layout of this panel set and the size a panel had before it collapsed (Enter expands back to it).
export function recordExpandedSize({ derivedItemConstraints, itemIds, mutableState, layout, prevLayout, requestedLayout }) {
  mutableState.layouts[itemIds.join(",")] = requestedLayout
  if (!prevLayout) return
  derivedItemConstraints.forEach((constraints) => {
    if (!constraints.collapsible) return
    const collapsedNow = near(constraints.collapsedSize, layout[constraints.itemId])
    const collapsedBefore = near(constraints.collapsedSize, prevLayout[constraints.itemId])
    if (collapsedNow && !collapsedBefore) mutableState.expandedItemSizes[constraints.itemId] = prevLayout[constraints.itemId]
  })
}

// The layout the imperative `resize(nextSize)` of one panel asks for (rrp.js `mt`): the last panel grows into the space the
// collapsed panels before it leave, otherwise the panel moves the separator after it (before it, for the last one).
export function panelResizeLayout({ itemId, itemIds, nextSize, prevLayout, itemConstraints }) {
  const size = prevLayout[itemId]
  const index = itemIds.indexOf(itemId)
  const first = index === 0
  const last = index === itemIds.length - 1
  if (last && nextSize < size && (first || itemIds.slice(0, index).every((_id, position) => {
    const constraints = itemConstraints[position]
    return constraints?.collapsible && near(constraints.collapsedSize, prevLayout[constraints.itemId])
  }))) {
    const before = itemIds.slice(0, index).reduce((total, id) => total + prevLayout[id], 0)
    return { ...prevLayout, [itemId]: round(100 - before) }
  }
  return resizeByDelta({
    delta: last ? size - nextSize : nextSize - size,
    initialLayout: prevLayout,
    itemConstraints,
    pivotIndices: last ? [index - 1, index] : [index, index + 1],
    prevLayout,
    trigger: "imperative-api"
  })
}

// The group state after the group measured `axisSize` (constraints re-derived, layout rescaled), or undefined when nothing
// changed. A layout deferred because the group mounted at size 0 is computed now. `state` is the previous group state.
export function nextGroupState({ items, itemIds, mutableState, state, axisSize, itemConstraints }) {
  let requestedAxisSize = state.requestedAxisSize
  let requestedLayout = state.requestedLayout
  if (state.defaultLayoutDeferred) {
    requestedAxisSize = axisSize
    requestedLayout = looseLayout({ itemIds, layout: rememberedOrDefaultLayout({ itemIds, mutableState, itemConstraints }) })
  }
  const rescaled = rescaleForGroupSize({ items, nextAxisSize: axisSize, prevAxisSize: requestedAxisSize, prevLayout: requestedLayout })
  const layout = validateLayout({ layout: rescaled, itemConstraints })
  if (!state.defaultLayoutDeferred && layoutsEqual(state.layout, layout) && constraintListsEqual(state.derivedItemConstraints, itemConstraints) &&
    state.axisSize === axisSize) return undefined
  return {
    defaultLayoutDeferred: false,
    derivedItemConstraints: itemConstraints,
    axisSize,
    layout,
    requestedAxisSize,
    requestedLayout,
    separatorToItems: state.separatorToItems
  }
}

// The layout after a keyboard resize of the separator between `pivotIndices`, or undefined when it changes nothing.
export function keyboardResizedLayout({ layout, itemConstraints, pivotIndices, delta }) {
  const resized = resizeByDelta({ delta, initialLayout: layout, itemConstraints, pivotIndices, prevLayout: layout, trigger: "keyboard" })
  const valid = validateLayout({ layout: resized, itemConstraints })
  return layoutsEqual(layout, valid) ? undefined : valid
}

// The `{ asPercentage, inPixels }` size record of a panel of `pixels` in a group of `axisSize`.
export function panelSize({ pixels, axisSize }) {
  return { asPercentage: round(pixels / axisSize * 100), inPixels: pixels }
}
