import { Controller } from "@hotwired/stimulus"
import { FormBubbleInput } from "shadcn/primitives/form_bubble_input"

// Radix Switch behavior (docs/shadcn-port/specs/switch.md). Host = the switch button.
// No key handlers: the native button turns Space/Enter into click.
export default class extends Controller {
  static values = { controlled: Boolean }

  connect() {
    this.initialChecked = this.checked
    const input = this.element.nextElementSibling
    this.bubble = new FormBubbleInput(this.element, {
      type: "checkbox",
      name: input?.getAttribute("name"),
      value: this.element.getAttribute("value") ?? "on",
      checked: this.checked,
      required: input?.required,
      disabled: this.element.disabled,
      form: this.element.getAttribute("form") || input?.getAttribute("form"),
      onReset: () => this.#update(this.initialChecked, false)
    })
    // Not a form control: Radix does not render the bubble input at all.
    if (!this.bubble.present && input?.getAttribute("aria-hidden") === "true") input.remove()
  }

  disconnect() {
    this.bubble?.release()
  }

  get checked() {
    return this.element.getAttribute("aria-checked") === "true"
  }

  toggle(event) {
    if (event.defaultPrevented) return
    const propagationStopped = event.cancelBubble
    if (this.bubble.present && !propagationStopped) event.stopPropagation()
    this.#update(!this.checked, true, propagationStopped)
  }

  #update(next, userInteraction, propagationStopped = false) {
    if (next === this.checked) return
    if (!this.controlledValue) {
      this.element.setAttribute("aria-checked", String(next))
      this.#state(next)
      this.bubble.sync({ checked: next }, { userInteraction, propagationStopped })
    }
    this.element.dispatchEvent(new CustomEvent("v2--switch:checked-change", { detail: { checked: next }, bubbles: true }))
  }

  #state(checked) {
    const state = checked ? "checked" : "unchecked"
    this.element.dataset.state = state
    this.element.querySelector("[data-slot=switch-thumb]")?.setAttribute("data-state", state)
  }
}
