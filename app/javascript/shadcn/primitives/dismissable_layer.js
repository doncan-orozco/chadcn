// Port of @radix-ui/react-dismissable-layer. Known divergences: "inside the layer" is DOM containment (there is no
// React tree to follow through portals) plus the content of every layer opened after it, which stands in for Radix's
// React-tree check (a popover opened from a dialog is a child of the dialog even though it is portaled to <body>), plus
// `branches` for related elements that must not count as outside.
//
//   const release = dismissable(contentEl, {
//     onEscape, onPointerDownOutside, onFocusOutside, onInteractOutside,   // receive a cancelable CustomEvent
//     onDismiss,                                                            // runs unless the event was default-prevented
//     disableOutsidePointerEvents,                                          // modal: body gets pointer-events: none
//     branches,                                                             // () => Element[]
//   })
//
// Only the top layer reacts to Escape; only layers at or above the highest pointer-blocking layer react to pointer
// and focus outside, exactly like Radix.
const layers = new Set()
const blocking = new Set()
let originalBodyPointerEvents

const POINTER_DOWN_OUTSIDE = "dismissableLayer.pointerDownOutside"
const FOCUS_OUTSIDE = "dismissableLayer.focusOutside"

export function dismissable(el, options = {}) {
  const { onEscape, onPointerDownOutside, onFocusOutside, onInteractOutside, onDismiss, disableOutsidePointerEvents = false, branches } = options
  const ownerDocument = el.ownerDocument
  const layer = { el }

  const isBranch = (target) => (branches?.() ?? []).some((branch) => branch.contains(target))
  const index = () => [...layers].indexOf(layer)
  const isInChildLayer = (target) => [...layers].slice(index() + 1).some((child) => child.el.contains(target))
  const pointerEventsEnabled = () => index() >= highestBlockingIndex()

  const dispatch = (name, handler, originalEvent) => {
    const event = new CustomEvent(name, { bubbles: false, cancelable: true, detail: { originalEvent } })
    handler?.(event)
    onInteractOutside?.(event)
    if (!event.defaultPrevented) onDismiss?.()
  }

  let removeClick = null
  const onPointerDown = (event) => {
    if (el.contains(event.target) || isInChildLayer(event.target)) return
    if (!pointerEventsEnabled() || isBranch(event.target)) return
    const handle = () => dispatch(POINTER_DOWN_OUTSIDE, onPointerDownOutside, event)
    if (event.pointerType === "touch") {
      // Touch: a scroll must not dismiss, so wait for the click that follows a real tap.
      removeClick?.()
      ownerDocument.addEventListener("click", handle, { once: true })
      removeClick = () => ownerDocument.removeEventListener("click", handle)
    } else {
      handle()
    }
  }

  const onFocusIn = (event) => {
    if (el.contains(event.target) || isInChildLayer(event.target) || isBranch(event.target)) return
    if (!pointerEventsEnabled()) return
    dispatch(FOCUS_OUTSIDE, onFocusOutside, event)
  }

  const onKeyDown = (event) => {
    if (event.key !== "Escape") return
    if (index() !== layers.size - 1) return
    onEscape?.(event)
    if (!event.defaultPrevented && onDismiss) {
      event.preventDefault()
      onDismiss()
    }
  }

  if (disableOutsidePointerEvents) {
    if (blocking.size === 0) originalBodyPointerEvents = ownerDocument.body.style.pointerEvents
    ownerDocument.body.style.pointerEvents = "none"
    blocking.add(layer)
  }
  layers.add(layer)
  updatePointerEvents()

  // Radix registers the pointerdown listener on the next tick so the event that opened the layer cannot close it.
  const pointerDownTimer = setTimeout(() => ownerDocument.addEventListener("pointerdown", onPointerDown), 0)
  ownerDocument.addEventListener("focusin", onFocusIn)
  ownerDocument.addEventListener("keydown", onKeyDown, { capture: true })

  return function release() {
    clearTimeout(pointerDownTimer)
    removeClick?.()
    ownerDocument.removeEventListener("pointerdown", onPointerDown)
    ownerDocument.removeEventListener("focusin", onFocusIn)
    ownerDocument.removeEventListener("keydown", onKeyDown, { capture: true })
    layers.delete(layer)
    blocking.delete(layer)
    if (disableOutsidePointerEvents && blocking.size === 0) ownerDocument.body.style.pointerEvents = originalBodyPointerEvents
    el.style.pointerEvents = ""
    updatePointerEvents()
  }
}

function highestBlockingIndex() {
  const all = [...layers]
  return Math.max(-1, ...[...blocking].map((layer) => all.indexOf(layer)))
}

// Every layer styles itself from the stack: `auto` when it may receive pointer events while the body is blocked,
// `none` for the layers below the highest blocking one (Radix recomputes this on every layer change).
function updatePointerEvents() {
  const highest = highestBlockingIndex()
  ;[...layers].forEach((layer, i) => {
    layer.el.style.pointerEvents = blocking.size > 0 ? (i >= highest ? "auto" : "none") : ""
  })
}
