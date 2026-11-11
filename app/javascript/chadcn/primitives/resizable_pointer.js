// Pointer behavior of react-resizable-panels 4.14.3 (spec: dev/port/specs/resizable.md): one set of document listeners shared by
// every group of a document (reference counted by `retainDocument` / `releaseDocument`), the drag session, double-click reset
// and the cursor sheet (an adopted stylesheet that overrides the cursor while hovering or dragging a separator).

import { layoutsEqual, resizeByDelta } from "chadcn/primitives/resizable_layout"
import { cursorFor, cursorRule, limitFlag, nextCursorFlags } from "chadcn/primitives/resizable_cursor"
import { pointerDelta, previewOffsets, previewRect, sameCenter } from "chadcn/primitives/resizable_geometry"
import { hitRegionsOf, pointerHits } from "chadcn/primitives/resizable_measure"
import {
  endInteraction, interaction, mountedAxes, panelApi, requireState, setInteraction, storeAxisState, unmountAxisState, updateDrag, commitLayout
} from "chadcn/primitives/resizable_store"

const documentRefs = new Map()
const cursorSheets = new WeakMap()

// --- cursor ----------------------------------------------------------------------------------------------------------------

const chromiumLike = () => window.navigator.userAgent.includes("Chrome") || window.navigator.userAgent.includes("Firefox")

export function updateCursor(document) {
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
      const axes = interaction.hitRegions.map((region) => region.axis)
      const cursor = cursorFor({ cursorFlags: interaction.cursorFlags, axes, state: interaction.state, chromium: chromiumLike() })
      const rule = cursorRule(cursor)
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

// --- drag ------------------------------------------------------------------------------------------------------------------

function applyPointer({ commit, document, event, hitRegions, initialLayoutMap, pointerDownAtPoint, prevCursorFlags }) {
  let flags = 0
  const current = interaction
  let previews = current.state === "active" ? current.previews : []
  const previewLayouts = new Map(current.state === "active" ? current.previewLayoutMap : undefined)
  hitRegions.forEach((region) => {
    const { axis, axisSize } = region
    const { orientation, items } = axis
    if (commit && axis.resizePreviewMode !== "separator") return
    const delta = pointerDelta({ orientation, point: { x: event.clientX, y: event.clientY }, origin: pointerDownAtPoint, axisSize })
    const initialLayout = initialLayoutMap.get(axis)
    const state = mountedAxes.get(axis)
    if (!initialLayout || !state) return
    const { derivedItemConstraints, layout, separatorToItems } = state
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
      const offsets = previewOffsets({ itemIds: items.map(({ id }) => id), layout: resized, initialLayout, axisSize })
      previews = previews.map((preview) => {
        if (preview.axis !== axis) return preview
        const next = offsets[preview.itemIndex]
        return next === preview.offset ? preview : { ...preview, offset: next }
      })
    }
    if (layoutsEqual(resized, base) && delta !== 0 && !axis.mutableState.disableCursor) flags |= limitFlag({ orientation, delta })
    if ((axis.resizePreviewMode !== "separator" || commit) && !layoutsEqual(resized, layout)) commitLayout(region.axis, state, resized)
  })
  const cursorFlags = nextCursorFlags({ flags, prevCursorFlags, movementX: event.movementX, movementY: event.movementY })
  const moved = current.state === "active" && (event.clientX !== current.pointerDownAtPoint.x || event.clientY !== current.pointerDownAtPoint.y)
  updateDrag(cursorFlags, previews, previewLayouts, moved)
  updateCursor(document)
}

// Re-announces the groups of a finished drag as a user interaction (the controller dispatches layout-changed).
function announceDragEnd(hitRegions) {
  hitRegions.forEach((region) => {
    if (!mountedAxes.has(region.axis)) return
    storeAxisState(region.axis, requireState(region.axis), { isUserInteraction: true })
  })
}

function finishDrag(document, event) {
  const current = interaction
  if (current.state !== "active") return false
  applyPointer({
    commit: true,
    document,
    event,
    hitRegions: current.hitRegions,
    initialLayoutMap: current.initialLayoutMap,
    pointerDownAtPoint: current.pointerDownAtPoint,
    prevCursorFlags: current.cursorFlags
  })
  endInteraction()
  if (current.hitRegions.length === 0) return false
  updateCursor(document)
  announceDragEnd(current.hitRegions)
  return true
}

