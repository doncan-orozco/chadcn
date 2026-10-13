import DialogController from "controllers/v2/dialog_controller"

// Radix AlertDialog on top of the dialog behavior. Spec: docs/shadcn-port/specs/alert-dialog.md (Behavior). It answers to
// its own identifier and reuses the markers the dialog controller reads (data-v2--dialog-part, data-v2--dialog-template).
//
// AlertDialog's differences (ad:58-63) are applied on the events the dialog controller dispatches from the host:
// - open-auto-focus: always prevented, then the last Cancel is focused (unless the caller prevented it: nothing).
// - pointer-down-outside / interact-outside: always prevented and hidden from the caller, so outside presses never close.
// Listeners sit on window (capture for the hidden ones, bubble for open-auto-focus so caller handlers run first).
export default class extends DialogController {
  connect() {
    super.connect()
    this.abortAlert = new AbortController()
    const { signal } = this.abortAlert
    const own = (event) => event.target === this.element
    const swallow = (event) => {
      if (!own(event)) return
      event.preventDefault()
      event.stopPropagation()
    }
    window.addEventListener(`${this.identifier}:pointer-down-outside`, swallow, { capture: true, signal })
    window.addEventListener(`${this.identifier}:interact-outside`, swallow, { capture: true, signal })
    window.addEventListener(`${this.identifier}:open-auto-focus`, (event) => {
      if (!own(event)) return
      const prevented = event.defaultPrevented
      event.preventDefault()
      if (!prevented) this.#cancel?.focus({ preventScroll: true })
    }, { signal })
  }

  disconnect() {
    this.abortAlert?.abort()
    super.disconnect()
  }

  templates() {
    return [...this.element.querySelectorAll("template[data-v2--dialog-template]")].filter(
      (template) => template.getAttribute("data-v2--dialog-template") === this.idValue && template.closest("[data-controller~='v2--alert-dialog']") === this.element
    )
  }

  // Radix keeps a single cancelRef: the last mounted Cancel wins.
  get #cancel() {
    const cancels = document.querySelectorAll(`[data-v2--alert-dialog-part=cancel][data-v2--alert-dialog-owner="${this.idValue}"]`)
    return [...cancels].at(-1)
  }
}
