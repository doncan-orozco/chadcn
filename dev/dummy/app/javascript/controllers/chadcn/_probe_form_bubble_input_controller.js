import { Controller } from "@hotwired/stimulus"
import { FormBubbleInput } from "chadcn/primitives/form_bubble_input"

// Parity probe for chadcn/primitives/form_bubble_input (scenario _primitives-form-bubble-input). Twin of
// react-shadcn-catalog/src/parity/primitives/form_bubble_input.tsx. Not shipped to components.
// Config comes from data-probe-* on the root (kind, name, value, required, disabled, options JSON, selected) so the same tree
// also drives the raw Radix control in React.
export default class extends Controller {
  static targets = ["control", "log", "set"]

  get config() {
    const d = this.element.dataset
    return {
      kind: d.probeKind, name: d.probeName ?? "field", value: d.probeValue ?? "on", required: d.probeRequired === "true",
      disabled: d.probeDisabled === "true", options: JSON.parse(d.probeOptions ?? "[]"), selected: d.probeSelected ?? ""
    }
  }

  connect() {
    this.counts = { click: 0, change: 0 }
    this.cfg = this.config
    this.host = this.element
    this.bubbles = this.controlTargets.map((control) => this.#bubbleFor(control))
    if (this.cfg.kind === "select") this.selectBubble = this.#selectBubble()
    this.host.addEventListener("click", this.#onClick)
    this.host.addEventListener("change", this.#onChange)
    this.#slotBubbles()
    this.#render()
  }

  disconnect() {
    this.host.removeEventListener("click", this.#onClick)
    this.host.removeEventListener("change", this.#onChange)
    this.bubbles?.forEach((bubble) => bubble.release())
    this.selectBubble?.release()
  }

  toggle(event) {
    const control = event.currentTarget
    const state = control.getAttribute("aria-checked")
    const bubble = this.bubbles[this.controlTargets.indexOf(control)]
    if (this.cfg.kind === "radio") return this.#check(control, event)
    const next = state === "mixed" ? true : state !== "true"
    this.#reflect(control, next)
    bubble.sync({ checked: next, indeterminate: false }, { userInteraction: true, propagationStopped: event.cancelBubble })
  }

  keydown(event) {
    if (event.key === "Enter") event.preventDefault()
  }

  choose(event) {
    const value = this.cfg.options[1]?.value
    const label = this.element.querySelector("[role=combobox] > span")
    if (label) label.textContent = this.cfg.options.find((o) => o.value === value)?.label ?? ""
    this.selectBubble.sync({ value })
  }

  #check(control, event) {
    this.controlTargets.forEach((item, index) => {
      const checked = item === control
      this.#reflect(item, checked)
      this.bubbles[index].sync({ checked }, item === control ? { userInteraction: true, propagationStopped: event.cancelBubble } : {})
    })
  }

  #reflect(control, checked) {
    control.setAttribute("aria-checked", String(checked))
    control.setAttribute("data-state", checked ? "checked" : "unchecked")
    if (this.cfg.kind === "radio") control.tabIndex = checked ? 0 : -1
  }

  #bubbleFor(control) {
    const type = this.cfg.kind === "switch" ? "checkbox" : this.cfg.kind
    return new FormBubbleInput(control, {
      type: type === "select" ? "checkbox" : type,
      name: this.cfg.name,
      value: control.getAttribute("value") || this.cfg.value || "on",
      checked: control.getAttribute("aria-checked") === "true",
      indeterminate: control.getAttribute("aria-checked") === "mixed",
      required: this.cfg.required,
      disabled: this.cfg.disabled,
      onReset: () => {}
    })
  }

  #selectBubble() {
    const control = this.element.querySelector("[role=combobox]")
    return new FormBubbleInput(control, { type: "select", name: this.cfg.name, required: this.cfg.required, disabled: this.cfg.disabled, value: this.cfg.selected, options: this.cfg.options })
  }

  #slotBubbles() {
    const inputs = [...this.bubbles, this.selectBubble].filter(Boolean).map((bubble) => bubble.input).filter(Boolean)
    inputs.forEach((input) => input.setAttribute("data-slot", "bubble"))
  }

  #onClick = (event) => {
    if (event.target.getAttribute?.("aria-hidden") === "true") this.counts.click++
    this.#render()
  }

  #onChange = () => {
    this.counts.change++
    this.#render()
  }

  #render() {
    const el = this.host.querySelector("[aria-hidden=true]")
    const form = this.host.tagName === "FORM" ? this.host : null
    const data = form ? [...new FormData(form).entries()].map(([key, value]) => `${key}=${value}`).join("&") : ""
    const input = el ? (el instanceof HTMLSelectElement ? el.value : el.checked) : "none"
    this.logTarget.textContent = `click=${this.counts.click} change=${this.counts.change} input=${input} data=${data}`
  }
}
