// Keyboard of a react-resizable-panels 4.14.3 separator (spec: dev/port/specs/resizable.md, Behavior). Pure: a key and the group
// orientation in, an intent out; no DOM, no Stimulus.

// Arrow keys move the separator by this many percent; Home and End by the whole group.
export const KEYBOARD_STEP = 5

// What a keydown on a separator asks for, or undefined for a key the separator ignores (its default is not prevented):
//   { type: "resize", delta }     move the separator by `delta` percent
//   { type: "none" }              a handled key that does nothing in this orientation (its default is still prevented)
//   { type: "toggle-collapse" }   Enter: collapse the panel before the separator, or expand it back
//   { type: "focus", backwards }  F6 / Shift+F6: focus the next (previous) separator of the group, wrapping
export function keyboardIntent({ key, orientation, shiftKey = false }) {
  const horizontal = orientation === "horizontal"
  switch (key) {
    case "ArrowDown": return horizontal ? { type: "none" } : { type: "resize", delta: KEYBOARD_STEP }
    case "ArrowUp": return horizontal ? { type: "none" } : { type: "resize", delta: -KEYBOARD_STEP }
    case "ArrowLeft": return horizontal ? { type: "resize", delta: -KEYBOARD_STEP } : { type: "none" }
    case "ArrowRight": return horizontal ? { type: "resize", delta: KEYBOARD_STEP } : { type: "none" }
    case "End": return { type: "resize", delta: 100 }
    case "Home": return { type: "resize", delta: -100 }
    case "Enter": return { type: "toggle-collapse" }
    case "F6": return { type: "focus", backwards: shiftKey }
  }
  return undefined
}

// Enter on a separator: the delta that collapses the panel before it, or expands it back to the size it had before it
// collapsed (else its minimum). Undefined when that panel is not collapsible.
export function collapseToggleDelta({ constraints, size, expandedSize }) {
  if (!constraints.collapsible) return undefined
  const target = constraints.collapsedSize === size ? expandedSize ?? constraints.minSize : constraints.collapsedSize
  return target - size
}

// F6 cycling over `count` separators from `index`.
export function nextSeparatorIndex({ index, count, backwards }) {
  return backwards ? (index > 0 ? index - 1 : count - 1) : index + 1 < count ? index + 1 : 0
}
