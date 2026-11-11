// The parts of the Combobox host that show or submit the selection (Base UI 1.9.0, spec dev/port/specs/combobox.md, Behavior):
// the hidden input(s) a native form submits (root:L1196-1297), the Value parts between their `value-start` / `value-end` markers
// (value:L14-41), the chips of a multiple selection (chips:L, chip:L) and the Clear button's mount and exit (clear:L47-124).
// No Stimulus: the chadcn--combobox controller owns one `ComboboxValue` and calls `render` whenever the selection changes.
//
// Known divergences: none beyond the controller's (item identity on the client is the form value).
import { chipArrowKeys, chipKeyAction } from "chadcn/primitives/combobox_navigation"
import { PART, part } from "chadcn/primitives/combobox_popup"

const CHIP = "[data-slot=combobox-chip]"

/**
 * Renders the selection into the host. `labelOf(key)` gives the label of a form value.
 * @example
 * const value = new ComboboxValue(host, { single: true, name: "fruit" }, ["apple"])
 * value.render(["pear"], { labelOf: (key) => labels.get(key) })
 */
export class ComboboxValue {
  /**
   * @param {HTMLElement} host The element of the chadcn--combobox controller.
   * @param {object} config
   * @param {boolean} config.single Single selection (one hidden input) or multiple (one hidden input per value).
   * @param {boolean} [config.required=false]
   * @param {string|null} [config.name] Name of the submitted inputs (multiple: none without it).
   * @param {string|null} [config.form] `form` attribute of the per-value inputs.
   * @param {boolean} [config.disabled=false]
   * @param {string[]} selected The selection the server rendered (the chips already in the document belong to it, in order).
   */
  constructor(host, { single, required = false, name = null, form = null, disabled = false }, selected) {
    this.host = host
    this.config = { single, required, name, form, disabled }
    this.hidden = host.querySelector(part("hidden-input"))
    this.chipsRoot = host.querySelector(part("chips"))
    this.chipKeys = new WeakMap()
    this.chips().forEach((chip, index) => this.chipKeys.set(chip, selected[index]))
    this.writing = false
    this.clearExit = null
  }

  /**
   * The chip elements in the Chips part, in order.
   * @returns {HTMLElement[]}
   */
  chips() {
    return [...(this.chipsRoot?.querySelectorAll(CHIP) ?? [])]
  }

  /**
   * Keys on a chip: arrows move between the chips, Backspace / Delete remove it, Enter / Space / a printable key go back to the
   * input, ArrowDown / ArrowUp open the popup (chipKeyAction).
   * @param {KeyboardEvent} event
   * @param {object} options
   * @param {number} options.selectedCount Number of selected values.
   * @param {string} options.direction Writing direction ("ltr" / "rtl").
   * @param {HTMLElement|null} options.input The input that takes the focus back.
   * @param {(index: number) => void} options.onRemove Removes the value of the chip at `index`.
   * @param {() => void} options.onOpen Opens the popup.
   */
  chipKeydown(event, { selectedCount, direction, input, onRemove, onOpen }) {
    const chips = this.chips()
    const index = chips.indexOf(event.target)
    const action = chipKeyAction(event, index, { count: chips.length, selectedCount, arrows: chipArrowKeys(direction) })
    if (action.prevent || action.stop) event.preventDefault()
    if (action.stop) event.stopPropagation()
    if (action.remove) onRemove(index)
    if (action.open) onOpen()
    if (action.focus === null) input?.focus()
    else this.chips()[action.focus]?.focus()
  }

  /**
   * Hidden inputs, Value parts and the Chips toolbar role for a new selection.
   * @param {string[]} selected Form values.
   * @param {object} options
   * @param {(key: string) => string} options.labelOf
   */
  render(selected, { labelOf }) {
    this.#syncInputs(selected)
    this.host.querySelectorAll(part("value-start")).forEach((start) => this.#renderValue(start, selected, labelOf))
    if (selected.length) this.chipsRoot?.setAttribute("role", "toolbar")
    else this.chipsRoot?.removeAttribute("role")
  }

  #syncInputs(selected) {
    const { single, required, name } = this.config
    this.#write(this.hidden, single ? (selected[0] ?? "") : "")
    if (this.hidden) this.hidden.required = required && !(!single && selected.length)
    if (single || !name) return
    // React keys these inputs by value: the ones that stay keep their node.
    const current = new Map([...this.host.querySelectorAll(part("form-value"))].map((input) => [input.value, input]))
    const inputs = selected.map((key) => current.get(key) ?? this.#formValueInput(key))
    current.forEach((input, key) => { if (!selected.includes(key)) input.remove() })
    this.hidden.after(...inputs)
  }

  #formValueInput(key) {
    const input = document.createElement("input")
    input.type = "hidden"
    if (this.config.form) input.setAttribute("form", this.config.form)
    input.name = this.config.name
    input.value = key
    input.disabled = this.config.disabled
    input.setAttribute(PART, "form-value")
    return input
  }

