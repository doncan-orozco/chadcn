import { Controller } from "@hotwired/stimulus"
import { dismissable } from "shadcn/primitives/dismissable_layer"
import { focusGuards } from "shadcn/primitives/focus_guards"
import { focusScope } from "shadcn/primitives/focus_scope"
import { hideOthers } from "shadcn/primitives/hide_others"
import { presence } from "shadcn/primitives/presence"
import { scrollLock } from "shadcn/primitives/scroll_lock"
import { mountTemplate } from "shadcn/primitives/template_mount"

// Radix Dialog. Spec: docs/shadcn-port/specs/dialog.md (Behavior).
//
// The controller element is a display: contents host. Overlay and Content ship in inert <template>s (the Portals) and are
// mounted directly into <body> only while open, like Radix mounts them. Mounted nodes live outside the controller scope,
// so their listeners are bound here and not through data-action.
//
// Known divergence: the focus scope (trap + return focus) is released when the exit animation ends, not at the moment
// the dialog starts closing.
const TEMPLATE = "template[data-shadcn--dialog-template]"

export default class extends Controller {
  static values = { open: Boolean, controlled: Boolean, modal: { type: Boolean, default: true }, id: String }

  connect() {
    this.parts = []
    this.shown = this.openValue
    this.disconnected = false
    this.hasInteractedOutside = false
    this.hasPointerDownOutside = false
    this.caching = false
    this.restoreTimer = null
    this.restorePending = false
    this.restoreOpen = false
    this.abortCache = new AbortController()
    document.addEventListener("turbo:before-cache", () => this.#resetForCache(), { signal: this.abortCache.signal })
    this.#syncTriggers()
    this.templates().forEach((template) => {
      if (this.openValue || this.#options(template).forceMount) this.#mount(template)
    })
  }

  disconnect() {
    this.disconnected = true
    this.abortCache?.abort()
    this.#cancelRestore()
    this.#cancelPending()
    ;[...this.parts].forEach((part) => this.#unmount(part))
  }

  // A page snapshot must not carry the mounted overlay, the scroll lock, the aria-hidden siblings or the open state: the
  // portaled nodes live in <body>, outside the controller element, so they would be restored without their controller.
  // Unmounts at once (no exit animation, no focus return) and closes an uncontrolled dialog; a controlled one keeps the
  // value the server rendered and mounts again from it on connect.
  //
  // Turbo takes the snapshot one timer tick after this event (PageView#cacheSnapshot -> nextEventLoopTick, hence the two
  // ticks below), and also takes it for visits that keep the page (a link to #hash). So an open dialog is opened again
  // once the snapshot is taken, if this controller is still connected: a real navigation replaces the page later and
  // disconnects it, which cancels the pending restore.
  #resetForCache() {
    const wasOpen = this.openValue || this.restoreOpen // a second before-cache inside the window carries the pending restore forward
    this.#cancelRestore()
    this.caching = true
    this.#cancelPending()
    ;[...this.parts].forEach((part) => this.#unmount(part))
    this.caching = false
    if (!this.controlledValue) this.openValue = false
    this.shown = false
    this.#syncTriggers()
    this.restorePending = true
    this.restoreOpen = wasOpen
    this.restoreTimer = setTimeout(() => {
      this.restoreTimer = setTimeout(() => this.#restoreAfterCache(wasOpen))
    })
  }

  #restoreAfterCache(wasOpen) {
    this.restoreTimer = null
    this.restorePending = false
    this.restoreOpen = false
    if (this.disconnected) return
    if (wasOpen) {
      if (!this.controlledValue) this.openValue = true
      this.#sync()
      return
    }
    // A closed dialog keeps its forceMount parts: the page stayed, so nothing else would mount them again.
    this.templates().forEach((template) => {
      if (this.#options(template).forceMount && !this.parts.some((part) => part.template === template)) this.#mount(template)
    })
  }

  #cancelRestore() {
    clearTimeout(this.restoreTimer)
    this.restoreTimer = null
    this.restorePending = false
    this.restoreOpen = false
  }

  toggle(event) {
    if (event.defaultPrevented) return
    this.request(!this.openValue)
  }

  close(event) {
    if (event.defaultPrevented) return
    this.request(false)
  }

  // useControllableState: the event fires on every change request, the DOM only changes when uncontrolled.
  request(next) {
    if (next === this.openValue) return
    this.dispatch("open-change", { detail: { open: next } })
    if (this.controlledValue) return
    this.openValue = next
    this.#sync()
  }

  openValueChanged() {
    this.#sync()
  }

  // Idempotent: request() applies synchronously and Stimulus reports the value change afterwards.
  #sync() {
    if (!this.parts || this.shown === this.openValue) return
    this.shown = this.openValue
    this.#syncTriggers()
    if (this.openValue) this.#open()
    else this.#close()
  }

  templates() {
    return [...this.element.querySelectorAll(TEMPLATE)].filter(
      (template) => template.getAttribute("data-shadcn--dialog-template") === this.idValue && template.closest("[data-controller~='shadcn--dialog']") === this.element
    )
  }

  get triggers() {
    return [...this.element.querySelectorAll("[data-shadcn--dialog-part=trigger]")]
  }

  // Radix keeps a single triggerRef: the last rendered trigger receives the focus back.
  get trigger() {
    return this.triggers.at(-1)
  }

  #options(template) {
    return JSON.parse(template.getAttribute("data-shadcn--dialog-options") || "{}")
  }

  #syncTriggers() {
    this.triggers.forEach((trigger) => {
      trigger.setAttribute("aria-expanded", String(this.openValue))
      trigger.dataset.state = this.openValue ? "open" : "closed"
      if (this.openValue) trigger.setAttribute("aria-controls", this.idValue)
      else trigger.removeAttribute("aria-controls")
    })
  }

