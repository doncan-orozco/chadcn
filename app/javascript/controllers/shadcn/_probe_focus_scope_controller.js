import { Controller } from "@hotwired/stimulus"
import { mountTemplate } from "shadcn/primitives/template_mount"
import { focusScope } from "shadcn/primitives/focus_scope"

// Parity probe for shadcn/primitives/focus_scope (docs/shadcn-port/scenarios/_primitives-focus-scope.json).
export default class extends Controller {
  static targets = ["template"]
  static values = { trapped: Boolean, loop: Boolean, preventMountFocus: Boolean, preventUnmountFocus: Boolean }

  #mount = null
  #release = null

  disconnect() {
    this.close()
  }

  open() {
    if (this.#mount) return
    this.#mount = mountTemplate(this.templateTarget)
    this.#release = focusScope(this.#mount.nodes[0], {
      trapped: this.trappedValue,
      loop: this.loopValue,
      onMountAutoFocus: (event) => this.preventMountFocusValue && event.preventDefault(),
      onUnmountAutoFocus: (event) => this.preventUnmountFocusValue && event.preventDefault(),
    })
  }

  close() {
    if (!this.#mount) return
    this.#release()
    this.#mount.unmount()
    this.#mount = this.#release = null
  }
}
