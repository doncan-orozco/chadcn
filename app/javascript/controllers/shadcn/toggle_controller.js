import { Controller } from "@hotwired/stimulus"

// Radix Toggle behavior (docs/shadcn-port/specs/toggle.md). Host = the toggle button.
// No key handlers: the native button turns Space/Enter into click.
export default class extends Controller {
  static values = { controlled: Boolean, disabled: Boolean }

  get pressed() {
    return this.element.getAttribute("aria-pressed") === "true"
  }

  toggle(event) {
    if (event.defaultPrevented || this.disabledValue) return
    const next = !this.pressed
    if (!this.controlledValue) {
      this.element.setAttribute("aria-pressed", String(next))
      this.element.dataset.state = next ? "on" : "off"
    }
    this.element.dispatchEvent(new CustomEvent("shadcn--toggle:pressed-change", { detail: { pressed: next }, bubbles: true }))
  }
}
