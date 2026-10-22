import { Controller } from "@hotwired/stimulus"
import { portal } from "chadcn/primitives/portal"

// Parity probe for chadcn/primitives/portal (docs/shadcn-port/scenarios/_primitives-portal.json).
export default class extends Controller {
  static targets = ["item"]
  static values = { container: String }

  #release = null
  #item = null

  connect() {
    this.#item = this.itemTarget // targets are looked up inside the controller element, which the portal leaves
    this.#portal()
  }

  disconnect() {
    this.#release?.()
  }

  toggle() {
    if (this.#release) {
      this.#release()
      this.#release = null
    } else {
      this.#portal()
    }
  }

  #portal() {
    const container = this.hasContainerValue ? document.querySelector(this.containerValue) : document.body
    this.#release = portal(this.#item, container)
  }
}
