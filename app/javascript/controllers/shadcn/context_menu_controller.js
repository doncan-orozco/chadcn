import { Controller } from "@hotwired/stimulus"
import { MenuLevel } from "controllers/shadcn/dropdown_menu_controller"

// Radix ContextMenu over the Menu code shared with DropdownMenu. Spec: docs/shadcn-port/specs/context-menu.md.
//
// The controller element is the Trigger (a span). Everything inside the menu (items, subs, typeahead, dismissal, focus,
// positioning) is the shared MenuLevel from the dropdown-menu controller; this file only adds what ContextMenu changes:
// the open point (a zero-size virtual anchor), the contextmenu / touch long-press opening and the forced right/start
// placement (the server renders side: right, sideOffset: 2, align: start into the template options).
const TEMPLATE = "shadcn--dropdown-menu-template"
// The focus is restored by FocusScope to what had it when the Content mounted (there is no trigger to return to).
class ContextLevel extends MenuLevel {
  teardown() {
    const mounted = !this.gone
    super.teardown()
    if (mounted && this.isRoot) this.controller.restoreFocus()
  }
}

export default class extends Controller {
  subTriggerSelector = "[data-slot=context-menu-sub-trigger]"

  static values = {
    open: Boolean,
    controlled: Boolean,
    modal: { type: Boolean, default: true },
    dir: { type: String, default: "ltr" },
    template: String,
    longPressDelay: { type: Number, default: 700 },
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
    this.point = { x: 0, y: 0 }
    this.longPressTimer = 0
    this.usingKeyboard = false
    this.hasInteractedOutside = false
    this.disconnecting = false
    this.onWindowBlur = () => this.requestOpen(false)
    // Radix reads the pointer position lazily: a zero-size rect at the last open point.
    this.anchor = {
      contextElement: this.element,
      getBoundingClientRect: () => DOMRect.fromRect({ width: 0, height: 0, x: this.point.x, y: this.point.y }),
      setAttribute() {},
      removeAttribute() {}
    }

    const { signal } = this.abort
    const touchOrPen = (handler) => (event) => event.pointerType !== "mouse" && handler(event)
    this.element.addEventListener("contextmenu", (event) => this.#onContextMenu(event), { signal })
    this.element.addEventListener("pointerdown", touchOrPen((event) => this.#onLongPressStart(event)), { signal })
    for (const type of ["pointermove", "pointercancel", "pointerup"]) {
      this.element.addEventListener(type, touchOrPen(() => this.#clearLongPress()), { signal })
    }
    // Radix clears the long-press timer in an effect that depends on `disabled` (CM:80-81).
    this.disabledObserver = new MutationObserver(() => this.#disabled && this.#clearLongPress())
    this.disabledObserver.observe(this.element, { attributes: true, attributeFilter: ["data-disabled"] })
    this.element.addEventListener("shadcn--context-menu:close-auto-focus", (event) => this.#trackCloseFocus(event), { signal })
    document.addEventListener("turbo:before-cache", () => this.#reset(), { signal })
    this.#trackModality(signal)

    if (this.isOpen) this.#mount()
    if (this.isOpen) window.addEventListener("blur", this.onWindowBlur)
    this.#syncTrigger()
  }

  disconnect() {
    if (!this.template) return
    this.disconnecting = true
    this.#clearLongPress()
    this.disabledObserver.disconnect()
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

  restoreFocus() {
    const previous = this.previousFocus
    this.previousFocus = null
    const { event, interactedOutside } = this.closeFocus ?? {}
    this.closeFocus = null
    if (this.disconnecting || event?.defaultPrevented || interactedOutside || !previous?.isConnected || document.activeElement === previous) return
    previous.focus()
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
    this.previousFocus = document.activeElement
    this.closeFocus = null
    this.root = new ContextLevel(this, { anchor: this.anchor, template: this.template, open: this.isOpen })
    this.root.mount()
  }

  #syncTrigger() {
    this.element.dataset.state = this.isOpen ? "open" : "closed"
  }

  // close-auto-focus is dispatched by the shared level right before it resets the outside-interaction flag.
  #trackCloseFocus(event) {
    this.closeFocus = { event, interactedOutside: this.hasInteractedOutside }
  }

  get #disabled() { return this.element.hasAttribute("data-disabled") }

  #openAt(event) {
    this.point = { x: event.clientX, y: event.clientY }
    if (this.isOpen) this.root?.placement.update()
    else this.requestOpen(true)
  }

  #onContextMenu(event) {
    if (event.defaultPrevented || this.#disabled) return
    this.#clearLongPress()
    this.#openAt(event)
    event.preventDefault()
  }

  #onLongPressStart(event) {
    if (event.defaultPrevented || this.#disabled) return
    this.#clearLongPress()
    if (this.isOpen) this.requestOpen(false)
    this.longPressTimer = window.setTimeout(() => this.#openAt(event), this.longPressDelayValue)
  }

  #clearLongPress() {
    window.clearTimeout(this.longPressTimer)
    this.longPressTimer = 0
  }

  // A cached page must not restore an open menu.
  #reset() {
    this.disconnecting = true
    this.#clearLongPress()
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
}
