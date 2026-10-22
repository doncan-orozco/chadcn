import { Controller } from "@hotwired/stimulus"
import { mountTemplate } from "chadcn/primitives/template_mount"

// Parity probe for chadcn/primitives/template_mount (docs/shadcn-port/scenarios/_primitives-template-mount.json).
export default class extends Controller {
  static targets = ["template"]
  static values = { into: { type: String, default: "after" } }

  #mount = null

  disconnect() {
    this.#mount?.unmount()
  }

  toggle() {
    if (this.#mount) {
      this.#mount.unmount()
      this.#mount = null
    } else {
      this.#mount = mountTemplate(this.templateTarget, { into: this.intoValue === "body" ? document.body : "after" })
    }
  }
}
