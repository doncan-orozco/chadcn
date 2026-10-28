import { Controller } from "@hotwired/stimulus"

// Chadcn::Form validity (dev/port/specs/form.md, Behavior): mirrors the browser's HTML5 constraint validation into the
// Form::Field contract (data-invalid, aria-invalid, data-error, aria-describedby, the field-error element). Action-only: no
// listeners of its own, all state lives in the DOM, so a Turbo cache restore finds it as it was left.
export default class extends Controller {
  // `invalid` does not bubble: captured on the form. Not prevented, so the native bubble and the focus of the first invalid
  // control stay. The attempt is remembered in data-chadcn-form-attempted on the form (a Turbo snapshot keeps it).
  report(event) {
    this.element.dataset.chadcnFormAttempted = "true"
    this.mirror(event.target)
  }

  // input/change. Before the first submit only a field that already shows an error (client or server: the first edit hands
  // it over to the client) or a committed change re-evaluates.
  edit(event) {
    const control = event.target
    if (!control.willValidate || control.form?.noValidate) return
    const field = control.closest("[data-slot=field]")
    if (!field) return
    if (this.element.dataset.chadcnFormAttempted === "true" || field.dataset.invalid === "true" || event.type === "change") {
      this.mirror(control, field)
    }
  }

  // The field-level state (data-invalid, label, message element) follows every validatable control of the field; the control's
  // own aria-invalid and message link follow its own validity.
  mirror(control, field = control.closest("[data-slot=field]")) {
    if (!field) return
    // validity, not checkValidity(): inside an event it would fire `invalid` again.
    const valid = control.validity.valid
    const invalid = [...field.querySelectorAll("input, select, textarea")].filter((el) => el.willValidate && !el.validity.valid)
    const fieldInvalid = !valid || invalid.length > 0
    const source = valid ? invalid[0] : control
    const label = field.querySelector("[data-slot=field-label]")
    // Only the element Form::Field::Error marked is ours; a caller's `field.error { ... }` block is left untouched.
    const error = field.querySelector("[data-slot=field-error][data-chadcn-form-message]")
    const labelled = label?.htmlFor ? field.ownerDocument.getElementById(label.htmlFor) : null
    const targets = labelled && labelled !== control ? [control, labelled] : [control]

    if (fieldInvalid) field.dataset.invalid = "true"
    else delete field.dataset.invalid
    for (const target of targets) target.setAttribute("aria-invalid", valid ? "false" : "true")
    label?.setAttribute("data-error", fieldInvalid ? "true" : "false")
    if (error) {
      const text = source ? source.validationMessage : ""
      if (error.textContent !== text) error.textContent = text
      error.hidden = !fieldInvalid
      if (error.id) for (const target of targets) this.describe(target, error.id, !valid)
    }
  }

  // form.reset(): back to the pristine state. Server-rendered errors are cleared too (as react-hook-form's reset does).
  reset() {
    delete this.element.dataset.chadcnFormAttempted
    for (const field of this.element.querySelectorAll("[data-slot=field][data-invalid]")) {
      delete field.dataset.invalid
      field.querySelector("[data-slot=field-label]")?.setAttribute("data-error", "false")
      const error = field.querySelector("[data-slot=field-error][data-chadcn-form-message]")
      if (error) {
        error.textContent = ""
        error.hidden = true
      }
      for (const target of field.querySelectorAll("[aria-invalid]")) {
        target.setAttribute("aria-invalid", "false")
        if (error?.id) this.describe(target, error.id, false)
      }
    }
  }

  describe(target, id, on) {
    const tokens = (target.getAttribute("aria-describedby") || "").split(/\s+/).filter((token) => token && token !== id)
    if (on) tokens.push(id)
    if (tokens.length) target.setAttribute("aria-describedby", tokens.join(" "))
    else target.removeAttribute("aria-describedby")
  }
}
