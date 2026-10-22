import { Controller } from "@hotwired/stimulus"

// shadcn InputGroupAddon onClick: focus the first input of the group unless a button was clicked.
// Spec: docs/shadcn-port/specs/input-group.md (Behavior).
export default class extends Controller {
  focusControl(event) {
    if (event.target.closest("button")) return
    this.element.parentElement?.querySelector("input")?.focus()
  }
}
