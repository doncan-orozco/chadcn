import { Controller } from "@hotwired/stimulus"
import { ITEM_SELECTOR, isDisabled, textValue, wrapArray } from "shadcn/primitives/collection"
import { dismissable } from "shadcn/primitives/dismissable_layer"
import { focusGuards } from "shadcn/primitives/focus_guards"
import { focusScope } from "shadcn/primitives/focus_scope"
import { ensureWrapper, positioner } from "shadcn/primitives/positioner"
import { presence } from "shadcn/primitives/presence"
import { rovingFocus } from "shadcn/primitives/roving_focus"
import { submenuGrace } from "shadcn/primitives/submenu_grace"
import { mountTemplate } from "shadcn/primitives/template_mount"
import { nextMatch, typeahead } from "shadcn/primitives/typeahead"

// Radix Menubar + Menu. Spec: docs/shadcn-port/specs/menubar.md (Behavior).
//
// The controller element is the root. One controller drives every Menu and Sub: triggers are roving items of the root
// (horizontal), Content and SubContent ship in inert <template>s and are mounted (portaled or in place) only while open,
// exactly like Radix. Everything inside a mounted content is wired here with delegated listeners on the content element:
// the clones live outside the controller scope, and delegation keeps caller listeners on the items running first
// (Radix composeEventHandlers).
//
// MenuLevel is one mounted menu (the root content of a Menu or a sub content) and SubMenu is the state of one SubTrigger.
// Their mechanics are the ones of controllers/v2/dropdown_menu_controller.js (the same react-menu); the differences are the
// menubar wiring: every menu is non-modal, the root value decides which menu is open, close focus, focus outside and the
// ArrowLeft/ArrowRight switching of menus.
//
// Known divergence from the shared primitives: roving focus inside a content is implemented per level (not with the
// roving_focus primitive) because an un-portaled SubContent sits inside its parent content and the primitive collects the
// items of nested groups too. Items are scoped by their closest [data-radix-menu-content].
const TEMPLATE = "v2--menubar-template"
const CONTENT = "[data-radix-menu-content]"
const MENUBAR_CONTENT = "[data-radix-menubar-content]"
const SELECTION_KEYS = ["Enter", " "]
const FIRST_LAST_KEYS = ["ArrowDown", "PageUp", "Home", "ArrowUp", "PageDown", "End"]
const LAST_KEYS = ["ArrowUp", "PageDown", "End"]
const FOCUS_INTENT = { ArrowUp: "prev", ArrowDown: "next", PageUp: "first", Home: "first", PageDown: "last", End: "last" }
const SUB_OPEN_KEYS = { ltr: [...SELECTION_KEYS, "ArrowRight"], rtl: [...SELECTION_KEYS, "ArrowLeft"] }
const SUB_CLOSE_KEYS = { ltr: ["ArrowLeft"], rtl: ["ArrowRight"] }
const pointerDowns = new WeakSet() // items that received the pointerdown of the current press (Radix isPointerDownRef)

function focusFirst(candidates, preventScroll = false) {
  const previous = document.activeElement
  for (const candidate of candidates) {
    if (candidate === previous) return
    candidate.focus({ preventScroll })
    if (document.activeElement !== previous) return
  }
}

const boundaries = (selectors) => (selectors ? [selectors].flat().flatMap((selector) => [...document.querySelectorAll(selector)]) : undefined)
const templateIn = (scope, id) => scope.querySelector(`template[data-${TEMPLATE}="${id}"]`)

// One MenubarMenu: its trigger, its template and the per menu flags of Radix (wasKeyboardTriggerOpenRef,
// hasInteractedOutsideRef).
class Menu {
  constructor(controller, trigger) {
    this.controller = controller
    this.trigger = trigger
    this.value = trigger.getAttribute("data-v2--menubar-menu-value")
    this.contentId = trigger.getAttribute("data-v2--menubar-content-id")
    this.template = templateIn(controller.element, this.contentId)
    this.level = null
    this.isOpen = false
    this.wasKeyboardTriggerOpen = false
    this.hasInteractedOutside = false
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
    this.level = new MenuLevel(this.controller, { menu: this, anchor: this.trigger, template: this.template, open: true })
    this.level.mount()
  }

