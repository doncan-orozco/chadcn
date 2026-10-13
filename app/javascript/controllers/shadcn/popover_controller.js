import { Controller } from "@hotwired/stimulus"
import { dismissable } from "shadcn/primitives/dismissable_layer"
import { focusGuards } from "shadcn/primitives/focus_guards"
import { focusScope } from "shadcn/primitives/focus_scope"
import { hideOthers } from "shadcn/primitives/hide_others"
import { positioner } from "shadcn/primitives/positioner"
import { presence } from "shadcn/primitives/presence"
import { scrollLock } from "shadcn/primitives/scroll_lock"
import { mountTemplate } from "shadcn/primitives/template_mount"

// Radix Popover (Root + Trigger + Anchor + Content). Spec: docs/shadcn-port/specs/popover.md (Behavior).
// The controller host is the first Trigger or, without one, the Content <template>. The content ships in that inert
// template and is mounted in <body> only while open (Portal + Presence). Mounted nodes live outside the controller
// scope, so their listeners are bound here.
//
// Known divergence: a modal focus trap is released when the exit animation ends, not when the popover starts closing.
export default class extends Controller {
  static values = { open: Boolean, controlled: Boolean, modal: Boolean, contentId: String, templateKey: String }

  connect() {
    this.template = document.querySelector(`template[data-v2--popover-template="${this.templateKeyValue}"]`)
    if (!this.template) return

    this.options = JSON.parse(this.template.dataset.options || "{}")
    this.shown = this.openValue
    this.disconnected = false
    this.resetFlags()
    this.abort = new AbortController()
    this.triggers.forEach((trigger) => {
      if (trigger !== this.element) trigger.addEventListener("click", (event) => this.toggle(event), { signal: this.abort.signal })
    })
    const { signal } = this.abort
    this.pageUrl = location.href.split("#")[0]
    document.addEventListener("turbo:before-cache", () => this.anchorVisit || this.reset(), { signal })
    this.syncTriggers()
    if (this.openValue) this.mount()
  }

  disconnect() {
    if (!this.template) return
    this.disconnected = true
    this.cancelPending()
    this.teardown()
    this.abort.abort()
  }

  toggle(event) {
    if (event.defaultPrevented) return
    this.request(!this.openValue)
  }

  // useControllableState: the event fires on every change request, the DOM only changes when uncontrolled.
  request(next) {
    if (next === this.openValue) return
    this.dispatch("open-change", { detail: { open: next } })
    if (this.controlledValue) return
    this.openValue = next
    this.sync()
  }

  openValueChanged() {
    this.sync()
  }

  // Idempotent: request() applies synchronously and Stimulus reports the value change afterwards.
  sync() {
    if (!this.template || this.shown === this.openValue) return
    this.shown = this.openValue
    this.syncTriggers()
    if (this.openValue) this.open()
    else this.close()
  }

  // Turbo also caches the page for a same-page anchor link (an as_child trigger with a hash href), which keeps the page.
  get anchorVisit() {
    return location.hash !== "" && location.href.split("#")[0] === this.pageUrl
  }

  // A cached page must not restore an open popover or a locked body.
  reset() {
    this.cancelPending()
    this.teardown()
    this.shown = false
    this.openValue = false
    this.syncTriggers()
  }

  get triggers() {
    const keyed = [...document.querySelectorAll(`[data-v2--popover-trigger="${this.templateKeyValue}"]`)]
    return this.element === this.template ? keyed : [this.element, ...keyed]
  }

  get anchor() {
    return document.querySelector(`[data-v2--popover-anchor="${this.templateKeyValue}"]`)
  }

  syncTriggers() {
    this.triggers.forEach((trigger) => {
      trigger.setAttribute("aria-expanded", String(this.shown))
      trigger.dataset.state = this.shown ? "open" : "closed"
      if (this.shown) trigger.setAttribute("aria-controls", this.contentIdValue)
      else trigger.removeAttribute("aria-controls")
    })
  }

  resetFlags() {
    this.hasInteractedOutside = false
    this.hasPointerDownOutside = false
    this.isRightClickOutside = false
  }

  // --- mounting ----------------------------------------------------------------------------------------------------

  open() {
    this.resetFlags()
    if (!this.mounted) return this.mount()
    this.content.dataset.state = "open"
    this.presence.enter()
  }

  close() {
    this.cancelPending()
    if (!this.mounted) return
    this.content.dataset.state = "closed"
    this.presence.exit()
  }

