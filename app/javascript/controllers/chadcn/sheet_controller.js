import DialogController from "controllers/chadcn/dialog_controller"

// Radix Dialog as shadcn Sheet. Spec: docs/shadcn-port/specs/sheet.md (Behavior). The behavior is the dialog's: this
// controller only answers to its own identifier (values data-chadcn--sheet-*, host selector) and reuses the markers the
// dialog controller reads from the parts (data-chadcn--dialog-part, data-chadcn--dialog-template).
export default class extends DialogController {
  templates() {
    return [...this.element.querySelectorAll("template[data-chadcn--dialog-template]")].filter(
      (template) => template.getAttribute("data-chadcn--dialog-template") === this.idValue && template.closest("[data-controller~='chadcn--sheet']") === this.element
    )
  }
}