  // The hidden input keeps what a native form submits; like React it also tells listeners when the value changed. `writing` is
  // true while those events run, so the autofill listener can tell them from the browser's.
  #write(input, value) {
    if (!input || input.value === value) return
    input.value = value
    input.setAttribute("value", value)
    this.writing = true
    input.dispatchEvent(new Event("input", { bubbles: true }))
    input.dispatchEvent(new Event("change", { bubbles: true }))
    this.writing = false
  }

  /**
   * Native autofill writes the label or the value of an option into the hidden input (root:L1231-1281): the item it names.
   * @template {{k: string, l: string}} T
   * @param {T[]} items
   * @returns {T|undefined}
   */
  autofilled(items) {
    const wanted = this.hidden.value.toLowerCase()
    return items.find(({ k, l }) => k.toLowerCase() === wanted || l.toLowerCase() === wanted)
  }

  // Value parts: the content between the `value-start` / `value-end` markers follows the selection.
  #renderValue(start, selected, labelOf) {
    const end = markerEnd(start)
    if (!end) return
    const prototypes = new Map([...start.content.querySelectorAll(part("value-prototype"))].map((proto) => [proto.getAttribute("data-key"), proto]))
    const live = []
    for (let node = start.nextSibling; node && node !== end; node = node.nextSibling) live.push(node)
    if (!prototypes.size) return renderValueText(start, end, live, selected.map(labelOf))
    if (this.config.single) {
      const proto = prototypes.get(selected[0] ?? "")
      live.forEach((node) => node.remove())
      if (proto) end.before(proto.content.cloneNode(true))
      return
    }
    this.#renderChips(prototypes, live, end, selected)
  }

  // React keys the chips by position and value: the leading chips that did not change keep their node, the rest are rebuilt.
  #renderChips(prototypes, live, end, selected) {
    const isChip = (node) => node.nodeType === Node.ELEMENT_NODE && node.matches(CHIP)
    const current = live.filter(isChip)
    const others = live.filter((node) => !isChip(node))
    let stable = 0
    while (stable < current.length && this.chipKeys.get(current[stable]) === selected[stable]) stable += 1
    current.slice(stable).forEach((chip) => chip.remove())
    const rebuilt = selected.slice(stable).flatMap((key) => {
      const proto = prototypes.get(key)
      const chips = proto ? [...proto.content.cloneNode(true).querySelectorAll(CHIP)] : []
      chips.forEach((chip) => this.chipKeys.set(chip, key))
      return chips
    })
    ;(others[0] ?? end).before(...rebuilt)
  }

  /**
   * Clear button: mounted while something is selected, unmounted after its exit animation (clear:L47-124).
   * @param {boolean} visible Something is selected.
   * @param {boolean} open The popup is open (data-popup-open).
   */
  syncClear(visible, open) {
    const template = this.host.querySelector(part("clear-template"))
    if (!template) return
    const live = this.host.querySelector(part("clear"))
    if (visible && !live) {
      const fragment = template.content.cloneNode(true)
      const button = fragment.firstElementChild
      button.setAttribute("data-visible", "")
      if (open) button.setAttribute("data-popup-open", "")
      template.after(fragment)
    } else if (visible && live) {
      live.removeAttribute("data-ending-style")
      live.setAttribute("data-visible", "")
      this.clearExit = null
    } else if (!visible && live && !live.hasAttribute("data-ending-style")) {
      live.removeAttribute("data-visible")
      live.setAttribute("data-ending-style", "")
      const token = (this.clearExit = Symbol("clear"))
      requestAnimationFrame(async () => {
        await Promise.all(live.getAnimations().map((animation) => animation.finished.catch(() => {})))
        if (this.clearExit === token) live.remove()
      })
    }
    this.host.querySelector(part("clear"))?.toggleAttribute("data-popup-open", open)
  }

  /**
   * Turbo snapshot: a Clear button still running its exit with nothing selected leaves at once.
   * @param {boolean} visible Something is selected.
   */
  resetClear(visible) {
    this.clearExit = null
    const leaving = this.host.querySelector(part("clear"))
    if (leaving?.hasAttribute("data-ending-style") && !visible) leaving.remove()
  }
}

function renderValueText(start, end, live, labels) {
  const placeholder = start.getAttribute("data-has-placeholder") === "true" ? start.getAttribute("data-placeholder") : null
  const text = !labels.length && placeholder !== null ? placeholder : labels.join(", ")
  live.forEach((node) => node.remove())
  if (text !== "") end.before(document.createTextNode(text))
}

function markerEnd(start) {
  for (let node = start.nextSibling; node; node = node.nextSibling) {
    if (node.nodeType === Node.ELEMENT_NODE && node.matches(part("value-end"))) return node
  }
  return null
}
