import { Controller } from "@hotwired/stimulus"
import { rovingFocus } from "chadcn/primitives/roving_focus"

// Parity probe for chadcn/primitives/roving_focus (scenarios _primitives-roving-focus). Config comes from data-roving-* attributes
// so the same tree also drives the raw Radix group in React.
export default class extends Controller {
  connect() {
    const data = this.element.dataset
    this.roving = rovingFocus(this.element, {
      orientation: data.orientation,
      loop: data.rovingLoop === "true",
      dir: data.rovingDir,
      currentTabStopId: data.rovingCurrent,
      isActive: (el) => el.hasAttribute("data-active"),
    })
  }

  disconnect() {
    this.roving.release()
  }
}
