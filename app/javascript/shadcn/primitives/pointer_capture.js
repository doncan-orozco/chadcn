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
