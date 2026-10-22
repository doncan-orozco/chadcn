import { Controller } from "@hotwired/stimulus"
import { items, textValue } from "chadcn/primitives/collection"
import { rovingFocus } from "chadcn/primitives/roving_focus"
import { isCharacterKey, nextMatch, typeahead } from "chadcn/primitives/typeahead"

// Parity probe for chadcn/primitives/typeahead (scenarios _primitives-typeahead): the Radix Menu content typeahead
// (react-menu handleTypeaheadSearch, onKeyDown, onBlur) over server-rendered `role="menuitem"` items, composed with
// roving focus like Menu does, plus the focus-driven `data-highlighted` of MenuItem.
export default class extends Controller {
  connect() {
    // Menu content: auto-focused on mount, and entry focus never jumps to an item unless the keyboard opened it.
    this.roving = rovingFocus(this.element, { orientation: "vertical", loop: true, onEntryFocus: (event) => event.preventDefault() })
    this.typeahead = typeahead({ onSearch: (search) => this.#search(search) })
    this.element.addEventListener("keydown", this.#keydown)
    this.element.addEventListener("focusin", this.#highlight)
    this.element.addEventListener("focusout", this.#blur)
    this.element.focus({ preventScroll: true })
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.#keydown)
    this.element.removeEventListener("focusin", this.#highlight)
    this.element.removeEventListener("focusout", this.#blur)
    this.typeahead.release()
    this.roving.release()
  }

  #keydown = (event) => {
    if (event.key === "Tab") event.preventDefault()
    if (isCharacterKey(event)) this.typeahead.push(event.key)
  }

  #search(search) {
    const enabled = items(this.element)
    const current = enabled.find((el) => el === document.activeElement)
    const values = enabled.map(textValue)
    const match = nextMatch(values, search, current && textValue(current))
    const target = enabled.find((el) => textValue(el) === match)
    if (target) setTimeout(() => target.focus())
  }

  #highlight = (event) => event.target.closest("[role=menuitem]")?.setAttribute("data-highlighted", "")

  #blur = (event) => {
    event.target.closest("[role=menuitem]")?.removeAttribute("data-highlighted")
    if (this.element.contains(event.relatedTarget)) return
    this.typeahead.reset()
  }
}
