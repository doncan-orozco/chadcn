import { Controller } from "@hotwired/stimulus"

// Radix Label behavior (docs/shadcn-port/specs/label.md): block text selection on double click.
export default class extends Controller {
  mousedown(event) {
    if (event.target.closest("button, input, select, textarea")) return
    if (!event.defaultPrevented && event.detail > 1) event.preventDefault()
  }
}
