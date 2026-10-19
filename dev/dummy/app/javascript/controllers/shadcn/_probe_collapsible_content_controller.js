import { Controller } from "@hotwired/stimulus"
import { mountTemplate } from "shadcn/primitives/template_mount"
import { collapsibleContent } from "shadcn/primitives/collapsible_content"

// Parity probe for shadcn/primitives/collapsible_content (docs/shadcn-port/scenarios/_primitives-collapsible-content.json).
export default class extends Controller {
  static targets = ["trigger", "content", "template"]
  static values = { open: Boolean }

  #mount = null
  #content = null

  connect() {
    if (this.openValue) this.#mountChildren()
    this.#content = collapsibleContent(this.contentTarget, { open: this.openValue, onExited: () => this.#unmountChildren() })
  }

  disconnect() {
    this.#content.release()
    this.#unmountChildren()
  }

  toggle() {
    this.openValue = !this.openValue
    const state = this.openValue ? "open" : "closed"
    this.element.dataset.state = this.triggerTarget.dataset.state = state
    this.triggerTarget.setAttribute("aria-expanded", String(this.openValue))
    // Radix only wires aria-controls while the content is open.
    if (this.openValue) this.triggerTarget.setAttribute("aria-controls", this.contentTarget.id)
    else this.triggerTarget.removeAttribute("aria-controls")
    if (this.openValue) this.#mountChildren()
    this.#content.setOpen(this.openValue)
  }

  #mountChildren() {
    this.#mount ??= mountTemplate(this.templateTarget)
  }

  #unmountChildren() {
    this.#mount?.unmount()
    this.#mount = null
  }
}
