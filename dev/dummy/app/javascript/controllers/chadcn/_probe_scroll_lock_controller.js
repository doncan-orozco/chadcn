import { Controller } from "@hotwired/stimulus"
import { scrollLock } from "chadcn/primitives/scroll_lock"

// Parity probe for chadcn/primitives/scroll_lock (docs/shadcn-port/scenarios/_primitives-scroll-lock.json).
// Each named holder takes a lock on its first toggle and releases it on the next one.
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
      this.#holders.set(name, scrollLock())
    }
  }
}
