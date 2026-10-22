import { Controller } from "@hotwired/stimulus"
import { FormBubbleInput } from "chadcn/primitives/form_bubble_input"
import { presence } from "chadcn/primitives/presence"

// Radix Checkbox behavior (docs/shadcn-port/specs/checkbox.md). Host = the checkbox button.
const ARIA = { checked: "true", unchecked: "false", indeterminate: "mixed" }

export default class extends Controller {
  static values = { controlled: Boolean, indicatorHtml: String }

  connect() {
    this.initialChecked = this.checked
    const input = this.element.nextElementSibling
    this.bubble = new FormBubbleInput(this.element, {
      type: "checkbox",
      name: input?.getAttribute("name"),
      value: this.element.getAttribute("value") ?? "on",
      checked: this.checked === true,
      indeterminate: this.checked === "indeterminate",
      required: input?.required,
      disabled: this.element.disabled,
      form: this.element.getAttribute("form") || input?.getAttribute("form"),
      onReset: () => this.#update(this.initialChecked, false)
    })
    // Not a form control: Radix does not render the bubble input at all.
    if (!this.bubble.present && input?.getAttribute("aria-hidden") === "true") input.remove()
    // The server-rendered initial indicator also leaves no template behind in the DOM.
    this.#watchIndicator()
  }

  disconnect() {
    this.presence?.release()
    this.presence = null
    this.watched = null // the instance is reused on reconnect: connect() must watch the indicator again
    this.bubble?.release()
  }

  get checked() {
    const state = this.element.dataset.state
    return state === "checked" ? true : state === "indeterminate" ? "indeterminate" : false
  }

  keydown(event) {
    if (event.key === "Enter") event.preventDefault()
  }

  toggle(event) {
    if (event.defaultPrevented) return
    const propagationStopped = event.cancelBubble
    if (this.bubble.present && !propagationStopped) event.stopPropagation()
    this.#update(this.checked === "indeterminate" ? true : !this.checked, true, propagationStopped)
  }

  #update(next, userInteraction, propagationStopped = false) {
    if (next === this.checked) return
    if (!this.controlledValue) {
      this.#render(next)
      this.bubble.sync({ checked: next === true, indeterminate: next === "indeterminate" }, { userInteraction, propagationStopped })
    }
    this.element.dispatchEvent(new CustomEvent("chadcn--checkbox:checked-change", { detail: { checked: next }, bubbles: true }))
  }

  #render(checked) {
    const state = checked === true ? "checked" : checked === "indeterminate" ? "indeterminate" : "unchecked"
    this.element.dataset.state = state
    this.element.setAttribute("aria-checked", ARIA[state])
    if (state === "unchecked") return this.#unmountIndicator()
    this.#mountIndicator(state)
  }

  #mountIndicator(state) {
    let indicator = this.element.querySelector("[data-slot=checkbox-indicator]")
    if (!indicator) {
      const template = document.createElement("template")
      template.innerHTML = this.indicatorHtmlValue
      indicator = template.content.firstElementChild
      this.element.append(indicator)
    }
    indicator.dataset.state = state
    this.#watchIndicator()
    this.presence?.enter()
  }

  #unmountIndicator() {
    const indicator = this.element.querySelector("[data-slot=checkbox-indicator]")
    if (!indicator) return
    indicator.dataset.state = "unchecked"
    this.#watchIndicator()
    this.presence.exit()
  }

  #watchIndicator() {
    const indicator = this.element.querySelector("[data-slot=checkbox-indicator]")
    if (this.watched === indicator) return
    this.presence?.release()
    this.watched = indicator
    this.presence = indicator && presence(indicator, { onExited: () => indicator.remove() })
  }
}