  mount() {
    this.mounted = mountTemplate(this.template, { into: document.body })
    this.content = this.mounted.nodes[0]
    this.content.dataset.state = this.openValue ? "open" : "closed"
    this.releases = []
    this.abortContent = new AbortController()
    this.presence = presence(this.content, { onExited: () => this.teardown() })

    const { collisionBoundary, ...placement } = this.options
    const reference = this.anchor || this.triggers.at(-1)
    this.placement = positioner(reference, this.content, {
      ...placement,
      collisionBoundary: collisionBoundary ? [...document.querySelectorAll(collisionBoundary)] : undefined
    })
    this.content.addEventListener("pointerdown", () => this.cancelPending(), { signal: this.abortContent.signal })

    // Radix effect order is children first: dismissable layer, focus scope, focus guards, hide others, scroll lock.
    this.releases.push(
      dismissable(this.content, {
        disableOutsidePointerEvents: this.modalValue,
        onEscape: (event) => this.forward("escape-key-down", event),
        onPointerDownOutside: (event) => this.onPointerDownOutside(event),
        onFocusOutside: (event) => this.onFocusOutside(event),
        onInteractOutside: (event) => this.onInteractOutside(event),
        onDismiss: () => this.request(false)
      }),
      focusScope(this.content, {
        trapped: this.modalValue,
        loop: true,
        onMountAutoFocus: (event) => {
          if (this.dispatch("open-auto-focus", { cancelable: true }).defaultPrevented) event.preventDefault()
        },
        onUnmountAutoFocus: (event) => this.onUnmountAutoFocus(event)
      }),
      focusGuards()
    )
    if (this.modalValue) this.releases.push(hideOthers(this.content), scrollLock())
  }

  teardown() {
    if (!this.mounted) return
    const wrapper = this.content.parentElement
    this.abortContent.abort()
    this.presence.release()
    this.placement.release()
    this.releases.reverse().forEach((release) => release())
    this.mounted.unmount()
    wrapper?.remove()
    this.mounted = this.content = null
  }

  // --- dismissable layer -------------------------------------------------------------------------------------------

  // Re-emit a primitive event as a public cancelable event; a prevented one keeps the primitive from acting.
  forward(name, event) {
    const originalEvent = event.detail?.originalEvent ?? event
    const forwarded = this.dispatch(name, { cancelable: true, detail: { originalEvent } })
    if (forwarded.defaultPrevented) event.preventDefault()
    return forwarded.defaultPrevented
  }

  // deferPointerDownOutside (popover:165): a primary press outside only arms the dismissal, the click that follows fires it.
  onPointerDownOutside(event) {
    const original = event.detail.originalEvent
    const rightClick = original.button === 2 || (original.button === 0 && original.ctrlKey === true)
    if (this.modalValue && rightClick) this.isRightClickOutside = true
    if (original.button !== 0 || original.pointerType === "touch") {
      this.forward("pointer-down-outside", event)
      return
    }
    event.preventDefault()
    this.skipInteract = true
    this.cancelPending()
    const fire = () => {
      this.pendingClick = null
      if (!this.openValue) return
      const outside = new CustomEvent("popover.pointerDownOutside", { cancelable: true, detail: { originalEvent: original } })
      this.forward("pointer-down-outside", outside)
      this.interactOutside(outside)
      if (!outside.defaultPrevented) this.request(false)
    }
    document.addEventListener("click", fire, { once: true })
    this.pendingClick = () => document.removeEventListener("click", fire)
  }

  onFocusOutside(event) {
    if (this.pendingClick) return event.preventDefault()
    this.forward("focus-outside", event)
    if (this.modalValue) event.preventDefault()
  }

  onInteractOutside(event) {
    if (this.skipInteract) {
      this.skipInteract = false
      return
    }
    this.interactOutside(event)
  }

  interactOutside(event) {
    const original = event.detail.originalEvent
    this.forward("interact-outside", event)
    if (this.modalValue) return
    if (!event.defaultPrevented) {
      this.hasInteractedOutside = true
      if (original.type === "pointerdown") this.hasPointerDownOutside = true
    }
    if (this.triggers.some((trigger) => trigger.contains(original.target))) event.preventDefault()
    if (original.type === "focusin" && this.hasPointerDownOutside) event.preventDefault()
  }

  cancelPending() {
    this.pendingClick?.()
    this.pendingClick = null
  }

  onUnmountAutoFocus(event) {
    if (this.disconnected) return event.preventDefault()
    if (this.dispatch("close-auto-focus", { cancelable: true }).defaultPrevented) return event.preventDefault()
    event.preventDefault()
    if (this.modalValue ? !this.isRightClickOutside : !this.hasInteractedOutside) this.triggers.at(-1)?.focus()
    this.resetFlags()
  }
}
