import { Controller } from "@hotwired/stimulus"
import { ensureId } from "chadcn/primitives/ids"

// Parity probe for chadcn/primitives/ids (scenarios _primitives-ids): wires trigger aria-controls to the panel id (server id first).
export default class extends Controller {
  connect() {
    const trigger = this.element.querySelector("[data-slot=trigger]")
    const panel = this.element.querySelector("[data-slot=panel]")
    const server = panel.id
    ensureId(panel, "radix")
    trigger.setAttribute("aria-controls", panel.id)
    trigger.dataset.idSource = server ? (panel.id === server ? "server" : "CHANGED") : panel.id.startsWith("radix-") ? "generated" : "EMPTY"
  }
}
