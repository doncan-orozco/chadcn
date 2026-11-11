import { Controller } from "@hotwired/stimulus"
import { mountTemplate } from "chadcn/primitives/template_mount"
import {
  ariaValues, assert, constraintListsEqual, initialLayout, layoutsEqual, looseLayout, near, recordExpandedSize, rescaleForGroupSize,
  resizeByDelta, round, validateLayout
} from "chadcn/primitives/resizable_layout"
import { collapseToggleDelta, keyboardIntent, nextSeparatorIndex } from "chadcn/primitives/resizable_keyboard"
import { axisSizeOf, hitRegionsOf, itemPixels, measureConstraints, sortByPosition } from "chadcn/primitives/resizable_measure"
import {
  commitLayout, groupApi, interaction, interactionChanges, isDragging, mountedAxes, onAxisChange, panelApi, requireState, storeAxisState
} from "chadcn/primitives/resizable_store"
import { releaseDocument, retainDocument, unmountAxis } from "chadcn/primitives/resizable_pointer"

// react-resizable-panels 4.14.3 (Group, Panel, Separator) behind shadcn Resizable. Spec: dev/port/specs/resizable.md (Code layout
// maps the library onto the modules). The layout engine (resizable_layout, _keyboard, _cursor, _geometry) is pure; the DOM
// reads (resizable_measure), the page-wide state (resizable_store) and the document pointer listeners (resizable_pointer) are
// shared by all groups of a document, like the library's module state. This controller is one group: it mounts it, observes its
// size, handles its separators' keys, and paints flex-grow, ARIA values, data-separator states, events and drag previews. The
// host element is the group div; its panels and separators are its direct children (a nested group is a separate controller).

const itemIdsOf = (axis) => axis.items.map(({ id }) => id)

// --- mounting a group ------------------------------------------------------------------------------------------------------

function mountAxis(axis) {
  let live = true
  assert(axis.element.ownerDocument.defaultView, "Cannot register an unmounted Group")
  // Validate and compute everything that can throw on caller input (ids, constraints JSON, default layout) before acquiring
  // the ResizeObserver or the document refcount. Stimulus still calls disconnect() after a connect() that threw and reuses
  // the controller instance when the same element is reinserted, so nothing may be held when connect throws and the
  // release below runs at most once.
  const panelIds = new Set()
  axis.items.forEach((item) => {
    assert(!panelIds.has(item.id), `Panel ids must be unique; id "${item.id}" was used more than once`)
    panelIds.add(item.id)
  })
  const separatorIds = new Set()
  axis.separators.forEach((separator) => {
    assert(!separatorIds.has(separator.id), `Separator ids must be unique; id "${separator.id}" was used more than once`)
    separatorIds.add(separator.id)
  })
  const itemIds = itemIdsOf(axis)
  const axisSize = axisSizeOf(axis)
  const constraints = measureConstraints(axis)
  const initial = initialLayout({ itemIds, mutableState: axis.mutableState, itemConstraints: constraints })
  const layout = validateLayout({ layout: initial, itemConstraints: constraints })
  const requestedLayout = looseLayout({ itemIds, layout: initial })
  const separatorToItems = new Map()
  hitRegionsOf({ axis, includeDisabled: true }).forEach((region) => {
    if (region.separator) separatorToItems.set(region.separator, region.items)
  })
  const document = axis.element.ownerDocument
  const ResizeObserverClass = document.defaultView.ResizeObserver
  const observer = new ResizeObserverClass((entries) => {
    for (const { borderBoxSize, target } of entries) {
      if (target !== axis.element) {
        reportPanelSize(axis, target, borderBoxSize)
        continue
      }
      if (!live) continue
      const axisSize = axisSizeOf(axis)
      if (axisSize === 0) return
      const state = mountedAxes.get(axis)
      if (!state) return
      const next = resizedGroupState(axis, state, axisSize)
      if (next) storeAxisState(axis, next)
    }
  })
  retainDocument(document)
  storeAxisState(axis, {
    defaultLayoutDeferred: axisSize === 0,
    derivedItemConstraints: constraints,
    axisSize,
    layout,
    requestedAxisSize: axisSize,
    requestedLayout,
    separatorToItems
  })
  observer.observe(axis.element)
  axis.items.forEach((item) => {
    if (item.onResize) observer.observe(item.element)
  })
  return () => {
    if (!live) return
    live = false
    unmountAxis(axis, document)
    releaseDocument(document)
    observer.disconnect()
  }
}

