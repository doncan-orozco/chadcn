import { Controller } from "@hotwired/stimulus"
import { collapsibleContent } from "chadcn/primitives/collapsible_content"
import { mountTemplate, mountedTemplate } from "chadcn/primitives/template_mount"
import { turboCacheRestore } from "chadcn/primitives/turbo_cache"

// Radix Collapsible. Spec: dev/port/specs/collapsible.md (Behavior).
//
// One controller per root. A closed content ships its body in an inert <template>; connect() takes it over (removing
// the template) so the DOM equals Radix: a closed content is empty, and with as_child it is absent (an empty Text anchor
// marks its place). Opening mounts the body (or the as_child element) through the template_mount primitive; markup the
// server rendered open is adopted as that mount. Open/closed mechanics (data-state, hidden, measured size variables, exit
// animation wait) live in the shared collapsible_content primitive.
//
// Known divergence: a force_mount content only toggles data-state (no re-measure).
const PREVENTION = ["transition-duration", "animation-name"]

export default class extends Controller {
  static values = { controlled: Boolean, disabled: Boolean, contentId: String }
  static targets = ["trigger", "content", "body"]

  connect() {
    this.#setup()
    this.cache = turboCacheRestore({ teardown: () => this.#teardownForCache(), restore: () => this.#setup() })
  }

  disconnect() {
    this.cache?.release()
    this.#teardown()
  }

  #setup() {
    const childTemplates = this.bodyTargets.filter((el) => el.hasAttribute("data-chadcn--collapsible-slot"))
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
  // template (connect() took them over, so a restored page could never open the content). The turbo_cache primitive sets the
  // controller up again once the snapshot is taken; until then (`cache.pending`) a toggle is ignored.
  #teardownForCache() {
    this.records?.forEach((record) => this.#restoreMarkup(record))
    this.#teardown()
  }

  #restoreMarkup(record) {
    const closed = this.element.dataset.state !== "open"
    if (record.child) {
      if (record.el && (!closed || record.forceMount)) return record.anchor.remove()
      record.mount?.unmount() // an exit animation still running
      record.mount = null
      record.el = null
      record.template.setAttribute("data-chadcn--collapsible-target", "body")
      record.template.setAttribute("data-chadcn--collapsible-slot", "child")
      return record.anchor.replaceWith(record.template)
    }
    if (record.forceMount || !closed) return
    // An exit animation still running is finished here: release() cancels the onExited that would hide the content.
    record.el.hidden = true
    record.el.style.removeProperty("--radix-collapsible-content-height")
    record.el.style.removeProperty("--radix-collapsible-content-width")
    record.body.setAttribute("data-chadcn--collapsible-target", "body")
    record.el.replaceChildren(record.body)
    record.mount = null
  }

  toggle(event) {
    if (event.defaultPrevented || this.cache?.pending) return
    const next = this.element.dataset.state !== "open"
    if (!this.controlledValue) this.#set(next)
    this.dispatch("open-change", { detail: { open: next }, cancelable: false })
  }

  // --- content records -----------------------------------------------------------------------------------------------

  #record(el) {
    const open = el.dataset.state === "open"
    const forceMount = el.getAttribute("data-chadcn--collapsible-force-mount") === "true"
    if (el.getAttribute("data-chadcn--collapsible-as-child") === "true") return this.#openChildRecord(el, open, forceMount)

    const body = this.#takeBody(el)
    const mount = open || forceMount ? mountedTemplate(body, [...el.childNodes]) : null
    const record = { el, body, forceMount, mount }
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
    const record = { el, child: true, anchor: document.createTextNode(""), template, forceMount, mount: mountedTemplate(template, [el]) }
    el.before(record.anchor)
    record.collapsible = this.#attach(record, open, forceMount)
    return record
  }

  #childRecord(template) {
    const anchor = document.createTextNode("")
    template.replaceWith(anchor)
    return { el: null, child: true, anchor, template, forceMount: false, mount: null }
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
    const template = el.querySelector(":scope > template[data-chadcn--collapsible-target~=body]")
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
      record.mount = mountTemplate(record.template, { anchor: record.anchor })
      const el = record.mount.nodes[0]
      el.dataset.state = "closed"
      el.hidden = true
      record.el = el
      record.collapsible = collapsibleContent(el, { open: false, onExited: () => this.#unmount(record) })
      return
    }
    record.mount ??= mountTemplate(record.body, { into: record.el })
  }

  #unmount(record) {
    if (this.element.dataset.state === "open") return
    if (record.child) {
      if (!record.el) return
      record.collapsible.release()
      record.mount.unmount()
      record.mount = null
      record.el = null
      record.collapsible = null
      return
    }
    if (!record.mount) return
    record.mount.unmount()
    record.mount = null
  }
}
