import { Controller } from "@hotwired/stimulus"
import { isDisabled, wrapArray } from "chadcn/primitives/collection"
import { MenuLevel } from "chadcn/primitives/menu_level"
import { rovingFocus } from "chadcn/primitives/roving_focus"

// Radix Menubar + Menu. Spec: dev/port/specs/menubar.md (Behavior).
//
// The controller element is the root. One controller drives every Menu and Sub: triggers are roving items of the root
// (horizontal), Content and SubContent ship in inert <template>s and are mounted (portaled or in place) only while open,
// exactly like Radix. The menu mechanics are the shared MenuLevel primitive (chadcn/primitives/menu_level, the same
// react-menu as dropdown-menu); each Menu passes it the menubar behavior: every menu is non-modal, the root value decides
// which menu is open, close focus, focus outside, entry focus and the ArrowLeft/ArrowRight switching of menus.
const TEMPLATE = "chadcn--menubar-template"
const MENUBAR_CONTENT = "[data-radix-menubar-content]"
const SELECTION_KEYS = ["Enter", " "]

const templateIn = (scope, id) => scope.querySelector(`template[data-${TEMPLATE}="${id}"]`)

// One MenubarMenu: its trigger, its template and the per menu flags of Radix (wasKeyboardTriggerOpenRef,
// hasInteractedOutsideRef).
class Menu {
  constructor(controller, trigger) {
    this.controller = controller
    this.trigger = trigger
    this.value = trigger.getAttribute("data-chadcn--menubar-menu-value")
    this.contentId = trigger.getAttribute("data-chadcn--menubar-content-id")
    this.template = templateIn(controller.element, this.contentId)
    this.level = null
    this.isOpen = false
    this.wasKeyboardTriggerOpen = false
    this.hasInteractedOutside = false
    this.behavior = {
      prefix: "chadcn--menubar",
      subTrigger: "[data-slot=menubar-sub-trigger]",
      modal: () => false,
      close: () => controller.close(),
      detach: () => { this.level = null },
      // Mb:228-232: focus moving onto a trigger of the menubar keeps the menu open.
      onFocusOutside: (level, event) => {
        const target = event.detail.originalEvent.target
        if (controller.menus.some((menu) => menu.trigger.contains(target))) event.preventDefault()
      },
      onInteractOutside: () => { this.hasInteractedOutside = true },
      // Mb:220-227: the menubar always takes over the focus return; focus goes to the trigger only when no menu is open
      // any more and the content had no outside interaction.
      onCloseAutoFocus: (level) => {
        if (controller.dispatch("close-auto-focus", { target: level.content }).defaultPrevented) return
        if (!controller.current && !this.hasInteractedOutside) this.trigger.focus()
        this.hasInteractedOutside = false
      },
      // Mb:236-238: the root content only takes the entry focus when the menu was opened from the trigger by the keyboard.
      entryFocus: () => this.wasKeyboardTriggerOpen,
      // MenubarContent onKeyDown (checkForDefaultPrevented: false). A content mounted in place already reaches the root
      // content's listener by bubbling; a portaled one reaches it through the React tree in Radix, so it calls it itself.
      onKeyDown: (level, event) => {
        if (level.isRoot || !level.rootLevel.content.contains(level.content)) this.#switchMenu(level, event)
      }
    }
  }

  get disabled() { return isDisabled(this.trigger) }

  sync(open) {
    this.isOpen = open
    this.trigger.setAttribute("aria-expanded", String(open))
    this.trigger.dataset.state = open ? "open" : "closed"
    if (open) this.trigger.setAttribute("aria-controls", this.contentId)
    else this.trigger.removeAttribute("aria-controls")
  }

  show() {
    if (!this.template) return
    if (this.level) return this.level.isOpen ? undefined : this.level.reopen()
    this.level = new MenuLevel(this.controller, { anchor: this.trigger, template: this.template, open: true, behavior: this.behavior })
    this.level.mount()
  }

  hide() {
    this.wasKeyboardTriggerOpen = false
    this.level?.close()
  }

  // Mb:239-261: ArrowRight / ArrowLeft anywhere in the menu content switch to the next / previous menu.
  #switchMenu(level, event) {
    if (!["ArrowRight", "ArrowLeft"].includes(event.key)) return
    const { controller } = this
    const target = event.target
    const targetIsSubTrigger = target.hasAttribute("data-radix-menubar-subtrigger")
    const insideSubMenu = target.closest(MENUBAR_CONTENT) !== level.rootLevel.content
    const isPrevKey = event.key === (controller.dirValue === "rtl" ? "ArrowRight" : "ArrowLeft")
    if (!isPrevKey && targetIsSubTrigger) return
    if (insideSubMenu && isPrevKey) return
    let candidates = controller.menus.filter((menu) => !menu.disabled)
    if (isPrevKey) candidates.reverse()
    const index = candidates.indexOf(this)
    candidates = controller.loopValue ? wrapArray(candidates, index + 1) : candidates.slice(index + 1)
    if (candidates[0]) controller.open(candidates[0])
  }
}