  hide() {
    this.wasKeyboardTriggerOpen = false
    this.level?.close()
  }
}

class SubMenu {
  constructor(parent, trigger) {
    this.parent = parent
    this.trigger = trigger
    this.id = trigger.getAttribute("data-v2--menubar-sub-content-id")
    this.controlled = trigger.getAttribute("data-v2--menubar-sub-controlled") === "true"
    this.isOpen = trigger.dataset.state === "open"
    this.level = null
    this.openTimer = 0
  }

  get template() { return templateIn(this.parent.content, this.id) }

  // useControllableState: the event fires on every change request, the DOM only changes when uncontrolled.
  request(next) {
    if (next === this.isOpen) return
    this.parent.controller.dispatch("open-change", { target: this.trigger, detail: { open: next } })
    if (!this.controlled) this.apply(next)
  }

  apply(next) {
    this.isOpen = next
    this.trigger.setAttribute("aria-expanded", String(next))
    this.trigger.dataset.state = next ? "open" : "closed"
    if (next) this.trigger.setAttribute("aria-controls", this.id)
    else this.trigger.removeAttribute("aria-controls")
    if (next) this.mountLevel()
    else this.level?.close()
  }

  mountLevel(open = true) {
    if (this.level) return this.level.isOpen ? undefined : this.level.reopen()
    const template = this.template
    if (!template) return
    this.level = new MenuLevel(this.parent.controller, { menu: this.parent.menu, anchor: this.trigger, template, parent: this.parent, sub: this, open })
    this.level.mount()
  }

  clearTimer() {
    window.clearTimeout(this.openTimer)
    this.openTimer = 0
  }
}

class MenuLevel {
  constructor(controller, { menu, anchor, template, parent = null, sub = null, open = true }) {
    this.controller = controller
    this.menu = menu
    this.anchor = anchor
    this.template = template
    this.parent = parent
    this.sub = sub
    this.isOpen = open
    this.options = JSON.parse(template.getAttribute("data-options") || "{}")
    // shadcn wraps the root Content in a Portal that is not force-mounted, so Content force_mount never keeps it mounted.
    this.forceMount = Boolean(parent && this.options.forceMount)
    this.subs = new Map()
    this.currentItem = null
    this.tabbingOut = false
    this.clickFocus = false
    this.abort = new AbortController()
    this.releases = []
  }

  get isRoot() { return !this.parent }
  get dir() { return this.controller.dirValue }
  get #rootLevel() { return this.parent ? this.parent.#rootLevel : this }

