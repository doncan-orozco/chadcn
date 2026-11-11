import { Controller } from "@hotwired/stimulus"
import { MenuLevel } from "chadcn/primitives/menu_level"

// Radix DropdownMenu + Menu. Spec: dev/port/specs/dropdown-menu.md (Behavior).
//
// The controller element is the Trigger. Content and SubContent ship in inert <template>s and are mounted (portaled or in
// place) only while open, exactly like Radix. The menu mechanics (items, subs, typeahead, dismissal, focus, positioning)
// are the shared MenuLevel primitive (chadcn/primitives/menu_level), whose default behavior is this controller's root:
// it calls requestOpen, reads modalValue and hasInteractedOutside, and clears root when the content is gone.
const TEMPLATE = "chadcn--dropdown-menu-template"
const SELECTION_KEYS = ["Enter", " "]

export default class extends Controller {
  static values = {
    open: Boolean,
    controlled: Boolean,
    modal: { type: Boolean, default: true },
    dir: { type: String, default: "ltr" },
    template: String,
    subOpenDelay: { type: Number, default: 100 },
    pointerGraceTimeout: { type: Number, default: 300 },
    typeaheadTimeout: { type: Number, default: 1000 }
  }

  connect() {
    this.template = document.querySelector(`template[data-${TEMPLATE}="${this.templateValue}"]`)
    if (!this.template) return

    this.abort = new AbortController()
    this.isOpen = this.openValue
    this.root = null
    this.usingKeyboard = false
    this.hasInteractedOutside = false
    this.disconnecting = false
    this.onWindowBlur = () => this.requestOpen(false)

    const { signal } = this.abort
    this.element.addEventListener("pointerdown", (event) => this.#onTriggerPointerDown(event), { signal })
    this.element.addEventListener("keydown", (event) => this.#onTriggerKeyDown(event), { signal })
    document.addEventListener("turbo:before-cache", () => this.#reset(), { signal })
    this.#trackModality(signal)

    if (this.isOpen) this.#mount()
    if (this.isOpen) window.addEventListener("blur", this.onWindowBlur)
    this.#syncTrigger()
  }

  disconnect() {
    if (!this.template) return
    this.disconnecting = true
    this.root?.teardown()
    this.abort.abort()
    window.removeEventListener("blur", this.onWindowBlur)
    this.template = null
  }

  // A controlled menu is driven by its open value (the server re-rendered).
  openValueChanged(value) {
    if (this.template && value !== this.isOpen) this.#apply(value)
  }

  // Every open/close request (useControllableState onChange): the event always fires, the DOM only changes when uncontrolled.
  requestOpen(next) {
    if (next === this.isOpen) return
    this.dispatch("open-change", { detail: { open: next } })
    if (!this.controlledValue) this.#apply(next)
  }

  #apply(next) {
    this.isOpen = next
    this.openValue = next
    this.#syncTrigger()
    if (next) {
      if (this.root) this.root.reopen()
      else this.#mount()
      window.addEventListener("blur", this.onWindowBlur)
    } else {
      window.removeEventListener("blur", this.onWindowBlur)
      this.root?.close()
    }
  }

  #mount() {
    this.root = new MenuLevel(this, { anchor: this.element, template: this.template, open: this.isOpen })
    this.root.mount()
  }

  #syncTrigger() {
    this.element.setAttribute("aria-expanded", String(this.isOpen))
    this.element.dataset.state = this.isOpen ? "open" : "closed"
    if (this.isOpen) this.element.setAttribute("aria-controls", this.templateValue)
    else this.element.removeAttribute("aria-controls")
  }

  // A cached page must not restore an open menu.
  #reset() {
    this.disconnecting = true
    this.root?.teardown()
    this.disconnecting = false
    window.removeEventListener("blur", this.onWindowBlur)
    this.isOpen = false
    this.openValue = false
    this.#syncTrigger()
  }

  // Menu keeps "using keyboard" until the next pointerdown/pointermove (M:67-80).
  #trackModality(signal) {
    const pointer = () => (this.usingKeyboard = false)
    document.addEventListener("keydown", () => {
      this.usingKeyboard = true
      document.addEventListener("pointerdown", pointer, { capture: true, once: true, signal })
      document.addEventListener("pointermove", pointer, { capture: true, once: true, signal })
    }, { capture: true, signal })
  }

  get #disabled() { return this.element.hasAttribute("data-disabled") }

  #onTriggerPointerDown(event) {
    if (event.defaultPrevented || this.#disabled || event.button !== 0 || event.ctrlKey) return
    const wasOpen = this.isOpen
    this.requestOpen(!wasOpen)
    if (!wasOpen) event.preventDefault() // the trigger must not take focus away from the content
  }

  #onTriggerKeyDown(event) {
    if (event.defaultPrevented || this.#disabled) return
    if (SELECTION_KEYS.includes(event.key)) this.requestOpen(!this.isOpen)
    if (event.key === "ArrowDown") this.requestOpen(true)
    if ([...SELECTION_KEYS, "ArrowDown"].includes(event.key)) event.preventDefault()
  }
}
