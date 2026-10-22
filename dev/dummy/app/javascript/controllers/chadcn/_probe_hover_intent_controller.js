// Parity probe for chadcn/primitives/hover_intent (+ positioner) against raw Radix Tooltip / HoverCard
// (scenario _primitives-hover-intent). Not a product controller.
// Root children: any elements; every `[data-slot=trigger]` is followed by its `[data-slot=content]`. The content is detached
// while closed and inserted right after its trigger while open (Radix renders it unmounted when closed).
// data-parity-options (JSON, shared with the React twin): kind "tooltip" | "hover-card", side, sideOffset,
//   tooltip: delayDuration, skipDelayDuration, hoverable (hoverable content, grace area) | hover-card: openDelay, closeDelay.
import { Controller } from "@hotwired/stimulus"
import { hoverIntent, hoverProvider } from "chadcn/primitives/hover_intent"
import { positioner } from "chadcn/primitives/positioner"
import { hoverGrace } from "chadcn/primitives/submenu_grace"

export default class extends Controller {
  static count = 0

  connect() {
    this.options = JSON.parse(this.element.dataset.parityOptions || "{}")
    this.tooltip = this.options.kind === "tooltip"
    this.provider = this.tooltip ? hoverProvider({ skipDelayDuration: this.options.skipDelayDuration }) : null
    this.pairs = [...this.element.querySelectorAll(":scope > [data-slot=trigger]")].map((trigger) => this.setup(trigger, trigger.nextElementSibling))
  }

  disconnect() {
    this.pairs?.forEach((pair) => {
      pair.intent.release()
      pair.placement?.release()
      pair.grace?.release()
      pair.abort.abort()
    })
    this.provider?.release()
  }

  setup(trigger, content) {
    content.remove()
    trigger.dataset.state = "closed"
    const pair = { trigger, content, contentId: `probe-content-${++this.constructor.count}`, abort: new AbortController(), placement: null, pointerDown: false, pointerMoved: false }
    pair.intent = hoverIntent({
      provider: this.provider,
      openDelay: this.tooltip ? this.options.delayDuration : this.options.openDelay,
      closeDelay: this.tooltip ? 0 : this.options.closeDelay,
      onOpen: ({ delayed }) => this.show(pair, this.tooltip ? (delayed ? "delayed-open" : "instant-open") : "open"),
      onClose: () => this.hide(pair)
    })
    const on = (el, type, handler) => el.addEventListener(type, handler, { signal: pair.abort.signal })
    const mouse = (handler) => (event) => event.pointerType !== "touch" && handler(event)
    if (this.tooltip) {
      on(trigger, "pointermove", mouse(() => {
        if (pair.pointerMoved || this.provider.isPointerInTransit) return
        pair.intent.enter()
        pair.pointerMoved = true
      }))
      on(trigger, "pointerleave", () => {
        if (this.options.hoverable) pair.intent.cancelOpen()
        else pair.intent.leave()
        pair.pointerMoved = false
      })
      on(trigger, "pointerdown", () => {
        pair.intent.close()
        pair.pointerDown = true
        document.addEventListener("pointerup", () => (pair.pointerDown = false), { once: true })
      })
      on(trigger, "focus", () => !pair.pointerDown && pair.intent.open())
      on(trigger, "blur", () => pair.intent.close())
      on(trigger, "click", () => pair.intent.close())
    } else {
      on(trigger, "pointerenter", mouse(() => pair.intent.enter()))
      on(trigger, "pointerleave", mouse(() => pair.intent.leave()))
      on(trigger, "focus", () => pair.intent.enter())
      on(trigger, "blur", () => pair.intent.leave())
      on(content, "pointerenter", mouse(() => pair.intent.enter()))
      on(content, "pointerleave", mouse(() => pair.intent.leave()))
    }
    return pair
  }

  show(pair, state) {
    pair.trigger.dataset.state = state
    pair.content.dataset.state = state
    if (this.tooltip) {
      pair.content.setAttribute("role", "tooltip")
      pair.content.id = pair.contentId
      pair.trigger.setAttribute("aria-describedby", pair.contentId)
    }
    pair.trigger.after(pair.content)
    if (this.options.hoverable) {
      pair.grace = hoverGrace(pair.trigger, pair.content, { onInTransitChange: (value) => (this.provider.isPointerInTransit = value), onClose: () => pair.intent.close() })
    }
    pair.placement = positioner(pair.trigger, pair.content, { side: this.options.side, sideOffset: this.options.sideOffset, align: this.options.align })
  }

  hide({ trigger, content, placement, grace }) {
    trigger.dataset.state = "closed"
    trigger.removeAttribute("aria-describedby")
    placement.release()
    grace?.release()
    content.parentElement.remove()
  }
}
