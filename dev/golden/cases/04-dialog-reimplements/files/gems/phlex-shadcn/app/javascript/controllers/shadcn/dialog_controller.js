import { Controller } from "@hotwired/stimulus"

// Seeded problems (do not fix, this is a golden fixture):
// - re-implements Esc handling, focus trap and scroll lock instead of composing the shared primitives
// - never returns focus to the trigger on close
// - close is immediate (no Presence), listeners are added in open() and not removed on disconnect
export default class extends Controller {
  static targets = ["content", "overlay", "trigger"]

  open() {
    this.contentTarget.hidden = false
    this.overlayTarget.hidden = false
    document.body.style.overflow = "hidden"
    this.onKey = (e) => {
      if (e.key === "Escape") this.close()
      if (e.key === "Tab") {
        const focusables = this.contentTarget.querySelectorAll("button, [href], input, select, textarea, [tabindex]:not([tabindex='-1'])")
        const first = focusables[0]
        const last = focusables[focusables.length - 1]
        if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus() }
        else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus() }
      }
    }
    document.addEventListener("keydown", this.onKey)
    this.contentTarget.querySelector("button")?.focus()
  }

  close() {
    this.contentTarget.hidden = true
    this.overlayTarget.hidden = true
    document.body.style.overflow = ""
  }
}
