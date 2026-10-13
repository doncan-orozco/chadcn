import { Controller } from "@hotwired/stimulus"
import { dismissable } from "shadcn/primitives/dismissable_layer"
import { hoverIntent, hoverProvider } from "shadcn/primitives/hover_intent"
import { positioner } from "shadcn/primitives/positioner"
import { presence } from "shadcn/primitives/presence"
import { hoverGrace } from "shadcn/primitives/submenu_grace"
import { mountTemplate } from "shadcn/primitives/template_mount"

// Radix Tooltip (Root + Trigger + Content). Spec: docs/shadcn-port/specs/tooltip.md (Behavior).
// The controller element is the trigger. The content lives in an inert <template> next to it and is mounted in <body>
// only while open (Portal + Presence), like Radix.
const GLOBAL_OPEN = "shadcn--tooltip:global-open"
const providers = new Map() // TooltipProvider state shared by every tooltip with the same provider-id

function acquireProvider(id, skipDelayDuration) {
  let entry = providers.get(id)
  if (!entry) {
    entry = { provider: hoverProvider({ skipDelayDuration }), refs: 0 }
    providers.set(id, entry)
  }
  entry.refs += 1
  return entry
}

function releaseProvider(id) {
  const entry = providers.get(id)
  if (!entry || (entry.refs -= 1) > 0) return
  entry.provider.release()
  providers.delete(id)
}

export default class extends Controller {
  static values = {
    open: Boolean,
    controlled: Boolean,
    delayDuration: Number,
    skipDelayDuration: Number,
    disableHoverableContent: Boolean,
    providerId: String,
    contentId: String
  }

  connect() {
    this.template = this.findTemplate()
    if (!this.template) return

    this.options = JSON.parse(this.template.dataset.options || "{}")
    this.abort = new AbortController()
    this.entry = acquireProvider(this.providerIdValue, this.skipDelayDurationValue)
    this.isOpen = this.openValue
    this.state = this.isOpen ? "instant-open" : "closed"
    this.callerDescribedby = (this.element.getAttribute("aria-describedby") || "").split(/\s+/).filter((id) => id && id !== this.contentIdValue)
    this.pointerDown = false
    this.hasPointerMoveOpened = false

    this.intent = hoverIntent({
      provider: this.entry.provider,
      openDelay: this.delayDurationValue,
      open: this.isOpen,
      onOpen: ({ delayed }) => this.request(true, delayed),
      onClose: () => this.request(false)
    })

    const on = (type, handler) => this.element.addEventListener(type, handler, { signal: this.abort.signal })
    on("pointermove", (event) => this.onPointerMove(event))
    on("pointerleave", () => this.onPointerLeave())
    on("pointerdown", () => this.onPointerDown())
    on("focus", () => !this.pointerDown && this.intent.open())
    on("blur", () => this.intent.close())
    on("click", () => this.intent.close())
    document.addEventListener("turbo:before-cache", () => this.reset(), { signal: this.abort.signal })

    if (this.isOpen) this.mount()
    this.syncTrigger()
  }

  disconnect() {
    if (!this.template) return
    this.reset()
    this.abort.abort()
    this.intent.release()
    releaseProvider(this.providerIdValue)
  }

  findTemplate() {
    const selector = `template[data-shadcn--tooltip-template="${this.contentIdValue}"]`
    return (this.element.parentElement || document).querySelector(selector) || document.querySelector(selector)
  }

  // A cached page must not restore an open tooltip.
  reset() {
    this.teardown()
    this.isOpen = false
    this.state = "closed"
    this.syncTrigger()
  }

  onPointerMove(event) {
    if (event.pointerType === "touch") return
    if (this.hasPointerMoveOpened || this.entry.provider.isPointerInTransit) return
    this.intent.enter()
    this.hasPointerMoveOpened = true
  }

  onPointerLeave() {
    if (this.disableHoverableContentValue) this.intent.close()
    else this.intent.cancelOpen()
    this.hasPointerMoveOpened = false
  }

  onPointerDown() {
    if (this.isOpen) this.intent.close()
    this.pointerDown = true
    document.addEventListener("pointerup", () => (this.pointerDown = false), { once: true })
  }

  // Every open/close request (Radix useControllableState onChange): the event always fires, the DOM only changes when uncontrolled.
  request(next, delayed = false) {
    if (next === this.isOpen) return
    this.dispatch("open-change", { detail: { open: next } })
    if (this.controlledValue) return this.intent.sync(this.isOpen)

    this.isOpen = next
    this.state = next ? (delayed ? "delayed-open" : "instant-open") : "closed"
    if (next) this.mount()
    else this.unmount()
    this.syncTrigger()
    if (next) document.dispatchEvent(new CustomEvent(GLOBAL_OPEN, { detail: { source: this } }))
  }

  syncTrigger() {
    this.element.dataset.state = this.state
    const ids = this.isOpen ? [...this.callerDescribedby, this.contentIdFromDom()] : this.callerDescribedby
    const value = [...new Set(ids.filter(Boolean))].join(" ")
    if (value) this.element.setAttribute("aria-describedby", value)
    else this.element.removeAttribute("aria-describedby")
  }

  // The element carrying role=tooltip is the content, or the visually hidden span in aria-label mode.
  contentIdFromDom() {
    return this.content?.querySelector("[role=tooltip]")?.id || this.content?.id || this.contentIdValue
  }

  mount() {
    if (this.mounted) {
      this.content.dataset.state = this.state
      this.presence.enter()
      return
    }

    this.mounted = mountTemplate(this.template, { into: document.body })
    this.content = this.mounted.nodes[0]
    this.content.dataset.state = this.state
    const { collisionBoundary, ...placement } = this.options
    this.placement = positioner(this.element, this.content, {
      ...placement,
      collisionBoundary: collisionBoundary ? [...document.querySelectorAll(collisionBoundary)] : undefined,
      arrow: this.content.querySelector(":scope > span:not([role])")
    })
    this.presence = presence(this.content, { onExited: () => this.teardown() })
    this.layers = new AbortController()
    this.releaseLayer = dismissable(this.content, {
      onEscape: (event) => this.forward("escape-key-down", event),
      onPointerDownOutside: (event) => this.forward("pointer-down-outside", event),
      onFocusOutside: (event) => event.preventDefault(),
      onDismiss: () => this.intent.close()
    })
    if (!this.disableHoverableContentValue) {
      this.grace = hoverGrace(this.element, this.content, {
        onInTransitChange: (value) => (this.entry.provider.isPointerInTransit = value),
        onClose: () => this.intent.close()
      })
    }
    const { signal } = this.layers
    document.addEventListener(GLOBAL_OPEN, (event) => event.detail.source !== this && this.intent.close(), { signal })
    window.addEventListener("scroll", (event) => event.target.contains(this.element) && this.intent.close(), { signal, capture: true })
  }

  // Exit: keep the node until its exit animation ends (Presence).
  unmount() {
    if (!this.mounted) return
    this.content.dataset.state = "closed"
    this.presence.exit()
  }

  forward(name, originalEvent) {
    const event = this.dispatch(name, { cancelable: true, detail: { originalEvent } })
    if (event.defaultPrevented) originalEvent.preventDefault()
  }

  teardown() {
    if (!this.mounted) return
    const wrapper = this.content.parentElement
    this.layers.abort()
    this.releaseLayer()
    this.grace?.release()
    this.grace = null
    this.entry.provider.isPointerInTransit = false
    this.presence.release()
    this.placement.release()
    this.mounted.unmount()
    wrapper?.remove()
    this.mounted = this.content = null
  }
}
