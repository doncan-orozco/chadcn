import { Controller } from "@hotwired/stimulus"
import { mountTemplate } from "shadcn/primitives/template_mount"
import { hideOthers } from "shadcn/primitives/hide_others"

// Parity probe for shadcn/primitives/hide_others (docs/shadcn-port/scenarios/_primitives-hide-others.json).
export default class extends Controller {
  static targets = ["template"]
  static values = { scope: { type: String, default: "body" } }

  #mounted = new Map()

  connect() {
    this.templateTargets.filter((t) => t.dataset.auto === "true").forEach((t) => this.#mount(t))
  }

  disconnect() {
    ;[...this.#mounted.keys()].forEach((name) => this.#unmount(name))
  }

  toggle({ params: { name } }) {
    if (this.#mounted.has(name)) this.#unmount(name)
    else this.#mount(this.templateTargets.find((t) => t.dataset.name === name))
  }

  #mount(template) {
    const name = template.dataset.name
    const mount = mountTemplate(template, { into: template.dataset.into === "body" ? document.body : "after" })
    const parent = this.scopeValue === "root" ? this.element : document.body
    const release = name.startsWith("modal") ? hideOthers(mount.nodes[0], parent) : () => {}
    this.#mounted.set(name, { mount, release })
  }

  #unmount(name) {
    const { mount, release } = this.#mounted.get(name)
    this.#mounted.delete(name)
    release()
    mount.unmount()
  }
}
