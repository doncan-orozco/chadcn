import { Controller } from "@hotwired/stimulus"

// Chadcn::Form validity (dev/port/specs/form.md, Behavior): mirrors the browser's HTML5 constraint validation into the
// Form::Field contract (data-invalid, aria-invalid, data-error, aria-describedby, the field-error element). Action-only: no
// listeners of its own, all state lives in the DOM, so a Turbo cache restore finds it as it was left.
export default class extends Controller {
  // `invalid` does not bubble: captured on the form. Not prevented, so the native bubble and the focus of the first invalid
  // control stay. The attempt is remembered in data-chadcn-form-attempted on the form (a Turbo snapshot keeps it).
  report(event) {
    if (this.element.dataset.chadcnFormAttempted !== "true") this.element.dataset.chadcnFormAttempted = "true"
    this.mirror(event.target)
  }

  // input/change/click. Before the first submit only a field that already shows an error (client or server: the first edit hands
  // it over to the client) or a committed change re-evaluates. A click counts only on the hidden native input of a Checkbox,
  // Switch or RadioGroup (the synthetic click of FormBubbleInput is its only notification); any other click is not an edit.
  edit(event) {
    const control = event.target
    if (event.type === "click" && !this.bubbleToggle(control)) return
    if (!control.willValidate || control.form?.noValidate) return
    const field = control.closest("[data-slot=field]")
    if (!field) return
    if (this.element.dataset.chadcnFormAttempted === "true" || field.dataset.invalid === "true" || event.type !== "input") {
      this.mirror(control, field)
    }
  }

  // The field-level state (data-invalid, label, message element) follows every validatable control of the field; the control's
  // own aria-invalid and message link follow its own validity.
  mirror(control, field = control.closest("[data-slot=field]")) {
    if (!field) return
    // validity, not checkValidity(): inside an event it would fire `invalid` again.
    const valid = control.validity.valid
    const invalid = [...field.querySelectorAll("input, select, textarea")].filter((candidate) => candidate.willValidate && !candidate.validity.valid)
    const fieldInvalid = !valid || invalid.length > 0
    // The message shown is the first invalid control's in document order, so it matches the control that takes focus.
    const source = invalid[0] || (valid ? null : control)
    const label = field.querySelector("[data-slot=field-label]")
    // Only the element Form::Field::Error marked is ours; a caller's `field.error { ... }` block is left untouched.
    const error = field.querySelector("[data-slot=field-error][data-chadcn-form-message]")
    const labelled = label?.htmlFor ? field.ownerDocument.getElementById(label.htmlFor) : null
    // The label's `for` target is a proxy only when it is not a native control: Checkbox/Switch/RadioGroup/Select/Slider roots
    // carry the id while a hidden native input holds the validity. A native sibling keeps its own aria-invalid.
    const proxy = labelled && labelled !== control && !labelled.matches("input, select, textarea") ? labelled : null
    const targets = proxy ? [control, proxy] : [control]
    const validOf = (target) => (target.willValidate ? target.validity.valid : valid)

    if (fieldInvalid) field.dataset.invalid = "true"
    else delete field.dataset.invalid
    for (const target of targets) target.setAttribute("aria-invalid", validOf(target) ? "false" : "true")
    label?.setAttribute("data-error", fieldInvalid ? "true" : "false")
    if (error) {
      error.hidden = !fieldInvalid
      const text = source ? source.validationMessage : ""
      if (error.textContent !== text) error.textContent = text
      if (error.id) for (const target of targets) this.toggleMessageLink(target, error.id, !validOf(target))
    }
  }

  // form.reset(): back to the pristine state. Server-rendered errors are cleared too (as react-hook-form's reset does). The
  // decision is taken after dispatch, so a later listener's preventDefault() (a "discard changes?" guard) keeps the errors.
  reset(event) {
    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => {
      if (event.defaultPrevented) return
      this.clear()
    }, 0)
  }

  clear() {
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
        if (error?.id) this.toggleMessageLink(target, error.id, false)
      }
    }
  }

  disconnect() {
    clearTimeout(this.resetTimer)
  }

  // The hidden native checkbox/radio FormBubbleInput mounts after a custom control (aria-hidden); a visible native one is not.
  bubbleToggle(control) {
    return (control.type === "checkbox" || control.type === "radio") && control.getAttribute("aria-hidden") === "true"
  }

  toggleMessageLink(target, id, linked) {
    const tokens = (target.getAttribute("aria-describedby") || "").split(/\s+/).filter((token) => token && token !== id)
    if (linked) tokens.push(id)
    if (tokens.length) target.setAttribute("aria-describedby", tokens.join(" "))
    else target.removeAttribute("aria-describedby")
  }
}
