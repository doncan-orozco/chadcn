import { Controller } from "@hotwired/stimulus"
import { FormBubbleInput } from "shadcn/primitives/form_bubble_input"
import { presence } from "shadcn/primitives/presence"
import { rovingFocus } from "shadcn/primitives/roving_focus"
import { items as collectionItems } from "shadcn/primitives/collection"

// Radix RadioGroup behavior (docs/shadcn-port/specs/radio-group.md). Host = the radiogroup element; the items are
// plain buttons wired by data-action (no per-item controller).
const ARROWS = ["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"]

export default class extends Controller {
  static values = { controlled: Boolean, loop: { type: Boolean, default: true }, orientation: String, dir: String, indicatorHtml: String }

  connect() {
    this.arrowPressed = false
    this.exiting = new Set()
    this.records = collectionItems(this.element, { includeDisabled: true }).map((button) => this.#record(button))
    this.value = this.records.find((record) => this.#checked(record.button))?.button.value ?? null
    this.initialValue = this.value
    this.roving = rovingFocus(this.element, {
      orientation: this.orientationValue || undefined,
      loop: this.loopValue,
      dir: this.dirValue,
      isActive: (button) => this.#checked(button)
    })
    document.addEventListener("keydown", this.onDocumentKeydown)
    document.addEventListener("keyup", this.onDocumentKeyup)
  }

  disconnect() {
    document.removeEventListener("keydown", this.onDocumentKeydown)
    document.removeEventListener("keyup", this.onDocumentKeyup)
    this.roving?.release()
    this.exiting.forEach((release) => release())
    this.records?.forEach((record) => record.bubble.release())
    this.records = []
  }

  onDocumentKeydown = (event) => { if (ARROWS.includes(event.key)) this.arrowPressed = true }
  onDocumentKeyup = () => { this.arrowPressed = false }

  select(event) {
    if (event.defaultPrevented) return
    const record = this.#recordOf(event.currentTarget)
    const propagationStopped = event.cancelBubble
    if (!this.#checked(record.button)) this.#change(record.button.value, true, propagationStopped)
    if (record.bubble.present && !propagationStopped) event.stopPropagation()
  }

  keydown(event) {
    if (!event.defaultPrevented && event.key === "Enter") event.preventDefault()
  }

  focus(event) {
    if (event.defaultPrevented) return
    if (this.arrowPressed) event.currentTarget.click()
  }

  #record(button) {
    const input = button.nextElementSibling
    const bubble = new FormBubbleInput(button, {
      type: "radio",
      name: input?.getAttribute("name"),
      value: button.value,
      checked: this.#checked(button),
      required: input?.required,
      disabled: button.disabled,
      form: input?.getAttribute("form"),
      onReset: () => this.#change(this.initialValue, false)
    })
    // Not a form control: Radix does not render the bubble input at all.
    if (!bubble.present && input?.getAttribute("aria-hidden") === "true") input.remove()
    return { button, bubble }
  }

  #recordOf(button) { return this.records.find((record) => record.button === button) }

  #checked(button) { return button.getAttribute("aria-checked") === "true" }

  // useControllableState: uncontrolled updates the DOM, both dispatch when the value differs.
  #change(next, userInteraction, propagationStopped = false) {
    if (next === this.value) return
    if (!this.controlledValue) this.#render(next, userInteraction, propagationStopped)
    this.element.dispatchEvent(new CustomEvent("shadcn--radio-group:value-change", { detail: { value: next }, bubbles: true }))
  }

  #render(next, userInteraction, propagationStopped) {
    this.value = next
    for (const record of this.records) {
      const checked = next !== null && record.button.value === next
      if (checked === this.#checked(record.button)) continue
      record.button.setAttribute("aria-checked", String(checked))
      record.button.dataset.state = checked ? "checked" : "unchecked"
      checked ? this.#mountIndicator(record.button) : this.#unmountIndicator(record.button)
      record.bubble.sync({ checked }, { userInteraction, propagationStopped })
    }
  }

  #indicatorOf(button) { return button.querySelector("[data-slot=radio-group-indicator]") }

  #mountIndicator(button) {
    if (this.#indicatorOf(button)) return
    const template = document.createElement("template")
    template.innerHTML = this.indicatorHtmlValue
    const indicator = template.content.firstElementChild
    if (button.hasAttribute("data-disabled")) indicator.setAttribute("data-disabled", "")
    button.append(indicator)
  }

  // Radix Presence: the node stays only while a running exit animation says so.
  #unmountIndicator(button) {
    const indicator = this.#indicatorOf(button)
    if (!indicator) return
    indicator.dataset.state = "unchecked"
    const watcher = presence(indicator, { onExited: () => { indicator.remove(); release() } })
    const release = () => { watcher.release(); this.exiting.delete(release) }
    this.exiting.add(release)
    watcher.exit()
  }
}
