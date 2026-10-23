import { Controller } from "@hotwired/stimulus"
import { dismissable } from "chadcn/primitives/dismissable_layer"
import { hoverIntent } from "chadcn/primitives/hover_intent"
import { positioner } from "chadcn/primitives/positioner"
import { presence } from "chadcn/primitives/presence"
import { mountTemplate } from "chadcn/primitives/template_mount"
import { turboCacheRestore } from "chadcn/primitives/turbo_cache"

// Radix HoverCard (Root + Trigger + Content). Spec: docs/shadcn-port/specs/hover-card.md (Behavior).
// The controller element is the trigger. The content lives in an inert <template> next to it and is mounted in <body>
// only while open (Portal + Presence), like Radix.
export default class extends Controller {
  static values = { open: Boolean, controlled: Boolean, openDelay: Number, closeDelay: Number, templateKey: String }

  connect() {
    this.template = this.findTemplate()
    if (!this.template) return

    this.options = JSON.parse(this.template.dataset.options || "{}")
    this.abort = new AbortController()
    this.isOpen = this.openValue
    this.hasSelection = false
    this.isPointerDownOnContent = false

    this.intent = hoverIntent({
      openDelay: this.openDelayValue,
      closeDelay: this.closeDelayValue,
      open: this.isOpen,
      onOpen: () => this.request(true),
      onClose: () => this.request(false)
    })

    const on = (type, handler) => this.element.addEventListener(type, handler, { signal: this.abort.signal })
    on("pointerenter", (event) => event.pointerType !== "touch" && this.intent.enter())
    on("pointerleave", (event) => event.pointerType !== "touch" && this.leave())
    on("focus", () => this.intent.enter())
    on("blur", () => this.leave())
    this.cache = turboCacheRestore({ teardown: () => this.reset(), restore: () => this.#restoreAfterCache() })

    if (this.isOpen) this.mount()
    this.syncTrigger()
  }

  // Controlled value: the content follows the attribute the caller re-renders (the first call runs before connect).
  openValueChanged() {
    if (!this.template || this.openValue === this.isOpen) return
    this.isOpen = this.openValue
    if (this.isOpen) this.mount()
    else this.unmount()
    this.intent.sync(this.isOpen)
    this.syncTrigger()
  }

  disconnect() {
    if (!this.template) return
    this.cache.release()
    this.reset()
    this.abort.abort()
    this.intent.release()
  }

  findTemplate() {
    const selector = `template[data-chadcn--hover-card-template="${this.templateKeyValue}"]`
    return (this.element.parentElement || document).querySelector(selector) || document.querySelector(selector)
  }

  // A cached page must not hold a hover-opened card (a server-rendered open value is honoured again on connect): the card is torn
  // down and the hover intent is reset, so no stale open flag or pending timer survives the snapshot (turbo_cache teardown, and
  // the disconnect cleanup). Once the snapshot is taken (turbo_cache restore), a trigger that is still hovered or focused re-arms
  // the intent, so the card comes back after its delay, like after a fresh pointerenter.
  reset() {
    this.intent?.sync(false)
    this.teardown()
    this.isOpen = false
    this.syncTrigger()
  }

  // Pointer presence counts only where hovering exists: on touch devices `:hover` sticks to the tapped element, and touch must
  // never open the card (pointerenter is ignored for it too).
  #restoreAfterCache() {
    const hovered = window.matchMedia("(hover: hover)").matches && this.element.matches(":hover")
    if (hovered || this.element.contains(document.activeElement)) this.intent.enter()
  }

  // Radix onClose: a text selection or a pressed pointer inside the content keeps the card open.
  leave() {
    if (this.hasSelection || this.isPointerDownOnContent) return this.intent.cancelOpen()
    this.intent.leave()
  }

  // Every open/close request (Radix useControllableState onChange): the event always fires, the DOM only changes when uncontrolled.
  request(next) {
    if (next === this.isOpen) return
    this.dispatch("open-change", { detail: { open: next } })
    if (this.controlledValue) return this.intent.sync(this.isOpen)

    this.isOpen = next
    if (next) this.mount()
    else this.unmount()
    this.syncTrigger()
  }

  syncTrigger() {
    this.element.dataset.state = this.isOpen ? "open" : "closed"
  }

  mount() {
    if (this.mounted) {
      this.content.dataset.state = "open"
      this.presence.enter()
      return
    }

    this.mounted = mountTemplate(this.template, { into: document.body })
    this.content = this.mounted.nodes[0]
    this.content.dataset.state = "open"
    this.removeTabStops()
    const { collisionBoundary, ...placement } = this.options
    this.placement = positioner(this.element, this.content, {
      ...placement,
      collisionBoundary: collisionBoundary ? [...document.querySelectorAll(collisionBoundary)] : undefined
    })
    this.presence = presence(this.content, { onExited: () => this.teardown() })
    this.layers = new AbortController()
    this.releaseLayer = dismissable(this.content, {
      onEscape: (event) => this.forward("escape-key-down", event),
      onPointerDownOutside: (event) => this.forward("pointer-down-outside", event),
      onFocusOutside: (event) => {
        this.forward("focus-outside", event)
        event.preventDefault()
      },
      onInteractOutside: (event) => this.forward("interact-outside", event),
      onDismiss: () => this.intent.close()
    })

    const { signal } = this.layers
    this.content.addEventListener("pointerenter", (event) => event.pointerType !== "touch" && this.intent.enter(), { signal })
    this.content.addEventListener("pointerleave", (event) => event.pointerType !== "touch" && this.leave(), { signal })
    this.content.addEventListener("pointerdown", () => this.onContentPointerDown(), { signal })
    document.addEventListener("pointerup", () => this.onPointerUp(), { signal })
  }

  // Exit: keep the node until its exit animation ends (Presence).
  unmount() {
    if (!this.mounted) return
    this.content.dataset.state = "closed"
    this.presence.exit()
  }

  onContentPointerDown() {
    this.containSelection()
    this.hasSelection = false
    this.isPointerDownOnContent = true
  }

  containSelection() {
    if (this.originalBodyUserSelect === undefined) this.originalBodyUserSelect = document.body.style.userSelect
    document.body.style.userSelect = "none"
    document.body.style.webkitUserSelect = "none"
    this.content.style.userSelect = "text"
    this.content.style.webkitUserSelect = "text"
  }

  releaseSelection() {
    if (this.originalBodyUserSelect === undefined) return
    document.body.style.userSelect = this.originalBodyUserSelect
    document.body.style.webkitUserSelect = this.originalBodyUserSelect
    this.originalBodyUserSelect = undefined
    if (this.content) {
      this.content.style.removeProperty("user-select")
      this.content.style.removeProperty("-webkit-user-select")
    }
  }

  onPointerUp() {
    this.releaseSelection()
    this.isPointerDownOnContent = false
    this.selectionTimer = window.setTimeout(() => {
      if (document.getSelection().toString() !== "") this.hasSelection = true
    }, 0)
  }

  // Radix keeps content tabbables out of the Tab order (getTabbableNodes -> tabindex -1).
  removeTabStops() {
    const walker = document.createTreeWalker(this.content, NodeFilter.SHOW_ELEMENT, {
      acceptNode: (node) => {
        if (node.disabled || node.hidden || (node.tagName === "INPUT" && node.type === "hidden")) return NodeFilter.FILTER_SKIP
        return node.tabIndex >= 0 ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_SKIP
      }
    })
    const nodes = []
    while (walker.nextNode()) nodes.push(walker.currentNode)
    nodes.forEach((node) => node.setAttribute("tabindex", "-1"))
  }

  forward(name, event) {
    const originalEvent = event.detail?.originalEvent ?? event
    const forwarded = this.dispatch(name, { cancelable: true, detail: { originalEvent } })
    if (forwarded.defaultPrevented) event.preventDefault()
  }

  teardown() {
    window.clearTimeout(this.selectionTimer)
    this.hasSelection = false
    this.isPointerDownOnContent = false
    this.releaseSelection()
    if (!this.mounted) return
    const wrapper = this.content.parentElement
    this.layers.abort()
    this.releaseLayer()
    this.presence.release()
    this.placement.release()
    this.mounted.unmount()
    wrapper?.remove()
    this.mounted = this.content = null
  }
}
