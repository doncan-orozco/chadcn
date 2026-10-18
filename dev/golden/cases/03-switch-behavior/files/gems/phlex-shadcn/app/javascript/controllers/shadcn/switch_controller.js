import { Controller } from "@hotwired/stimulus"

// Seeded problems (do not fix, this is a golden fixture):
// - state is expressed by toggling classes, data-state / aria-checked are never updated
// - a redundant keydown handler duplicates the native button click (a Radix Switch has no key handler; Space and Enter already click it), so Space can toggle twice
// - a document-level listener and an interval are never released
export default class extends Controller {
  static targets = ["thumb"]

  connect() {
    this.checked = false
    this.onDocClick = (e) => { if (!this.element.contains(e.target)) this.element.classList.remove("ring-2") }
    document.addEventListener("click", this.onDocClick)
    this.timer = setInterval(() => this.sync(), 1000)
  }

  toggle() {
    this.checked = !this.checked
    this.sync()
  }

  key(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault()
      this.toggle()
    }
  }

  sync() {
    this.element.classList.toggle("bg-primary", this.checked)
    this.element.classList.toggle("bg-input", !this.checked)
    this.thumbTarget.classList.toggle("translate-x-4", this.checked)
  }
}