  mount() {
    const portaled = this.isRoot || this.options.portal
    const container = (!this.isRoot && this.options.container && document.querySelector(this.options.container)) || document.body
    this.mounted = mountTemplate(this.template, { into: portaled ? container : "after" })
    this.content = this.mounted.nodes[0]
    this.wrapper = ensureWrapper(this.content)
    this.content.dataset.state = this.isOpen ? "open" : "closed"

    // Listener order matters: the item rules must run before the grace primitive updates the pointer direction.
    this.#bind()
    this.grace = submenuGrace(this.content, { timeout: this.controller.pointerGraceTimeoutValue })
    this.typeahead = typeahead({ onSearch: (search) => this.#search(search), timeout: this.controller.typeaheadTimeoutValue })
    this.#place()
    this.#render()
    this.presence = presence(this.content, { onExited: () => this.teardown() })
    this.#effects()
    this.#mountSubs()
  }

  // Begin the exit: state flips now, the node stays until its exit animation ends (Presence).
  close() {
    if (!this.isOpen) return
    this.isOpen = false
    this.content.dataset.state = "closed"
    this.subs.forEach((sub) => sub.request(false))
    this.#disengage()
    this.#engageIdle()
    if (!this.forceMount) this.presence.exit()
  }

  reopen() {
    this.isOpen = true
    this.content.dataset.state = "open"
    this.presence.enter()
    this.#disengage()
    this.#engage()
  }

  teardown() {
    if (this.gone) return
    this.gone = true
    this.subs.forEach((sub) => {
      sub.clearTimer()
      sub.level?.teardown()
    })
    this.abort.abort()
    this.grace.release()
    this.typeahead.release()
    this.#disengage()
    this.presence.release()
    this.placement.release()
    this.releases.reverse().forEach((release) => release())
    this.wrapper.remove()
    if (this.sub) this.sub.level = null
    else this.menu.level = null
  }

  #place() {
    const o = this.options
    this.placement = positioner(this.anchor, this.content, {
      side: this.isRoot ? o.side : this.dir === "rtl" ? "left" : "right",
      sideOffset: o.sideOffset,
      align: o.align,
      alignOffset: o.alignOffset,
      arrowPadding: o.arrowPadding,
      avoidCollisions: o.avoidCollisions,
      collisionPadding: o.collisionPadding,
      collisionBoundary: boundaries(o.collisionBoundary),
      sticky: o.sticky,
      hideWhenDetached: o.hideWhenDetached,
      updatePositionStrategy: o.updatePositionStrategy,
      dir: this.dir
    })
  }

  // Radix effect order is children first: dismissable layer, focus scope, focus guards. A menubar menu is never modal: no
  // scroll lock, no hide others, no trap.
  #effects() {
    if (this.isOpen) this.#engage()
    this.releases.push(
      focusScope(this.content, {
        onMountAutoFocus: (event) => this.#autoFocusOnMount(event),
        onUnmountAutoFocus: (event) => this.#autoFocusOnUnmount(event)
      })
    )
    this.releases.push(focusGuards())
  }

  #mountSubs() {
    this.content.querySelectorAll("[data-slot=menubar-sub-trigger]").forEach((trigger) => {
      if (!this.#owns(trigger)) return
      const sub = new SubMenu(this, trigger)
      this.subs.set(trigger, sub)
      // MenuSub closes itself (and reports it) when its menu mounts: default_open never survives, only a controlled
      // open: true keeps the sub content mounted (M:618-621; the oracle shows every default_open sub closed).
      sub.request(false)
      if (sub.isOpen) sub.mountLevel()
      else if (sub.template && JSON.parse(sub.template.getAttribute("data-options") || "{}").forceMount) sub.mountLevel(false)
    })
  }

  // DismissableLayer. Released as soon as the menu starts closing (Radix drops disableOutsidePointerEvents with `open`).
  #engage() {
    const root = this.isRoot
    this.releaseLayer = dismissable(this.content, {
      branches: () => this.#descendantContents(),
      onEscape: (event) => {
        if (this.#forward("escape-key-down", event) || root) return
        this.controller.close()
        event.preventDefault()
      },
      onPointerDownOutside: (event) => this.#forward("pointer-down-outside", event),
      onFocusOutside: (event) => {
        if (this.#forward("focus-outside", event)) return
        if (root) {
          // Mb:228-232: focus moving onto a trigger of the menubar keeps the menu open.
          const target = event.detail.originalEvent.target
          if (this.controller.menus.some((menu) => menu.trigger.contains(target))) event.preventDefault()
        } else if (event.detail.originalEvent.target !== this.sub.trigger) {
          this.sub.request(false)
        }
      },
      onInteractOutside: (event) => {
        if (this.#forward("interact-outside", event) || !root) return
        this.menu.hasInteractedOutside = true
      },
      onDismiss: root ? () => this.controller.close() : undefined
    })
  }

  #disengage() {
    this.releaseLayer?.()
    this.releaseLayer = null
  }

  // While it plays its exit animation the layer stays in the stack; its items keep their pointer events.
  #engageIdle() {
    this.releaseLayer = dismissable(this.content, { branches: () => this.#descendantContents() })
  }

  // Re-emit a primitive event as a public cancelable event; a prevented one keeps the primitive from dismissing.
  #forward(name, event) {
    const originalEvent = event.detail?.originalEvent ?? event
    const forwarded = this.controller.dispatch(name, { target: this.content, detail: { originalEvent } })
    if (forwarded.defaultPrevented) event.preventDefault()
    return forwarded.defaultPrevented
  }

  #autoFocusOnMount(event) {
    event.preventDefault()
    if (this.isRoot) {
      if (!this.controller.dispatch("open-auto-focus", { target: this.content }).defaultPrevented) this.content.focus({ preventScroll: true })
    } else if (this.controller.usingKeyboard) {
      this.content.focus()
    }
  }

