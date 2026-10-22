import { Controller } from "@hotwired/stimulus"
import { dismissable } from "chadcn/primitives/dismissable_layer"
import { presence } from "chadcn/primitives/presence"

// Radix NavigationMenu (Root + List + Item + Trigger + Content + Viewport + Link + Indicator).
// Spec: docs/shadcn-port/specs/navigation-menu.md (Behavior). The controller element is the root `nav`.
// Radix mounts Content, the Viewport and the Indicator on the client; the server ships them in inert <template>s
// (targets) that are cloned here, so every mount is a fresh node like in React.
const TRIGGER = "[data-slot=navigation-menu-trigger]"
const LINK = "[data-slot=navigation-menu-link]"
const CONTENT = "[data-slot=navigation-menu-content]"
const GROUP = "[data-slot=navigation-menu-list], [data-slot=navigation-menu-content]"
const ITEM = "[data-radix-collection-item]"
const VALUE_PARAM = "data-chadcn--navigation-menu-value-param"
const CONTROLS_PARAM = "data-chadcn--navigation-menu-controls-param"
const ARROW_KEYS = ["ArrowRight", "ArrowLeft", "ArrowUp", "ArrowDown"]
const CLOSE_DELAY = 150 // hard-coded in Radix (nm:88)
// react-visually-hidden style object, set through element.style so it serializes like React's.
const VISUALLY_HIDDEN = {
  position: "absolute", border: "0px", width: "1px", height: "1px", padding: "0px", margin: "-1px",
  overflow: "hidden", clip: "rect(0px, 0px, 0px, 0px)", whiteSpace: "nowrap", wordWrap: "normal"
}

export default class extends Controller {
  static values = {
    value: String, controlled: Boolean, delayDuration: Number, skipDelayDuration: Number,
    orientation: String, dir: String, activationMode: String
  }
  static targets = ["contentTemplate", "viewportTemplate", "indicatorTemplate"]

  connect() {
    this.abort = new AbortController()
    this.timers = { open: 0, close: 0, skip: 0 }
    this.pending = undefined
    this.flushTimer = 0
    this.state = this.previous = this.valueValue
    this.isOpenDelayed = true
    this.items = new Map()
    this.triggerStates = new Map()
    this.vp = null
    this.ind = null
    this.viewportMode = this.hasViewportTemplateTarget
    this.entries = this.contentTemplateTargets.map((template) => ({
      value: template.dataset.value, template, forceMount: template.dataset.forceMount === "true",
      el: null, inline: false, motion: null, exiting: false, presence: null, release: null, abort: null
    }))

    const { signal } = this.abort
    this.triggers().forEach((trigger) => this.wireTrigger(trigger, signal))
    this.element.addEventListener("keydown", (event) => this.onKeydown(event), { signal })
    this.element.addEventListener("click", (event) => this.onLinkClick(event), { signal })
    document.addEventListener("turbo:before-cache", () => this.reset(), { signal })
    this.sync()
  }

  disconnect() {
    Object.values(this.timers).forEach((timer) => window.clearTimeout(timer))
    window.clearTimeout(this.flushTimer)
    this.abort.abort()
    this.teardown()
  }

  // A cached page must not restore an open menu.
  reset() {
    this.state = this.previous = ""
    this.teardown()
    this.syncTriggers()
  }

  // ---- state ----------------------------------------------------------------------------------------------------

  // Radix useControllableState + React batching. Hover/timer updates are rendered in a later task (continuous / default
  // lane) while discrete ones (click, key, dismiss) render synchronously, together with whatever is still queued: a click
  // that follows the pointermove which hover-opened the same item closes it without ever rendering the opened state.
  // Controlled: nothing is queued, onChange fires when the requested value differs from the prop.
  setValue(update, { sync = false } = {}) {
    const base = this.controlledValue ? this.state : (this.pending ?? this.state)
    const next = typeof update === "function" ? update(base) : update
    if (this.controlledValue) {
      if (next !== this.state) this.valueChanged(next)
      return
    }

    this.pending = next
    if (sync) this.flush()
    else if (!this.flushTimer) this.flushTimer = window.setTimeout(() => this.flush(), 0)
  }

