// Cursor of react-resizable-panels 4.14.3 while hovering or dragging separators (spec: dev/port/specs/resizable.md). Pure: flags
// and orientations in, a CSS cursor name out; no DOM, no Stimulus. The cursor sheet that applies it lives in resizable_pointer.

// Flags: the drag hit a limit in that direction (the cursor then points back only).
export const CURSOR_LEFT = 1
export const CURSOR_RIGHT = 2
export const CURSOR_UP = 4
export const CURSOR_DOWN = 8
export const CURSOR_HORIZONTAL = 3
export const CURSOR_VERTICAL = 12

// `axes`: the groups under the pointer (`{ orientation, mutableState: { disableCursor } }`); `chromium`: the user agent names
// Chrome or Firefox (they get the directional resize cursors). Undefined: no cursor override.
export function cursorFor({ cursorFlags, axes, state, chromium }) {
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
  if (state === "active" && cursorFlags && chromium) {
    const left = (cursorFlags & CURSOR_LEFT) !== 0
    const right = (cursorFlags & CURSOR_RIGHT) !== 0
    const up = (cursorFlags & CURSOR_UP) !== 0
    const down = (cursorFlags & CURSOR_DOWN) !== 0
    if (left) return up ? "se-resize" : down ? "ne-resize" : "e-resize"
    if (right) return up ? "sw-resize" : down ? "nw-resize" : "w-resize"
    if (up) return "s-resize"
    if (down) return "n-resize"
  }
  if (chromium) return horizontal > 0 && vertical > 0 ? "move" : horizontal > 0 ? "ew-resize" : "ns-resize"
  return horizontal > 0 && vertical > 0 ? "grab" : horizontal > 0 ? "col-resize" : "row-resize"
}

// The limit flag of one group whose layout did not move for a pointer `delta` along `orientation`.
export function limitFlag({ orientation, delta }) {
  switch (orientation) {
    case "horizontal": return delta < 0 ? CURSOR_LEFT : CURSOR_RIGHT
    case "vertical": return delta < 0 ? CURSOR_UP : CURSOR_DOWN
  }
  return 0
}

// The flags after a pointer move: an axis the pointer did not move along keeps its previous flags.
export function nextCursorFlags({ flags, prevCursorFlags, movementX, movementY }) {
  let cursorFlags = 0
  cursorFlags |= movementX === 0 ? prevCursorFlags & CURSOR_HORIZONTAL : flags & CURSOR_HORIZONTAL
  cursorFlags |= movementY === 0 ? prevCursorFlags & CURSOR_VERTICAL : flags & CURSOR_VERTICAL
  return cursorFlags
}

// The rule the document cursor sheet holds while the cursor is overridden.
export const cursorRule = (cursor) => `*, *:hover {cursor: ${cursor} !important; }`
