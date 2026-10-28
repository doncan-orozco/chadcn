import { Controller } from "@hotwired/stimulus"

// Chadcn::Form validity (dev/port/specs/form.md, Behavior): mirrors the browser's HTML5 constraint validation into the
// Form::Field contract (data-invalid, aria-invalid, data-error, aria-describedby, the field-error element). Action-only: no
// listeners of its own, all state lives in the DOM, so a Turbo cache restore finds it as it was left.
export default class extends Controller {
  // `invalid` does not bubble: captured on the form. Not prevented, so the native bubble and the focus of the first invalid
  // control stay.
  report(event) {
    this.attempted = true
    this.mirror(event.target)
  }

  // input/change. Before the first submit only a field that already shows an error (client or server: the first edit hands
  // it over to the client) or a committed change re-evaluates.
  edit(event) {
    const control = event.target
    if (!control.willValidate) return
    const field = control.closest("[data-slot=field]")
    if (!field) return
    if (this.attempted || field.dataset.invalid === "true" || event.type === "change") this.mirror(control)
  }

  mirror(control) {
    const field = control.closest("[data-slot=field]")
    if (!field) return
    // validity, not checkValidity(): inside an event it would fire `invalid` again.
    const { valid } = control.validity
    const label = field.querySelector("[data-slot=field-label]")
    const error = field.querySelector("[data-slot=field-error]")
    const labelled = label?.htmlFor ? field.ownerDocument.getElementById(label.htmlFor) : null
    const targets = labelled && labelled !== control ? [control, labelled] : [control]

    if (valid) delete field.dataset.invalid
    else field.dataset.invalid = "true"
    for (const target of targets) target.setAttribute("aria-invalid", valid ? "false" : "true")
    label?.setAttribute("data-error", valid ? "false" : "true")
    if (error) {
      error.textContent = valid ? "" : control.validationMessage
      error.hidden = valid
      if (error.id) for (const target of targets) this.describe(target, error.id, !valid)
    }
  }

  describe(target, id, on) {
    const tokens = (target.getAttribute("aria-describedby") || "").split(/\s+/).filter((token) => token && token !== id)
    if (on) tokens.push(id)
    if (tokens.length) target.setAttribute("aria-describedby", tokens.join(" "))
    else target.removeAttribute("aria-describedby")
  }
}
