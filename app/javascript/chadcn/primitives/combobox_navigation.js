// Keyboard navigation and selection steps of the Combobox (Base UI 1.9.0, spec dev/port/specs/combobox.md, Behavior):
// useListNavigation with virtual focus (nav:L303-411), the highlight an opening popup starts with (root:L760-870), the chip keys
// (chip:L, chips:L) and the multiple-selection toggles (root:L664-710). Pure functions over indexes and form values: no DOM, no
// Stimulus.
//
// Known divergences: none.
import { isCharacterKey } from "chadcn/primitives/typeahead"

/**
 * The index an ArrowDown / ArrowUp moves the highlight to (-1: none). With `loopFocus` the highlight wraps, passing through "none"
 * at either end when `autoHighlight` is false.
 * @param {number} current Highlighted index, -1 for none.
 * @param {number} count Number of shown items (> 0).
 * @param {object} options
 * @param {boolean} options.decrement ArrowUp.
 * @param {boolean} options.loopFocus
 * @param {boolean|string} options.autoHighlight false, true or "always".
 * @returns {number}
 * @example
 * nextHighlight(2, 3, { decrement: false, loopFocus: true, autoHighlight: false }) // -1
 */
export function nextHighlight(current, count, { decrement, loopFocus, autoHighlight }) {
  const max = count - 1
  if (!loopFocus) return decrement ? Math.max(0, current - 1) : Math.min(max, current + 1)
  if (decrement ? current <= 0 : current >= max) {
    const outside = decrement ? -1 : count
    return autoHighlight === false && current !== outside ? -1 : decrement ? max : 0
  }
  return current + (decrement ? -1 : 1)
}

/**
 * The highlight an opening popup starts with: the first selected item, else (opened with an arrow key) the first / last enabled
 * one, else the first item with `autoHighlight: "always"`; null for none.
 * @param {{key: string, disabled: boolean}[]} entries The shown items in order.
 * @param {object} options
 * @param {string} options.reason Reason of the opening (kept for the selected item).
 * @param {string[]} options.selected Form values of the selection.
 * @param {string|null} options.keyOpened Key of the keydown that opened the popup.
 * @param {boolean|string} options.autoHighlight
 * @returns {{ index: number, reason: string, scroll: boolean }|null}
 * @example
 * openHighlight([{ key: "a", disabled: true }, { key: "b", disabled: false }], { reason: "list-navigation", selected: [], keyOpened: "ArrowDown", autoHighlight: false })
 * // { index: 1, reason: "list-navigation", scroll: true }
 */
export function openHighlight(entries, { reason, selected, keyOpened, autoHighlight }) {
  const selectedIndex = entries.findIndex(({ key }) => selected.includes(key))
  if (selectedIndex >= 0) return { index: selectedIndex, reason, scroll: true }
  const enabled = entries.map(({ disabled }, index) => ({ disabled, index })).filter(({ disabled }) => !disabled)
  if (keyOpened === "ArrowDown" && enabled.length) return { index: enabled[0].index, reason: "list-navigation", scroll: true }
  if (keyOpened === "ArrowUp" && enabled.length) return { index: enabled.at(-1).index, reason: "list-navigation", scroll: true }
  if (autoHighlight === "always" && entries.length) return { index: 0, reason: "none", scroll: false }
  return null
}

/**
 * The arrow keys that move to the previous and the next chip for a writing direction.
 * @param {string} direction "ltr" or "rtl".
 * @returns {{ previous: string, next: string }}
 * @example
 * chipArrowKeys("rtl") // { previous: "ArrowRight", next: "ArrowLeft" }
 */
export function chipArrowKeys(direction) {
  return direction === "rtl" ? { previous: "ArrowRight", next: "ArrowLeft" } : { previous: "ArrowLeft", next: "ArrowRight" }
}

/**
 * What a key pressed on a chip does. `focus`: index of the chip that takes focus afterwards (counted after a removal), or null
 * for the input. `prevent`: preventDefault only; `stop`: preventDefault and stopPropagation; `remove`: drop this chip's value;
 * `open`: open the popup.
 * @param {KeyboardEvent|object} keyEvent The key event (`key` and the `ctrlKey` / `metaKey` / `altKey` modifiers).
 * @param {number} index Index of the chip.
 * @param {object} options
 * @param {number} options.count Number of chips.
 * @param {number} options.selectedCount Number of selected values.
 * @param {{previous: string, next: string}} options.arrows From chipArrowKeys.
 * @returns {{ focus: number|null, prevent?: boolean, stop?: boolean, remove?: boolean, open?: boolean }}
 * @example
 * chipKeyAction({ key: "Backspace" }, 2, { count: 3, selectedCount: 3, arrows }) // { focus: 1, remove: true, stop: true }
 */
export function chipKeyAction(keyEvent, index, { count, selectedCount, arrows }) {
  const { key } = keyEvent
  if (key === arrows.previous) return { focus: index > 0 ? index - 1 : null, prevent: true }
  if (key === arrows.next) return { focus: index < count - 1 ? index + 1 : null, prevent: true }
  if (key === "Backspace" || key === "Delete") {
    const next = index >= selectedCount - 1 ? selectedCount - 2 : index
    return { focus: next < 0 ? null : next, remove: true, stop: true }
  }
  if (key === "Enter" || key === " ") return { focus: null, stop: true }
  if (key === "ArrowDown" || key === "ArrowUp") return { focus: null, stop: true, open: true }
  if (isCharacterKey(keyEvent)) return { focus: null }
  return { focus: index }
}

/**
 * A multiple selection with `key` added at the end, or removed when present.
 * @param {string[]} selected
 * @param {string} key
 * @returns {string[]}
 * @example
 * toggleValue(["a", "b"], "a") // ["b"]
 */
export function toggleValue(selected, key) {
  return selected.includes(key) ? selected.filter((value) => value !== key) : [...selected, key]
}

/**
 * The selection without the value at `index`.
 * @param {string[]} selected
 * @param {number} index
 * @returns {string[]}
 * @example
 * withoutIndex(["a", "b", "c"], 1) // ["a", "c"]
 */
export function withoutIndex(selected, index) {
  return selected.filter((_, position) => position !== index)
}
