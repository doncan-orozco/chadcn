// Golden stub: the shared primitive that dialog_controller.js should compose instead of re-implementing Esc/outside-dismiss.
export function dismissable(element, { onEscape, onPointerDownOutside, onFocusOutside, onDismiss } = {}) {
  return () => {}
}