// The group state after the group element measured `axisSize` (constraints re-derived, layout rescaled), or undefined when
// nothing changed. A layout deferred because the group mounted at size 0 is computed now.
function resizedGroupState(axis, state, axisSize) {
  const constraints = measureConstraints(axis)
  let requestedAxisSize = state.requestedAxisSize
  let requestedLayout = state.requestedLayout
  if (state.defaultLayoutDeferred) {
    const itemIds = itemIdsOf(axis)
    requestedAxisSize = axisSize
    requestedLayout = looseLayout({ itemIds, layout: initialLayout({ itemIds, mutableState: axis.mutableState, itemConstraints: constraints }) })
  }
  const rescaled = rescaleForGroupSize({ items: axis.items, nextAxisSize: axisSize, prevAxisSize: requestedAxisSize, prevLayout: requestedLayout })
  const layout = validateLayout({ layout: rescaled, itemConstraints: constraints })
  if (!state.defaultLayoutDeferred && layoutsEqual(state.layout, layout) && constraintListsEqual(state.derivedItemConstraints, constraints) &&
    state.axisSize === axisSize) return undefined
  return {
    defaultLayoutDeferred: false,
    derivedItemConstraints: constraints,
    axisSize,
    layout,
    requestedAxisSize,
    requestedLayout,
    separatorToItems: state.separatorToItems
  }
}

function reportPanelSize(axis, element, borderBoxSize) {
  if (!borderBoxSize[0]) return
  const item = axis.items.find((candidate) => candidate.element === element)
  if (!item || !item.onResize) return
  const total = axisSizeOf(axis)
  const pixels = itemPixels(axis, item)
  const prevSize = item.mutableValues.prevSize
  const size = { asPercentage: round(pixels / total * 100), inPixels: pixels }
  item.mutableValues.prevSize = size
  item.onResize(size, item.id, prevSize)
}

// --- keyboard --------------------------------------------------------------------------------------------------------------

function separatorPair(axis, state, element) {
  const separator = axis.separators.find((candidate) => candidate.element === element)
  assert(separator, "Matching separator not found")
  const pair = state.separatorToItems.get(separator)
  assert(pair, "Matching panels not found")
  return pair
}

function resizeFromKeyboard(axis, element, delta) {
  const state = requireState(axis)
  const pivots = separatorPair(axis, state, element).map((item) => axis.items.indexOf(item))
  const layout = groupApi(axis).getLayout()
  const resized = resizeByDelta({ delta, initialLayout: layout, itemConstraints: state.derivedItemConstraints, pivotIndices: pivots, prevLayout: layout, trigger: "keyboard" })
  const valid = validateLayout({ layout: resized, itemConstraints: state.derivedItemConstraints })
  if (!layoutsEqual(layout, valid)) commitLayout(axis, state, valid, { isUserInteraction: true })
}