  flush() {
    window.clearTimeout(this.flushTimer)
    this.flushTimer = 0
    const next = this.pending
    this.pending = undefined
    if (next === undefined || next === this.state) return

    this.previous = this.state
    this.state = next
    this.sync()
    this.valueChanged(next)
  }

  // Radix onChange (a passive effect after the commit): skip-delay bookkeeping, then the value-change event.
  valueChanged(next) {
    window.clearTimeout(this.timers.skip)
    if (next !== "") {
      if (this.skipDelayDurationValue > 0) this.isOpenDelayed = false
    } else {
      this.timers.skip = window.setTimeout(() => (this.isOpenDelayed = true), this.skipDelayDurationValue)
    }
    this.dispatch("value-change", { detail: { value: next } })
  }

  get automatic() {
    return this.activationModeValue !== "manual"
  }

  startCloseTimer() {
    window.clearTimeout(this.timers.close)
    this.timers.close = window.setTimeout(() => this.setValue(""), CLOSE_DELAY)
  }

  handleOpen(value) {
    window.clearTimeout(this.timers.close)
    this.setValue(value)
  }

  handleDelayedOpen(value) {
    if (this.state === value) return window.clearTimeout(this.timers.close)
    this.timers.open = window.setTimeout(() => {
      window.clearTimeout(this.timers.close)
      this.setValue(value)
    }, this.delayDurationValue)
  }

  onTriggerEnter(value) {
    if (!this.automatic) return
    window.clearTimeout(this.timers.open)
    if (this.isOpenDelayed) this.handleDelayedOpen(value)
    else this.handleOpen(value)
  }

  onTriggerLeave() {
    if (!this.automatic) return
    window.clearTimeout(this.timers.open)
    this.startCloseTimer()
  }

  onContentEnter() {
    if (this.automatic) window.clearTimeout(this.timers.close)
  }

  onContentLeave() {
    if (this.automatic) this.startCloseTimer()
  }

  // ---- triggers -------------------------------------------------------------------------------------------------

  triggers() {
    return [...this.element.querySelectorAll(TRIGGER)]
  }

  valueOf(trigger) {
    return trigger.getAttribute(VALUE_PARAM)
  }

  triggerFor(value) {
    return this.triggers().find((trigger) => this.valueOf(trigger) === value)
  }

  item(value) {
    if (!this.items.has(value)) this.items.set(value, { wasEscapeClose: false, restoreTabOrder: () => {}, proxy: null, owns: null })
    return this.items.get(value)
  }

  entry(value) {
    return this.entries.find((entry) => entry.value === value)
  }

  wireTrigger(trigger, signal) {
    const value = this.valueOf(trigger)
    const state = { wasClickClose: false, hasPointerMoveOpened: false }
    this.triggerStates.set(trigger, state)
    const mouse = (handler) => (event) => event.pointerType === "mouse" && handler(event)
    const on = (type, handler) => trigger.addEventListener(type, handler, { signal })

    on("pointerenter", () => {
      state.wasClickClose = false
      this.item(value).wasEscapeClose = false
    })
    on("pointermove", mouse(() => {
      if (trigger.disabled || state.wasClickClose || this.item(value).wasEscapeClose || state.hasPointerMoveOpened) return
      this.onTriggerEnter(value)
      state.hasPointerMoveOpened = true
    }))
    on("pointerleave", mouse(() => {
      if (trigger.disabled) return
      this.onTriggerLeave()
      state.hasPointerMoveOpened = false
    }))
    on("click", () => {
      const open = this.state === value
      this.setValue((previous) => (previous === value ? "" : value), { sync: true })
      state.wasClickClose = open
    })
  }

  // data-state / aria on every trigger, plus the focus proxy and aria-owns spans while open (nm:391-410).
  syncTriggers() {
    this.triggers().forEach((trigger) => {
      const value = this.valueOf(trigger)
      const open = this.state === value
      const item = this.item(value)
      trigger.setAttribute("data-state", open ? "open" : "closed")
      trigger.setAttribute("aria-expanded", String(open))
      if (open) trigger.setAttribute("aria-controls", trigger.getAttribute(CONTROLS_PARAM))
      else trigger.removeAttribute("aria-controls")

      if (open && !item.proxy) item.proxy = this.createProxy(trigger, value)
      if (!open && item.proxy) {
        item.proxy.remove()
        item.proxy = null
      }
      const owns = open && this.viewportMode
      if (owns && !item.owns) {
        item.owns = document.createElement("span")
        item.owns.setAttribute("aria-owns", trigger.getAttribute(CONTROLS_PARAM))
        item.proxy.after(item.owns)
      }
      if (!owns && item.owns) {
        item.owns.remove()
        item.owns = null
      }
    })
  }

