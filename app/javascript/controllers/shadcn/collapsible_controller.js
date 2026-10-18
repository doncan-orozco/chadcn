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

  restoreTimer = null

  connect() {
    this.#setup()
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
    clearTimeout(this.restoreTimer)
    this.restoring = false
    this.#teardown()
  }

  #setup() {
    const childTemplates = this.bodyTargets.filter((el) => el.hasAttribute("data-shadcn--collapsible-slot"))
    this.records = [
      ...this.contentTargets.map((el) => this.#record(el)),
      ...childTemplates.map((template) => this.#childRecord(template))
    ]
  }

  #teardown() {
    this.records?.forEach((record) => record.collapsible?.release())
    this.records = []
  }

  // A page snapshot must hold the server markup: a closed content with its body template, a closed as_child content as its
  // template (connect() took them over, so a restored page could never open the content). Turbo takes the snapshot one timer
  // tick after this event (hence the two ticks below) and also for visits that keep the page (a link to #hash), so the
  // controller is set up again once the snapshot is taken; a real navigation disconnects it first, which cancels that.
  onBeforeCache = () => {
    clearTimeout(this.restoreTimer)
    this.records?.forEach((record) => this.#restoreMarkup(record))
    this.#teardown()
    this.restoring = true
    this.restoreTimer = setTimeout(() => {
      this.restoreTimer = setTimeout(() => {
        this.#setup()
        this.restoring = false
      })
    })
  }

  #restoreMarkup(record) {
    const closed = this.element.dataset.state !== "open"
    if (record.child) {
      if (record.el && (!closed || record.forceMount)) return record.anchor.remove()
      record.el?.remove() // an exit animation still running
      record.el = null
      record.template.setAttribute("data-shadcn--collapsible-target", "body")
      record.template.setAttribute("data-shadcn--collapsible-slot", "child")
      return record.anchor.replaceWith(record.template)
    }
    if (record.forceMount || !closed) return
    // An exit animation still running is finished here: release() cancels the onExited that would hide the content.
    record.el.hidden = true
    record.el.style.removeProperty("--radix-collapsible-content-height")
    record.el.style.removeProperty("--radix-collapsible-content-width")
    record.body.setAttribute("data-shadcn--collapsible-target", "body")
    record.el.replaceChildren(record.body)
    record.mounted = false
  }

  toggle(event) {
    if (event.defaultPrevented || this.restoring) return
    const next = this.element.dataset.state !== "open"
    if (!this.controlledValue) this.#set(next)
    this.dispatch("open-change", { detail: { open: next }, cancelable: false })
  }

  // --- content records -----------------------------------------------------------------------------------------------

  #record(el) {
    const open = el.dataset.state === "open"
    const forceMount = el.getAttribute("data-shadcn--collapsible-force-mount") === "true"
    if (el.getAttribute("data-shadcn--collapsible-as-child") === "true") return this.#openChildRecord(el, open, forceMount)

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
    const template = el.querySelector(":scope > template[data-shadcn--collapsible-target~=body]")
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