  // Mb:220-227: the menubar always takes over the focus return; focus goes to the trigger only when no menu is open any
  // more and the content had no outside interaction.
  #autoFocusOnUnmount(event) {
    event.preventDefault()
    if (!this.isRoot || this.controller.disconnecting) return
    if (this.controller.dispatch("close-auto-focus", { target: this.content }).defaultPrevented) return
    if (!this.controller.current && !this.menu.hasInteractedOutside) this.menu.trigger.focus()
    this.menu.hasInteractedOutside = false
  }

  #descendantContents() {
    return [...this.subs.values()].flatMap((sub) => (sub.level ? [sub.level.content, ...sub.level.#descendantContents()] : []))
  }

  // --- items -------------------------------------------------------------------------------------------------------

  #owns(el) { return el.closest(CONTENT) === this.content }
  #items() { return [...this.content.querySelectorAll(ITEM_SELECTOR)].filter((el) => this.#owns(el)) }
  #focusable() { return this.#items().filter((el) => !isDisabled(el)) }
  #itemFrom(event) {
    const item = event.target.closest?.(ITEM_SELECTOR)
    return item && this.#owns(item) ? item : null
  }

  // RovingFocusGroup tab stop. The content itself stays tabindex=-1: FocusScope forwards it through the asChild chain
  // and it overrides the group tabindex (the Radix output the oracle shows).
  #render() {
    this.#items().forEach((item) => {
      const tabIndex = item === this.currentItem ? 0 : -1
      if (item.tabIndex !== tabIndex) item.tabIndex = tabIndex
    })
  }

  #setCurrent(item) {
    this.currentItem = item
    this.#render()
  }

  #bind() {
    const on = (target, type, handler) => target.addEventListener(type, handler, { signal: this.abort.signal })
    on(this.content, "keydown", (event) => {
      this.#onKeyDown(event)
      // MenubarContent onKeyDown (checkForDefaultPrevented: false). A content mounted in place already reaches the root
      // content's listener by bubbling; a portaled one reaches it through the React tree in Radix, so it calls it itself.
      if (this.isRoot || !this.#rootLevel.content.contains(this.content)) this.#menubarKeyDown(event)
    })
    on(this.content, "click", (event) => this.#onClick(event))
    on(this.content, "pointerdown", (event) => this.#onPointerDown(event))
    on(this.content, "pointerup", (event) => this.#onPointerUp(event))
    on(this.content, "pointermove", (event) => this.#onPointerMove(event))
    on(this.content, "mousedown", (event) => this.#onMouseDown(event))
    on(this.content, "focusin", (event) => this.#onFocusIn(event))
    on(this.content, "focusout", (event) => this.#onFocusOut(event))
    this.#items().forEach((item) => on(item, "pointerleave", (event) => this.#onItemLeave(event, item)))
  }

  // Mb:239-261: ArrowRight / ArrowLeft anywhere in the menu content switch to the next / previous menu.
  #menubarKeyDown(event) {
    if (!["ArrowRight", "ArrowLeft"].includes(event.key)) return
    const rootContent = this.#rootLevel.content
    const target = event.target
    const targetIsSubTrigger = target.hasAttribute("data-radix-menubar-subtrigger")
    const insideSubMenu = target.closest(MENUBAR_CONTENT) !== rootContent
    const isPrevKey = event.key === (this.dir === "rtl" ? "ArrowRight" : "ArrowLeft")
    if (!isPrevKey && targetIsSubTrigger) return
    if (insideSubMenu && isPrevKey) return
    let candidates = this.controller.menus.filter((menu) => !menu.disabled)
    if (isPrevKey) candidates.reverse()
    const index = candidates.indexOf(this.menu)
    candidates = this.controller.loopValue ? wrapArray(candidates, index + 1) : candidates.slice(index + 1)
    if (candidates[0]) this.controller.open(candidates[0])
  }

  #onMouseDown(event) {
    this.clickFocus = true
    const item = this.#itemFrom(event)
    if (!item) return
    if (isDisabled(item)) event.preventDefault()
    else this.#setCurrent(item)
  }

  #onFocusIn(event) {
    const item = this.#itemFrom(event)
    if (item) {
      item.setAttribute("data-highlighted", "")
      this.#setCurrent(item)
    }
    // Entry focus (RovingFocusGroup): the content itself received focus from the keyboard. The root content only takes
    // it when its menu was opened from the trigger by the keyboard (Mb:236-238).
    const entry = !this.isRoot || this.menu.wasKeyboardTriggerOpen
    if (entry && event.target === this.content && !this.clickFocus && !this.tabbingOut && this.controller.usingKeyboard) {
      const enabled = this.#focusable()
      focusFirst([this.currentItem && enabled.includes(this.currentItem) ? this.currentItem : null, ...enabled].filter(Boolean), true)
    }
    this.clickFocus = false
  }

  #onFocusOut(event) {
    this.#itemFrom(event)?.removeAttribute("data-highlighted")
    this.tabbingOut = false
    this.#render()
    // A portaled sub content bubbles its blur through the React tree to the parent content (M:352-357).
    if (this.parent && !this.parent.content.contains(this.content)) this.parent.typeahead.reset()
  }

  #onKeyDown(event) {
    const item = this.#itemFrom(event)
    if (item && !event.defaultPrevented) this.#itemKeyDown(event, item)
    if (this.sub && !event.defaultPrevented && this.content.contains(event.target) && SUB_CLOSE_KEYS[this.dir].includes(event.key)) {
      this.sub.trigger.focus()
      this.sub.request(false)
      event.preventDefault()
    }
    if (event.defaultPrevented) return

    const inside = event.target.closest(CONTENT) === this.content
    if (inside && event.key === "Tab") event.preventDefault()
    if (inside && !(event.ctrlKey || event.altKey || event.metaKey) && event.key.length === 1) this.typeahead.push(event.key)
    if (event.target !== this.content || !FIRST_LAST_KEYS.includes(event.key)) return
    event.preventDefault()
    const candidates = this.#focusable()
    if (LAST_KEYS.includes(event.key)) candidates.reverse()
    focusFirst(candidates)
  }

  #itemKeyDown(event, item) {
    const sub = this.subs.get(item)
    if (!isDisabled(item) && event.target === item && !(this.typeahead.search !== "" && event.key === " ")) {
      if (sub && SUB_OPEN_KEYS[this.dir].includes(event.key)) {
        const wasOpen = sub.isOpen
        sub.request(true)
        if (wasOpen) sub.level?.content.focus()
        event.preventDefault()
      } else if (!sub && SELECTION_KEYS.includes(event.key)) {
        item.click()
        event.preventDefault()
      }
    }
    if (event.defaultPrevented) return

    if (event.key === "Tab" && event.shiftKey) {
      this.tabbingOut = true
      this.#render()
      return
    }
    const intent = FOCUS_INTENT[event.key]
    if (event.target !== item || !intent || event.metaKey || event.ctrlKey || event.altKey || event.shiftKey) return
    event.preventDefault()
    let candidates = this.#focusable()
    if (intent === "last") candidates.reverse()
    else if (intent === "prev" || intent === "next") {
      if (intent === "prev") candidates.reverse()
      const index = candidates.indexOf(item)
      candidates = this.options.loop ? [...candidates.slice(index + 1), ...candidates.slice(0, index + 1)] : candidates.slice(index + 1)
    }
    setTimeout(() => focusFirst(candidates))
  }

  // Typeahead (M:233-249): the candidates are the enabled items of THIS content only.
  #search(search) {
    const items = this.#focusable()
    const current = items.find((item) => item === document.activeElement)
    const match = nextMatch(items.map(textValue), search, current && textValue(current))
    const target = items.find((item) => textValue(item) === match)
    if (target) setTimeout(() => target.focus())
  }

  #onClick(event) {
    const item = this.#itemFrom(event)
    if (!item || event.defaultPrevented || isDisabled(item)) return
    const sub = this.subs.get(item)
    if (!sub) return this.#select(item)

    item.focus()
    if (!sub.isOpen) sub.request(true)
  }

  #select(item) {
    const select = this.controller.dispatch("select", { target: item })
    const role = item.getAttribute("role")
    if (role === "menuitemcheckbox") {
      const checked = item.dataset.state === "checked"
      this.controller.dispatch("checked-change", { target: item, cancelable: false, detail: { checked: !checked } })
    } else if (role === "menuitemradio") {
      this.controller.dispatch("value-change", { target: item, cancelable: false, detail: { value: item.getAttribute("data-v2--menubar-value") } })
    }
    if (select.defaultPrevented) pointerDowns.delete(item)
    else this.controller.close()
  }

  #onPointerDown(event) {
    const item = this.#itemFrom(event)
    if (item && !this.subs.has(item)) pointerDowns.add(item)
  }

  // Press on the trigger, drag, release on an item selects it (M:425-431).
  #onPointerUp(event) {
    const item = this.#itemFrom(event)
    if (item && !this.subs.has(item) && !event.defaultPrevented && !pointerDowns.has(item)) item.click()
  }

  #onPointerMove(event) {
    if (event.pointerType !== "mouse") return
    const item = this.#itemFrom(event)
    if (!item || event.defaultPrevented) return
    const sub = this.subs.get(item)
    if (sub) {
      this.#itemEnter(event)
      if (event.defaultPrevented) return
      if (!isDisabled(item) && !sub.isOpen && !sub.openTimer) {
        this.grace.clearIntent()
        sub.openTimer = window.setTimeout(() => {
          sub.request(true)
          sub.clearTimer()
        }, this.controller.subOpenDelayValue)
      }
    }
    if (isDisabled(item)) return this.#itemLeave(event)
    this.#itemEnter(event)
    if (!event.defaultPrevented) item.focus({ preventScroll: true })
  }

  #onItemLeave(event, item) {
    if (event.pointerType !== "mouse") return
    const sub = this.subs.get(item)
    if (sub) {
      sub.clearTimer()
      if (sub.level) this.grace.subTriggerLeave(event, sub.level.content)
      else if (this.grace.isPointerMovingToSubmenu(event)) return
      else this.grace.clearIntent()
    }
    this.#itemLeave(event)
  }

  #itemEnter(event) {
    if (this.grace.isPointerMovingToSubmenu(event)) event.preventDefault()
  }

  #itemLeave(event) {
    if (this.grace.isPointerMovingToSubmenu(event)) return
    this.content.focus()
    this.#setCurrent(null)
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