  // --- mounting ----------------------------------------------------------------------------------------------------

  #open() {
    this.hasInteractedOutside = false
    this.hasPointerDownOutside = false
    const mounted = new Set(this.parts.map((part) => part.template))
    this.parts.forEach((part) => this.#reopen(part))
    this.templates().forEach((template) => {
      if (!mounted.has(template)) this.#mount(template)
    })
  }

  #close() {
    this.#cancelPending()
    this.parts.forEach((part) => {
      part.el.dataset.state = "closed"
      this.#releaseLayer(part)
      if (!part.forceMount) part.presence.exit()
    })
  }

  #mount(template) {
    const options = this.#options(template)
    const container = (options.container && document.querySelector(options.container)) || document.body
    const mount = mountTemplate(template, { into: container })
    const parts = mount.nodes.map((el) => ({
      el, template, mount, kind: el.getAttribute("data-shadcn--dialog-part"), forceMount: Boolean(options.forceMount), releases: []
    }))
    parts.forEach((part) => {
      part.el.dataset.state = this.openValue ? "open" : "closed"
      part.presence = presence(part.el, { onExited: () => this.#unmount(part) })
      this.parts.push(part)
    })
    // Radix effect order is children first: dismissable layer, focus scope, scroll lock, focus guards, hide others.
    parts.forEach((part) => {
      if (part.kind === "content") this.#effectsForContent(part)
      else if (part.kind === "overlay" && this.modalValue) part.releases.push(scrollLock())
    })
  }

  #reopen(part) {
    part.el.dataset.state = "open"
    part.presence.enter()
    if (part.kind === "content" && !part.releaseLayer) this.#engage(part)
  }

  #unmount(part) {
    if (!this.parts.includes(part)) return
    this.parts = this.parts.filter((other) => other !== part)
    this.#releaseLayer(part)
    part.abort?.abort()
    part.presence.release()
    part.releases.reverse().forEach((release) => release())
    part.el.remove()
  }

  #effectsForContent(part) {
    part.abort = new AbortController()
    const on = (type, handler) => part.el.addEventListener(type, handler, { signal: part.abort.signal })
    on("click", (event) => this.#onContentClick(event, part))
    on("pointerdown", () => this.#cancelPending())
    if (this.openValue) this.#engage(part)

    part.releases.push(
      focusScope(part.el, {
        trapped: this.modalValue && this.openValue,
        loop: true,
        onMountAutoFocus: (event) => {
          if (this.dispatch("open-auto-focus").defaultPrevented) event.preventDefault()
        },
        onUnmountAutoFocus: (event) => this.#autoFocusOnUnmount(event)
      })
    )
    part.releases.push(focusGuards())
    if (this.modalValue) part.releases.push(hideOthers(part.el))
  }

  // Close buttons live in the portaled content: delegated here, after the handlers the caller put on the button itself.
  #onContentClick(event, part) {
    if (event.defaultPrevented) return
    const close = event.target.closest?.("[data-shadcn--dialog-part=close]")
    if (close && part.el.contains(close)) this.request(false)
  }

  // --- dismissable layer -------------------------------------------------------------------------------------------

  #engage(part) {
    part.releaseLayer = dismissable(part.el, {
      disableOutsidePointerEvents: this.modalValue && this.openValue,
      onEscape: (event) => {
        if (this.#forward("escape-key-down", event)) event.preventDefault()
      },
      onPointerDownOutside: (event) => this.#onPointerDownOutside(event),
      onFocusOutside: (event) => this.#onFocusOutside(event),
      onInteractOutside: (event) => {
        if (this.skipInteract) {
          this.skipInteract = false
          return
        }
        this.#interactOutside(event)
      },
      onDismiss: () => this.request(false)
    })
  }

  #releaseLayer(part) {
    part.releaseLayer?.()
    part.releaseLayer = null
  }

  // Re-emit a primitive event as a public cancelable event; a prevented one keeps the primitive from dismissing.
  #forward(name, event) {
    const originalEvent = event.detail?.originalEvent ?? event
    const forwarded = this.dispatch(name, { detail: { originalEvent } })
    if (forwarded.defaultPrevented) event.preventDefault()
    return forwarded.defaultPrevented
  }

  // deferPointerDownOutside (dialog:266): a primary press outside only arms the dismissal, the click that follows fires it.
  #onPointerDownOutside(event) {
    const original = event.detail.originalEvent
    const rightClick = original.button === 2 || (original.button === 0 && original.ctrlKey === true)
    if (this.modalValue && rightClick) {
      this.#forward("pointer-down-outside", event)
      return
    }
    if (original.button !== 0 || original.pointerType === "touch") {
      this.#forward("pointer-down-outside", event)
      return
    }
    event.preventDefault()
    this.skipInteract = true
    this.#cancelPending()
    const fire = () => {
      this.pendingClick = null
      if (!this.openValue) return
      const outside = new CustomEvent("dialog.pointerDownOutside", { cancelable: true, detail: { originalEvent: original } })
      this.#forward("pointer-down-outside", outside)
      this.#interactOutside(outside)
      if (!outside.defaultPrevented) this.request(false)
    }
    document.addEventListener("click", fire, { once: true })
    this.pendingClick = () => document.removeEventListener("click", fire)
  }

  #onFocusOutside(event) {
    if (this.pendingClick) return event.preventDefault()
    this.#forward("focus-outside", event)
    if (this.modalValue) event.preventDefault()
  }

  #interactOutside(event) {
    const original = event.detail.originalEvent
    this.#forward("interact-outside", event)
    if (this.modalValue) return
    if (!event.defaultPrevented) {
      this.hasInteractedOutside = true
      if (original.type === "pointerdown") this.hasPointerDownOutside = true
    }
    if (this.triggers.some((trigger) => trigger.contains(original.target))) event.preventDefault()
    if (original.type === "focusin" && this.hasPointerDownOutside) event.preventDefault()
  }

  #cancelPending() {
    this.pendingClick?.()
    this.pendingClick = null
  }

  #autoFocusOnUnmount(event) {
    if (this.disconnected || this.caching) return event.preventDefault()
    if (this.dispatch("close-auto-focus").defaultPrevented) return event.preventDefault()
    event.preventDefault()
    if (this.modalValue || !this.hasInteractedOutside) this.trigger?.focus()
    this.hasInteractedOutside = false
  }
}
