import { Controller } from "@hotwired/stimulus"
import { collapsibleContent } from "shadcn/primitives/collapsible_content"

// Radix Collapsible. Spec: docs/shadcn-port/specs/collapsible.md (Behavior).
//
// One controller per root. A closed content ships its body in an inert <template>; connect() takes it over (removing
// the template) so the DOM equals Radix: a closed content is empty, and with as_child it is absent (an empty Text anchor
// marks its place). Open/closed mechanics (data-state, hidden, measured size variables, exit animation wait) live in the
// shared collapsible_content primitive.
//
// Known divergence: a force_mount content only toggles data-state (no re-measure).
const PREVENTION = ["transition-duration", "animation-name"]

export default class extends Controller {
  static values = { controlled: Boolean, disabled: Boolean, contentId: String }
  static targets = ["trigger", "content", "body"]

  connect() {
    const childTemplates = this.bodyTargets.filter((el) => el.hasAttribute("data-v2--collapsible-slot"))
    this.records = [
      ...this.contentTargets.map((el) => this.#record(el)),
      ...childTemplates.map((template) => this.#childRecord(template))
    ]
  }

  disconnect() {
    this.records?.forEach((record) => record.collapsible?.release())
    this.records = []
  }

  toggle(event) {
    if (event.defaultPrevented) return
    const next = this.element.dataset.state !== "open"
    if (!this.controlledValue) this.#set(next)
    this.dispatch("open-change", { detail: { open: next }, cancelable: false })
  }

  // --- content records -----------------------------------------------------------------------------------------------

  #record(el) {
    const open = el.dataset.state === "open"
    const forceMount = el.getAttribute("data-v2--collapsible-force-mount") === "true"
    if (el.getAttribute("data-v2--collapsible-as-child") === "true") return this.#openChildRecord(el, open, forceMount)

    const body = this.#takeBody(el)
    const record = { el, body, forceMount, mounted: open || forceMount }
    record.collapsible = this.#attach(record, open, forceMount)
    return record
  }

  // as_child content present at render time (open or force-mounted): the element itself is the slotted child.
  #openChildRecord(el, open, forceMount) {
    const template = document.createElement("template")
    const copy = el.cloneNode(true)
    PREVENTION.forEach((property) => copy.style.removeProperty(property))
    if (!copy.getAttribute("style")) copy.removeAttribute("style")
    template.content.append(copy)
    const record = { el, child: true, anchor: document.createTextNode(""), template, forceMount }
    el.before(record.anchor)
    record.collapsible = this.#attach(record, open, forceMount)
    return record
  }

  #childRecord(template) {
    const anchor = document.createTextNode("")
    template.replaceWith(anchor)
    return { el: null, child: true, anchor, template, forceMount: false }
  }

  #attach(record, open, forceMount) {
    if (forceMount) {
      collapsibleContent(record.el, { open: true }).release()
      return null
    }
    return collapsibleContent(record.el, { open, onExited: () => this.#unmount(record) })
  }

  // The closed body template, or a template built from the server-rendered children of an open content.
  #takeBody(el) {
    const template = el.querySelector(":scope > template[data-v2--collapsible-target~=body]")
    if (template) {
      template.remove()
      return template
    }
    const fresh = document.createElement("template")
    fresh.content.append(...[...el.childNodes].map((node) => node.cloneNode(true)))
    return fresh
  }

  // --- state ---------------------------------------------------------------------------------------------------------

  #set(open) {
    const state = open ? "open" : "closed"
    this.element.dataset.state = state
    this.triggerTargets.forEach((trigger) => {
      trigger.dataset.state = state
      trigger.setAttribute("aria-expanded", String(open))
      if (open) trigger.setAttribute("aria-controls", this.contentIdValue)
      else trigger.removeAttribute("aria-controls")
    })
    this.records.forEach((record) => this.#setContent(record, open))
  }

  #setContent(record, open) {
    if (record.forceMount) {
      record.el.dataset.state = open ? "open" : "closed"
      return
    }
    if (open) this.#mount(record)
    record.collapsible.setOpen(open)
  }

  #mount(record) {
    if (record.child) {
      if (record.el) return
      const el = record.template.content.cloneNode(true).firstElementChild
      el.dataset.state = "closed"
      el.hidden = true
      record.anchor.after(el)
      record.el = el
      record.collapsible = collapsibleContent(el, { open: false, onExited: () => this.#unmount(record) })
      return
    }
    if (record.mounted) return
    record.el.append(record.body.content.cloneNode(true))
    record.mounted = true
  }

  #unmount(record) {
    if (this.element.dataset.state === "open") return
    if (record.child) {
      if (!record.el) return
      record.collapsible.release()
      record.el.remove()
      record.el = null
      record.collapsible = null
      return
    }
    if (!record.mounted) return
    record.el.replaceChildren()
    record.mounted = false
  }
}
