// Shared state of every resizable group of the page, like the module state of react-resizable-panels 4.14.3 (spec:
// dev/port/specs/resizable.md): the mounted groups and their layouts, the pointer interaction, the change emitters, and the
// imperative panel and group APIs (rrp.js `mt`, `Ge`). No DOM writes.
//
// Group state: `{ defaultLayoutDeferred, derivedItemConstraints, axisSize, layout, requestedAxisSize, requestedLayout,
// separatorToItems }`. Interaction: `{ state: "inactive", cursorFlags }`, `{ state: "hover", cursorFlags, hitRegions }` or
// `{ state: "active", cursorFlags, didPointerMove, hitRegions, initialLayoutMap, pointerDownAtPoint, previewLayoutMap, previews }`.
// `interaction` and `mountedAxes` are live bindings: importers read the current value.

import { layoutsEqual, near, panelResizeLayout, round, validateLayout } from "chadcn/primitives/resizable_layout"
import { itemPixels, percentOfAxis } from "chadcn/primitives/resizable_measure"

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

export let interaction = { cursorFlags: 0, state: "inactive" }
export const interactionChanges = new Emitter()
const axisChanges = new Emitter()
// State is keyed by the axis object, never by its id: ids repeat across groups (Turbo streams restart them at _r_0_).
export let mountedAxes = new Map()

// --- interaction -----------------------------------------------------------------------------------------------------------

export function setInteraction(next) {
  const prev = interaction
  interaction = next
  if (prev.state === "active" && next.state !== "active" && prev.didPointerMove) {
    prev.hitRegions.forEach(({ separator }) => {
      if (separator && separator.element.ownerDocument.activeElement === separator.element) separator.element.blur()
    })
  }
  interactionChanges.emit({ prev, next })
}

export function updateDrag(cursorFlags, previews = [], previewLayoutMap, didPointerMove = false) {
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

export const endInteraction = () => setInteraction({ cursorFlags: 0, state: "inactive" })

// Removes a group that unmounts mid-hover or mid-drag from the interaction; true when it was part of it.
function dropAxisFromInteraction(axis) {
  if (interaction.state === "inactive") return false
  const regions = interaction.hitRegions.filter((region) => region.axis !== axis)
  const hadPreview = interaction.state === "active" && interaction.previews.some((preview) => preview.axis === axis)
  if (regions.length === interaction.hitRegions.length && !hadPreview) return false
  if (regions.length === 0) {
    endInteraction()
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

export const isDragging = (axis) => interaction.state === "active" && interaction.hitRegions.some((region) => region.axis === axis)

// --- groups ----------------------------------------------------------------------------------------------------------------

export function storeAxisState(axis, state, options) {
  const prev = mountedAxes.get(axis)
  mountedAxes = new Map(mountedAxes)
  mountedAxes.set(axis, state)
  axisChanges.emit({ axis, isUserInteraction: options?.isUserInteraction === true, prev, next: state })
}

// Stores `layout` as both the current and the requested layout of the group.
export function commitLayout(axis, state, layout, options) {
  storeAxisState(axis, { ...state, layout, requestedAxisSize: state.axisSize, requestedLayout: layout }, options)
}

// Forgets the group; true when it took part in the current interaction (the cursor needs repainting).
export function unmountAxisState(axis) {
  mountedAxes = new Map(mountedAxes)
  mountedAxes.delete(axis)
  return dropAxisFromInteraction(axis)
}

export function requireState(axis) {
  const state = mountedAxes.get(axis)
  if (!state) throw new Error(`chadcn--resizable: group ${axis.id} is not mounted`)
  return state
}

export function onAxisChange(axis, listener) {
  return axisChanges.add((change) => { if (change.axis === axis) listener(change) })
}

// --- imperative api --------------------------------------------------------------------------------------------------------

export function panelApi({ axis, itemId }) {
  const constraintsOf = () => {
    const found = requireState(axis).derivedItemConstraints.find((candidate) => candidate.itemId === itemId)
    if (found !== undefined) return found
    throw new Error(`Panel constraints not found for Panel ${itemId}`)
  }
  const itemOf = () => {
    requireState(axis)
    const found = axis.items.find((candidate) => candidate.id === itemId)
    if (found !== undefined) return found
    throw new Error(`Layout not found for Panel ${itemId}`)
  }
  const sizeOf = () => {
    const found = requireState(axis).layout[itemId]
    if (found !== undefined) return found
    throw new Error(`Layout not found for Panel ${itemId}`)
  }
  const resizeTo = (nextSize) => {
    if (nextSize === sizeOf()) return
    const state = requireState(axis)
    const { derivedItemConstraints, layout } = state
    const nextLayout = panelResizeLayout({ itemId, itemIds: axis.items.map(({ id }) => id), nextSize, prevLayout: layout, itemConstraints: derivedItemConstraints })
    const valid = validateLayout({ layout: nextLayout, itemConstraints: derivedItemConstraints })
    if (!layoutsEqual(layout, valid)) commitLayout(axis, state, valid)
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
      const item = itemOf()
      return { asPercentage: sizeOf(), inPixels: itemPixels(axis, item) }
    },
    isCollapsed() {
      const { collapsible, collapsedSize } = constraintsOf()
      return collapsible && near(collapsedSize, sizeOf())
    },
    resize(size) {
      resizeTo(round(percentOfAxis(axis, itemOf(), size)))
    }
  }
}

export function groupApi(axis) {
  return {
    getLayout() {
      const { defaultLayoutDeferred, layout } = requireState(axis)
      return defaultLayoutDeferred ? {} : layout
    },
    setLayout(layout) {
      const state = requireState(axis)
      const { defaultLayoutDeferred, derivedItemConstraints, layout: current } = state
      const valid = validateLayout({ layout, itemConstraints: derivedItemConstraints })
      if (defaultLayoutDeferred) return current
      if (!layoutsEqual(current, valid)) commitLayout(axis, state, valid)
      return valid
    }
  }
}
