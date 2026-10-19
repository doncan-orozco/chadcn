import { Controller } from "@hotwired/stimulus"
import { mountTemplate } from "shadcn/primitives/template_mount"
import { dismissable } from "shadcn/primitives/dismissable_layer"

// Parity probe for shadcn/primitives/dismissable_layer (docs/shadcn-port/scenarios/_primitives-dismissable-layer.json).
// Each <template data-name="x"> is a layer; open/close take a `name` param.
export default class extends Controller {
  static targets = ["template"]
  static values = { modal: Boolean, preventEscape: Boolean, preventOutside: Boolean }

  #layers = new Map()

  disconnect() {
    ;[...this.#layers.keys()].forEach((name) => this.#close(name))
  }

  open({ params: { name } }) {
    if (this.#layers.has(name)) return
    const template = this.templateTargets.find((t) => (t.dataset.name ?? "default") === name)
    const mount = mountTemplate(template)
    const release = dismissable(mount.nodes[0], {
      disableOutsidePointerEvents: this.modalValue,
      onEscape: (event) => this.preventEscapeValue && event.preventDefault(),
      onPointerDownOutside: (event) => this.preventOutsideValue && event.preventDefault(),
      onFocusOutside: (event) => this.preventOutsideValue && event.preventDefault(),
      onDismiss: () => this.#close(name),
    })
    this.#layers.set(name, { mount, release })
  }

  close({ params: { name } }) {
    this.#close(name)
  }

  #close(name) {
    const layer = this.#layers.get(name)
    if (!layer) return
    this.#layers.delete(name)
    layer.release()
    layer.mount.unmount()
  }
}
