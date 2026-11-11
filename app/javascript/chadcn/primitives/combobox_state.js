// The Base UI state machine of the Combobox (Base UI 1.9.0 `AriaCombobox`, spec dev/port/specs/combobox.md, Behavior): the
// selection, the text of the input and the query it filters with (root:L225-420), the open requests (root:L580-650), the cleanup
// after the exit (root:L717-756), the item selection (root:L664-710) and the highlighted item (nav:L303-411). Every change is first
// offered to the caller as a cancelable event and applied only when it was not cancelled and the matching value is not controlled.
// No DOM, no Stimulus: the chadcn--combobox controller is the `host` that dispatches the events and writes the DOM.
//
// Known divergences: none beyond the controller's (item identity is the form value).
import { nextHighlight, openHighlight, toggleValue } from "chadcn/primitives/combobox_navigation"

const PUBLIC_HIGHLIGHT_REASONS = ["keyboard", "pointer"]

/**
 * @typedef {object} ComboboxHost
 * @property {(name: string, detail: object, options?: {cancelable?: boolean}) => boolean} emit Dispatches an event; true when it
 *   was cancelled.
 * @property {(key: string) => string} labelOf Label of a form value.
 * @property {(open: boolean) => boolean} canOpen Whether a request to open (or close) can be made at all.
 * @property {(selected: string[]) => void} selectionChanged The selection changed (uncontrolled): store and render it.
 * @property {(text: string, { store: boolean }) => void} writeText Writes the text into the inputs; `store` keeps it as the value.
 * @property {() => void} queryChanged The query changed: filter the list again.
 * @property {(open: boolean, reason: string, event: Event|null) => void} openChanged The open state changed (uncontrolled).
 * @property {() => string[]} shownKeys Form values of the shown items, in order ([] while unmounted).
 * @property {() => boolean[]} shownDisabled Disabled flags of the shown items, in order.
 * @property {() => boolean} mounted Whether the popup is in the document.
 * @property {(index: number) => void} paintHighlight Paints the highlighted index (-1: none).
 * @property {(index: number) => void} scrollToShown Scrolls the shown item at `index` into view.
 */

/**
 * Selection, text, open state and highlight of one combobox.
 * @example
 * const state = new ComboboxState({ single: true, inPopup: false, selected: [], text: "", controlled: {} }, host)
 * state.select("apple", event, { filtering: () => false })
 */
export class ComboboxState {
  /**
   * @param {object} options
   * @param {boolean} options.single Single selection.
   * @param {boolean} options.inPopup The search field lives inside the popup.
   * @param {string[]} options.selected Initial selection (form values).
   * @param {string} options.text Initial text of the input.
   * @param {{value?: boolean, inputValue?: boolean, open?: boolean}} options.controlled Which values the caller controls.
   * @param {ComboboxHost} host
   */
  constructor({ single, inPopup, selected, text, controlled }, host) {
    this.single = single
    this.inPopup = inPopup
    this.controlled = controlled
    this.host = host
    this.selected = [...selected]
    this.text = text
    this.initialText = text
    this.isOpen = false
    this.queryEdited = false
    // The query a closing popup keeps filtering with, so the list does not jump during the exit (null: none).
    this.closeQuery = null
    this.hadInputClear = false
    this.active = -1
    this.pointerModality = true
  }

  /** Label of the single selection ("" when none or multiple). @returns {string} */
  get selectedLabel() {
    return this.single && this.selected.length ? this.host.labelOf(this.selected[0]) : ""
  }

  /** The text that filters: the frozen query while the popup closes, else the trimmed text. @returns {string} */
  query() {
    return !this.isOpen && this.closeQuery !== null ? this.closeQuery : this.text.trim()
  }

  /**
   * Asks to change the selection; false when the caller cancelled. Controlled: the event fires, the selection stays. A single
   * combobox with its input outside the popup shows the label of the new selection.
   * @param {string[]} next
   * @param {string} reason
   * @returns {boolean}
   */
  setSelected(next, reason) {
    const value = this.single ? (next[0] ?? null) : next
    if (this.host.emit("value-change", { value, reason })) return false
    if (!this.controlled.value) {
      this.selected = [...next]
      this.host.selectionChanged(this.selected)
    }
    if (this.single && !this.inPopup) this.setText(next.length ? this.host.labelOf(next[0]) : "", reason)
    return true
  }

  /**
   * Asks to change the text; false when the caller cancelled. Controlled: the inputs keep showing the current text.
   * @param {string} next
   * @param {string} reason
   * @returns {boolean}
   */
  setText(next, reason) {
    if (this.host.emit("input-value-change", { inputValue: next, reason })) return false
    this.hadInputClear = reason === "input-clear"
    if (this.controlled.inputValue) {
      this.host.writeText(this.text, { store: false })
      return true
    }
    this.applyText(next)
    return true
  }

  /**
   * Applies a text (no event): an open popup whose text moved away from the initial text and the selection label is being edited.
   * @param {string} next
   */
  applyText(next) {
    this.text = next
    this.host.writeText(next, { store: !this.controlled.inputValue })
    const trimmed = next.trim()
    if (this.isOpen && trimmed !== "" && trimmed !== this.initialText && !(this.single && !this.inPopup && next === this.selectedLabel)) this.queryEdited = true
    this.host.queryChanged()
  }

  /** The user typed a query: a close the caller ignored no longer freezes it, and the list follows it. */
  typed() {
    if (this.isOpen && this.closeQuery !== null) this.closeQuery = null
  }

