import DialogController from "controllers/v2/dialog_controller"

// Radix Dialog as shadcn Sheet. Spec: docs/shadcn-port/specs/sheet.md (Behavior). The behavior is the dialog's: this
// controller only answers to its own identifier (values data-v2--sheet-*, host selector) and reuses the markers the
// dialog controller reads from the parts (data-v2--dialog-part, data-v2--dialog-template).
export default class extends DialogController {
  templates() {
    return [...this.element.querySelectorAll("template[data-v2--dialog-template]")].filter(
      (template) => template.getAttribute("data-v2--dialog-template") === this.idValue && template.closest("[data-controller~='v2--sheet']") === this.element
    )
  }
}
