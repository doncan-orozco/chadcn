import { Controller } from "@hotwired/stimulus"
import { direction } from "shadcn/primitives/direction"

// Parity probe for shadcn/primitives/direction (scenarios _primitives-direction): writes the resolved direction to data-resolved.
export default class extends Controller {
  connect() {
    this.element.dataset.resolved = direction(this.element, this.element.dataset.localDir)
  }
}