function onSeparatorKeydown(event, axis) {
  if (event.defaultPrevented) return
  const element = event.currentTarget
  if (axis.disabled || axis.separators.find((separator) => separator.element === element)?.disabled) return
  const intent = keyboardIntent({ key: event.key, orientation: axis.orientation, shiftKey: event.shiftKey })
  if (!intent) return
  event.preventDefault()
  switch (intent.type) {
    case "resize":
      resizeFromKeyboard(axis, element, intent.delta)
      break
    case "toggle-collapse": {
      const { derivedItemConstraints, layout } = requireState(axis)
      const item = separatorPair(axis, requireState(axis), element)[0]
      const constraints = derivedItemConstraints.find((candidate) => candidate.itemId === item.id)
      assert(constraints, "Panel metadata not found")
      const delta = collapseToggleDelta({ constraints, size: layout[item.id], expandedSize: axis.mutableState.expandedItemSizes[item.id] })
      if (delta !== undefined) resizeFromKeyboard(axis, element, delta)
      break
    }
    case "focus": {
      const elements = axis.separators.map((separator) => separator.element)
      const index = elements.findIndex((candidate) => candidate === element)
      elements[nextSeparatorIndex({ index, count: elements.length, backwards: intent.backwards })].focus({ preventScroll: true })
      break
    }
  }
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
  static targets = ["panel", "handle", "preview"]
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
    // A Turbo snapshot taken mid-drag can carry preview overlays; they belong to no live drag.
    element.querySelectorAll(":scope > [data-resize-preview]").forEach((stale) => stale.remove())
    // Direct children only: Stimulus targets also match the parts of a nested group that sits inside a panel.
    const direct = (target) => target.parentElement === element
    const items = sortByPosition(orientation, this.panelTargets.filter(direct).map((panel) => this.#panelItem(panel)))
    const separators = sortByPosition(orientation, this.handleTargets.filter(direct).map((handle) => this.#separatorRecord(handle)))
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
    this.unmount = undefined
    this.unmount = mountAxis(this.axis)
    const { defaultLayoutDeferred, derivedItemConstraints, layout, requestedLayout } = requireState(this.axis)
    if (!defaultLayoutDeferred && derivedItemConstraints.length > 0) {
      this.#emitLayoutChange(layout)
      this.#emitLayoutChanged(layout, false, requestedLayout)
    }
    this.stopAxisChanges = onAxisChange(this.axis, (change) => this.#axisChanged(change))
    this.stopInteractionChanges = interactionChanges.add(() => this.#interactionChanged())
    this.axis.separators.forEach((separator) => { if (separator.element.matches(":focus")) this.focused.add(separator) })
    this.#paint()
    this.#paintSeparators()
  }

  disconnect() {
    const { stopAxisChanges, stopInteractionChanges, unmount, previewNodes } = this
    this.stopAxisChanges = this.stopInteractionChanges = this.unmount = this.previewNodes = undefined
    stopAxisChanges?.()
    stopInteractionChanges?.()
    unmount?.()
    previewNodes?.forEach(({ node, mount }) => {
      mount?.unmount()
      node.remove()
    })
    this.axis = undefined
  }

  // Stimulus actions rendered on every handle by Chadcn::Resizable::Handle.
  keydown(event) {
    onSeparatorKeydown(event, this.#mountedAxis())
  }

  focus(event) {
    this.#setFocused(event.currentTarget, true)
  }

  blur(event) {
    this.#setFocused(event.currentTarget, false)
  }

  getLayout() {
    return groupApi(this.#mountedAxis()).getLayout()
  }

  setLayout(layout) {
    return groupApi(this.#mountedAxis()).setLayout(layout)
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
    return panelApi({ axis: this.#mountedAxis(), itemId })
  }

  #mountedAxis() {
    if (!this.axis) throw new Error("chadcn--resizable: the group is not connected")
    return this.axis
  }

  #setFocused(element, focused) {
    const separator = this.axis?.separators.find((candidate) => candidate.element === element)
    if (!separator) return
    if (focused) this.focused.add(separator)
    else this.focused.delete(separator)
    this.#paintSeparators()
  }

  #panelItem(element) {
    const constraintProps = JSON.parse(element.getAttribute("data-chadcn--resizable-constraints") || "{}")
    const { id: givenId, ...props } = constraintProps
    return {
      element,
      id: element.id,
      mutableValues: { expandToSize: undefined, prevSize: undefined },
      onResize: (size, _id, prevSize) => {
        this.dispatch("resize", { target: element, detail: { size, id: givenId, prevSize } })
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
      preview: this.previewTargets.find((target) => target.parentElement === element)
    }
  }

  #axisChanged(change) {
    const { derivedItemConstraints, layout, requestedLayout } = change.next
    this.#paint()
    if (change.next.defaultLayoutDeferred || derivedItemConstraints.length === 0) return
    recordExpandedSize({
      derivedItemConstraints, itemIds: itemIdsOf(this.axis), mutableState: this.axis.mutableState, layout, prevLayout: change.prev?.layout, requestedLayout
    })
    this.#emitLayoutChange(layout)
    if (!isDragging(this.axis)) this.#emitLayoutChanged(layout, change.isUserInteraction, requestedLayout)
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
    const state = mountedAxes.get(this.axis)
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