  createProxy(trigger, value) {
    const proxy = document.createElement("span")
    proxy.setAttribute("aria-hidden", "true")
    proxy.tabIndex = 0
    Object.assign(proxy.style, VISUALLY_HIDDEN)
    proxy.addEventListener("focus", (event) => {
      const content = this.entry(value)?.el
      const wasTriggerFocused = event.relatedTarget === trigger
      const wasFocusFromContent = content?.contains(event.relatedTarget)
      if (wasTriggerFocused || !wasFocusFromContent) this.enterContent(value, wasTriggerFocused ? "start" : "end")
    }, { signal: this.abort.signal })
    trigger.after(proxy)
    return proxy
  }

  // ---- keyboard -------------------------------------------------------------------------------------------------

  onKeydown(event) {
    const item = event.target.closest?.(ITEM)
    if (!item) return

    if (item.matches(TRIGGER)) this.onTriggerKeydown(event, item)
    // The oracle never runs the group handler after the trigger entry handler prevented the key (spec: Behavior, Keyboard).
    if (!event.defaultPrevented) this.onGroupKeydown(event, item)
  }

  onTriggerKeydown(event, trigger) {
    const value = this.valueOf(trigger)
    const vertical = this.orientationValue === "vertical"
    const entryKey = vertical ? (this.dirValue === "rtl" ? "ArrowLeft" : "ArrowRight") : "ArrowDown"
    if (this.state !== value || event.key !== entryKey) return

    this.enterContent(value, "start")
    event.preventDefault()
  }

  // Radix FocusGroupItem (not a roving tabindex): arrows/Home/End move focus through the group, never looping.
  onGroupKeydown(event, item) {
    if (!["Home", "End", ...ARROW_KEYS].includes(event.key)) return

    const group = item.closest(GROUP)
    let candidates = [...group.querySelectorAll(ITEM)].filter((node) => node.closest(GROUP) === group)
    const previousKey = this.dirValue === "rtl" ? "ArrowRight" : "ArrowLeft"
    if ([previousKey, "ArrowUp", "End"].includes(event.key)) candidates.reverse()
    if (ARROW_KEYS.includes(event.key)) candidates = candidates.slice(candidates.indexOf(item) + 1)
    window.setTimeout(() => this.focusFirst(candidates))
    event.preventDefault()
  }

  enterContent(value, side = "start") {
    const el = this.entry(value)?.el
    if (!el) return

    this.item(value).restoreTabOrder()
    const candidates = this.tabbable(el)
    if (candidates.length) this.focusFirst(side === "start" ? candidates : candidates.reverse())
  }

  onContentKeydown(event, entry) {
    if (event.key !== "Tab" || event.altKey || event.ctrlKey || event.metaKey) return

    const candidates = this.tabbable(entry.el)
    const index = candidates.indexOf(document.activeElement)
    const next = event.shiftKey ? candidates.slice(0, index).reverse() : candidates.slice(index + 1, candidates.length)
    if (this.focusFirst(next)) event.preventDefault()
    else this.item(entry.value).proxy?.focus()
  }

  tabbable(container) {
    const nodes = []
    const walker = document.createTreeWalker(container, NodeFilter.SHOW_ELEMENT, {
      acceptNode: (node) => {
        if (node.disabled || node.hidden || (node.tagName === "INPUT" && node.type === "hidden")) return NodeFilter.FILTER_SKIP
        return node.tabIndex >= 0 ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_SKIP
      }
    })
    while (walker.nextNode()) nodes.push(walker.currentNode)
    return nodes
  }

  focusFirst(candidates) {
    const previous = document.activeElement
    return candidates.some((candidate) => {
      if (candidate === previous) return true
      candidate.focus()
      return document.activeElement !== previous
    })
  }

