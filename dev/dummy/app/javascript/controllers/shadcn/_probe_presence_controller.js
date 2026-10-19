import { Controller } from "@hotwired/stimulus"
import { mountTemplate } from "shadcn/primitives/template_mount"
import { presence } from "shadcn/primitives/presence"

// Parity probe for shadcn/primitives/presence + template_mount (docs/shadcn-port/scenarios/_primitives-presence.json).
export default class extends Controller {
  static targets = ["template"]
  static values = { open: Boolean }

  #mount = null
  #presence = null

  connect() {
    if (this.openValue) this.#open()
  }

  disconnect() {
    this.#presence?.release()
    this.#mount?.unmount()
  }

  toggle() {
    if (!this.#mount) return this.#open()
    const panel = this.#mount.nodes[0]
    if (panel.dataset.state === "open") {
      panel.dataset.state = "closed"
      this.#presence.exit()
    } else {
      // Re-opened while the exit animation runs: Radix Presence cancels the unmount.
      panel.dataset.state = "open"
      this.#presence.enter()
    }
  }

  #open() {
    this.#mount = mountTemplate(this.templateTarget)
    const panel = this.#mount.nodes[0]
    panel.dataset.state = "open"
    this.#presence = presence(panel, {
      onExited: () => {
        this.#presence.release()
        this.#mount.unmount()
        this.#mount = this.#presence = null
      },
    })
  }
}