  /** The typed text filters from now on. */
  markEdited() {
    this.queryEdited = true
  }

  /**
   * Clears the text and the selection (Escape on a closed input, the Clear button).
   * @param {string} reason
   */
  clear(reason) {
    this.setText("", reason)
    this.setSelected([], reason)
  }

  /**
   * `setOpen`: asks the caller first; a controlled popup keeps its state until the caller changes it. A close freezes the query
   * that was edited; a reopen during the exit keeps what that close froze.
   * @param {boolean} next
   * @param {string} reason
   * @param {Event|null} event
   * @param {object} [options]
   * @param {string} [options.query] The query to freeze (default: the current one).
   */
  requestOpen(next, reason, event, { query = this.query() } = {}) {
    if (next === this.isOpen || !this.host.canOpen(next)) return
    if (this.host.emit("open-change", { open: next, reason })) return
    if (next && this.closeQuery !== null) this.#interruptedReopen(reason === "input-change")
    if (!next && this.queryEdited) {
      this.closeQuery = query
      if (this.single) {
        if (query === "") this.queryEdited = false
      } else if (this.inPopup) {
        this.setActive(-1, reason)
      } else {
        this.setText("", "input-clear")
      }
    }
    if (this.controlled.open) return
    this.host.openChanged(next, reason, event)
  }

  #interruptedReopen(isInputChange) {
    const pending = !isInputChange && this.inPopup && this.text !== "" && (this.text.trim() === this.closeQuery || this.text === this.selectedLabel)
    if (!isInputChange && (pending || this.text === "" || (this.single && !this.inPopup && this.text === this.selectedLabel))) this.queryEdited = false
    this.closeQuery = null
    if (pending) this.setText("", "input-clear")
  }

  /** handleUnmountCleanup (root:L717-756): after the exit the query is forgotten and the text settles on the selection. */
  finish() {
    this.reset()
    if (this.single) {
      if (this.inPopup) {
        if (this.text !== "") this.setText("", "input-clear")
      } else {
        const label = this.selectedLabel
        if (this.text !== label) this.setText(label, label === "" ? "input-clear" : "none")
      }
    } else if (this.text !== "" && !this.hadInputClear) {
      this.setText("", "input-clear")
    }
  }

  /** Forgets the edited and frozen query (Turbo snapshot, unmount). */
  reset() {
    this.queryEdited = false
    this.closeQuery = null
  }

  /**
   * handleSelection (root:L664-710): single selects and closes; multiple toggles, and while a query filters, a search field in the
   * popup is cleared (the toggled item stays highlighted) and an input outside it closes the popup.
   * @param {string} key Form value of the pressed item.
   * @param {Event|null} event
   * @param {object} options
   * @param {() => boolean} options.filtering Whether the field holds a query (asked after the selection changed).
   */
  select(key, event, { filtering }) {
    const query = this.query()
    if (this.single) {
      if (this.setSelected([key], "item-press")) this.requestOpen(false, "item-press", event, { query })
      return
    }
    if (!this.setSelected(toggleValue(this.selected, key), "item-press") || !filtering()) return
    if (!this.inPopup) return this.requestOpen(false, "item-press", event, { query })
    this.setText("", "input-clear")
    const index = this.host.shownKeys().indexOf(key)
    if (index >= 0) this.setActive(index, "none")
  }

  /**
   * Sets the highlighted index (-1: none, always -1 while unmounted), paints it and reports a change with `item-highlighted`.
   * Keyboard moves (and `scroll`) bring the item into view.
   * @param {number} index
   * @param {string} reason
   * @param {Event|null} [event]
   * @param {object} [options]
   * @param {boolean} [options.scroll=false]
   */
  setActive(index, reason, event = null, { scroll = false } = {}) {
    const next = this.host.mounted() ? index : -1
    const changed = next !== this.active
    this.active = next
    this.host.paintHighlight(next)
    if (changed) {
      const value = next >= 0 ? this.host.shownKeys()[next] : undefined
      this.host.emit("item-highlighted", { value, index: next, reason: PUBLIC_HIGHLIGHT_REASONS.includes(reason) ? reason : "none" }, { cancelable: false })
    }
    if (next >= 0 && (scroll || !this.pointerModality)) this.host.scrollToShown(next)
  }

  /**
   * The highlight an opening popup starts with (unless the query was edited).
   * @param {string} reason Reason of the opening.
   * @param {string|null} keyOpened Key of the keydown that opened it.
   * @param {boolean|string} autoHighlight
   */
  openHighlight(reason, keyOpened, autoHighlight) {
    if (!this.host.mounted() || this.queryEdited) return
    const disabled = this.host.shownDisabled()
    const entries = this.host.shownKeys().map((key, index) => ({ key, disabled: disabled[index] }))
    const start = openHighlight(entries, { reason, selected: this.selected, keyOpened, autoHighlight })
    if (start) this.setActive(start.index, start.reason, null, { scroll: start.scroll })
  }

  /**
   * ArrowDown / ArrowUp in an open popup (useListNavigation with virtual focus).
   * @param {boolean} decrement ArrowUp.
   * @param {Event} event
   * @param {object} options `loopFocus` and `autoHighlight` of the combobox.
   */
  navigate(decrement, event, { loopFocus, autoHighlight }) {
    const count = this.host.shownKeys().length
    if (!this.host.mounted() || count === 0) return
    this.setActive(nextHighlight(this.active, count, { decrement, loopFocus, autoHighlight }), "keyboard", event)
  }
}
