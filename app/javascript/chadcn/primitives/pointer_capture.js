// Pointer-capture drag helper (slider thumb/track, resizable handle). Replaces: the SliderImpl pointer handlers of
// react-slider (setPointerCapture on event.target at pointerdown, hasPointerCapture gating move/up).
//
// Known divergences: `onCancel` is an addition: a `pointercancel` (touch interrupted by the OS) ends the drag; Radix
// silently loses it. It only fires when the consumer passes it.
//
// Usage:
//   const drag = pointerCapture(rootEl, {
//     onStart: (event) => {},   // pointerdown on rootEl or a descendant; event.target already holds the capture
//     onMove:  (event) => {},   // pointermove while that target holds the capture
//     onEnd:   (event) => {},   // pointerup while that target holds the capture (capture is released first)
//     onCancel: (event) => {},  // optional
//     filter:  (event) => true  // optional: false ignores the pointerdown entirely (e.g. non-primary button)
//   })
//   drag.release()              // remove the listeners
//
// pointerdown calls event.preventDefault() like Radix (no text selection, no focus move; consumers focus explicitly).

/**
 * Pointer-capture drag helper: captures the pointer on pointerdown and reports moves/up while it holds the capture.
 *
 * `pointerdown` calls `preventDefault()` (no text selection, no focus move; consumers focus explicitly). `release()`
 * removes the listeners only: a capture in progress is not released and ends with the browser's pointerup.
 * @param {HTMLElement} root Listens to pointer events on this element and its descendants.
 * @param {object} [handlers]
 * @param {(event: PointerEvent) => void} [handlers.onStart]
 * @param {(event: PointerEvent) => void} [handlers.onMove]
 * @param {(event: PointerEvent) => void} [handlers.onEnd] Runs after the capture was released.
 * @param {(event: PointerEvent) => void} [handlers.onCancel] On `pointercancel`.
 * @param {(event: PointerEvent) => boolean} [handlers.filter] Return false to ignore a pointerdown.
 * @returns {{ isCapturing: (event: PointerEvent) => boolean | undefined, release: () => void }}
 * @example
 * const drag = pointerCapture(trackEl, { onMove: (event) => setValue(event.clientX) })
 * drag.release()
 */
export function pointerCapture(root, { onStart, onMove, onEnd, onCancel, filter } = {}) {
  const captured = (event) => event.target.hasPointerCapture?.(event.pointerId)

  const down = (event) => {
    if (filter && !filter(event)) return
    event.target.setPointerCapture(event.pointerId)
    event.preventDefault()
    onStart?.(event)
  }
  const move = (event) => {
    if (captured(event)) onMove?.(event)
  }
  const up = (event) => {
    if (!captured(event)) return
    event.target.releasePointerCapture(event.pointerId)
    onEnd?.(event)
  }
  const cancel = (event) => {
    if (onCancel) onCancel(event)
  }

  root.addEventListener("pointerdown", down)
  root.addEventListener("pointermove", move)
  root.addEventListener("pointerup", up)
  root.addEventListener("pointercancel", cancel)

  return {
    isCapturing: captured,
    release() {
      root.removeEventListener("pointerdown", down)
      root.removeEventListener("pointermove", move)
      root.removeEventListener("pointerup", up)
      root.removeEventListener("pointercancel", cancel)
    }
  }
}
