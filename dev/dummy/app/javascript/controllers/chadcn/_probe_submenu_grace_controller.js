// Parity probe for chadcn/primitives/submenu_grace (+ positioner) against the raw Radix DropdownMenu with a sub menu
// (scenario _primitives-submenu-grace). Not a product controller: it models only what the grace logic observably drives
// (item focus on pointer move/leave, roving tab stop, sub open delay, sub closing on focus outside).
// Tree: root > trigger, menu > [item*, sub-trigger, sub-content > item*, item*]. Options (data-parity-options, shared with the
// React twin): side, align, sideOffset.
import { Controller } from "@hotwired/stimulus"
import { positioner } from "chadcn/primitives/positioner"
import { submenuGrace } from "chadcn/primitives/submenu_grace"

const SUB_OPEN_DELAY = 100
const mouse = (handler) => (event) => event.pointerType === "mouse" && handler(event)

export default class extends Controller {
  static count = 0

  connect() {
    this.options = JSON.parse(this.element.dataset.parityOptions || "{}")
    this.abort = new AbortController()
    this.trigger = this.element.querySelector(":scope > [data-slot=trigger]")
    const menu = this.element.querySelector(":scope > [data-slot=menu]")
    this.root = this.level(menu)
    this.setAttributes(this.trigger, { "aria-haspopup": "menu", "aria-expanded": "true", "data-state": "open", id: "probe-trigger", "aria-controls": menu.id })
    menu.setAttribute("aria-labelledby", "probe-trigger")
    this.subContent = menu.querySelector(":scope > [data-slot=sub-content]")
    this.subTrigger = menu.querySelector(":scope > [data-slot=sub-trigger]")
    this.subContent.remove()
    this.sub = this.level(this.subContent)
    this.setAttributes(this.subTrigger, { "aria-haspopup": "menu", "aria-expanded": "false", "data-state": "closed", id: "probe-sub-trigger" })
    this.subContent.setAttribute("aria-labelledby", "probe-sub-trigger")
    this.setupSubTrigger()
    document.addEventListener("focusin", (event) => this.focusOutside(event), { signal: this.abort.signal })
    this.placement = positioner(this.trigger, menu, { side: this.options.side, align: this.options.align, sideOffset: this.options.sideOffset })
    menu.focus({ preventScroll: true })
  }

  disconnect() {
    this.abort.abort()
    window.clearTimeout(this.openTimer)
    this.placement?.release()
    this.subPlacement?.release()
    this.root?.grace.release()
    this.sub?.grace.release()
  }

  setAttributes(el, attrs) {
    Object.entries(attrs).forEach(([name, value]) => el.setAttribute(name, value))
  }

  // One menu level (the menu or the sub menu): roving tab stop, item focus/leave rules, grace tracking.
  level(content) {
    content.style.outline = "none" // RovingFocusGroup root style
    content.id ||= `probe-menu-${++this.constructor.count}`
    this.setAttributes(content, { role: "menu", dir: "ltr", "aria-orientation": "vertical", "data-orientation": "vertical", "data-state": "open", tabindex: "-1" })
    const level = { content, grace: submenuGrace(content), items: [...content.querySelectorAll(":scope > [data-slot=item], :scope > [data-slot=sub-trigger]")] }
    const on = (el, type, handler) => el.addEventListener(type, handler, { signal: this.abort.signal })
    const setTabStop = (current) => level.items.forEach((item) => item.setAttribute("tabindex", item === current ? "0" : "-1"))
    setTabStop(null)
    level.items.forEach((item) => {
      this.setAttributes(item, { role: "menuitem", "data-orientation": "vertical" })
      on(item, "focus", () => {
        item.setAttribute("data-highlighted", "")
        setTabStop(item)
      })
      on(item, "blur", () => item.removeAttribute("data-highlighted"))
      on(item, "pointermove", mouse((event) => {
        if (event.defaultPrevented || level.grace.isPointerMovingToSubmenu(event)) return
        item.focus({ preventScroll: true })
      }))
      on(item, "pointerleave", mouse((event) => {
        if (level.grace.isPointerMovingToSubmenu(event)) return
        content.focus()
        setTabStop(null)
      }))
    })
    return level
  }

  // Radix MenuSubTrigger: its handlers run BEFORE the plain item handlers (composeEventHandlers), which skip when prevented.
  setupSubTrigger() {
    const trigger = this.subTrigger
    const on = (type, handler, options = {}) => trigger.addEventListener(type, handler, { signal: this.abort.signal, ...options })
    on("click", () => {
      trigger.focus()
      if (!this.subOpen) this.openSub()
    })
    on("pointermove", mouse((event) => {
      if (this.root.grace.isPointerMovingToSubmenu(event)) {
        event.preventDefault()
        return
      }
      if (!this.subOpen && !this.openTimer) {
        this.root.grace.clearIntent()
        this.openTimer = window.setTimeout(() => {
          this.openTimer = 0
          this.openSub()
        }, SUB_OPEN_DELAY)
      }
    }), { capture: true })
    on("pointerleave", mouse((event) => {
      window.clearTimeout(this.openTimer)
      this.openTimer = 0
      this.root.grace.subTriggerLeave(event, this.subOpen ? this.subContent : null)
    }), { capture: true })
  }

  openSub() {
    this.subOpen = true
    this.setAttributes(this.subTrigger, { "aria-expanded": "true", "data-state": "open", "aria-controls": this.subContent.id })
    this.subTrigger.after(this.subContent)
    this.subPlacement = positioner(this.subTrigger, this.subContent, { side: "right", align: "start" })
  }

  closeSub() {
    this.subOpen = false
    this.setAttributes(this.subTrigger, { "aria-expanded": "false", "data-state": "closed" })
    this.subTrigger.removeAttribute("aria-controls")
    this.subPlacement.release()
    this.subContent.parentElement.remove()
  }

  // Sub menu DismissableLayer: focus moving anywhere but the sub content or its trigger closes it.
  focusOutside(event) {
    if (this.subOpen && !this.subContent.contains(event.target) && event.target !== this.subTrigger) this.closeSub()
  }
}
