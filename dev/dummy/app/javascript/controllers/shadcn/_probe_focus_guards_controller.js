import { Controller } from "@hotwired/stimulus"
import { focusGuards } from "shadcn/primitives/focus_guards"

// Parity probe for shadcn/primitives/focus_guards (docs/shadcn-port/scenarios/_primitives-focus-guards.json).
// Each named holder takes the guards on its first toggle and gives them back on the next one.
export default class extends Controller {
  #holders = new Map()

  disconnect() {
    this.#holders.forEach((release) => release())
    this.#holders.clear()
  }

  toggle({ params: { name } }) {
    const release = this.#holders.get(name)
    if (release) {
      release()
      this.#holders.delete(name)
    } else {
      this.#holders.set(name, focusGuards())
    }
  }
}