  // Radix handleContentExit: tabbables of a closing content leave the tab order (restored on the next entry).
  removeFromTabOrder(entry) {
    if (!entry.el) return
    const candidates = this.tabbable(entry.el)
    if (!candidates.length) return

    candidates.forEach((candidate) => {
      candidate.dataset.tabindex = candidate.getAttribute("tabindex") || ""
      candidate.setAttribute("tabindex", "-1")
    })
    this.item(entry.value).restoreTabOrder = () => candidates.forEach((candidate) => candidate.setAttribute("tabindex", candidate.dataset.tabindex))
  }

  // ---- links / dismissal ----------------------------------------------------------------------------------------

  onLinkClick(event) {
    const link = event.target.closest?.(LINK)
    if (!link) return

    const selected = this.dispatch("link-select", { target: link, cancelable: true, detail: {} })
    if (selected.defaultPrevented || event.metaKey) return

    const entry = this.entries.find((candidate) => candidate.el?.contains(link))
    if (entry) this.dismiss(entry)
  }

  // Radix rootContentDismiss handler: close, drop the content tabbables, give focus back to the trigger.
  dismiss(entry) {
    const hadFocus = entry.el.contains(document.activeElement)
    this.removeFromTabOrder(entry)
    this.setValue("", { sync: true })
    if (hadFocus) this.triggerFor(entry.value)?.focus()
  }

  forward(name, event, entry) {
    const originalEvent = event.detail?.originalEvent ?? event
    const forwarded = this.dispatch(name, { target: entry.el, cancelable: true, detail: { originalEvent } })
    if (forwarded.defaultPrevented) event.preventDefault()
  }

  layerCallbacks(entry) {
    return {
      onEscape: (event) => {
        this.forward("escape-key-down", event, entry)
        if (!event.defaultPrevented) this.item(entry.value).wasEscapeClose = true
      },
      onPointerDownOutside: (event) => {
        this.forward("pointer-down-outside", event, entry)
        const target = event.detail.originalEvent.target
        const isTrigger = this.triggers().some((trigger) => trigger.contains(target))
        if (isTrigger || this.vp?.el.contains(target)) event.preventDefault()
      },
      onFocusOutside: (event) => {
        this.forward("focus-outside", event, entry)
        if (event.defaultPrevented) return

        this.removeFromTabOrder(entry)
        const { target, relatedTarget } = event.detail.originalEvent
        if (this.element.contains(target) || !this.element.contains(relatedTarget)) event.preventDefault()
      },
      onDismiss: () => this.dismiss(entry)
    }
  }

  // ---- mounting -------------------------------------------------------------------------------------------------

  sync() {
    const open = this.state !== ""
    if (this.viewportMode) this.syncViewport(open)
    else this.syncInline()
    this.syncTriggers()
    this.syncIndicator(open)
  }

  syncViewport(open) {
    const present = this.vpForce || open
    if (present && !this.vp) this.mountViewport()
    if (!this.vp) return this.syncForcedInline()

    // Content only lives in the viewport while it is mounted (nm:512): move in-place content over.
    this.entries.forEach((entry) => entry.inline && this.unmountContent(entry))

    const active = open ? this.state : this.previous
    this.entries.forEach((entry) => entry.el && this.applyMotion(entry))
    this.entries.forEach((entry) => {
      const shown = entry.forceMount || entry.value === active
      if (shown && !entry.el) this.mountContent(entry, false)
      else if (shown) this.reenter(entry)
      else if (entry.el) this.exit(entry)
    })
    this.observeViewportContent(this.entry(active))

    this.vp.el.setAttribute("data-state", open ? "open" : "closed")
    this.vp.el.style.pointerEvents = open ? "" : "none"
    if (present) this.reenter(this.vp)
    else this.exit(this.vp)
  }

  get vpForce() {
    return this.viewportTemplateTarget.dataset.forceMount === "true"
  }

  mountViewport() {
    const el = this.viewportTemplateTarget.content.firstElementChild.cloneNode(true)
    el.setAttribute("data-state", "open")
    this.viewportTemplateTarget.after(el)
    const { signal } = this.abort
    el.addEventListener("pointerenter", () => this.onContentEnter(), { signal })
    el.addEventListener("pointerleave", (event) => event.pointerType === "mouse" && this.onContentLeave(), { signal })
    this.vp = { el, exiting: false, content: null, disposeSize: null }
    this.vp.presence = presence(el, { onExited: () => this.unmountViewport() })
  }

