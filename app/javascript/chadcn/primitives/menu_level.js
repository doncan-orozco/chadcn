import { ITEM_SELECTOR, isDisabled, textValue } from "chadcn/primitives/collection"
import { dismissable } from "chadcn/primitives/dismissable_layer"
import { focusGuards } from "chadcn/primitives/focus_guards"
import { focusScope } from "chadcn/primitives/focus_scope"
import { hideOthers } from "chadcn/primitives/hide_others"
import { ensureWrapper, positioner } from "chadcn/primitives/positioner"
import { presence } from "chadcn/primitives/presence"
import { scrollLock } from "chadcn/primitives/scroll_lock"
import { submenuGrace } from "chadcn/primitives/submenu_grace"
import { mountTemplate } from "chadcn/primitives/template_mount"
import { nextMatch, typeahead } from "chadcn/primitives/typeahead"

// The Radix react-menu mechanics shared by dropdown-menu, context-menu and menubar.
//
// MenuLevel is one mounted menu (the root Content or a SubContent) and SubMenu is the state of one SubTrigger. Content and
// SubContent ship in inert <template>s and are mounted (portaled or in place) only while open, exactly like Radix. Everything
// inside a mounted content is wired with delegated listeners on the content element: the clones live outside the
// controller scope, and delegation keeps caller listeners on the items running first (Radix composeEventHandlers).
//
// The controller passed in provides the shared values (`dirValue`, `subOpenDelayValue`, `pointerGraceTimeoutValue`,
// `typeaheadTimeoutValue`), `dispatch`, and the `usingKeyboard` / `disconnecting` flags. What the root of a menu does
// differently per component is the `behavior` of the root level, which its sub levels inherit. The defaults are the
// DropdownMenu root (ContextMenu reuses it): they use `requestOpen`, `modalValue`, `hasInteractedOutside` and `root` on the
// controller. Menubar overrides them (never modal, one value for every menu, its own focus return and menu switching).
//
// Known divergence from the shared primitives: roving focus is implemented per level here (not with the roving_focus
// primitive) because an un-portaled SubContent sits inside its parent content and the primitive collects the items of
// nested groups too. Items are scoped by their closest [data-radix-menu-content].
const CONTENT = "[data-radix-menu-content]"
const SELECTION_KEYS = ["Enter", " "]
const FIRST_LAST_KEYS = ["ArrowDown", "PageUp", "Home", "ArrowUp", "PageDown", "End"]
const LAST_KEYS = ["ArrowUp", "PageDown", "End"]
const FOCUS_INTENT = { ArrowUp: "prev", ArrowDown: "next", PageUp: "first", Home: "first", PageDown: "last", End: "last" }
const SUB_OPEN_KEYS = { ltr: [...SELECTION_KEYS, "ArrowRight"], rtl: [...SELECTION_KEYS, "ArrowLeft"] }
const SUB_CLOSE_KEYS = { ltr: ["ArrowLeft"], rtl: ["ArrowRight"] }
const pointerDowns = new WeakSet() // items that received the pointerdown of the current press (Radix isPointerDownRef)

// The DropdownMenu root. Every hook receives the root level of the menu, except onKeyDown (the level whose content got
// the key).
export const DEFAULT_BEHAVIOR = Object.freeze({
  // The data-attribute namespace of the templates, sub content ids and item values (`data-<prefix>-template`, ...).
  prefix: "chadcn--dropdown-menu",
  subTrigger: "[data-slot=dropdown-menu-sub-trigger]",
  modal: (level) => Boolean(level.controller.modalValue),
  // Close the whole menu: an outside dismiss, Escape in a sub content, a selected item.
  close: (level) => level.controller.requestOpen(false),
  // The root level was torn down.
  detach: (level) => { level.controller.root = null },
  onFocusOutside: (level, event) => { if (level.modal) event.preventDefault() },
  onInteractOutside: (level, event) => {
    const original = event.detail.originalEvent
    const rightClick = original.button === 2 || (original.button === 0 && original.ctrlKey === true)
    if (!level.controller.modalValue || rightClick) level.controller.hasInteractedOutside = true
  },
  // FocusScope unmount of the root content (its own focus return is always prevented).
  onCloseAutoFocus: (level) => {
    const { controller } = level
    if (controller.dispatch("close-auto-focus").defaultPrevented) return
    if (!controller.hasInteractedOutside) controller.element.focus()
    controller.hasInteractedOutside = false
  },
  // Whether the root content forwards a keyboard focus to its first item (RovingFocusGroup entry focus).
  entryFocus: () => true,
  // An extra keydown listener on every content of the menu, run after the menu's own (null: none).
  onKeyDown: null
})

function focusFirst(candidates, preventScroll = false) {
  const previous = document.activeElement
  for (const candidate of candidates) {
    if (candidate === previous) return
    candidate.focus({ preventScroll })
    if (document.activeElement !== previous) return
  }
}

const boundaries = (selectors) => (selectors ? [selectors].flat().flatMap((selector) => [...document.querySelectorAll(selector)]) : undefined)
const templateOptions = (template) => JSON.parse(template?.getAttribute("data-options") || "{}")