export default class extends Controller {
  static values = {
    value: String,
    controlled: Boolean,
    loop: { type: Boolean, default: true },
    dir: { type: String, default: "ltr" },
    subOpenDelay: { type: Number, default: 100 },
    pointerGraceTimeout: { type: Number, default: 300 },
    typeaheadTimeout: { type: Number, default: 1000 }
  }

  connect() {
    this.abort = new AbortController()
    this.current = this.valueValue
    this.usingKeyboard = false
    this.disconnecting = false
    this.onWindowBlur = () => this.close()
    this.menus = [...this.element.querySelectorAll("[data-slot=menubar-trigger]")].map((trigger) => new Menu(this, trigger))

    const { signal } = this.abort
    this.roving = rovingFocus(this.element, { orientation: "horizontal", loop: this.loopValue, dir: this.dirValue })
    this.menus.forEach((menu) => this.#bindTrigger(menu, signal))
    document.addEventListener("turbo:before-cache", () => this.#reset(), { signal })
    this.#trackModality(signal)

    this.#render()
  }

  disconnect() {
    this.disconnecting = true
    this.menus.forEach((menu) => menu.level?.teardown())
    this.abort.abort()
    this.roving.release()
    window.removeEventListener("blur", this.onWindowBlur)
    this.menus = []
  }

  // A controlled menubar is driven by its value (the server re-rendered).
  valueValueChanged(value) {
    if (this.menus && value !== this.current) this.#apply(value)
  }

  // --- MenubarContext (Mb:59-73) ---------------------------------------------------------------------------------

  open(menu) {
    this.#request(menu.value)
    this.roving.setCurrentTabStop(menu.trigger.id)
  }

  close() { this.#request("") }

  toggle(menu) {
    this.#request(this.current ? "" : menu.value)
    this.roving.setCurrentTabStop(menu.trigger.id)
  }

  // Every value change request (useControllableState onChange): the event fires on a change, the DOM only changes when
  // uncontrolled.
  #request(next) {
    if (next === this.current) return
    this.dispatch("value-change", { detail: { value: next } })
    if (!this.controlledValue) this.#apply(next)
  }

  #apply(next) {
    this.current = next
    this.valueValue = next
    this.#render()
  }

  #render() {
    const anyOpen = Boolean(this.current)
    this.menus.forEach((menu) => {
      const open = menu.value === this.current
      const changed = open !== menu.isOpen
      menu.sync(open)
      if (!open && (changed || menu.level)) menu.hide()
    })
    this.menus.forEach((menu) => menu.isOpen && menu.show())
    window.removeEventListener("blur", this.onWindowBlur)
    if (anyOpen) window.addEventListener("blur", this.onWindowBlur)
  }

  // A cached page must not restore an open menu.
  #reset() {
    this.disconnecting = true
    this.menus.forEach((menu) => menu.level?.teardown())
    this.disconnecting = false
    this.current = ""
    this.valueValue = ""
    this.menus.forEach((menu) => menu.sync(false))
    window.removeEventListener("blur", this.onWindowBlur)
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

  // --- Trigger (Mb:140-195). The listeners sit on the trigger so they run before the roving group's own keydown. ------

  #bindTrigger(menu, signal) {
    const { trigger } = menu
    trigger.addEventListener("pointerdown", (event) => this.#onTriggerPointerDown(event, menu), { signal })
    trigger.addEventListener("pointerenter", (event) => this.#onTriggerPointerEnter(event, menu), { signal })
    trigger.addEventListener("keydown", (event) => this.#onTriggerKeyDown(event, menu), { signal })
    trigger.addEventListener("focus", () => trigger.setAttribute("data-highlighted", ""), { signal })
    trigger.addEventListener("blur", () => trigger.removeAttribute("data-highlighted"), { signal })
  }

  #onTriggerPointerDown(event, menu) {
    if (event.defaultPrevented || menu.disabled || event.button !== 0 || event.ctrlKey) return
    const wasOpen = menu.isOpen
    this.open(menu)
    if (!wasOpen) event.preventDefault() // the trigger must not take focus away from the content
  }

  // The focus goes first: the content that opens takes the focus right after (React renders after the handler).
  #onTriggerPointerEnter(event, menu) {
    if (event.defaultPrevented || !this.current || menu.isOpen) return
    menu.trigger.focus()
    this.open(menu)
  }

  #onTriggerKeyDown(event, menu) {
    if (event.defaultPrevented || menu.disabled) return
    const { key } = event
    if (![...SELECTION_KEYS, "ArrowDown"].includes(key)) return
    menu.wasKeyboardTriggerOpen = true // before the menu mounts: its entry focus reads it
    if (SELECTION_KEYS.includes(key)) this.toggle(menu)
    if (key === "ArrowDown") this.open(menu)
    event.preventDefault()
  }
}