  // Without a mounted viewport a forceMount content renders in place inside its item (nm:526-543).
  syncForcedInline() {
    this.entries.forEach((entry) => {
      if (!entry.forceMount) return
      if (!entry.el) this.mountContent(entry, true)
      this.applyInlineState(entry, entry.value === this.state)
    })
    this.restoreInlineState()
  }

  unmountViewport({ remount = true } = {}) {
    if (!this.vp) return
    this.entries.forEach((entry) => this.unmountContent(entry))
    this.vp.disposeSize?.()
    this.vp.presence.release()
    this.vp.el.remove()
    this.vp = null
    if (remount) this.syncForcedInline()
  }

  // Viewport size follows the active content (nm:687-690).
  observeViewportContent(entry) {
    if (!entry?.el || entry.el === this.vp.content) return

    this.vp.disposeSize?.()
    this.vp.content = entry.el
    this.vp.disposeSize = this.observeResize(entry.el, () => {
      if (!this.vp) return
      this.vp.el.style.setProperty("--radix-navigation-menu-viewport-width", `${entry.el.offsetWidth}px`)
      this.vp.el.style.setProperty("--radix-navigation-menu-viewport-height", `${entry.el.offsetHeight}px`)
    })
  }

  syncInline() {
    this.entries.forEach((entry) => entry.el && this.applyMotion(entry))
    this.entries.forEach((entry) => {
      const open = entry.value === this.state
      if (entry.forceMount || open) {
        if (!entry.el) this.mountContent(entry, true)
        else this.reenter(entry)
        this.applyInlineState(entry, open)
      } else if (entry.el) {
        this.applyInlineState(entry, false)
        this.exit(entry)
      }
    })
    this.restoreInlineState()
  }

  // The dismissable_layer primitive resets `style.pointerEvents` of every layer whenever a layer is added or removed,
  // while Radix lets the content style win (nm:539), so it is re-applied after each change.
  restoreInlineState() {
    this.entries.forEach((entry) => entry.inline && this.applyInlineState(entry, entry.value === this.state))
  }

  applyInlineState(entry, open) {
    entry.el.setAttribute("data-state", open ? "open" : "closed")
    entry.el.style.pointerEvents = open ? "" : "none"
  }

  mountContent(entry, inline) {
    const el = entry.template.content.firstElementChild.cloneNode(true)
    entry.el = el
    entry.inline = inline
    entry.exiting = false
    this.applyMotion(entry)
    if (inline) {
      this.applyInlineState(entry, entry.value === this.state)
      entry.template.after(el)
    } else {
      this.insertInViewport(entry)
    }

    entry.abort = new AbortController()
    const { signal } = entry.abort
    el.addEventListener("keydown", (event) => this.onContentKeydown(event, entry), { signal })
    if (inline) {
      el.addEventListener("pointerenter", () => this.onContentEnter(), { signal })
      el.addEventListener("pointerleave", (event) => event.pointerType === "mouse" && this.onContentLeave(), { signal })
    }
    entry.presence = presence(el, { onExited: () => this.unmountContent(entry) })
    entry.release = dismissable(el, this.layerCallbacks(entry))
  }

  // Contents keep the registration order of their Content call sites.
  insertInViewport(entry) {
    const following = this.entries.slice(this.entries.indexOf(entry) + 1).find((candidate) => candidate.el && candidate.el.parentElement === this.vp.el)
    this.vp.el.insertBefore(entry.el, following?.el ?? null)
  }

  unmountContent(entry) {
    if (!entry.el) return
    entry.release()
    entry.abort.abort()
    entry.presence.release()
    entry.el.remove()
    Object.assign(entry, { el: null, inline: false, motion: null, exiting: false, presence: null, release: null, abort: null })
    this.restoreInlineState()
  }

  // Presence: a part that left stays until its exit animation ends (immediately without animation).
  exit(part) {
    if (part.exiting) return
    part.exiting = true
    part.presence.exit()
  }

  reenter(part) {
    if (!part.exiting) return
    part.exiting = false
    part.presence.enter()
  }