export class SubMenu {
  constructor(parent, trigger) {
    const { prefix } = parent.behavior
    this.parent = parent
    this.trigger = trigger
    this.id = trigger.getAttribute(`data-${prefix}-sub-content-id`)
    this.controlled = trigger.getAttribute(`data-${prefix}-sub-controlled`) === "true"
    this.isOpen = trigger.dataset.state === "open"
    this.level = null
    this.openTimer = 0
    this.options = templateOptions(this.template)
  }

  get template() {
    return this.parent.content.querySelector(`template[data-${this.parent.behavior.prefix}-template="${this.id}"]`)
  }

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
    this.level = new MenuLevel(this.parent.controller, { anchor: this.trigger, template, parent: this.parent, sub: this, open })
    this.level.mount()
  }

  clearTimer() {
    window.clearTimeout(this.openTimer)
    this.openTimer = 0
  }
}

export class MenuLevel {
  constructor(controller, { anchor, template, parent = null, sub = null, open = true, behavior = {} }) {
    this.controller = controller
    this.anchor = anchor
    this.template = template
    this.parent = parent
    this.sub = sub
    this.isOpen = open
    this.behavior = parent ? parent.behavior : { ...DEFAULT_BEHAVIOR, ...behavior }
    this.options = templateOptions(template)
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
  get rootLevel() { return this.parent ? this.parent.rootLevel : this }
  get dir() { return this.controller.dirValue }
  get modal() { return this.isRoot && this.behavior.modal(this) }

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
    // In-place subs mount first: React runs child effects before the parent's, so their layers register below the root's.
    // A portaled sub only mounts after the parent's commit.
    this.#mountSubs(false)
    this.#effects()
    this.#mountSubs(true)
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
    else this.behavior.detach(this)
  }

  #closeMenu() { this.behavior.close(this.rootLevel) }

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

  // Radix effect order is children first: dismissable layer, focus scope, scroll lock, focus guards, hide others. A
  // non-modal menu gets no trap, no scroll lock and no hide others.
  #effects() {
    if (this.isOpen) this.#engage()
    else this.#engageIdle()
    const modal = this.modal
    this.releases.push(
      focusScope(this.content, {
        trapped: modal && this.isOpen,
        onMountAutoFocus: (event) => this.#autoFocusOnMount(event),
        onUnmountAutoFocus: (event) => this.#autoFocusOnUnmount(event)
      })
    )
    if (modal) this.releases.push(scrollLock())
    this.releases.push(focusGuards())
    if (modal) this.releases.push(hideOthers(this.content))
  }

  #mountSubs(portaled) {
    if (!portaled) this.content.querySelectorAll(this.behavior.subTrigger).forEach((trigger) => {
      if (this.#owns(trigger)) this.subs.set(trigger, new SubMenu(this, trigger))
    })
    this.subs.forEach((sub) => {
      if (Boolean(sub.options.portal) !== portaled) return
      // MenuSub closes itself (and reports it) when its menu mounts: default_open never survives, only a controlled
      // open: true keeps the sub content mounted (M:618-621; the oracle shows every default_open sub closed).
      sub.request(false)
      if (sub.isOpen) sub.mountLevel()
      else if (sub.options.forceMount) sub.mountLevel(false)
    })
  }

  // DismissableLayer. Released as soon as the menu starts closing (Radix drops disableOutsidePointerEvents with `open`).
  #engage() {
    const root = this.isRoot
    this.releaseLayer = dismissable(this.content, {
      disableOutsidePointerEvents: this.modal && this.isOpen,
      branches: () => this.#descendantContents(),
      onEscape: (event) => {
        if (this.#forward("escape-key-down", event) || root) return
        this.#closeMenu()
        event.preventDefault()
      },
      onPointerDownOutside: (event) => this.#forward("pointer-down-outside", event),
      onFocusOutside: (event) => {
        if (this.#forward("focus-outside", event)) return
        if (root) this.behavior.onFocusOutside(this, event)
        else if (event.detail.originalEvent.target !== this.sub.trigger) this.sub.request(false)
      },
      onInteractOutside: (event) => {
        if (this.#forward("interact-outside", event) || !root) return
        this.behavior.onInteractOutside(this, event)
      },
      onDismiss: root ? () => this.#closeMenu() : undefined
    })
  }

  #disengage() {
    this.releaseLayer?.()
    this.releaseLayer = null
  }

  // While it plays its exit animation the layer stays in the stack but no longer blocks the page (disableOutsidePointerEvents
  // follows `open`), so its items keep pointer-events: auto under a blocking parent.
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

  #autoFocusOnUnmount(event) {
    event.preventDefault()
    if (!this.isRoot || this.controller.disconnecting) return
    this.behavior.onCloseAutoFocus(this)
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
      this.behavior.onKeyDown?.(this, event)
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
    // Entry focus (RovingFocusGroup): the content itself received focus from the keyboard.
    const entry = !this.isRoot || this.behavior.entryFocus(this)
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
      const value = item.getAttribute(`data-${this.behavior.prefix}-value`)
      this.controller.dispatch("value-change", { target: item, cancelable: false, detail: { value } })
    }
    if (select.defaultPrevented) pointerDowns.delete(item)
    else this.#closeMenu()
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
