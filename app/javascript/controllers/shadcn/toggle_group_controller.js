import { Controller } from "@hotwired/stimulus"
import { rovingFocus } from "shadcn/primitives/roving_focus"

// Radix ToggleGroup behavior (docs/shadcn-port/specs/toggle-group.md). Host = the group element; the items are plain
// buttons wired by data-action (no per-item controller). Arrows only move focus (roving focus), click presses.
export default class extends Controller {
  static values = {
    type: String, controlled: Boolean, initial: Array, loop: { type: Boolean, default: true },
    rovingFocus: { type: Boolean, default: true }, orientation: String, dir: String
  }

  connect() {
    this.value = this.#readValue()
    if (this.rovingFocusValue) {
      this.roving = rovingFocus(this.element, {
        orientation: this.orientationValue || undefined,
        loop: this.loopValue,
        dir: this.dirValue,
        isActive: (button) => this.#pressed(button)
      })
    }
  }

  disconnect() {
    this.roving?.release()
    this.roving = null
  }

  toggle(event) {
    if (event.defaultPrevented) return
    const item = event.currentTarget
    if (item.disabled) return
    this.#change(this.#next(this.#valueOf(item), !this.#pressed(item)))
  }

  get #single() { return this.typeValue === "single" }

  get #items() { return [...this.element.querySelectorAll("[data-slot=toggle-group-item]")] }

  #valueOf(item) { return item.getAttribute("data-v2--toggle-group-item-value") }

  #pressed(item) { return item.dataset.state === "on" }

  // Server-rendered value: the given order (activation order for multiple), reconciled with the DOM after Turbo restores.
  #readValue() {
    const pressed = this.#items.filter((item) => this.#pressed(item)).map((item) => this.#valueOf(item))
    if (this.#single) return pressed[0] ?? ""
    const initial = this.initialValue
    return [...initial.filter((value) => pressed.includes(value)), ...pressed.filter((value) => !initial.includes(value))]
  }

  #next(value, pressed) {
    if (this.#single) return pressed ? value : ""
    return pressed ? [...this.value, value] : this.value.filter((current) => current !== value)
  }

  // useControllableState: uncontrolled updates the DOM, both dispatch when the value differs (multiple always differs).
  #change(next) {
    if (this.#single && next === this.value) return
    if (!this.controlledValue) this.#render(next)
    this.element.dispatchEvent(new CustomEvent("v2--toggle-group:value-change", { detail: { value: next }, bubbles: true }))
  }

  #render(next) {
    this.value = next
    for (const item of this.#items) {
      const pressed = this.#single ? this.#valueOf(item) === next : next.includes(this.#valueOf(item))
      if (pressed === this.#pressed(item)) continue
      item.dataset.state = pressed ? "on" : "off"
      item.setAttribute(this.#single ? "aria-checked" : "aria-pressed", String(pressed))
    }
  }
}