  // data-motion of one content (nm:591-609); entries that are neither selected nor previously selected keep their last value.
  applyMotion(entry) {
    const values = this.triggers().map((trigger) => this.valueOf(trigger))
    if (this.dirValue === "rtl") values.reverse()
    const index = values.indexOf(this.state)
    const previousIndex = values.indexOf(this.previous)
    const selected = entry.value === this.state
    const wasSelected = previousIndex === values.indexOf(entry.value)
    if (selected || wasSelected) {
      entry.motion = null
      if (index !== previousIndex) {
        if (selected && previousIndex !== -1) entry.motion = index > previousIndex ? "from-end" : "from-start"
        else if (wasSelected && index !== -1) entry.motion = index > previousIndex ? "to-start" : "to-end"
      }
    }
    if (entry.motion) entry.el.setAttribute("data-motion", entry.motion)
    else entry.el.removeAttribute("data-motion")
  }

  // ---- indicator ------------------------------------------------------------------------------------------------

  syncIndicator(open) {
    if (!this.hasIndicatorTemplateTarget) return

    const force = this.indicatorTemplateTarget.dataset.forceMount === "true"
    const present = force || open
    if (present && !this.ind) this.mountIndicator()
    const ind = this.ind
    if (!ind) return

    const trigger = this.triggerFor(this.state)
    if (trigger && trigger !== ind.trigger) {
      ind.disposeTrigger?.()
      ind.trigger = trigger
      ind.disposeTrigger = this.observeResize(trigger, () => this.measureIndicator())
    }
    this.renderIndicator()
    if (present) this.reenter(ind)
    else if (ind.el) this.exit(ind)
    else this.unmountIndicator()
  }

  mountIndicator() {
    const track = this.element.querySelector("[data-slot=navigation-menu-list]").parentElement
    this.ind = { track, trigger: null, position: null, el: null, exiting: false, presence: null, disposeTrigger: null }
    this.ind.disposeTrack = this.observeResize(track, () => this.measureIndicator())
  }

  measureIndicator() {
    const { ind } = this
    if (!ind?.trigger) return

    const horizontal = this.orientationValue !== "vertical"
    ind.position = horizontal ? { size: ind.trigger.offsetWidth, offset: ind.trigger.offsetLeft } : { size: ind.trigger.offsetHeight, offset: ind.trigger.offsetTop }
    this.renderIndicator()
  }

  // Rendered only once a position exists (nm:484).
  renderIndicator() {
    const { ind } = this
    if (!ind?.position) return

    const created = !ind.el
    if (created) {
      ind.el = this.indicatorTemplateTarget.content.firstElementChild.cloneNode(true)
      ind.track.append(ind.el)
    }
    const { size, offset } = ind.position
    const { style } = ind.el
    ind.el.setAttribute("data-state", this.state === "" ? "hidden" : "visible")
    style.position = "absolute"
    if (this.orientationValue === "vertical") {
      Object.assign(style, { top: "0px", height: `${size}px`, transform: `translateY(${offset}px)` })
      style.setProperty("--radix-navigation-menu-indicator-translate-y", `${offset}px`)
    } else {
      Object.assign(style, { left: "0px", width: `${size}px`, transform: `translateX(${offset}px)` })
      style.setProperty("--radix-navigation-menu-indicator-translate-x", `${offset}px`)
    }
    // Presence records the animation of the element as rendered (its data-state), so it is created last.
    if (created) ind.presence = presence(ind.el, { onExited: () => this.unmountIndicator() })
  }

  unmountIndicator() {
    const { ind } = this
    if (!ind) return

    ind.disposeTrack()
    ind.disposeTrigger?.()
    ind.presence?.release()
    ind.el?.remove()
    this.ind = null
  }

  // Radix useResizeObserver: the callback runs in the next animation frame after a resize.
  observeResize(el, callback) {
    let raf = 0
    const observer = new ResizeObserver(() => {
      window.cancelAnimationFrame(raf)
      raf = window.requestAnimationFrame(callback)
    })
    observer.observe(el)
    return () => {
      window.cancelAnimationFrame(raf)
      observer.disconnect()
    }
  }

  teardown() {
    this.entries.forEach((entry) => this.unmountContent(entry))
    this.unmountViewport({ remount: false })
    this.unmountIndicator()
    this.items.forEach((item) => {
      item.proxy?.remove()
      item.owns?.remove()
      item.proxy = item.owns = null
    })
  }
}
