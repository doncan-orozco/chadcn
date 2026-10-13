import { Controller } from "@hotwired/stimulus"
import { collapsibleContent } from "shadcn/primitives/collapsible_content"
import { direction } from "shadcn/primitives/direction"
import { items as collectionItems } from "shadcn/primitives/collection"

// Radix Accordion. Spec: docs/shadcn-port/specs/accordion.md (Behavior).
//
// One controller per root. Each item's content ships its closed body in an inert <template>; connect() takes it over
// (removing the template) so the DOM equals Radix: a closed content is empty. Open/closed mechanics (data-state, hidden,
// measured size variables, exit animation wait) live in the shared collapsible_content primitive.
//
// Known divergence: a force_mount content only toggles data-state (no re-measure).
const KEYS = ["ArrowDown", "ArrowUp", "ArrowLeft", "ArrowRight", "Home", "End"]

export default class extends Controller {
  static values = {
    type: { type: String, default: "single" },
    controlled: Boolean,
    collapsible: Boolean,
    disabled: Boolean,
    orientation: { type: String, default: "vertical" },
    dir: String
  }
  static targets = ["item", "trigger", "content"]

  connect() {
    this.records = this.itemTargets.map((el) => this.#record(el))
    this.element.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    this.element.removeEventListener("keydown", this.onKeydown)
    this.records?.forEach((record) => record.collapsible?.release())
    this.records = []
  }

  toggle(event) {
    if (event.defaultPrevented) return
    const record = this.records.find((r) => r.trigger === event.currentTarget)
    if (record) this.#request(record)
  }

  onKeydown = (event) => {
    if (this.disabledValue || !KEYS.includes(event.key)) return
    const triggers = this.triggerTargets.filter((trigger) => !trigger.disabled)
    const index = triggers.indexOf(event.target)
    if (index === -1) return
    event.preventDefault()

    const last = triggers.length - 1
    const horizontal = this.orientationValue === "horizontal"
    const ltr = direction(null, this.dirValue) === "ltr"
    const next = () => (index + 1 > last ? 0 : index + 1)
    const previous = () => (index - 1 < 0 ? last : index - 1)
    let target = index
    if (event.key === "Home") target = 0
    else if (event.key === "End") target = last
    else if (event.key === "ArrowDown" && !horizontal) target = next()
    else if (event.key === "ArrowUp" && !horizontal) target = previous()
    else if (event.key === "ArrowRight" && horizontal) target = ltr ? next() : previous()
    else if (event.key === "ArrowLeft" && horizontal) target = ltr ? previous() : next()
    triggers[target].focus()
  }

  // --- value ---------------------------------------------------------------------------------------------------------

  #record(el) {
    const trigger = el.querySelector("[data-shadcn--accordion-target~=trigger]")
    const contentEl = el.querySelector("[data-shadcn--accordion-target~=content]")
    const open = el.dataset.state === "open"
    const forceMount = contentEl.getAttribute("data-shadcn--accordion-force-mount") === "true"
    const body = this.#takeBody(contentEl)
    const record = { el, value: el.getAttribute("data-shadcn--accordion-item-value"), trigger, header: trigger.parentElement, contentEl, body, forceMount, mounted: open || forceMount }
    record.collapsible = forceMount ? null : collapsibleContent(contentEl, { open, onExited: () => this.#unmount(record) })
    if (forceMount) collapsibleContent(contentEl, { open: true }).release()
    return record
  }

  // The closed body template, or a template built from the server-rendered children of an open content.
  #takeBody(contentEl) {
    const template = contentEl.querySelector(":scope > template[data-shadcn--accordion-target~=body]")
    if (template) {
      template.remove()
      return template
    }
    const fresh = document.createElement("template")
    fresh.content.append(...[...contentEl.childNodes].map((node) => node.cloneNode(true)))
    return fresh
  }

  get openValues() {
    return this.records.filter((r) => r.el.dataset.state === "open").map((r) => r.value)
  }

  #request(record) {
    const wasOpen = record.el.dataset.state === "open"
    if (this.typeValue === "multiple") {
      const current = this.openValues
      this.#change(wasOpen ? current.filter((v) => v !== record.value) : [...current, record.value], [record])
      return
    }
    if (wasOpen && !this.collapsibleValue) return
    this.#change(wasOpen ? "" : record.value, this.records)
  }

  #change(next, affected) {
    const current = this.typeValue === "multiple" ? this.openValues : (this.openValues[0] ?? "")
    if (JSON.stringify(next) === JSON.stringify(current)) return
    if (!this.controlledValue) {
      const open = new Set([next].flat())
      affected.forEach((record) => this.#set(record, open.has(record.value)))
    }
    this.dispatch("value-change", { detail: { value: next } })
  }

  // --- item state ----------------------------------------------------------------------------------------------------

  #set(record, open) {
    if ((record.el.dataset.state === "open") === open) return
    const state = open ? "open" : "closed"
    ;[record.el, record.header, record.trigger].forEach((el) => (el.dataset.state = state))
    record.trigger.setAttribute("aria-expanded", String(open))
    if (open) record.trigger.setAttribute("aria-controls", record.contentEl.id)
    else record.trigger.removeAttribute("aria-controls")
    this.#syncAriaDisabled(record, open)
    if (record.forceMount) {
      record.contentEl.dataset.state = state
      return
    }
    if (open) this.#mount(record)
    record.collapsible.setOpen(open)
  }

  #syncAriaDisabled(record, open) {
    const locked = open && !this.collapsibleValue
    if (locked) record.trigger.setAttribute("aria-disabled", "true")
    else record.trigger.removeAttribute("aria-disabled")
  }

  #mount(record) {
    if (record.mounted) return
    record.contentEl.append(record.body.content.cloneNode(true))
    record.mounted = true
  }

  #unmount(record) {
    if (!record.mounted || record.el.dataset.state === "open") return
    record.contentEl.replaceChildren()
    record.mounted = false
  }
}