function cancelDrag(document) {
  const current = interaction
  if (current.state !== "active") return false
  current.previewLayoutMap.forEach((layout, axis) => {
    const state = mountedAxes.get(axis)
    if (axis.resizePreviewMode === "separator" && state && !layoutsEqual(layout, state.layout)) commitLayout(axis, state, layout)
  })
  endInteraction()
  announceDragEnd(current.hitRegions)
  updateCursor(document)
  return true
}

// The separator previews of a group for a drag that starts on `hitRegions` (resize_preview_mode "separator").
function previewsOf(axis, hitRegions) {
  const { element, orientation, items } = axis
  const bounds = element.getBoundingClientRect()
  const scroll = { left: element.scrollLeft, top: element.scrollTop, clientLeft: element.clientLeft, clientTop: element.clientTop }
  const horizontal = orientation === "horizontal"
  return hitRegionsOf({ expandHitTargets: false, axis, includeDisabled: true }).map(({ items: pair, rect, separator }, index) => ({
    active: hitRegions.some((hit) => {
      if (hit.axis !== axis || hit.items[0] !== pair[0]) return false
      if (separator || hit.separator) return hit.separator === separator
      return sameCenter({ horizontal, a: rect, b: hit.rect })
    }),
    axis,
    key: separator ? `separator-${separator.id}` : `panel-${pair[0].id}-${index}`,
    offset: 0,
    itemIndex: items.indexOf(pair[0]),
    rect: previewRect({ horizontal, rect, separator, bounds, scroll }),
    separator
  }))
}

// --- document listeners ----------------------------------------------------------------------------------------------------

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
        pointerDownAtPoint: current.pointerDownAtPoint,
        prevCursorFlags: current.cursorFlags
      })
      break
    }
    default: {
      const hits = pointerHits(event, mountedAxes)
      if (hits.length === 0) {
        if (current.state !== "inactive") endInteraction()
      } else {
        setInteraction({ cursorFlags: 0, hitRegions: hits, state: "hover" })
      }
      updateCursor(event.currentTarget)
    }
  }
}

function onPointerOut(event) {
  if (event.relatedTarget instanceof HTMLIFrameElement && interaction.state === "hover") endInteraction()
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

// Double-click on a separator resets the first adjacent panel that has a default size.
function onDoubleClick(event) {
  if (event.defaultPrevented) return
  pointerHits(event, mountedAxes).forEach((region) => {
    if (!region.separator || region.separator.disableDoubleClick) return
    const item = region.items.find((candidate) => candidate.constraintProps.defaultSize !== undefined)
    if (!item) return
    panelApi({ axis: region.axis, itemId: item.id }).resize(item.constraintProps.defaultSize)
    event.preventDefault()
  })
}

const DOCUMENT_LISTENERS = [
  ["contextmenu", onContextMenu, true], ["dblclick", onDoubleClick, true], ["lostpointercapture", onLostPointerCapture, true],
  ["pointercancel", onPointerCancel, true], ["pointerdown", onPointerDown, true], ["pointerleave", onPointerLeave, false],
  ["pointermove", onPointerMove, false], ["pointerout", onPointerOut, false], ["pointerup", onPointerUp, true]
]

export function retainDocument(document) {
  const count = (documentRefs.get(document) ?? 0) + 1
  documentRefs.set(document, count)
  if (count !== 1) return
  DOCUMENT_LISTENERS.forEach(([type, listener, capture]) => document.addEventListener(type, listener, capture))
  document.defaultView?.addEventListener("blur", onWindowBlur)
}

export function releaseDocument(document) {
  const count = Math.max(0, (documentRefs.get(document) ?? 0) - 1)
  documentRefs.set(document, count)
  if (count) return
  DOCUMENT_LISTENERS.forEach(([type, listener, capture]) => document.removeEventListener(type, listener, capture))
  document.defaultView?.removeEventListener("blur", onWindowBlur)
  releaseCursorSheet(document)
}

// Forgets a group that unmounts and repaints the cursor when it was hovered or dragged.
export function unmountAxis(axis, document) {
  if (unmountAxisState(axis)) updateCursor(document)
}
